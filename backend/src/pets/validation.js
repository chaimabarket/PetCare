const { ApiError } = require('../firestore');
const { text } = require('../validation');
const E = require('./enums');

const MAX_PHOTOS = 5;
const MAX_CONTACTS = 5;
// Limite de `firestore.rules` : 750 000 octets par photo.
const MAX_PHOTO_BYTES = 750000;
const MAX_WEIGHT_KG = 500;
const CHIP = /^[0-9]{15}$/;
const BASE64 = /^[A-Za-z0-9+/]+={0,2}$/;
const DAY = /^\d{4}-\d{2}-\d{2}$/;
// Décalage horaire maximal entre le jour de l'utilisateur et le minuit UTC de ce jour.
const MAX_DAY_OFFSET_MS = 15 * 60 * 60 * 1000;

function optionalText(value, label, max) {
  return text(value, label, { max }) || null;
}

function oneOf(value, allowed, label) {
  if (!allowed.includes(value)) throw new ApiError(400, `${label} est invalide.`);
  return value;
}

function pastDate(value, label) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime()) || date > new Date()) throw new ApiError(400, `${label} est invalide.`);
  return date;
}

/** Champs de la fiche, tels que le formulaire d'ajout et de modification les envoie. */
function petFields(body = {}) {
  const chipNumber = optionalText(body.chipNumber, 'Le numéro de puce', 15);
  if (chipNumber && !CHIP.test(chipNumber)) throw new ApiError(400, 'Le numéro de puce doit contenir 15 chiffres.');

  const species = oneOf(body.species, E.SPECIES, "L'espèce");
  // Avec « other », `breed` contient l'animal saisi librement (ours, tigre, tortue…).
  const breed = optionalText(body.breed, 'La race', 80);
  if (species === 'other' && !breed) throw new ApiError(400, "Indiquez de quel animal il s'agit.");

  return {
    name: text(body.name, 'Le nom', { min: 2, max: 80 }),
    species,
    sex: oneOf(body.sex, E.SEX, 'Le sexe'),
    breed,
    birthDate: pastDate(body.birthDate, 'La date de naissance'),
    birthDateEstimated: body.birthDateEstimated === true,
    chipNumber,
    sterilized: body.sterilized === true,
    notes: notes(body.notes),
  };
}

function notes(value) {
  return optionalText(value, 'Les notes', 500);
}

function contacts(value) {
  if (!Array.isArray(value) || value.length > MAX_CONTACTS) {
    throw new ApiError(400, `Une fiche accepte ${MAX_CONTACTS} contacts au maximum.`);
  }
  return value.map((contact) => ({
    name: text(contact?.name, 'Le nom du contact', { min: 1, max: 80 }),
    detail: text(contact?.detail, 'Le détail du contact', { max: 120 }),
    phone: text(contact?.phone, 'Le téléphone du contact', { min: 1, max: 20 }),
    emergency: contact?.emergency === true,
  }));
}

/** Changements partiels de la fiche : seuls les champs présents dans la requête sont modifiés. */
function petPatch(body = {}) {
  const patch = {};
  if (body.notes !== undefined) patch.notes = notes(body.notes);
  if (body.contacts !== undefined) patch.contacts = contacts(body.contacts);
  if (body.favorite !== undefined) {
    if (typeof body.favorite !== 'boolean') throw new ApiError(400, 'Le favori est invalide.');
    patch.favorite = body.favorite;
  }
  if (Object.keys(patch).length === 0) throw new ApiError(400, 'Aucun champ à modifier.');
  return patch;
}

/** Vérifie une photo en base64 et renvoie ses octets. */
function photoBytes(value) {
  if (typeof value !== 'string' || !BASE64.test(value)) throw new ApiError(400, 'Une photo est invalide.');
  const bytes = Buffer.from(value, 'base64');
  if (bytes.length > MAX_PHOTO_BYTES) throw new ApiError(400, 'Une photo est trop lourde (750 Ko maximum).');
  return bytes;
}

/**
 * Galerie voulue, dans l'ordre : `{ "id": "..." }` garde une photo existante,
 * `{ "data": "<base64>" }` en ajoute une.
 */
function gallery(value) {
  if (!Array.isArray(value) || value.length > MAX_PHOTOS) {
    throw new ApiError(400, `Une fiche accepte ${MAX_PHOTOS} photos au maximum.`);
  }
  return value.map((photo) => {
    if (typeof photo?.id === 'string' && photo.id) return { id: photo.id };
    return { bytes: photoBytes(photo?.data) };
  });
}

function weightKg(value) {
  if (typeof value !== 'number' || !(value > 0) || value > MAX_WEIGHT_KG) {
    throw new ApiError(400, `Le poids doit être compris entre 0 et ${MAX_WEIGHT_KG} kg.`);
  }
  return value;
}

/**
 * Pesée : `date` (AAAA-MM-JJ, jour de l'utilisateur et identifiant du document) et
 * `measuredOn` (minuit de ce jour dans son fuseau horaire).
 */
function weightEntry(body = {}) {
  if (!DAY.test(body.date || '') || Number.isNaN(Date.parse(body.date))) {
    throw new ApiError(400, 'La date de la pesée est invalide.');
  }
  const measuredOn = pastDate(body.measuredOn, 'La date de la pesée');
  if (Math.abs(measuredOn - Date.parse(body.date)) > MAX_DAY_OFFSET_MS) {
    throw new ApiError(400, 'La date de la pesée est invalide.');
  }
  return {
    id: body.date,
    data: { measuredOn, weightKg: weightKg(body.weightKg), note: optionalText(body.note, 'La note', 500) },
  };
}

/** Correction d'une pesée : son jour reste son identifiant, seuls le poids et la note changent. */
function weightCorrection(body = {}) {
  return { weightKg: weightKg(body.weightKg), note: optionalText(body.note, 'La note', 500) };
}

module.exports = { petFields, petPatch, photoBytes, gallery, weightEntry, weightCorrection, MAX_PHOTOS };
