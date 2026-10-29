// Accès à Firestore par son API REST, avec le jeton de l'utilisateur connecté :
// les règles de sécurité de `firestore.rules` s'appliquent donc à chaque appel,
// et le serveur n'a besoin d'aucune clé secrète.

const crypto = require('node:crypto');

const PROJECT_ID = process.env.FIREBASE_PROJECT_ID || 'petcare-communit';
const ROOT = `projects/${PROJECT_ID}/databases/(default)/documents`;
const BASE = `https://firestore.googleapis.com/v1/${ROOT}`;

class ApiError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

/** Convertit une valeur JavaScript au format Firestore (listes, objets et dates compris). */
function toValue(value) {
  if (value === null || value === undefined) return { nullValue: null };
  if (typeof value === 'string') return { stringValue: value };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (typeof value === 'number') {
    return Number.isInteger(value) ? { integerValue: String(value) } : { doubleValue: value };
  }
  if (value instanceof Date) return { timestampValue: value.toISOString() };
  if (Array.isArray(value)) return { arrayValue: { values: value.map(toValue) } };
  if (typeof value === 'object') return { mapValue: { fields: toFields(value) } };
  throw new Error(`Type non pris en charge : ${typeof value}`);
}

/** Convertit une valeur Firestore en valeur JavaScript (les dates restent des textes ISO). */
function fromValue(value) {
  if ('stringValue' in value) return value.stringValue;
  if ('booleanValue' in value) return value.booleanValue;
  if ('integerValue' in value) return Number(value.integerValue);
  if ('doubleValue' in value) return value.doubleValue;
  if ('timestampValue' in value) return value.timestampValue;
  if ('arrayValue' in value) return (value.arrayValue.values || []).map(fromValue);
  if ('mapValue' in value) return fromFields(value.mapValue.fields || {});
  return null;
}

function toFields(data) {
  return Object.fromEntries(Object.entries(data).map(([key, value]) => [key, toValue(value)]));
}

function fromFields(fields) {
  return Object.fromEntries(Object.entries(fields).map(([key, value]) => [key, fromValue(value)]));
}

function fromDocument(doc) {
  return { id: doc.name.split('/').pop(), ...fromFields(doc.fields || {}) };
}

/** Identifiant aléatoire pour un nouveau document. */
function newId() {
  return crypto.randomBytes(15).toString('base64url').slice(0, 20);
}

async function call(token, url, options = {}) {
  let response;
  try {
    // Sans jeton (visiteur), Firestore applique les règles des lectures publiques.
    const headers = { 'Content-Type': 'application/json' };
    if (token) headers.Authorization = `Bearer ${token}`;
    response = await fetch(url, { ...options, headers });
  } catch {
    throw new ApiError(502, 'Firestore est injoignable.');
  }
  if (response.ok) return response.json();

  let status = '';
  try {
    status = (await response.json()).error?.status || '';
  } catch {
    // Corps vide : on se fie au code HTTP.
  }
  if (response.status === 401) throw new ApiError(401, 'Session expirée, reconnectez-vous.');
  if (response.status === 403) throw new ApiError(403, "Vous n'avez pas accès à cette ressource.");
  if (response.status === 404) throw new ApiError(404, 'Ressource introuvable.');
  if (status === 'ALREADY_EXISTS' || status === 'FAILED_PRECONDITION') {
    throw new ApiError(409, "L'état de la ressource ne permet pas cette opération.");
  }
  throw new ApiError(502, 'Erreur du service de données.');
}

/** Lit un document ; renvoie null s'il n'existe pas. */
async function getDocument(token, path) {
  try {
    return fromDocument(await call(token, `${BASE}/${path}`));
  } catch (error) {
    if (error.status === 404) return null;
    throw error;
  }
}

/**
 * Prépare l'écriture d'un document.
 * - par défaut : mise à jour partielle des champs de [data] ;
 * - [replace] : remplace tout le document ;
 * - [mustExist] / [mustNotExist] : conditions sur l'état actuel du document ;
 * - [serverTimestamps] : champs qui reçoivent l'heure du serveur.
 */
function writeOp(path, data, { serverTimestamps = [], mustExist = false, mustNotExist = false, replace = false } = {}) {
  const write = { update: { name: `${ROOT}/${path}`, fields: toFields(data) } };
  if (!replace) write.updateMask = { fieldPaths: Object.keys(data) };
  if (mustExist) write.currentDocument = { exists: true };
  if (mustNotExist) write.currentDocument = { exists: false };
  if (serverTimestamps.length) {
    write.updateTransforms = serverTimestamps.map((fieldPath) => ({
      fieldPath,
      setToServerValue: 'REQUEST_TIME',
    }));
  }
  return write;
}

function deleteOp(path) {
  return { delete: `${ROOT}/${path}` };
}

/** Envoie plusieurs écritures dans une seule transaction atomique. */
async function commit(token, writes) {
  if (writes.length === 0) return;
  await call(token, `${BASE}:commit`, { method: 'POST', body: JSON.stringify({ writes }) });
}

/** Écrit un seul document. */
const writeDocument = (token, path, data, options) => commit(token, [writeOp(path, data, options)]);

/** Met à jour plusieurs documents existants en une seule requête. */
const updateMany = (token, updates) =>
  commit(token, updates.map(({ path, data }) => writeOp(path, data, { mustExist: true })));

/**
 * Cherche dans la collection [collection]. Avec [parentPath], c'est une sous-collection de ce document ;
 * sans, une collection de premier niveau. Chaque filtre : { field, op: 'EQUAL' | 'IN', value }.
 */
async function queryCollection(token, parentPath, collection, { where, filters = [], orderBy, limit } = {}) {
  const all = where ? [{ op: 'EQUAL', ...where }, ...filters] : filters;
  const structuredQuery = { from: [{ collectionId: collection }] };

  const wire = all.map((f) => ({
    fieldFilter: { field: { fieldPath: f.field }, op: f.op || 'EQUAL', value: toValue(f.value) },
  }));
  if (wire.length === 1) structuredQuery.where = wire[0];
  if (wire.length > 1) structuredQuery.where = { compositeFilter: { op: 'AND', filters: wire } };

  if (orderBy) {
    structuredQuery.orderBy = [{ field: { fieldPath: orderBy }, direction: 'DESCENDING' }];
  }
  if (limit) structuredQuery.limit = limit;

  const url = parentPath ? `${BASE}/${parentPath}:runQuery` : `${BASE}:runQuery`;
  const rows = await call(token, url, { method: 'POST', body: JSON.stringify({ structuredQuery }) });
  return rows.filter((row) => row.document).map((row) => fromDocument(row.document));
}

module.exports = {
  ApiError,
  getDocument,
  writeDocument,
  writeOp,
  deleteOp,
  commit,
  updateMany,
  queryCollection,
  newId,
};
