// Valeurs fixes du module Adoption, identiques à `adoption_enums.dart` (celles enregistrées dans Firestore).

const SPECIES = ['chat', 'chien', 'lapin', 'oiseau', 'rongeur', 'autre'];
const SEX = ['male', 'femelle'];
const SIZE = ['petit', 'moyen', 'grand'];
const ENERGY = ['faible', 'moyen', 'eleve'];
const BADGES = [
  'calme', 'energique', 'affectueux', 'joueur', 'timide', 'ok_enfants',
  'ok_chats', 'ok_chiens', 'interieur', 'exterieur', 'eduque', 'soins',
];

const LISTING_STATUS = { draft: 'brouillon', available: 'disponible', reserved: 'reservee', adopted: 'adoptee', archived: 'archivee' };
const APPLICATION_STATUS = {
  pending: 'envoyee', reviewing: 'en_etude', accepted: 'acceptee', adopted: 'adoptee', refused: 'refusee', withdrawn: 'retiree',
};
const OPEN_APPLICATION_STATUSES = [APPLICATION_STATUS.pending, APPLICATION_STATUS.reviewing, APPLICATION_STATUS.accepted];

const HOUSING = ['appartement', 'maison'];
const TENURE = ['proprietaire', 'locataire'];
const LIFESTYLE = ['calme', 'modere', 'dynamique'];
const EXPERIENCE = ['premiere_fois', 'familier', 'connaisseur'];
const EXPERIENCE_HINT = {
  premiere_fois: 'Débutant bienveillant',
  familier: 'Déjà eu un animal',
  connaisseur: 'Grande expérience',
};
const KIDS_AGE_RANGES = ['0 - 5 ans', '6 - 12 ans', '13+ ans'];

module.exports = {
  SPECIES, SEX, SIZE, ENERGY, BADGES, LISTING_STATUS, APPLICATION_STATUS, OPEN_APPLICATION_STATUSES,
  HOUSING, TENURE, LIFESTYLE, EXPERIENCE, EXPERIENCE_HINT, KIDS_AGE_RANGES,
};
