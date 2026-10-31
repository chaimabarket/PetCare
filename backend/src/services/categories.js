const express = require('express');

const { requireAuth, optionalAuth } = require('../auth');
const { ApiError, getDocument, writeOp, deleteOp, commit, queryCollection, newId } = require('../firestore');

const wrap = (handler) => (req, res, next) => Promise.resolve(handler(req, res)).catch(next);

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

const byOrder = (a, b) => (a.order - b.order) || String(a.name).localeCompare(String(b.name), 'fr');

function categoriesRouter() {
  const router = express.Router();

  /** Catégories de l'annuaire, dans l'ordre d'affichage. */
  router.get('/', optionalAuth, wrap(async (req, res) => {
    const stored = await queryCollection(req.token, null, 'serviceCategories');
    res.json(stored.length === 0 ? DEFAULT_CATEGORIES : stored.sort(byOrder));
  }));

  /** Ajoute une catégorie (administrateur) ; elle s'affiche en dernier avant « Autres ». */
  router.post('/', requireAuth, wrap(async (req, res) => {
    const fields = categoryFields(req.body);
    const stored = await queryCollection(req.token, null, 'serviceCategories');
    const regular = stored.filter((c) => c.order < 99);
    const order = regular.length === 0 ? 1 : Math.max(...regular.map((c) => c.order)) + 1;
    const id = newId();
    await commit(req.token, [writeOp(`serviceCategories/${id}`, { ...fields, order }, {
      serverTimestamps: ['updatedAt'],
      mustNotExist: true,
    })]);
    res.status(201).json(await getDocument(req.token, `serviceCategories/${id}`));
  }));

  router.put('/:id', requireAuth, wrap(async (req, res) => {
    const fields = categoryFields(req.body);
    const path = `serviceCategories/${req.params.id}`;
    const current = await getDocument(req.token, path);
    if (!current) throw new ApiError(404, 'Catégorie introuvable.');
    const order = Number.isInteger(req.body.order) ? req.body.order : current.order;
    await commit(req.token, [writeOp(path, { ...fields, order }, { serverTimestamps: ['updatedAt'], mustExist: true })]);
    res.json(await getDocument(req.token, path));
  }));

  /** Supprime une catégorie ; les prestataires déjà classés dedans gardent leur texte. */
  router.delete('/:id', requireAuth, wrap(async (req, res) => {
    await commit(req.token, [deleteOp(`serviceCategories/${req.params.id}`)]);
    res.status(204).end();
  }));

  return router;
}

module.exports = { categoriesRouter, DEFAULT_CATEGORIES, ICONS, categoryFields };
