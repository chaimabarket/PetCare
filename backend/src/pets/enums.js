// Valeurs fixes du module Profils des animaux, identiques à `pet.dart` (celles enregistrées dans Firestore).

const SPECIES = ['dog', 'cat', 'rabbit', 'rodent', 'bird', 'other'];
const SEX = ['male', 'female'];
const PET_STATUS = { active: 'active', archived: 'archived' };

module.exports = { SPECIES, SEX, PET_STATUS };
