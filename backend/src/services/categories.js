const { ApiError } = require('../firestore');

// Icônes connues de l'application ; une clé inconnue s'affiche avec l'icône par défaut.
const ICONS = [
  'veterinaire', 'toilettage', 'promenade', 'pension', 'boutique', 'education', 'pharmacie', 'transport', 'autre',
];

/** Catégories proposées tant que l'administrateur n'en a pas enregistré dans la base. */
const DEFAULT_CATEGORIES = [
  { isDefault: true, id: 'veterinaires', name: 'Vétérinaires', icon: 'veterinaire', order: 1 },
  { isDefault: true, id: 'toiletteurs', name: 'Toiletteurs', icon: 'toilettage', order: 2 },
  { isDefault: true, id: 'promeneurs', name: 'Promeneurs', icon: 'promenade', order: 3 },
  { isDefault: true, id: 'pensions', name: 'Pensions', icon: 'pension', order: 4 },
  { isDefault: true, id: 'boutiques', name: 'Boutiques', icon: 'boutique', order: 5 },
  { isDefault: true, id: 'autres', name: 'Autres', icon: 'autre', order: 99 },
];

function categoryFields(body = {}) {
  const name = typeof body.name === 'string' ? body.name.trim() : '';
  if (name.length < 2 || name.length > 40) throw new ApiError(400, 'Le nom doit contenir entre 2 et 40 caractères.');
  const icon = body.icon === undefined ? 'autre' : body.icon;
  if (!ICONS.includes(icon)) throw new ApiError(400, "L'icône est inconnue.");
  return { name, icon };
}

module.exports = { DEFAULT_CATEGORIES, ICONS, categoryFields };
