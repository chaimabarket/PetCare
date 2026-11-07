// Règles métier du module Rendez-vous : conflits, versions (RG-20), statuts, report, annulation, rappels.
// Le service ne connaît ni Express ni Firestore : il appelle le dépôt et le notifieur.

const { ApiError } = require('../firestore');
const R = require('./rules');
const V = require('./validation');

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

function createAppointmentsService(repository, notify) {
  const notice = (title, body) => ({ title, body, category: 'rendezvous' });

  async function appointmentOrFail(token, id) {
    const appointment = await repository.getAppointment(token, id);
    if (!appointment) throw new ApiError(404, 'Rendez-vous introuvable.');
    return appointment;
  }

  /** Refuse un créneau qui chevauche un autre rendez-vous actif du même animal. */
  async function assertNoPetConflict(token, ownerId, petName, start, end, ignoreId = null) {
    const all = await repository.listAppointmentsByOwner(token, ownerId);
    const conflict = R.findPetConflict(all, { petName, start, end, ignoreId });
    if (conflict) throw new ApiError(409, `${petName.trim()} a déjà « ${conflict.title} » prévu le ${when(conflict.startsAt)}.`);
  }

  /**
   * Applique une modification si le rendez-vous n'a pas changé depuis son affichage (RG-20) :
   * la `version` envoyée doit être celle du document, et l'écriture est refusée si quelqu'un
   * le modifie entre notre lecture et notre écriture.
   */
  async function transition(token, user, appointmentId, body, {
    check, changes, action = null, reason = null, oldStart = null, newStart = null, notifyTitle = null, notifyBody = null,
  }) {
    const found = await repository.getAppointmentWithTime(token, appointmentId);
    if (!found) throw new ApiError(404, 'Rendez-vous introuvable.');
    const current = found.doc;
    const currentVersion = current.version ?? 1;

    if (currentVersion !== V.version(body.version)) {
      throw new ApiError(409, "Ce rendez-vous vient d'être modifié par quelqu'un d'autre. Vérifiez-le puis recommencez.");
    }
    const error = check(current);
    if (error) throw new ApiError(409, error);

    const data = { ...changes(current), version: currentVersion + 1 };
    if (action) {
      const entry = { action, at: new Date(), by: user.uid };
      if (reason) entry.reason = reason;
      if (oldStart) entry.oldStart = new Date(oldStart);
      if (newStart) entry.newStart = new Date(newStart);
      data.changes = [...history(current.changes), entry];
    }
    await repository.changeAppointment(token, appointmentId, data, found.updateTime);

    if (notifyTitle && notifyBody) {
      // On prévient l'autre personne : le prestataire si c'est le client qui agit, et inversement.
      const target = user.uid === current.ownerId ? (current.providerId ?? current.ownerId) : current.ownerId;
      await notify(token, target, notice(notifyTitle, notifyBody(current)));
    }
    return repository.getAppointment(token, appointmentId);
  }

  return {
    /** Rendez-vous de l'utilisateur : ceux de ses animaux et, s'il est prestataire, ceux qu'il a reçus. */
    async listAgenda(token, uid) {
      const [mine, received] = await Promise.all([
        repository.listAppointmentsByOwner(token, uid),
        // Un propriétaire n'a pas de réservations reçues : une erreur ici donne simplement une liste vide.
        repository.listAppointmentsByProvider(token, uid).catch(() => []),
      ]);
      const byId = new Map([...mine, ...received].map((a) => [a.id, a]));
      return [...byId.values()].sort(byStart);
    },

    getAppointment: appointmentOrFail,

    /**
     * Crée un rendez-vous (FR-11). Sans `providerId`, c'est un rendez-vous personnel qui démarre
     * « Confirmé » ; avec, une réservation du module Services qui attend le prestataire (RG-16).
     */
    async createAppointment(token, user, body) {
      const fields = V.appointmentFields(body);
      const booking = fields.providerId !== null;
      if (booking && fields.providerId === user.uid) throw new ApiError(400, 'Vous ne pouvez pas réserver votre propre service.');

      await assertNoPetConflict(token, user.uid, fields.petName, fields.startsAt, fields.endsAt);

      const id = await repository.createAppointment(token, {
        ...fields,
        ownerId: user.uid,
        status: booking ? R.STATUS.planned : R.STATUS.confirmed,
        version: 1,
        changes: [{ action: R.ACTION.created, at: new Date(), by: user.uid }],
      });

      const moment = when(fields.startsAt);
      if (booking) {
        await notify(token, fields.providerId, notice('Nouvelle demande de réservation', `${fields.title} pour ${fields.petName} le ${moment}.`));
      } else {
        await notify(token, user.uid, notice('Rendez-vous ajouté', `${fields.title} pour ${fields.petName} le ${moment}.`));
      }
      return repository.getAppointment(token, id);
    },

    /** Le prestataire confirme une réservation en attente (RG-16, RG-17). */
    async confirm(token, user, id, body) {
      const current = await appointmentOrFail(token, id);
      if (current.providerId !== user.uid) throw new ApiError(403, 'Seul le prestataire peut confirmer cette réservation.');
      return transition(token, user, id, body, {
        check: (a) => (R.canConfirm(a) ? null : 'Ce rendez-vous ne peut plus être confirmé.'),
        changes: () => ({ status: R.STATUS.confirmed }),
        action: R.ACTION.confirmed,
        notifyTitle: 'Rendez-vous confirmé',
        notifyBody: (a) => `${a.title} pour ${a.petName} est confirmé le ${when(a.startsAt)}.`,
      });
    },

    /**
     * Reporte avant le début, avec un motif (RG-18) : même rendez-vous, nouvel horaire, même durée.
     * Une réservation repasse « En attente » : le prestataire doit la confirmer à nouveau.
     */
    async reschedule(token, user, id, body) {
      const current = await appointmentOrFail(token, id);
      const newStart = V.date(body.startsAt, 'Le nouvel horaire');
      if (newStart <= new Date()) throw new ApiError(400, 'Le rendez-vous doit commencer dans le futur.');
      if (newStart.getTime() === new Date(current.startsAt).getTime()) {
        throw new ApiError(400, "Choisissez un horaire différent de l'horaire actuel.");
      }
      const reason = V.text(body.reason, 'Le motif du report', { min: 1, max: 300 });
      const duration = new Date(current.endsAt) - new Date(current.startsAt);
      const newEnd = new Date(newStart.getTime() + duration);
      await assertNoPetConflict(token, current.ownerId, current.petName, newStart, newEnd, current.id);

      return transition(token, user, id, body, {
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
      });
    },

    /** Annule un rendez-vous pas encore commencé (RG-17). Annulé est définitif. */
    cancel(token, user, id, body) {
      const reason = V.text(body.reason, 'Le motif', { max: 300 }) || null;
      return transition(token, user, id, body, {
        check: (a) => (R.canCancel(a) ? null : 'Ce rendez-vous ne peut plus être annulé : il a déjà commencé.'),
        changes: () => ({ status: R.STATUS.cancelled, cancelReason: reason }),
        action: R.ACTION.cancelled,
        reason,
        notifyTitle: 'Rendez-vous annulé',
        notifyBody: (a) => `${a.title} pour ${a.petName}, prévu le ${when(a.startsAt)}, est annulé.`,
      });
    },

    /** Termine un rendez-vous confirmé après son heure de fin (RG-19). */
    complete: (token, user, id, body) =>
      transition(token, user, id, body, {
        check: (a) => (R.canComplete(a) ? null : "Un rendez-vous se termine après son heure de fin, s'il était confirmé."),
        changes: () => ({ status: R.STATUS.completed }),
        action: R.ACTION.completed,
      }),

    /** Rappel du rendez-vous : `minutes` avant le début, 0 pour aucun rappel. */
    setReminder(token, user, id, body) {
      const minutes = V.integer(body.minutes, 'Le rappel', { min: 0, max: 30 * 24 * 60 });
      return transition(token, user, id, body, {
        check: (a) => (R.isActive(a) ? null : 'Ce rendez-vous est terminé ou annulé.'),
        changes: () => ({ reminderMinutes: minutes, reminderDoneAt: null }),
      });
    },

    /** Bouton « Fait » de la liste des rappels (ou son annulation avec `done: false`). */
    setReminderDone(token, user, id, body) {
      const done = body.done !== false;
      return transition(token, user, id, body, {
        check: () => null,
        changes: () => ({ reminderDoneAt: done ? new Date() : null }),
      });
    },
  };
}

/** Rappels de soins créés à la main (vaccin, vermifuge…), indépendants des rendez-vous. */
function createRemindersService(repository) {
  async function reminderOrFail(token, id) {
    const reminder = await repository.getReminder(token, id);
    if (!reminder) throw new ApiError(404, 'Rappel introuvable.');
    return reminder;
  }

  return {
    async listReminders(token, uid) {
      return (await repository.listRemindersByOwner(token, uid)).sort(byDue);
    },

    async createReminder(token, uid, body) {
      const id = await repository.createReminder(token, { ...V.reminderFields(body), ownerId: uid, done: false, doneAt: null });
      return repository.getReminder(token, id);
    },

    /** Bouton « Fait » : `{ "done": true }`, ou `false` pour l'annuler. */
    async setDone(token, id, body) {
      await reminderOrFail(token, id);
      if (typeof body.done !== 'boolean') throw new ApiError(400, 'Le champ done doit valoir true ou false.');
      if (body.done) await repository.markReminderDone(token, id);
      else await repository.markReminderNotDone(token, id);
      return repository.getReminder(token, id);
    },

    async deleteReminder(token, id) {
      await reminderOrFail(token, id);
      await repository.deleteReminder(token, id);
    },
  };
}

module.exports = { createAppointmentsService, createRemindersService, when };
