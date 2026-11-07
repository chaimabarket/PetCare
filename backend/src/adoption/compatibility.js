// Score de compatibilité : même calcul que `compatibility.dart`, fait ici pour que le score
// enregistré avec une candidature ne dépende pas du téléphone qui l'envoie.

const { EXPERIENCE_HINT } = require('./enums');

const WEIGHTS = {
  noGarden: 20,
  kids: 25,
  cats: 20,
  dogs: 20,
  energyMismatch: 15,
  tooLongAlone: 15,
  noLandlordAgreement: 30,
  allergies: 10,
  firstTime: 5,
};

const hoursAloneLabel = (hours) => (hours >= 10 ? '10 h et plus / jour' : `${hours} h / jour`);

/** Compare les besoins de l'animal [listing] et les réponses [a] du candidat. */
function computeCompatibility(listing, a) {
  const name = listing.name;
  let score = 100;
  const points = [];

  const check = (ok, penalty, label, okDetail, warnDetail) => {
    if (!ok) score -= penalty;
    points.push({ ok, label, detail: ok ? okDetail : warnDetail });
  };

  if (listing.needsGarden) {
    check(a.hasGarden, WEIGHTS.noGarden, 'Extérieur', 'Jardin ou extérieur accessible.',
      `${name} a besoin d'un extérieur, le foyer n'en a pas.`);
  }
  if (a.kids > 0) {
    check(listing.goodWithKids, WEIGHTS.kids, 'Enfants', `${name} est à l'aise avec les enfants.`,
      `${name} n'est pas indiqué(e) comme compatible avec des enfants.`);
  }
  if (a.cats > 0) {
    check(listing.goodWithCats, WEIGHTS.cats, 'Chats au foyer', `${name} s'entend avec les chats.`,
      `Le foyer a déjà un chat, ${name} ne cohabite pas avec eux.`);
  }
  if (a.dogs > 0) {
    check(listing.goodWithDogs, WEIGHTS.dogs, 'Chiens au foyer', `${name} s'entend avec les chiens.`,
      `Le foyer a déjà un chien, ${name} ne cohabite pas avec eux.`);
  }

  const energyMismatch =
    (listing.energy === 'eleve' && a.lifestyle === 'calme') ||
    (listing.energy === 'faible' && a.lifestyle === 'dynamique');
  check(!energyMismatch, WEIGHTS.energyMismatch, 'Rythme de vie',
    "Ambiance du foyer adaptée à son énergie.", `Énergie de ${name} et rythme du foyer peu compatibles.`);

  check(a.hoursAlone <= listing.okAloneHours, WEIGHTS.tooLongAlone, 'Temps seul',
    `Absences compatibles (${hoursAloneLabel(a.hoursAlone)}).`,
    `${name} supporte ${listing.okAloneHours} h seul(e), le candidat est absent ${hoursAloneLabel(a.hoursAlone)}.`);

  if (a.tenure === 'locataire') {
    check(a.landlordAgrees, WEIGHTS.noLandlordAgreement, 'Logement',
      'Locataire avec accord du propriétaire.', 'Locataire sans accord confirmé du propriétaire.');
  }
  if (a.allergies) {
    score -= WEIGHTS.allergies;
    points.push({ ok: false, label: 'Allergies', detail: 'Allergies signalées dans le foyer.' });
  }
  if (a.experience === 'premiere_fois') {
    score -= WEIGHTS.firstTime;
    points.push({
      ok: false,
      label: 'Expérience',
      detail: "Premier animal de ce type : prévoir des conseils d'intégration.",
    });
  } else {
    points.push({ ok: true, label: 'Expérience', detail: EXPERIENCE_HINT[a.experience] });
  }

  return { score: Math.min(100, Math.max(0, score)), points };
}

module.exports = { computeCompatibility, WEIGHTS };
