// Accès à Firestore par son API REST, avec le jeton de l'utilisateur connecté :
// les règles de sécurité de `firestore.rules` s'appliquent donc à chaque appel,
// et le serveur n'a besoin d'aucune clé secrète.

const PROJECT_ID = process.env.FIREBASE_PROJECT_ID || 'petcare-communit';
const ROOT = `projects/${PROJECT_ID}/databases/(default)/documents`;
const BASE = `https://firestore.googleapis.com/v1/${ROOT}`;

class ApiError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

/** Convertit une valeur JavaScript au format Firestore. */
function toValue(value) {
  if (value === null || value === undefined) return { nullValue: null };
  if (typeof value === 'string') return { stringValue: value };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (typeof value === 'number') {
    return Number.isInteger(value) ? { integerValue: String(value) } : { doubleValue: value };
  }
  throw new Error(`Type non pris en charge : ${typeof value}`);
}

/** Convertit une valeur Firestore en valeur JavaScript. */
function fromValue(value) {
  if ('stringValue' in value) return value.stringValue;
  if ('booleanValue' in value) return value.booleanValue;
  if ('integerValue' in value) return Number(value.integerValue);
  if ('doubleValue' in value) return value.doubleValue;
  if ('timestampValue' in value) return value.timestampValue;
  return null;
}

function toFields(data) {
  return Object.fromEntries(Object.entries(data).map(([key, value]) => [key, toValue(value)]));
}

function fromDocument(doc) {
  const fields = {};
  for (const [key, value] of Object.entries(doc.fields || {})) fields[key] = fromValue(value);
  return { id: doc.name.split('/').pop(), ...fields };
}

async function call(token, url, options = {}) {
  let response;
  try {
    response = await fetch(url, {
      ...options,
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    });
  } catch {
    throw new ApiError(502, 'Firestore est injoignable.');
  }
  if (response.ok) return response.json();

  if (response.status === 401) throw new ApiError(401, 'Session expirée, reconnectez-vous.');
  if (response.status === 403) throw new ApiError(403, "Vous n'avez pas accès à cette ressource.");
  if (response.status === 404) throw new ApiError(404, 'Ressource introuvable.');
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

function buildWrite(path, data, { serverTimestamps = [], mustExist = false } = {}) {
  const write = {
    update: { name: `${ROOT}/${path}`, fields: toFields(data) },
    updateMask: { fieldPaths: Object.keys(data) },
  };
  if (mustExist) write.currentDocument = { exists: true };
  if (serverTimestamps.length) {
    write.updateTransforms = serverTimestamps.map((fieldPath) => ({
      fieldPath,
      setToServerValue: 'REQUEST_TIME',
    }));
  }
  return write;
}

/**
 * Écrit les champs [data] d'un document (création ou mise à jour partielle).
 * Les champs de [serverTimestamps] reçoivent l'heure du serveur.
 */
async function writeDocument(token, path, data, options) {
  await call(token, `${BASE}:commit`, {
    method: 'POST',
    body: JSON.stringify({ writes: [buildWrite(path, data, options)] }),
  });
}

/** Met à jour plusieurs documents existants en une seule requête. */
async function updateMany(token, updates) {
  if (updates.length === 0) return;
  const writes = updates.map(({ path, data }) => buildWrite(path, data, { mustExist: true }));
  await call(token, `${BASE}:commit`, { method: 'POST', body: JSON.stringify({ writes }) });
}

/** Liste les documents de la sous-collection [collection] du document [parentPath]. */
async function queryCollection(token, parentPath, collection, { where, orderBy, limit } = {}) {
  const structuredQuery = { from: [{ collectionId: collection }] };
  if (where) {
    structuredQuery.where = {
      fieldFilter: { field: { fieldPath: where.field }, op: 'EQUAL', value: toValue(where.value) },
    };
  }
  if (orderBy) {
    structuredQuery.orderBy = [{ field: { fieldPath: orderBy }, direction: 'DESCENDING' }];
  }
  if (limit) structuredQuery.limit = limit;

  const rows = await call(token, `${BASE}/${parentPath}:runQuery`, {
    method: 'POST',
    body: JSON.stringify({ structuredQuery }),
  });
  return rows.filter((row) => row.document).map((row) => fromDocument(row.document));
}

module.exports = { ApiError, getDocument, writeDocument, updateMany, queryCollection };
