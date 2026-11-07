// Couche données du module Rendez-vous : collections `appointments` et `reminders`.
// Aucune règle métier ici : le service décide, le dépôt lit et écrit.

const {
  getDocument, getDocumentWithTime, writeOp, deleteOp, commit, writeDocument, queryCollection, newId,
} = require('../firestore');

function createAppointmentsRepository(
  firestore = { getDocument, getDocumentWithTime, writeOp, deleteOp, commit, writeDocument, queryCollection, newId },
) {
  const {
    getDocument: get, getDocumentWithTime: getWithTime, writeOp: op, deleteOp: del, commit: run,
    writeDocument: write, queryCollection: query, newId: id,
  } = firestore;

  return {
    // ----------------------------------------------------------- Rendez-vous

    listAppointmentsByOwner: (token, uid) => query(token, null, 'appointments', { where: { field: 'ownerId', value: uid } }),

    listAppointmentsByProvider: (token, uid) => query(token, null, 'appointments', { where: { field: 'providerId', value: uid } }),

    getAppointment: (token, appointmentId) => get(token, `appointments/${appointmentId}`),

    /** Le rendez-vous avec l'heure de sa dernière modification, pour refuser une écriture concurrente (RG-20). */
    getAppointmentWithTime: (token, appointmentId) => getWithTime(token, `appointments/${appointmentId}`),

    async createAppointment(token, data) {
      const appointmentId = id();
      await write(token, `appointments/${appointmentId}`, data, { serverTimestamps: ['createdAt'], mustNotExist: true });
      return appointmentId;
    },

    /** Écrit la modification si le rendez-vous n'a pas changé depuis [updateTime]. */
    changeAppointment: (token, appointmentId, data, updateTime) =>
      run(token, [op(`appointments/${appointmentId}`, data, { serverTimestamps: ['updatedAt'], updateTime })]),

    // ----------------------------------------------------------- Rappels de soins

    listRemindersByOwner: (token, uid) => query(token, null, 'reminders', { where: { field: 'ownerId', value: uid } }),

    getReminder: (token, reminderId) => get(token, `reminders/${reminderId}`),

    async createReminder(token, data) {
      const reminderId = id();
      await write(token, `reminders/${reminderId}`, data, { serverTimestamps: ['createdAt'], mustNotExist: true });
      return reminderId;
    },

    markReminderDone: (token, reminderId) =>
      write(token, `reminders/${reminderId}`, { done: true }, { serverTimestamps: ['doneAt'], mustExist: true }),

    markReminderNotDone: (token, reminderId) =>
      write(token, `reminders/${reminderId}`, { done: false, doneAt: null }, { mustExist: true }),

    deleteReminder: (token, reminderId) => run(token, [del(`reminders/${reminderId}`)]),
  };
}

module.exports = { createAppointmentsRepository };
