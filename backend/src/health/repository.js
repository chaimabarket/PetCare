// Couche données du module Santé : `pets/{petId}/healthEntries` (et leurs `files`) et `pets/{petId}/treatments`.
// Aucune règle métier ici : le service décide (propriétaire, animal archivé, prise déjà notée), le dépôt écrit.

const { getDocument, writeDocument, writeOp, deleteOp, commit, queryCollection, newId } = require('../firestore');
const E = require('./enums');

const petPath = (id) => `pets/${id}`;
const entryPath = (petId, id) => `pets/${petId}/healthEntries/${id}`;
const filePath = (petId, entryId, index) => `${entryPath(petId, entryId)}/files/${index}`;
const treatmentPath = (petId, id) => `pets/${petId}/treatments/${id}`;

function createHealthRepository(firestore = { getDocument, writeDocument, writeOp, deleteOp, commit, queryCollection, newId }) {
  const { getDocument: get, writeDocument: write, writeOp: op, deleteOp: del, commit: run, queryCollection: query, newId: id } = firestore;

  return {
    // ----------------------------------------------------------- Animaux (lecture seule)

    getPet: (token, petId) => get(token, petPath(petId)),

    listPetsByOwner: (token, uid) => query(token, null, 'pets', { where: { field: 'ownerId', value: uid } }),

    // ----------------------------------------------------------- Carnet

    /** Soins, du plus récent au plus ancien (avec [ordered]), ou dans l'ordre de la base. */
    listEntries: (token, petId, { ordered = false } = {}) =>
      query(token, petPath(petId), 'healthEntries', ordered ? { orderBy: 'date' } : {}),

    getEntry: (token, petId, entryId) => get(token, entryPath(petId, entryId)),

    /** Ajoute un soin et ses pièces jointes en une seule écriture atomique ; renvoie l'identifiant du soin. */
    async createEntry(token, petId, { data, files }) {
      const entryId = id();
      await run(token, [
        op(entryPath(petId, entryId), {
          ...data,
          attachments: files.map((f) => ({ name: f.name, mimeType: f.mimeType, size: f.bytes.length })),
        }, { serverTimestamps: ['createdAt'], mustNotExist: true }),
        ...files.map((f, i) => op(filePath(petId, entryId, i), { name: f.name, mimeType: f.mimeType, data: f.bytes }, {
          replace: true,
          mustNotExist: true,
        })),
      ]);
      return entryId;
    },

    markReminderDone: (token, petId, entryId) => write(token, entryPath(petId, entryId), { reminderDone: true }, { mustExist: true }),

    getEntryFile: (token, petId, entryId, index) => get(token, filePath(petId, entryId, index)),

    deleteEntry(token, petId, entryId) {
      const writes = [];
      for (let i = 0; i < E.MAX_ATTACHMENTS; i += 1) writes.push(del(filePath(petId, entryId, i)));
      writes.push(del(entryPath(petId, entryId)));
      return run(token, writes);
    },

    // ----------------------------------------------------------- Traitements

    listTreatments: (token, petId, { ordered = false } = {}) =>
      query(token, petPath(petId), 'treatments', ordered ? { orderBy: 'startDate' } : {}),

    getTreatment: (token, petId, treatmentId) => get(token, treatmentPath(petId, treatmentId)),

    async createTreatment(token, petId, data) {
      const treatmentId = id();
      await write(token, treatmentPath(petId, treatmentId), data, { serverTimestamps: ['createdAt'], mustNotExist: true });
      return treatmentId;
    },

    /** Ajoute une prise à la liste par Firestore : les règles n'acceptent qu'une prise de plus à chaque écriture. */
    addDose(token, petId, treatmentId, at) {
      const write_ = op(treatmentPath(petId, treatmentId), {}, { mustExist: true });
      write_.updateTransforms = [{
        fieldPath: 'doses',
        appendMissingElements: { values: [{ timestampValue: at.toISOString() }] },
      }];
      return run(token, [write_]);
    },

    stopTreatment: (token, petId, treatmentId, reason) =>
      write(token, treatmentPath(petId, treatmentId), { stopReason: reason }, { serverTimestamps: ['stoppedAt'], mustExist: true }),
  };
}

module.exports = { createHealthRepository };
