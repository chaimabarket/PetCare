const express = require('express');

const { requireAuth } = require('../auth');
const {
  ApiError, getDocument, writeDocument, writeOp, deleteOp, commit, queryCollection, newId,
} = require('../firestore');
const E = require('./enums');
const {
  petFields, petPatch, photoBytes, gallery, weightEntry, weightCorrection, MAX_PHOTOS,
} = require('./validation');

const wrap = (handler) => (req, res, next) => Promise.resolve(handler(req, res)).catch(next);

const newestFirst = (a, b) => new Date(b.createdAt || 0) - new Date(a.createdAt || 0);

const petPath = (id) => `pets/${id}`;
const photoPath = (petId, id) => `pets/${petId}/photos/${id}`;
const weightPath = (petId, id) => `pets/${petId}/weights/${id}`;

async function petOrFail(req) {
  const pet = await getDocument(req.token, petPath(req.params.id));
  if (!pet) throw new ApiError(404, 'Animal introuvable.');
  if (pet.ownerId !== req.user.uid) throw new ApiError(403, "Cet animal n'est pas le vôtre.");
  return pet;
}

/** Un animal archivé reste consultable, mais il faut le restaurer avant de le modifier. */
async function activePetOrFail(req) {
  const pet = await petOrFail(req);
  if (pet.status === E.PET_STATUS.archived) {
    throw new ApiError(409, "Restaurez d'abord cet animal pour le modifier.");
  }
  return pet;
}

async function galleryOf(token, petId) {
  const docs = await queryCollection(token, petPath(petId), 'photos');
  return docs.sort((a, b) => a.sortOrder - b.sortOrder);
}

function newPhotoOp(petId, bytes, sortOrder) {
  return writeOp(photoPath(petId, newId()), { data: bytes, sortOrder }, {
    serverTimestamps: ['createdAt'],
    replace: true,
    mustNotExist: true,
  });
}

/** Écritures qui donnent à chaque photo sa position dans [ordered], la première en couverture. */
function reorderOps(petId, ordered) {
  return ordered.flatMap((photo, sortOrder) => (photo.sortOrder === sortOrder
    ? []
    : [writeOp(photoPath(petId, photo.id), { sortOrder }, { mustExist: true })]));
}

/** Pesée du jour enregistrée avec la fiche : elle remplace une éventuelle mesure de ce jour. */
function todayWeightOp(petId, body) {
  const { id, data } = weightEntry(body);
  return writeOp(weightPath(petId, id), data, { serverTimestamps: ['createdAt'], replace: true });
}

function petsRouter() {
  const router = express.Router();
  router.use(requireAuth);

  // ------------------------------------------------------------------ Fiches

  /** Mes animaux, les plus récents d'abord. `?status=active` ou `archived` pour filtrer. */
  router.get('/', wrap(async (req, res) => {
    const { status } = req.query;
    if (status !== undefined && !Object.values(E.PET_STATUS).includes(status)) {
      throw new ApiError(400, 'Le statut est invalide.');
    }
    const mine = await queryCollection(req.token, null, 'pets', {
      where: { field: 'ownerId', value: req.user.uid },
    });
    res.json(mine.filter((p) => !status || p.status === status).sort(newestFirst));
  }));

  /** Crée la fiche, ses photos et sa première pesée en une seule écriture atomique. */
  router.post('/', wrap(async (req, res) => {
    const fields = petFields(req.body);
    const photos = gallery(req.body.photos ?? []);
    if (photos.some((p) => p.id)) throw new ApiError(400, 'Une photo est invalide.');

    const id = newId();
    const writes = [
      writeOp(petPath(id), {
        ...fields,
        ownerId: req.user.uid,
        status: E.PET_STATUS.active,
        archivedReason: null,
        favorite: false,
        contacts: [],
      }, { serverTimestamps: ['createdAt', 'updatedAt'], mustNotExist: true }),
      ...photos.map((p, i) => newPhotoOp(id, p.bytes, i)),
    ];
    if (req.body.weight) writes.push(todayWeightOp(id, req.body.weight));

    await commit(req.token, writes);
    res.status(201).json(await getDocument(req.token, petPath(id)));
  }));

  router.get('/:id', wrap(async (req, res) => {
    res.json(await petOrFail(req));
  }));

  /** Modifie la fiche et, si `photos` est envoyé, remplace la galerie par cette liste. */
  router.put('/:id', wrap(async (req, res) => {
    const pet = await activePetOrFail(req);
    const fields = petFields(req.body);
    const writes = [writeOp(petPath(pet.id), fields, { serverTimestamps: ['updatedAt'], mustExist: true })];

    if (req.body.photos !== undefined) {
      const wanted = gallery(req.body.photos);
      const current = await galleryOf(req.token, pet.id);
      const currentById = new Map(current.map((p) => [p.id, p]));
      const keptIds = new Set(wanted.filter((p) => p.id).map((p) => p.id));
      if ([...keptIds].some((id) => !currentById.has(id))) throw new ApiError(400, 'Une photo est invalide.');

      current.filter((p) => !keptIds.has(p.id)).forEach((p) => writes.push(deleteOp(photoPath(pet.id, p.id))));
      wanted.forEach((photo, i) => {
        if (photo.bytes) writes.push(newPhotoOp(pet.id, photo.bytes, i));
        else if (currentById.get(photo.id).sortOrder !== i) {
          writes.push(writeOp(photoPath(pet.id, photo.id), { sortOrder: i }, { mustExist: true }));
        }
      });
    }
    if (req.body.weight) writes.push(todayWeightOp(pet.id, req.body.weight));

    await commit(req.token, writes);
    res.json(await getDocument(req.token, petPath(pet.id)));
  }));

  /** Modifie seulement `notes`, `favorite` ou `contacts`. */
  router.patch('/:id', wrap(async (req, res) => {
    const pet = await activePetOrFail(req);
    await writeDocument(req.token, petPath(pet.id), petPatch(req.body), {
      serverTimestamps: ['updatedAt'],
      mustExist: true,
    });
    res.json(await getDocument(req.token, petPath(pet.id)));
  }));

  /** Archive l'animal (RG-06) : jamais supprimé, son historique est conservé. */
  router.post('/:id/archive', wrap(async (req, res) => {
    const pet = await petOrFail(req);
    await writeDocument(req.token, petPath(pet.id), { status: E.PET_STATUS.archived, archivedReason: 'USER' }, {
      serverTimestamps: ['updatedAt'],
      mustExist: true,
    });
    res.status(204).end();
  }));

  router.post('/:id/restore', wrap(async (req, res) => {
    const pet = await petOrFail(req);
    await writeDocument(req.token, petPath(pet.id), { status: E.PET_STATUS.active, archivedReason: null }, {
      serverTimestamps: ['updatedAt'],
      mustExist: true,
    });
    res.status(204).end();
  }));

  // ------------------------------------------------------------------ Photos

  /** Galerie en base64, la photo principale d'abord. */
  router.get('/:id/photos', wrap(async (req, res) => {
    const docs = await galleryOf(req.token, req.params.id);
    res.json(docs.map(({ id, data, sortOrder }) => ({ id, data, sortOrder })));
  }));

  /** Photo principale seule, ou `null` : la liste des animaux n'a pas besoin de toute la galerie. */
  router.get('/:id/cover', wrap(async (req, res) => {
    const [cover] = await queryCollection(req.token, petPath(req.params.id), 'photos', {
      orderBy: 'sortOrder',
      direction: 'ASCENDING',
      limit: 1,
    });
    res.json(cover ? { id: cover.id, data: cover.data, sortOrder: cover.sortOrder } : null);
  }));

  /** Ajoute une photo en fin de galerie : la position est calculée ici, pas par le client. */
  router.post('/:id/photos', wrap(async (req, res) => {
    const pet = await activePetOrFail(req);
    const bytes = photoBytes(req.body.data);
    const current = await galleryOf(req.token, pet.id);
    if (current.length >= MAX_PHOTOS) throw new ApiError(409, `Une fiche accepte ${MAX_PHOTOS} photos au maximum.`);

    await commit(req.token, [newPhotoOp(pet.id, bytes, current.length)]);
    res.status(201).json({ sortOrder: current.length });
  }));

  /** Supprime une photo et recompacte l'ordre pour garder la couverture en position 0. */
  router.delete('/:id/photos/:photoId', wrap(async (req, res) => {
    const pet = await activePetOrFail(req);
    const current = await galleryOf(req.token, pet.id);
    if (!current.some((p) => p.id === req.params.photoId)) throw new ApiError(404, 'Photo introuvable.');

    await commit(req.token, [
      deleteOp(photoPath(pet.id, req.params.photoId)),
      ...reorderOps(pet.id, current.filter((p) => p.id !== req.params.photoId)),
    ]);
    res.status(204).end();
  }));

  /** Place la photo en position 0 (photo principale). */
  router.post('/:id/photos/:photoId/cover', wrap(async (req, res) => {
    const pet = await activePetOrFail(req);
    const current = await galleryOf(req.token, pet.id);
    const chosen = current.find((p) => p.id === req.params.photoId);
    if (!chosen) throw new ApiError(404, 'Photo introuvable.');

    await commit(req.token, reorderOps(pet.id, [chosen, ...current.filter((p) => p !== chosen)]));
    res.status(204).end();
  }));

  // ------------------------------------------------------------------ Pesées

  /** Pesées, la plus récente d'abord (`?limit=1` pour la dernière). */
  router.get('/:id/weights', wrap(async (req, res) => {
    const limit = req.query.limit ? Math.min(Math.max(parseInt(req.query.limit, 10) || 1, 1), 1000) : undefined;
    res.json(await queryCollection(req.token, petPath(req.params.id), 'weights', {
      orderBy: 'measuredOn',
      limit,
    }));
  }));

  /** Enregistre une pesée : une seule par jour. */
  router.post('/:id/weights', wrap(async (req, res) => {
    const pet = await activePetOrFail(req);
    const { id, data } = weightEntry(req.body);
    try {
      await writeDocument(req.token, weightPath(pet.id, id), data, {
        serverTimestamps: ['createdAt'],
        replace: true,
        mustNotExist: true,
      });
    } catch (error) {
      if (error.status === 409) throw new ApiError(409, 'Une pesée existe déjà à cette date.');
      throw error;
    }
    res.status(201).json(await getDocument(req.token, weightPath(pet.id, id)));
  }));

  /** Corrige le poids ou la note d'une pesée existante. */
  router.put('/:id/weights/:entryId', wrap(async (req, res) => {
    const pet = await activePetOrFail(req);
    const data = weightCorrection(req.body);
    const path = weightPath(pet.id, req.params.entryId);
    if (!await getDocument(req.token, path)) throw new ApiError(404, 'Pesée introuvable.');

    await writeDocument(req.token, path, data, { mustExist: true });
    res.json(await getDocument(req.token, path));
  }));

  router.delete('/:id/weights/:entryId', wrap(async (req, res) => {
    const pet = await activePetOrFail(req);
    await commit(req.token, [deleteOp(weightPath(pet.id, req.params.entryId))]);
    res.status(204).end();
  }));

  return router;
}

module.exports = { petsRouter };
