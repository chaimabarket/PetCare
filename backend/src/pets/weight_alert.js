// Alerte de poids : repère une variation anormale entre la dernière pesée et les pesées des 90 jours précédents.
// Même logique que `lib/features/pets/data/weight_alert.dart` (cas communs : test/fixtures/weight_alert_cases.json).
//
// Ce sont des repères d'alerte, pas un diagnostic. Sources consultées le 04/11/2026 :
// - WSAVA Nutritional Assessment Guidelines (2011), https://pmc.ncbi.nlm.nih.gov/articles/PMC11107980/ :
//   une variation de poids inexpliquée est un facteur de risque qui justifie un examen approfondi (sans pourcentage).
// - VCA Hospitals (fiches rédigées par des vétérinaires), https://vcahospitals.com/know-your-pet/abnormal-weight-loss-in-cats
//   et https://vcahospitals.com/know-your-pet/weight-loss-abnormal-in-dogs : une perte de plus de 10 % du poids habituel
//   est cliniquement significative, et une perte rapide est plus inquiétante.
// - AAHA 2021 Nutrition and Weight Management Guidelines et iCatCare : 1 point de score corporel (sur 9) correspond à
//   environ 10 % du poids (repère de la règle `gain-10`).
// Les règles `source: 'petcare'` sont des repères PetCare, non officiels : aucune source ne donne de chiffre pour ces cas.

const DAY_MS = 86400000;
/** Au-delà, la dernière pesée est trop ancienne pour signaler un problème actuel. */
const MAX_AGE_DAYS = 30;
/** Animaux plus fragiles : une perte rapide plus faible suffit. */
const SMALL_SPECIES = ['rabbit', 'rodent', 'bird'];

/**
 * Règles, de la plus grave à la moins grave : la première qui correspond est retenue.
 * `direction` : -1 perte, 1 prise, 0 les deux. `days` : écart maximal avec la pesée de référence.
 */
const RULES = [
  { id: 'extreme', kind: 'check', level: 'consult', direction: 0, percent: 30, days: 7, source: 'petcare' },
  { id: 'loss-10', kind: 'loss', level: 'consult', direction: -1, percent: 10, days: 90, source: 'vca' },
  { id: 'rapid-loss', kind: 'loss', level: 'consult', direction: -1, percent: 5, percentSmall: 3, days: 7, source: 'petcare' },
  { id: 'gain-20', kind: 'gain', level: 'consult', direction: 1, percent: 20, days: 90, source: 'petcare', adultOnly: true },
  { id: 'loss-5', kind: 'loss', level: 'watch', direction: -1, percent: 5, days: 30, source: 'petcare' },
  { id: 'gain-10', kind: 'gain', level: 'watch', direction: 1, percent: 10, days: 90, source: 'aaha', adultOnly: true },
];

const daysBetween = (from, to) => Math.round((to - from) / DAY_MS);

function ageInMonths(birth, at) {
  const months = (at.getUTCFullYear() - birth.getUTCFullYear()) * 12 + at.getUTCMonth() - birth.getUTCMonth();
  return at.getUTCDate() < birth.getUTCDate() ? months - 1 : months;
}

const round1 = (value) => Math.round(value * 10) / 10;

/**
 * Analyse les pesées `[{ id, measuredOn, weightKg }]` ; renvoie l'alerte la plus grave, ou `null`.
 * Une prise de poids n'est signalée que chez l'adulte (un jeune animal grandit) et seulement si la dernière pesée
 * dépasse toutes les précédentes de la fenêtre (un retour au poids habituel n'est pas une prise).
 */
function analyzeWeights({ entries, species, birthDate = null, status = 'active', now = new Date() }) {
  if (status === 'archived') return null;
  const list = (entries || [])
    .map((e) => ({ id: e.id, at: new Date(e.measuredOn), kg: Number(e.weightKg) }))
    .filter((e) => !Number.isNaN(e.at.getTime()) && e.kg > 0)
    .sort((a, b) => a.at - b.at);
  if (list.length < 2) return null;

  const latest = list[list.length - 1];
  if (daysBetween(latest.at, new Date(now)) > MAX_AGE_DAYS) return null;
  const young = birthDate != null && ageInMonths(new Date(birthDate), latest.at) < 12;
  const small = SMALL_SPECIES.includes(species);

  for (const rule of RULES) {
    if (rule.adultOnly && young) continue;
    const threshold = small && rule.percentSmall ? rule.percentSmall : rule.percent;
    const window = list.slice(0, -1).filter((e) => {
      const days = daysBetween(e.at, latest.at);
      return days >= 1 && days <= rule.days;
    });
    if (rule.direction > 0 && window.some((e) => e.kg >= latest.kg)) continue;

    let best = null;
    for (const ref of window) {
      const change = ((latest.kg - ref.kg) / ref.kg) * 100;
      if (rule.direction === 0 && young && change > 0) continue;
      const magnitude = rule.direction === 0 ? Math.abs(change) : change * rule.direction;
      if (magnitude + 1e-9 < threshold) continue;
      if (!best || magnitude > best.magnitude) best = { ref, magnitude };
    }
    if (best) {
      return {
        id: `${rule.id}-${best.ref.id}`,
        rule: rule.id,
        kind: rule.kind,
        level: rule.level,
        source: rule.source,
        percent: round1(best.magnitude),
        days: daysBetween(best.ref.at, latest.at),
        reference: { id: best.ref.id, kg: best.ref.kg },
        latest: { id: latest.id, kg: latest.kg, measuredOn: latest.at.toISOString() },
      };
    }
  }
  return null;
}

/** « 9,4 », « 10 », « 5,5 » : au plus deux décimales, sans zéro inutile. */
function formatNumber(value) {
  return value.toFixed(2).replace(/\.?0+$/, '').replace('.', ',');
}

/** Texte de la notification (en français, comme les autres notifications de l'application). */
function alertMessage(alert, petName) {
  const name = petName || 'votre animal';
  const period = `${formatNumber(alert.percent)} % en ${alert.days} ${alert.days === 1 ? 'jour' : 'jours'}`;
  const values = `(${formatNumber(alert.reference.kg)} kg → ${formatNumber(alert.latest.kg)} kg)`;
  const fact = {
    loss: `${name} a perdu ${period} ${values}.`,
    gain: `${name} a pris ${period} ${values}.`,
    check: `Le poids de ${name} a varié de ${period} ${values} : vérifiez la pesée.`,
  }[alert.kind];
  const advice = alert.level === 'consult'
    ? 'Prenez rendez-vous avec un vétérinaire.'
    : 'Surveillez son poids et parlez-en à votre vétérinaire.';
  return {
    title: alert.level === 'consult' ? `Poids de ${name} : consultez un vétérinaire` : `Poids de ${name} à surveiller`,
    body: `${fact} ${advice} Ce n'est pas un diagnostic.`,
  };
}

/** Une notification par épisode : même animal, même règle et même pesée de référence donnent le même identifiant. */
const alertNotificationId = (petId, alert) => `poids-${petId}-${alert.id}`;

module.exports = { analyzeWeights, alertMessage, alertNotificationId, RULES };
