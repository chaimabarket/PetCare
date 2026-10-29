const { ApiError } = require('./firestore');

const ROLES = ['proprietaire', 'prestataire', 'refuge'];
const PHONE = /^[+0-9 ().-]{6,20}$/;

function text(value, label, { min = 0, max = 80 } = {}) {
  const clean = typeof value === 'string' ? value.trim() : '';
  if (clean.length < min) throw new ApiError(400, `${label} est obligatoire.`);
  if (clean.length > max) throw new ApiError(400, `${label} est trop long (${max} caractères maximum).`);
  return clean;
}

function phone(value) {
  if (value === undefined || value === null || String(value).trim() === '') return null;
  const clean = String(value).trim();
  if (!PHONE.test(clean)) throw new ApiError(400, 'Le numéro de téléphone est invalide.');
  return clean;
}

/** Champs modifiables du profil. */
function profileFields(body = {}) {
  return {
    fullName: text(body.fullName, 'Le nom', { min: 2 }),
    city: text(body.city, 'La ville'),
    phone: phone(body.phone),
  };
}

function role(value) {
  if (!ROLES.includes(value)) throw new ApiError(400, 'Le rôle doit être proprietaire, prestataire ou refuge.');
  return value;
}

module.exports = { profileFields, role, ROLES };
