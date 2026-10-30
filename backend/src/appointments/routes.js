const express = require('express');

const { requireAuth } = require('../auth');
const {
  ApiError, getDocument, getDocumentWithTime, writeOp, deleteOp, commit, writeDocument, queryCollection, newId,
} = require('../firestore');
const R = require('./rules');
const V = require('./validation');

const wrap = (handler) => (req, res, next) => Promise.resolve(handler(req, res)).catch(next);

const byStart = (a, b) => new Date(a.startsAt) - new Date(b.startsAt);
const byDue = (a, b) => new Date(a.dueAt) - new Date(b.dueAt);

// ------------------------------------------------------------ Textes des notifications

const SHORT_MONTHS = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
// Les dates sont stockées en UTC ; les textes sont écrits à l'heure de la Tunisie.
const TIME_ZONE = process.env.APP_TIME_ZONE || 'Africa/Tunis';

/** « 12 nov. à 10:30 », comme formatDayMonth + formatTime côté Flutter. */
function when(value) {
  const parts = Object.fromEntries(
    new Intl.DateTimeFormat('fr-FR', {
      timeZone: TIME_ZONE, day: 'numeric', month: 'numeric', hour: '2-digit', minute: '2-digit', hourCycle: 'h23',
    }).formatToParts(new Date(value)).map((p) => [p.type, p.value]),
  );
  return `${Number(parts.day)} ${SHORT_MONTHS[Number(parts.month) - 1]} à ${parts.hour}:${parts.minute}`;
}

/** Notification « Rendez-vous » ; c'est un complément, son échec ne bloque jamais l'action. */
async function notify(token, uid, title, body) {
  try {
    await writeDocument(token, `users/${uid}/notifications/${newId()}`, { title, body, category: 'rendezvous', read: false }, {
      serverTimestamps: ['createdAt'],
      mustNotExist: true,
    });
  } catch {
    // Ignoré volontairement.
  }
}

// ------------------------------------------------------------------ Lectures

/** Rendez-vous de l'utilisateur : ceux de ses animaux et, s'il est prestataire, ceux qu'il a reçus. */
async function agendaOf(token, uid) {
  const [mine, received] = await Promise.all([
    queryCollection(token, null, 'appointments', { where: { field: 'ownerId', value: uid } }),
    // Un propriétaire n'a pas de réservations reçues : une erreur ici donne simplement une liste vide.
    queryCollection(token, null, 'appointments', { where: { field: 'providerId', value: uid } }).catch(() => []),
  ]);
  const byId = new Map([...mine, ...received].map((a) => [a.id, a]));
  return [...byId.values()].sort(byStart);
}

async function appointmentOrFail(token, id) {
  const appointment = await getDocument(token, `appointments/${id}`);
  if (!appointment) throw new ApiError(404, 'Rendez-vous introuvable.');
  return appointment;
}

/** Refuse un créneau qui chevauche un autre rendez-vous actif du même animal. */
async function assertNoPetConflict(token, ownerId, petName, start, end, ignoreId = null) {
  const all = await queryCollection(token, null, 'appointments', { where: { field: 'ownerId', value: ownerId } });
  const conflict = R.findPetConflict(all, { petName, start, end, ignoreId });
  if (conflict) {
    throw new ApiError(409, `${petName.trim()} a déjà « ${conflict.title} » prévu le ${when(conflict.startsAt)}.`);
  }
}

/**
 * Les dates de l'historique reviennent de Firestore en texte ISO : on les repasse en dates
 * pour qu'elles restent des « timestamp » une fois réécrites.
 */
function history(changes) {
  return (Array.isArray(changes) ? changes : []).map((c) => {
    const entry = { ...c };
    for (const key of ['at', 'oldStart', 'newStart']) {
      if (typeof entry[key] === 'string') entry[key] = new Date(entry[key]);
    }
    return entry;
  });
}

// ------------------------------------------------------------------ Rendez-vous

function appointmentsRouter() {
  const router = express.Router();
  router.use(requireAuth);

  router.get('/', wrap(async (req, res) => {
    res.json(await agendaOf(req.token, req.user.uid));
  }));

  router.get('/:id', wrap(async (req, res) => {
    res.json(await appointmentOrFail(req.token, req.params.id));
  }));

  /**
   * Crée un rendez-vous (FR-11). Sans `providerId`, c'est un rendez-vous personnel qui démarre
   * « Confirmé » ; avec, une réservation du module Services qui attend le prestataire (RG-16).
   */
  router.post('/', wrap(async (req, res) => {
    const uid = req.user.uid;
    const fields = V.appointmentFields(req.body);
    const booking = fields.providerId !== null;
    if (booking && fields.providerId === uid) throw new ApiError(400, 'Vous ne pouvez pas réserver votre propre service.');

    await assertNoPetConflict(req.token, uid, fields.petName, fields.startsAt, fields.endsAt);

    const id = newId();
    const path = `appointments/${id}`;
    await writeDocument(req.token, path, {
      ...fields,
      ownerId: uid,
      status: booking ? R.STATUS.planned : R.STATUS.confirmed,
      version: 1,
      changes: [{ action: R.ACTION.created, at: new Date(), by: uid }],
    }, { serverTimestamps: ['createdAt'], mustNotExist: true });

    const moment = when(fields.startsAt);
    if (booking) {
      await notify(req.token, fields.providerId, 'Nouvelle demande de réservation',
        `${fields.title} pour ${fields.petName} le ${moment}.`);
    } else {
      await notify(req.token, uid, 'Rendez-vous ajouté', `${fields.title} pour ${fields.petName} le ${moment}.`);
    }
    res.status(201).json(await getDocument(req.token, path));
  }));

  /**
   * Applique une modification si le rendez-vous n'a pas changé depuis son affichage (RG-20) :
   * la `version` envoyée doit être celle du document, et l'écriture est refusée si quelqu'un
   * le modifie entre notre lecture et notre écriture.
   */
  async function transition(req, {
    check, changes, action = null, reason = null, oldStart = null, newStart = null, notifyTitle = null, notifyBody = null,
  }) {
    const uid = req.user.uid;
    const path = `appointments/${req.params.id}`;
    const found = await getDocumentWithTime(req.token, path);
    if (!found) throw new ApiError(404, 'Rendez-vous introuvable.');
    const current = found.doc;
    const currentVersion = current.version ?? 1;

    if (currentVersion !== V.version(req.body.version)) {
      throw new ApiError(409, "Ce rendez-vous vient d'être modifié par quelqu'un d'autre. Vérifiez-le puis recommencez.");
    }
    const error = check(current);
    if (error) throw new ApiError(409, error);

    const data = { ...changes(current), version: currentVersion + 1 };
    if (action) {
      const entry = { action, at: new Date(), by: uid };
      if (reason) entry.reason = reason;
      if (oldStart) entry.oldStart = new Date(oldStart);
      if (newStart) entry.newStart = new Date(newStart);
      data.changes = [...history(current.changes), entry];
    }
    await commit(req.token, [writeOp(path, data, { serverTimestamps: ['updatedAt'], updateTime: found.updateTime })]);

    if (notifyTitle && notifyBody) {
      // On prévient l'autre personne : le prestataire si c'est le client qui agit, et inversement.
      const target = uid === current.ownerId ? (current.providerId ?? current.ownerId) : current.ownerId;
      await notify(req.token, target, notifyTitle, notifyBody(current));
    }
    return getDocument(req.token, path);
  }

  /** Le prestataire confirme une réservation en attente (RG-16, RG-17). */
  router.post('/:id/confirm', wrap(async (req, res) => {
    const current = await appointmentOrFail(req.token, req.params.id);
    if (current.providerId !== req.user.uid) throw new ApiError(403, 'Seul le prestataire peut confirmer cette réservation.');
    res.json(await transition(req, {
      check: (a) => (R.canConfirm(a) ? null : 'Ce rendez-vous ne peut plus être confirmé.'),
      changes: () => ({ status: R.STATUS.confirmed }),
      action: R.ACTION.confirmed,
      notifyTitle: 'Rendez-vous confirmé',
      notifyBody: (a) => `${a.title} pour ${a.petName} est confirmé le ${when(a.startsAt)}.`,
    }));
  }));

  /**
   * Reporte avant le début, avec un motif (RG-18) : même rendez-vous, nouvel horaire, même durée.
   * Une réservation repasse « En attente » : le prestataire doit la confirmer à nouveau.
   */
  router.post('/:id/reschedule', wrap(async (req, res) => {
    const current = await appointmentOrFail(req.token, req.params.id);
    const newStart = V.date(req.body.startsAt, 'Le nouvel horaire');
    if (newStart <= new Date()) throw new ApiError(400, 'Le rendez-vous doit commencer dans le futur.');
    if (newStart.getTime() === new Date(current.startsAt).getTime()) {
      throw new ApiError(400, "Choisissez un horaire différent de l'horaire actuel.");
    }
    const reason = V.text(req.body.reason, 'Le motif du report', { min: 1, max: 300 });
    const duration = new Date(current.endsAt) - new Date(current.startsAt);
    const newEnd = new Date(newStart.getTime() + duration);
    await assertNoPetConflict(req.token, current.ownerId, current.petName, newStart, newEnd, current.id);

    res.json(await transition(req, {
      check: (a) => (R.canReschedule(a) ? null : 'Ce rendez-vous ne peut plus être reporté : il a commencé ou est terminé.'),
      changes: (a) => ({
        startsAt: newStart,
        endsAt: newEnd,
        status: R.isBooking(a) ? R.STATUS.planned : R.STATUS.confirmed,
        // Le rappel est recalculé pour le nouvel horaire (RG-21).
        reminderDoneAt: null,
      }),
      action: R.ACTION.rescheduled,
      reason,
      oldStart: current.startsAt,
      newStart,
      notifyTitle: 'Rendez-vous reporté',
      notifyBody: (a) => `${a.title} pour ${a.petName} : ${when(a.startsAt)} → ${when(newStart)}.`
        + (R.isBooking(a) ? ' En attente de confirmation du prestataire.' : ''),
    }));
  }));

  /** Annule un rendez-vous pas encore commencé (RG-17). Annulé est définitif. */
  router.post('/:id/cancel', wrap(async (req, res) => {
    const reason = V.text(req.body.reason, 'Le motif', { max: 300 }) || null;
    res.json(await transition(req, {
      check: (a) => (R.canCancel(a) ? null : 'Ce rendez-vous ne peut plus être annulé : il a déjà commencé.'),
      changes: () => ({ status: R.STATUS.cancelled, cancelReason: reason }),
      action: R.ACTION.cancelled,
      reason,
      notifyTitle: 'Rendez-vous annulé',
      notifyBody: (a) => `${a.title} pour ${a.petName}, prévu le ${when(a.startsAt)}, est annulé.`,
    }));
  }));

  /** Termine un rendez-vous confirmé après son heure de fin (RG-19). */
  router.post('/:id/complete', wrap(async (req, res) => {
    res.json(await transition(req, {
      check: (a) => (R.canComplete(a) ? null : "Un rendez-vous se termine après son heure de fin, s'il était confirmé."),
      changes: () => ({ status: R.STATUS.completed }),
      action: R.ACTION.completed,
    }));
  }));

  /** Rappel du rendez-vous : `minutes` avant le début, 0 pour aucun rappel. */
  router.put('/:id/reminder', wrap(async (req, res) => {
    const minutes = V.integer(req.body.minutes, 'Le rappel', { min: 0, max: 30 * 24 * 60 });
    res.json(await transition(req, {
      check: (a) => (R.isActive(a) ? null : 'Ce rendez-vous est terminé ou annulé.'),
      changes: () => ({ reminderMinutes: minutes, reminderDoneAt: null }),
    }));
  }));

  /** Bouton « Fait » de la liste des rappels (ou son annulation avec `done: false`). */
  router.put('/:id/reminder-done', wrap(async (req, res) => {
    const done = req.body.done !== false;
    res.json(await transition(req, {
      check: () => null,
      changes: () => ({ reminderDoneAt: done ? new Date() : null }),
    }));
  }));

  return router;
}

// ------------------------------------------------------------------ Rappels de soins

function remindersRouter() {
  const router = express.Router();
  router.use(requireAuth);

  async function ownReminderOrFail(req) {
    const reminder = await getDocument(req.token, `reminders/${req.params.id}`);
    if (!reminder) throw new ApiError(404, 'Rappel introuvable.');
    return reminder;
  }

  router.get('/', wrap(async (req, res) => {
    const list = await queryCollection(req.token, null, 'reminders', { where: { field: 'ownerId', value: req.user.uid } });
    res.json(list.sort(byDue));
  }));

  router.post('/', wrap(async (req, res) => {
    const path = `reminders/${newId()}`;
    await writeDocument(req.token, path, {
      ...V.reminderFields(req.body),
      ownerId: req.user.uid,
      done: false,
      doneAt: null,
    }, { serverTimestamps: ['createdAt'], mustNotExist: true });
    res.status(201).json(await getDocument(req.token, path));
  }));

  /** Bouton « Fait » : `{ "done": true }`, ou `false` pour l'annuler. */
  router.patch('/:id', wrap(async (req, res) => {
    await ownReminderOrFail(req);
    if (typeof req.body.done !== 'boolean') throw new ApiError(400, 'Le champ done doit valoir true ou false.');
    const path = `reminders/${req.params.id}`;
    if (req.body.done) {
      await writeDocument(req.token, path, { done: true }, { serverTimestamps: ['doneAt'], mustExist: true });
    } else {
      await writeDocument(req.token, path, { done: false, doneAt: null }, { mustExist: true });
    }
    res.json(await getDocument(req.token, path));
  }));

  router.delete('/:id', wrap(async (req, res) => {
    await ownReminderOrFail(req);
    await commit(req.token, [deleteOp(`reminders/${req.params.id}`)]);
    res.status(204).end();
  }));

  return router;
}

module.exports = { appointmentsRouter, remindersRouter, when };
