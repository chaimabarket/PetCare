// Règles du cahier des charges pour les rendez-vous (RG-12 à RG-21).
// Mêmes règles que lib/features/appointments/data/appointment.dart : les tests des deux côtés
// utilisent les mêmes cas.

const STATUS = {
  planned: 'planned', // « En attente » : réservation non confirmée par le prestataire
  confirmed: 'confirmed',
  completed: 'completed',
  cancelled: 'cancelled',
};

const ACTIVE = [STATUS.planned, STATUS.confirmed];

const ACTION = {
  created: 'create',
  confirmed: 'confirm',
  rescheduled: 'reschedule', // « Reporté » est une action de l'historique, pas un statut (RG-18)
  cancelled: 'cancel',
  completed: 'complete',
};

const time = (value) => new Date(value).getTime();

const isActive = (a) => ACTIVE.includes(a.status);
const hasStarted = (a, now = new Date()) => time(a.startsAt) <= time(now);
const hasEnded = (a, now = new Date()) => time(a.endsAt) <= time(now);
const isBooking = (a) => a.providerId !== undefined && a.providerId !== null;

/** Seule une réservation en attente, pas encore commencée, peut être confirmée (RG-16, RG-17). */
const canConfirm = (a, now) => a.status === STATUS.planned && !hasStarted(a, now);

/** Report et annulation : seulement avant le début (RG-17). */
const canReschedule = (a, now) => isActive(a) && !hasStarted(a, now);
const canCancel = (a, now) => isActive(a) && !hasStarted(a, now);

/** Terminé seulement depuis Confirmé, après l'heure de fin (RG-19). */
const canComplete = (a, now) => a.status === STATUS.confirmed && hasEnded(a, now);

/** Vrai si le rendez-vous chevauche l'intervalle [start, end[. */
const overlaps = (a, start, end) => time(a.startsAt) < time(end) && time(start) < time(a.endsAt);

const samePet = (a, petName) => (a.petName || '').trim().toLowerCase() === petName.trim().toLowerCase();

/** Le rendez-vous actif du même animal qui chevauche [start, end[, ou null. */
function findPetConflict(appointments, { petName, start, end, ignoreId = null }) {
  return appointments.find((a) => a.id !== ignoreId && isActive(a) && samePet(a, petName) && overlaps(a, start, end))
    || null;
}

module.exports = {
  STATUS,
  ACTIVE,
  ACTION,
  isActive,
  isBooking,
  canConfirm,
  canReschedule,
  canCancel,
  canComplete,
  overlaps,
  findPetConflict,
};
