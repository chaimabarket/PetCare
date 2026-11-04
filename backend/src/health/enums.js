// Valeurs fixes du module Santé, identiques à `health_entry.dart` et `treatment.dart` (celles enregistrées dans Firestore).

const ENTRY_TYPES = ['visite', 'vaccin', 'examen', 'allergie', 'note'];
const ENTRY_TYPE = { visit: 'visite', vaccine: 'vaccin', exam: 'examen', allergy: 'allergie', note: 'note' };
const TREATMENT_FORMS = ['comprime', 'gouttes', 'injection', 'pipette', 'autre'];
const MIME_TYPES = ['application/pdf', 'image/jpeg', 'image/png', 'image/heic', 'image/webp'];

const MAX_ATTACHMENTS = 3;
const MAX_ATTACHMENT_BYTES = 900 * 1024;

module.exports = {
  ENTRY_TYPES, ENTRY_TYPE, TREATMENT_FORMS, MIME_TYPES, MAX_ATTACHMENTS, MAX_ATTACHMENT_BYTES,
};
