// Filtres du fil d'adoption : même logique que `adoption_filters.dart`.

function normalize(text) {
  return String(text || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();
}

function ageInMonths(birthDate, now = new Date()) {
  const born = new Date(birthDate);
  let months = (now.getFullYear() - born.getFullYear()) * 12 + now.getMonth() - born.getMonth();
  if (now.getDate() < born.getDate()) months -= 1;
  return Math.max(0, months);
}

function ageGroup(months) {
  if (months < 12) return 'baby';
  if (months < 36) return 'young';
  if (months < 96) return 'adult';
  return 'senior';
}

/** Annonce « Adopte-moi » : en ligne depuis plus de 30 jours ou soins spécifiques. */
function isUrgent(listing, now = new Date()) {
  if (listing.status !== 'disponible') return false;
  if ((listing.badges || []).includes('soins')) return true;
  if (!listing.createdAt) return false;
  return (now - new Date(listing.createdAt)) / 86400000 > 30;
}

const list = (value) => (value ? String(value).split(',').filter(Boolean) : []);

/** Lit les filtres de la requête : ?q=&species=chat,chien&age=baby&sex=&size=&city=&badges=&urgent=1 */
function parseFilters(query) {
  return {
    q: normalize((query.q || '').trim()),
    species: list(query.species),
    ages: list(query.age),
    sex: query.sex || null,
    sizes: list(query.size),
    city: query.city ? String(query.city).toLowerCase() : null,
    badges: list(query.badges),
    urgentOnly: query.urgent === '1' || query.urgent === 'true',
  };
}

function matches(listing, f) {
  if (f.species.length && !f.species.includes(listing.species)) return false;
  if (f.ages.length && !f.ages.includes(ageGroup(ageInMonths(listing.birthDate)))) return false;
  if (f.sex && listing.sex !== f.sex) return false;
  if (f.sizes.length && !f.sizes.includes(listing.size)) return false;
  if (f.city && String(listing.city || '').toLowerCase() !== f.city) return false;
  if (!f.badges.every((b) => (listing.badges || []).includes(b))) return false;
  if (f.urgentOnly && !isUrgent(listing)) return false;
  if (!f.q) return true;
  return [listing.name, listing.breed, listing.city, listing.species, listing.publisherName].some((field) =>
    normalize(field).includes(f.q),
  );
}

module.exports = { parseFilters, matches, ageInMonths, ageGroup, isUrgent };
