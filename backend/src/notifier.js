// Envoi d'une notification dans `users/{uid}/notifications`, partagé par les modules.
// C'est un complément : son échec ne bloque jamais l'action principale.

const { writeDocument, newId } = require('./firestore');

function createNotifier(firestore = { writeDocument, newId }) {
  return async function notify(token, uid, { title, body, category }) {
    try {
      await firestore.writeDocument(
        token,
        `users/${uid}/notifications/${firestore.newId()}`,
        { title, body, category, read: false },
        { serverTimestamps: ['createdAt'], mustNotExist: true },
      );
    } catch {
      // Ignoré volontairement.
    }
  };
}

module.exports = { createNotifier };
