// Règles métier du module Utilisateurs : profil et notifications de l'utilisateur connecté.

const { ApiError } = require('../firestore');
const { profileFields, role } = require('../validation');

/** Ce que l'API montre d'un profil. */
function publicProfile(doc) {
  const { id, fullName, email, city, phone, role: userRole, createdAt } = doc;
  return { uid: id, fullName, email, city, phone: phone ?? null, role: userRole, createdAt: createdAt ?? null };
}

function createUsersService(repository) {
  return {
    /** Crée le profil juste après l'inscription Firebase Auth. Le rôle `admin` ne s'obtient pas ici. */
    async createProfile(token, user, body) {
      if (await repository.getProfile(token, user.uid)) throw new ApiError(409, 'Ce profil existe déjà.');
      const data = { ...profileFields(body), email: user.email, role: role(body.role) };
      await repository.createProfile(token, user.uid, data);
      return publicProfile(await repository.getProfile(token, user.uid));
    },

    async getProfile(token, uid) {
      const doc = await repository.getProfile(token, uid);
      if (!doc) throw new ApiError(404, 'Profil introuvable.');
      return publicProfile(doc);
    },

    /** Modifie le nom, la ville et le téléphone ; le rôle et l'e-mail restent fixes. */
    async updateProfile(token, uid, body) {
      await repository.updateProfile(token, uid, profileFields(body));
      return publicProfile(await repository.getProfile(token, uid));
    },

    // ----------------------------------------------------------- Notifications

    /** Les plus récentes d'abord ; `limit` entre 1 et 100 (50 par défaut). */
    listNotifications(token, uid, limitParam) {
      const limit = Math.min(Math.max(parseInt(limitParam, 10) || 50, 1), 100);
      return repository.listNotifications(token, uid, limit);
    },

    async unreadCount(token, uid) {
      return { count: (await repository.listUnreadNotifications(token, uid)).length };
    },

    async markAllRead(token, uid) {
      const unread = await repository.listUnreadNotifications(token, uid);
      await repository.markNotificationsRead(token, uid, unread.map((n) => n.id));
      return { updated: unread.length };
    },

    markRead: (token, uid, notificationId) => repository.markNotificationRead(token, uid, notificationId),
  };
}

module.exports = { createUsersService, publicProfile };
