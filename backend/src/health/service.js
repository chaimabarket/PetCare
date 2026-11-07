// Règles métier du module Santé : seul le propriétaire accède au carnet, un animal archivé ne se modifie plus,
// prises de traitement, arrêts et synthèse de l'onglet Santé. Ni Express ni Firestore ici.

const { ApiError } = require('../firestore');
const { PET_STATUS } = require('../pets/enums');
const E = require('./enums');
const { entryFields, treatmentFields, attachments, doseTime, stopReason } = require('./validation');

const DAY_MS = 24 * 60 * 60 * 1000;

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

function createHealthService(repository) {
  async function petOrFail(token, uid, petId) {
    const pet = await repository.getPet(token, petId);
    if (!pet) throw new ApiError(404, 'Animal introuvable.');
    if (pet.ownerId !== uid) throw new ApiError(403, "Cet animal n'est pas le vôtre.");
    return pet;
  }

  /** Le carnet d'un animal archivé se consulte, mais ne se modifie plus. */
  async function activePetOrFail(token, uid, petId) {
    const pet = await petOrFail(token, uid, petId);
    if (pet.status === PET_STATUS.archived) throw new ApiError(409, "Restaurez d'abord cet animal pour modifier son carnet.");
    return pet;
  }

  async function treatmentOrFail(token, petId, treatmentId) {
    const treatment = await repository.getTreatment(token, petId, treatmentId);
    if (!treatment) throw new ApiError(404, 'Traitement introuvable.');
    return treatment;
  }

  return {
    // ----------------------------------------------------------- Carnet

    listEntries: (token, petId) => repository.listEntries(token, petId, { ordered: true }),

    async getEntry(token, petId, entryId) {
      const entry = await repository.getEntry(token, petId, entryId);
      if (!entry) throw new ApiError(404, 'Soin introuvable.');
      return entry;
    },

    /** Ajoute un soin et ses pièces jointes en une seule écriture atomique. */
    async addEntry(token, user, petId, body) {
      const fields = entryFields(body);
      const files = attachments(body.attachments);
      const pet = await activePetOrFail(token, user.uid, petId);

      const entryId = await repository.createEntry(token, pet.id, {
        data: { ...fields, ownerId: user.uid, reminderDone: false },
        files,
      });
      invalidateSummary(user.uid);
      return repository.getEntry(token, pet.id, entryId);
    },

    /** Bouton ✓✓ « rappel déjà fait » de la carte « Prochain rappel vaccinal ». */
    async markReminderDone(token, user, petId, entryId) {
      const pet = await activePetOrFail(token, user.uid, petId);
      await repository.markReminderDone(token, pet.id, entryId);
      invalidateSummary(user.uid);
    },

    /** Pièce jointe : `{ name, mimeType, data }`, le contenu en base64. */
    async getEntryFile(token, petId, entryId, index) {
      const file = await repository.getEntryFile(token, petId, entryId, index);
      if (!file) throw new ApiError(404, 'Pièce jointe introuvable.');
      return { name: file.name, mimeType: file.mimeType, data: file.data };
    },

    async deleteEntry(token, user, petId, entryId) {
      const pet = await activePetOrFail(token, user.uid, petId);
      await repository.deleteEntry(token, pet.id, entryId);
      invalidateSummary(user.uid);
    },

    // ----------------------------------------------------------- Traitements

    listTreatments: (token, petId) => repository.listTreatments(token, petId, { ordered: true }),

    getTreatment: treatmentOrFail,

    async addTreatment(token, user, petId, body) {
      const fields = treatmentFields(body);
      const pet = await activePetOrFail(token, user.uid, petId);
      const treatmentId = await repository.createTreatment(token, pet.id, {
        ...fields,
        ownerId: user.uid,
        doses: [],
        stoppedAt: null,
        stopReason: null,
      });
      invalidateSummary(user.uid);
      return repository.getTreatment(token, pet.id, treatmentId);
    },

    /** « Noter la prise » : maintenant, ou à l'heure `at` du créneau coché dans le tableau du jour. */
    async addDose(token, user, petId, treatmentId, body) {
      const pet = await activePetOrFail(token, user.uid, petId);
      const treatment = await treatmentOrFail(token, petId, treatmentId);
      if (treatment.stoppedAt) throw new ApiError(409, 'Ce traitement est arrêté.');
      const at = doseTime(body, treatment);
      if ((treatment.doses || []).some((d) => new Date(d).getTime() === at.getTime())) {
        throw new ApiError(409, 'Cette prise est déjà notée.');
      }

      await repository.addDose(token, pet.id, treatment.id, at);
      invalidateSummary(user.uid);
      return repository.getTreatment(token, pet.id, treatment.id);
    },

    /** Arrêt avant la date de fin prévue, avec la raison donnée par le praticien. */
    async stopTreatment(token, user, petId, treatmentId, body) {
      const reason = stopReason(body);
      const pet = await activePetOrFail(token, user.uid, petId);
      const treatment = await treatmentOrFail(token, petId, treatmentId);
      if (treatment.stoppedAt) throw new ApiError(409, 'Ce traitement est déjà arrêté.');
      if (new Date(treatment.endDate).getTime() + DAY_MS < Date.now()) throw new ApiError(409, 'Ce traitement est déjà terminé.');

      await repository.stopTreatment(token, pet.id, treatment.id, reason);
      invalidateSummary(user.uid);
      return repository.getTreatment(token, pet.id, treatment.id);
    },

    // ----------------------------------------------------------- Synthèse

    /** Synthèse de tous mes animaux, en un seul appel (gardée 30 s). */
    async summary(token, uid) {
      const cached = summaryCache.get(uid);
      if (cached && cached.expires > Date.now()) return cached.data;

      const pets = await repository.listPetsByOwner(token, uid);
      const summaries = await Promise.all(pets.map(async (pet) => {
        const [entries, treatments] = await Promise.all([
          repository.listEntries(token, pet.id),
          repository.listTreatments(token, pet.id),
        ]);
        return petSummary(pet, entries, treatments);
      }));
      const data = { generatedAt: new Date().toISOString(), pets: summaries.sort((a, b) => a.name.localeCompare(b.name)) };

      summaryCache.set(uid, { data, expires: Date.now() + SUMMARY_TTL_MS });
      return data;
    },
  };
}

module.exports = { createHealthService, petSummary, invalidateSummary };
