const express = require('express');

const { requireAuth } = require('../auth');
const {
  ApiError, getDocument, writeDocument, writeOp, deleteOp, commit, queryCollection, newId,
} = require('../firestore');
const { PET_STATUS } = require('../pets/enums');
const E = require('./enums');
const {
  entryFields, treatmentFields, attachments, doseTime, stopReason,
} = require('./validation');

const wrap = (handler) => (req, res, next) => Promise.resolve(handler(req, res)).catch(next);

const DAY_MS = 24 * 60 * 60 * 1000;

const petPath = (id) => `pets/${id}`;
const entryPath = (petId, id) => `pets/${petId}/healthEntries/${id}`;
const filePath = (petId, entryId, index) => `${entryPath(petId, entryId)}/files/${index}`;
const treatmentPath = (petId, id) => `pets/${petId}/treatments/${id}`;

// ------------------------------------------------------------------ Synthèse en cache

/**
 * Synthèse de l'onglet Santé gardée 30 s par utilisateur : l'onglet, le tableau du jour et la carte de
 * l'Accueil la demandent en même temps, et le quota Firestore gratuit est limité.
 * Toute écriture santé de l'utilisateur la vide.
 */
const SUMMARY_TTL_MS = 30 * 1000;
const summaryCache = new Map();

function invalidateSummary(uid) {
  summaryCache.delete(uid);
}

async function petOrFail(req) {
  const pet = await getDocument(req.token, petPath(req.params.petId));
  if (!pet) throw new ApiError(404, 'Animal introuvable.');
  if (pet.ownerId !== req.user.uid) throw new ApiError(403, "Cet animal n'est pas le vôtre.");
  return pet;
}

/** Le carnet d'un animal archivé se consulte, mais ne se modifie plus. */
async function activePetOrFail(req) {
  const pet = await petOrFail(req);
  if (pet.status === PET_STATUS.archived) {
    throw new ApiError(409, "Restaurez d'abord cet animal pour modifier son carnet.");
  }
  return pet;
}

/** Après une écriture : la synthèse de l'utilisateur sera relue au prochain appel. */
function written(req) {
  invalidateSummary(req.user.uid);
}

/**
 * Carnet de santé et traitements d'un animal : `/api/pets/{petId}/health/...`.
 *
 * Les données sont dans `pets/{petId}/healthEntries` et `pets/{petId}/treatments`. Le serveur appelle
 * Firestore avec le jeton de l'utilisateur : seul le propriétaire de l'animal y a accès (règles du module 2).
 */
function healthRouter() {
  const router = express.Router({ mergeParams: true });
  router.use(requireAuth);

  async function treatmentOrFail(req) {
    const treatment = await getDocument(req.token, treatmentPath(req.params.petId, req.params.treatmentId));
    if (!treatment) throw new ApiError(404, 'Traitement introuvable.');
    return treatment;
  }

  // ------------------------------------------------------------------ Carnet

  /** Soins du carnet, du plus récent au plus ancien. */
  router.get('/entries', wrap(async (req, res) => {
    res.json(await queryCollection(req.token, petPath(req.params.petId), 'healthEntries', { orderBy: 'date' }));
  }));

  router.get('/entries/:entryId', wrap(async (req, res) => {
    const entry = await getDocument(req.token, entryPath(req.params.petId, req.params.entryId));
    if (!entry) throw new ApiError(404, 'Soin introuvable.');
    res.json(entry);
  }));

  /** Ajoute un soin et ses pièces jointes en une seule écriture atomique. */
  router.post('/entries', wrap(async (req, res) => {
    const fields = entryFields(req.body);
    const files = attachments(req.body.attachments);
    const pet = await activePetOrFail(req);
    const id = newId();

    await commit(req.token, [
      writeOp(entryPath(pet.id, id), {
        ...fields,
        ownerId: req.user.uid,
        reminderDone: false,
        attachments: files.map((f) => ({ name: f.name, mimeType: f.mimeType, size: f.bytes.length })),
      }, { serverTimestamps: ['createdAt'], mustNotExist: true }),
      ...files.map((f, i) => writeOp(filePath(pet.id, id, i), {
        name: f.name,
        mimeType: f.mimeType,
        data: f.bytes,
      }, { replace: true, mustNotExist: true })),
    ]);
    written(req);
    res.status(201).json(await getDocument(req.token, entryPath(pet.id, id)));
  }));

  /** Bouton ✓✓ « rappel déjà fait » de la carte « Prochain rappel vaccinal ». */
  router.patch('/entries/:entryId/reminder-done', wrap(async (req, res) => {
    const pet = await activePetOrFail(req);
    await writeDocument(req.token, entryPath(pet.id, req.params.entryId), { reminderDone: true }, { mustExist: true });
    written(req);
    res.status(204).end();
  }));

  /** Pièce jointe : `{ name, mimeType, data }`, le contenu en base64. */
  router.get('/entries/:entryId/files/:index', wrap(async (req, res) => {
    const file = await getDocument(req.token, filePath(req.params.petId, req.params.entryId, req.params.index));
    if (!file) throw new ApiError(404, 'Pièce jointe introuvable.');
    res.json({ name: file.name, mimeType: file.mimeType, data: file.data });
  }));

  router.delete('/entries/:entryId', wrap(async (req, res) => {
    const pet = await activePetOrFail(req);
    const writes = [];
    for (let i = 0; i < E.MAX_ATTACHMENTS; i += 1) writes.push(deleteOp(filePath(pet.id, req.params.entryId, i)));
    writes.push(deleteOp(entryPath(pet.id, req.params.entryId)));
    await commit(req.token, writes);
    written(req);
    res.status(204).end();
  }));

  // ------------------------------------------------------------------ Traitements

  router.get('/treatments', wrap(async (req, res) => {
    res.json(await queryCollection(req.token, petPath(req.params.petId), 'treatments', { orderBy: 'startDate' }));
  }));

  router.get('/treatments/:treatmentId', wrap(async (req, res) => {
    res.json(await treatmentOrFail(req));
  }));

  router.post('/treatments', wrap(async (req, res) => {
    const fields = treatmentFields(req.body);
    const pet = await activePetOrFail(req);
    const id = newId();
    await writeDocument(req.token, treatmentPath(pet.id, id), {
      ...fields,
      ownerId: req.user.uid,
      doses: [],
      stoppedAt: null,
      stopReason: null,
    }, { serverTimestamps: ['createdAt'], mustNotExist: true });
    written(req);
    res.status(201).json(await getDocument(req.token, treatmentPath(pet.id, id)));
  }));

  /** « Noter la prise » : maintenant, ou à l'heure `at` du créneau coché dans le tableau du jour. */
  router.post('/treatments/:treatmentId/doses', wrap(async (req, res) => {
    const pet = await activePetOrFail(req);
    const treatment = await treatmentOrFail(req);
    if (treatment.stoppedAt) throw new ApiError(409, 'Ce traitement est arrêté.');
    const at = doseTime(req.body, treatment);
    if ((treatment.doses || []).some((d) => new Date(d).getTime() === at.getTime())) {
      throw new ApiError(409, 'Cette prise est déjà notée.');
    }

    // Ajout à la liste par Firestore : les règles n'acceptent qu'une prise de plus à chaque écriture.
    const write = writeOp(treatmentPath(pet.id, treatment.id), {}, { mustExist: true });
    write.updateTransforms = [{
      fieldPath: 'doses',
      appendMissingElements: { values: [{ timestampValue: at.toISOString() }] },
    }];
    await commit(req.token, [write]);
    written(req);
    res.status(201).json(await getDocument(req.token, treatmentPath(pet.id, treatment.id)));
  }));

  /** Arrêt avant la date de fin prévue, avec la raison donnée par le praticien. */
  router.post('/treatments/:treatmentId/stop', wrap(async (req, res) => {
    const reason = stopReason(req.body);
    const pet = await activePetOrFail(req);
    const treatment = await treatmentOrFail(req);
    if (treatment.stoppedAt) throw new ApiError(409, 'Ce traitement est déjà arrêté.');
    if (new Date(treatment.endDate).getTime() + DAY_MS < Date.now()) {
      throw new ApiError(409, 'Ce traitement est déjà terminé.');
    }

    await writeDocument(req.token, treatmentPath(pet.id, treatment.id), { stopReason: reason }, {
      serverTimestamps: ['stoppedAt'],
      mustExist: true,
    });
    written(req);
    res.json(await getDocument(req.token, treatmentPath(pet.id, treatment.id)));
  }));

  return router;
}

// ------------------------------------------------------------------ Synthèse

const byDateDesc = (field) => (a, b) => new Date(b[field] || 0) - new Date(a[field] || 0);

/**
 * Résumé santé d'un animal. Les statuts (« en retard », prises du jour) dépendent du fuseau horaire du
 * téléphone : ils sont calculés dans l'application à partir de ces données brutes.
 */
function petSummary(pet, entries, treatments, now = Date.now()) {
  const lastVisit = entries
    .filter((e) => e.type === E.ENTRY_TYPE.visit || e.type === E.ENTRY_TYPE.exam)
    .sort(byDateDesc('date'))[0];
  const running = treatments.filter((t) => !t.stoppedAt && new Date(t.endDate).getTime() + DAY_MS >= now);

  return {
    id: pet.id,
    name: pet.name,
    species: pet.species,
    breed: pet.breed ?? null,
    status: pet.status,
    pendingVaccines: entries
      .filter((e) => e.type === E.ENTRY_TYPE.vaccine && e.nextReminderAt && !e.reminderDone)
      .map(({ id, title, vaccineName, date, nextReminderAt, practitioner }) => ({
        id, title, vaccineName: vaccineName ?? null, date, nextReminderAt, practitioner: practitioner ?? null,
      }))
      .sort((a, b) => new Date(a.nextReminderAt) - new Date(b.nextReminderAt)),
    lastVisit: lastVisit
      ? {
        id: lastVisit.id, type: lastVisit.type, title: lastVisit.title, date: lastVisit.date, practitioner: lastVisit.practitioner ?? null,
      }
      : null,
    allergies: entries
      .filter((e) => e.type === E.ENTRY_TYPE.allergy)
      .sort(byDateDesc('date'))
      .map(({ id, title }) => ({ id, title })),
    activeTreatments: running.map(({ ownerId, createdAt, ...t }) => t),
  };
}

/** `/api/health` : synthèse de tous mes animaux, en un seul appel. */
function healthSummaryRouter() {
  const router = express.Router();
  router.use(requireAuth);

  router.get('/summary', wrap(async (req, res) => {
    const { uid } = req.user;
    const cached = summaryCache.get(uid);
    if (cached && cached.expires > Date.now()) return res.json(cached.data);

    const pets = await queryCollection(req.token, null, 'pets', { where: { field: 'ownerId', value: uid } });
    const summaries = await Promise.all(pets.map(async (pet) => {
      const [entries, treatments] = await Promise.all([
        queryCollection(req.token, petPath(pet.id), 'healthEntries'),
        queryCollection(req.token, petPath(pet.id), 'treatments'),
      ]);
      return petSummary(pet, entries, treatments);
    }));
    const data = { generatedAt: new Date().toISOString(), pets: summaries.sort((a, b) => a.name.localeCompare(b.name)) };

    summaryCache.set(uid, { data, expires: Date.now() + SUMMARY_TTL_MS });
    return res.json(data);
  }));

  return router;
}

module.exports = {
  healthRouter, healthSummaryRouter, petSummary, invalidateSummary,
};
