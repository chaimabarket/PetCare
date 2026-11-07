// Validation du module Santé : mêmes limites que HealthRepository (Flutter) et firestore.rules.

const { ApiError } = require('../firestore');
const E = require('./enums');

const BASE64 = /^[A-Za-z0-9+/]+={0,2}$/;
const TIME = /^([01]\d|2[0-3]):[0-5]\d$/;
const DAY_MS = 24 * 60 * 60 * 1000;
// Marge pour l'horloge du téléphone, comme dans les règles.
const CLOCK_MARGIN_MS = 60 * 60 * 1000;

function text(value, label, { min = 0, max = 120 } = {}) {
  const clean = typeof value === 'string' ? value.trim() : '';
  if (clean.length < min) throw new ApiError(400, `${label} est obligatoire.`);
  if (clean.length > max) throw new ApiError(400, `${label} est trop long (${max} caractères maximum).`);
  return clean;
}

/** Texte facultatif : null s'il est vide. */
function optionalText(value, label, max) {
  const clean = text(value, label, { max });
  return clean === '' ? null : clean;
}

function date(value, label, { required = true } = {}) {
  if (value === undefined || value === null || value === '') {
    if (required) throw new ApiError(400, `${label} est obligatoire.`);
    return null;
  }
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) throw new ApiError(400, `${label} est invalide.`);
  return parsed;
}

function oneOf(value, allowed, label) {
  if (!allowed.includes(value)) throw new ApiError(400, `${label} est invalide.`);
  return value;
}

function optionalNumber(value, label, { min = 0 } = {}) {
  if (value === undefined || value === null || value === '') return null;
  const n = Number(value);
  if (!Number.isFinite(n) || n < min) throw new ApiError(400, `${label} est invalide.`);
  return n;
}

/** Pièces jointes : [{ name, mimeType, data (base64) }] → liste avec les octets décodés. */
function attachments(value) {
  const list = value === undefined || value === null ? [] : value;
  if (!Array.isArray(list) || list.length > E.MAX_ATTACHMENTS) {
    throw new ApiError(400, `${E.MAX_ATTACHMENTS} pièces jointes au maximum.`);
  }
  return list.map((file) => {
    const name = text(file?.name, 'Le nom du fichier', { min: 1, max: 200 });
    const mimeType = oneOf(file?.mimeType, E.MIME_TYPES, `Le type de « ${name} »`);
    if (typeof file.data !== 'string' || !BASE64.test(file.data)) throw new ApiError(400, `« ${name} » est invalide.`);
    const bytes = Buffer.from(file.data, 'base64');
    if (bytes.length > E.MAX_ATTACHMENT_BYTES) {
      throw new ApiError(400, `« ${name} » dépasse 900 Ko. Choisissez un fichier plus léger.`);
    }
    return { name, mimeType, bytes };
  });
}

/**
 * Un soin du carnet, tel que l'écran « Ajouter un soin médical » l'envoie.
 * `nextReminderAt` : rappel d'un vaccin (obligatoire) ou prochain contrôle d'une visite (facultatif).
 */
function entryFields(body = {}) {
  const type = oneOf(body.type, E.ENTRY_TYPES, "Le type d'acte médical");
  const when = date(body.date, 'La date du soin');
  if (when.getTime() > Date.now() + CLOCK_MARGIN_MS) {
    throw new ApiError(400, 'La date du soin ne peut pas être dans le futur.');
  }
  const isVaccine = type === E.ENTRY_TYPE.vaccine;
  const vaccineName = isVaccine ? text(body.vaccineName, 'Le nom du vaccin', { min: 1 }) : null;

  let nextReminderAt = null;
  if (isVaccine) nextReminderAt = date(body.nextReminderAt, 'La date du prochain rappel');
  if (type === E.ENTRY_TYPE.visit) nextReminderAt = date(body.nextReminderAt, 'La date du prochain contrôle', { required: false });
  if (nextReminderAt && nextReminderAt <= when) {
    throw new ApiError(400, isVaccine
      ? 'Le prochain rappel doit être après la date du vaccin.'
      : 'Le prochain contrôle doit être après la date de la visite.');
  }

  return {
    type,
    title: text(body.title, 'Le titre du soin', { min: 1 }),
    date: when,
    description: optionalText(body.description, 'La description', 1000),
    practitioner: optionalText(body.practitioner, 'Le vétérinaire', 120),
    cost: optionalNumber(body.cost, 'Le coût'),
    vaccineName,
    batchNumber: isVaccine ? optionalText(body.batchNumber, 'Le numéro de lot', 60) : null,
    nextReminderAt,
    weightKg: optionalNumber(body.weightKg, 'Le poids'),
    weightDeltaKg: optionalNumber(body.weightDeltaKg, "L'écart de poids", { min: -Infinity }),
  };
}

/** Un traitement, tel que l'écran « Nouveau traitement » l'envoie. */
function treatmentFields(body = {}) {
  const startDate = date(body.startDate, 'La date de début');
  const endDate = date(body.endDate, 'La date de fin');
  if (endDate < startDate) throw new ApiError(400, 'La date de fin doit être après la date de début.');
  const renewalAt = date(body.renewalAt, 'La date de renouvellement', { required: false });
  if (renewalAt && renewalAt <= endDate) {
    throw new ApiError(400, 'Le renouvellement doit être après la fin du traitement.');
  }

  const times = Array.isArray(body.doseTimes) ? [...new Set(body.doseTimes)] : [];
  if (times.length > 8) throw new ApiError(400, '8 heures de prise au maximum.');
  times.forEach((t) => {
    if (typeof t !== 'string' || !TIME.test(t)) throw new ApiError(400, 'Une heure de prise est invalide (HH:MM).');
  });

  return {
    category: text(body.category, 'La catégorie', { max: 40 }) || 'Autre',
    name: text(body.name, 'Le nom du médicament', { min: 1 }),
    subtitle: optionalText(body.subtitle, 'Le principe actif', 120),
    form: oneOf(body.form ?? 'autre', E.TREATMENT_FORMS, 'La forme du médicament'),
    practitioner: optionalText(body.practitioner, 'Le vétérinaire', 120),
    posology: text(body.posology, 'La posologie prescrite', { min: 1, max: 500 }),
    startDate,
    endDate,
    doseTimes: times.sort(),
    renewalAt,
    scheduleNote: optionalText(body.scheduleNote, 'La note de protocole', 120),
  };
}

/**
 * Heure d'une prise notée : maintenant par défaut, ou `at` (cocher le créneau de 8 h à 10 h).
 * Pas dans le futur, et pendant la période du traitement.
 */
function doseTime(body = {}, treatment) {
  const at = date(body.at, "L'heure de la prise", { required: false }) ?? new Date();
  if (at.getTime() > Date.now() + 5 * 60 * 1000) throw new ApiError(400, 'Une prise ne peut pas être notée dans le futur.');
  const start = new Date(treatment.startDate).getTime();
  const end = new Date(treatment.endDate).getTime() + DAY_MS;
  if (at.getTime() < start - DAY_MS || at.getTime() > end) {
    throw new ApiError(400, "Cette prise est en dehors de la période du traitement.");
  }
  return at;
}

function stopReason(body = {}) {
  return text(body.reason, "La raison de l'arrêt", { min: 1, max: 300 });
}

module.exports = {
  entryFields, treatmentFields, attachments, doseTime, stopReason,
};
