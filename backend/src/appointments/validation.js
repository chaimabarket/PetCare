const { ApiError } = require('../firestore');

// Mêmes valeurs que les enums Flutter (AppointmentType, AppointmentPlace, ReminderCategory).
const TYPES = ['vaccin', 'veterinaire', 'toilettage', 'soin', 'education', 'garde', 'autre'];
const PLACES = ['domicile', 'exterieur', 'autre'];
const REMINDER_CATEGORIES = ['medicament', 'soin', 'veterinaire', 'traitement', 'hygiene', 'controle'];

const MAX_DURATION_MINUTES = 24 * 60;
const MAX_REMINDER_MINUTES = 30 * 24 * 60;

function text(value, label, { min = 0, max = 120 } = {}) {
  const clean = typeof value === 'string' ? value.trim() : '';
  if (clean.length < min) throw new ApiError(400, `${label} est obligatoire.`);
  if (clean.length > max) throw new ApiError(400, `${label} est trop long (${max} caractères maximum).`);
  return clean;
}

/** Texte facultatif : null s'il est vide. */
function optionalText(value, label, max = 200) {
  const clean = text(value, label, { max });
  return clean === '' ? null : clean;
}

function oneOf(value, allowed, label) {
  if (!allowed.includes(value)) throw new ApiError(400, `${label} est invalide.`);
  return value;
}

function integer(value, label, { min, max, fallback }) {
  const n = value === undefined || value === null ? fallback : Number(value);
  if (!Number.isInteger(n) || n < min || n > max) throw new ApiError(400, `${label} est invalide.`);
  return n;
}

function date(value, label) {
  const d = new Date(value);
  if (typeof value !== 'string' || Number.isNaN(d.getTime())) throw new ApiError(400, `${label} est invalide.`);
  return d;
}

/** Début futur et durée : renvoie { startsAt, endsAt }. */
function schedule(body, now = new Date()) {
  const startsAt = date(body.startsAt, 'La date de début');
  if (startsAt <= now) throw new ApiError(400, 'Le rendez-vous doit commencer dans le futur.');
  const minutes = integer(body.durationMinutes, 'La durée', { min: 5, max: MAX_DURATION_MINUTES });
  return { startsAt, endsAt: new Date(startsAt.getTime() + minutes * 60000) };
}

/** Champs d'un nouveau rendez-vous. Avec `providerId`, c'est une réservation (module Services). */
function appointmentFields(body = {}, now = new Date()) {
  const { startsAt, endsAt } = schedule(body, now);
  const booking = typeof body.providerId === 'string' && body.providerId.trim() !== '';
  const fields = {
    petId: optionalText(body.petId, "L'identifiant de l'animal", 128),
    petName: text(body.petName, "L'animal concerné", { min: 1, max: 60 }),
    petBreed: optionalText(body.petBreed, 'La race', 80),
    petPhotoUrl: optionalText(body.petPhotoUrl, 'La photo', 2000),
    title: text(body.title, "L'intitulé", { min: 1, max: 120 }),
    type: oneOf(body.type, TYPES, 'Le type'),
    startsAt,
    endsAt,
    notes: text(body.notes, 'La note', { max: 500 }),
    reminderMinutes: integer(body.reminderMinutes, 'Le rappel', { min: 0, max: MAX_REMINDER_MINUTES, fallback: 1440 }),
    pushReminder: body.pushReminder !== false,
  };

  if (!booking) {
    return {
      ...fields,
      providerId: null,
      place: oneOf(body.place ?? 'autre', PLACES, 'Le lieu'),
      location: text(body.location, "L'adresse", { max: 160 }),
    };
  }

  const price = body.price === undefined || body.price === null ? null : Number(body.price);
  if (price !== null && (!Number.isFinite(price) || price < 0)) throw new ApiError(400, 'Le prix est invalide.');
  const providerAddress = optionalText(body.providerAddress, "L'adresse du prestataire", 160);
  return {
    ...fields,
    providerId: body.providerId.trim(),
    providerName: text(body.providerName, 'Le prestataire', { min: 1, max: 80 }),
    providerAddress,
    providerPhone: optionalText(body.providerPhone, 'Le téléphone du prestataire', 20),
    serviceId: text(body.serviceId, 'Le service', { min: 1, max: 128 }),
    price,
    place: 'autre',
    location: providerAddress ?? '',
    pushReminder: true,
  };
}

/** Version affichée par l'application : sert à refuser une modification faite sur des données périmées (RG-20). */
function version(value) {
  return integer(value, 'La version', { min: 1, max: Number.MAX_SAFE_INTEGER });
}

/** Champs d'un nouveau rappel de soin. */
function reminderFields(body = {}) {
  return {
    petName: text(body.petName, "L'animal concerné", { min: 1, max: 60 }),
    petBreed: optionalText(body.petBreed, 'La race', 80),
    petPhotoUrl: optionalText(body.petPhotoUrl, 'La photo', 2000),
    title: text(body.title, "L'intitulé", { min: 1, max: 120 }),
    description: optionalText(body.description, 'La description', 300),
    detail: optionalText(body.detail, 'Le détail', 80),
    category: oneOf(body.category, REMINDER_CATEGORIES, 'La catégorie'),
    dueAt: date(body.dueAt, "L'échéance"),
  };
}

module.exports = {
  TYPES,
  PLACES,
  REMINDER_CATEGORIES,
  text,
  integer,
  date,
  schedule,
  appointmentFields,
  reminderFields,
  version,
};
