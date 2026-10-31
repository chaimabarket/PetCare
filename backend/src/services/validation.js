const { ApiError } = require('../firestore');

const PROVIDER_STATUSES = ['pending', 'published', 'rejected'];
const SERVICE_STATUSES = ['published', 'archived'];
const BOOKING_STATUSES = ['confirmed', 'declined', 'cancelled'];

const PHONE = /^[+0-9 ().-]{6,20}$/;
const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const TIME = /^([01]\d|2[0-3]):[0-5]\d$/;

function text(value, label, { min = 0, max = 80 } = {}) {
  const clean = typeof value === 'string' ? value.trim() : '';
  if (clean.length < min) throw new ApiError(400, min <= 1 ? `${label} est obligatoire.` : `${label} est trop court.`);
  if (clean.length > max) throw new ApiError(400, `${label} est trop long (${max} caractères maximum).`);
  return clean;
}

function optionalText(value, label, max) {
  if (value === undefined || value === null || String(value).trim() === '') return null;
  return text(value, label, { max });
}

function oneOf(value, allowed, label) {
  if (!allowed.includes(value)) throw new ApiError(400, `${label} est invalide.`);
  return value;
}

/** Profil du prestataire (`PUT /providers/me`). */
function providerFields(body = {}) {
  const phone = text(body.phone, 'Le téléphone', { min: 1, max: 20 });
  if (!PHONE.test(phone)) throw new ApiError(400, 'Le numéro de téléphone est invalide.');
  const email = text(body.email, "L'adresse e-mail", { min: 1, max: 120 });
  if (!EMAIL.test(email)) throw new ApiError(400, "L'adresse e-mail est invalide.");

  return {
    name: text(body.name, 'Le nom', { min: 2, max: 80 }),
    category: text(body.category, 'La catégorie', { min: 1, max: 40 }),
    city: text(body.city, 'La ville', { min: 1, max: 80 }),
    description: text(body.description, 'La description', { max: 1000 }),
    phone,
    email,
    photoUrl: optionalText(body.photoUrl, 'La photo', 500),
    address: optionalText(body.address, "L'adresse", 200),
  };
}

/** Prestation (`POST` et `PUT /providers/me/services`). */
function serviceFields(body = {}) {
  const duration = Number(body.durationMinutes);
  if (!Number.isInteger(duration) || duration < 5 || duration > 480) {
    throw new ApiError(400, 'La durée doit être comprise entre 5 et 480 minutes.');
  }
  const price = Number(body.price);
  if (!Number.isFinite(price) || price < 0 || price > 100000) throw new ApiError(400, 'Le prix est invalide.');

  return {
    name: text(body.name, 'Le nom de la prestation', { min: 2, max: 80 }),
    category: text(body.category, 'La catégorie', { min: 1, max: 40 }),
    durationMinutes: duration,
    price,
    status: oneOf(body.status ?? 'published', SERVICE_STATUSES, 'Le statut'),
    description: text(body.description, 'La description', { max: 500 }),
  };
}

/** Disponibilité d'un jour : `enabled` et des plages `{start, end}` au format HH:MM. */
function availabilityFields(body = {}) {
  const ranges = Array.isArray(body.ranges) ? body.ranges : [];
  if (ranges.length > 6) throw new ApiError(400, 'Six plages horaires au maximum par jour.');
  const clean = ranges.map((range) => {
    if (!TIME.test(range?.start) || !TIME.test(range?.end) || range.start >= range.end) {
      throw new ApiError(400, "Une plage horaire est invalide (début avant la fin, au format HH:MM).");
    }
    return { start: range.start, end: range.end };
  });
  return { enabled: body.enabled === true, ranges: clean };
}

function weekday(value) {
  const day = Number(value);
  if (!Number.isInteger(day) || day < 1 || day > 7) throw new ApiError(400, 'Le jour doit être compris entre 1 (lundi) et 7 (dimanche).');
  return day;
}

/** Demande de réservation (`POST /bookings`). */
function bookingFields(body = {}) {
  const dateTime = new Date(body.dateTime);
  if (Number.isNaN(dateTime.getTime()) || dateTime <= new Date()) {
    throw new ApiError(400, 'Choisissez une date et une heure à venir.');
  }
  return {
    providerId: text(body.providerId, 'Le prestataire', { min: 1, max: 128 }),
    serviceId: text(body.serviceId, 'La prestation', { min: 1, max: 128 }),
    animalName: text(body.animalName, "Le nom de l'animal", { min: 1, max: 80 }),
    dateTime,
    notes: text(body.notes, 'Les notes', { max: 500 }),
  };
}

module.exports = {
  PROVIDER_STATUSES,
  SERVICE_STATUSES,
  BOOKING_STATUSES,
  providerFields,
  serviceFields,
  availabilityFields,
  weekday,
  bookingFields,
  oneOf,
};
