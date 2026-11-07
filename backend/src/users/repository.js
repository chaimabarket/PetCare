// Couche données du module Utilisateurs : profil `users/{uid}` et notifications `users/{uid}/notifications`.

const { getDocument, writeDocument, updateMany, queryCollection } = require('../firestore');

const userPath = (uid) => `users/${uid}`;

function createUsersRepository(firestore = { getDocument, writeDocument, updateMany, queryCollection }) {
  const { getDocument: get, writeDocument: write, updateMany: updateAll, queryCollection: query } = firestore;

  return {
    getProfile: (token, uid) => get(token, userPath(uid)),

    createProfile: (token, uid, data) => write(token, userPath(uid), data, { serverTimestamps: ['createdAt'] }),

    updateProfile: (token, uid, fields) =>
      write(token, userPath(uid), fields, { serverTimestamps: ['updatedAt'], mustExist: true }),

    listNotifications: (token, uid, limit) =>
      query(token, userPath(uid), 'notifications', { orderBy: 'createdAt', limit }),

    listUnreadNotifications: (token, uid) =>
      query(token, userPath(uid), 'notifications', { where: { field: 'read', value: false } }),

    markNotificationRead: (token, uid, notificationId) =>
      write(token, `${userPath(uid)}/notifications/${notificationId}`, { read: true }, { mustExist: true }),

    markNotificationsRead: (token, uid, notificationIds) =>
      updateAll(token, notificationIds.map((id) => ({ path: `${userPath(uid)}/notifications/${id}`, data: { read: true } }))),
  };
}

module.exports = { createUsersRepository };
