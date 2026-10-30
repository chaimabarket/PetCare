const { ApiError } = require('./firestore');

// Clé « web » du projet Firebase (publique, déjà présente dans l'application).
const API_KEY = process.env.FIREBASE_API_KEY || 'AIzaSyBQ6NPS05TgD8qoAKkiQEPbZpxAvEN1Sh0';
const LOOKUP_URL = `https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=${API_KEY}`;
const CACHE_MS = 5 * 60 * 1000;

const cache = new Map();

/** Demande à Firebase Auth à qui appartient ce jeton. */
async function identify(token) {
  const cached = cache.get(token);
  if (cached && cached.expires > Date.now()) return cached.user;

  let response;
  try {
    response = await fetch(LOOKUP_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ idToken: token }),
    });
  } catch {
    throw new ApiError(502, 'Firebase Auth est injoignable.');
  }
  if (!response.ok) throw new ApiError(401, 'Jeton invalide ou expiré.');

  const { users } = await response.json();
  if (!users || users.length === 0) throw new ApiError(401, 'Jeton invalide ou expiré.');

  const user = { uid: users[0].localId, email: users[0].email || '' };
  cache.set(token, { user, expires: Date.now() + CACHE_MS });
  return user;
}

/** Middleware : exige `Authorization: Bearer <jeton Firebase>`. */
async function requireAuth(req, _res, next) {
  try {
    const header = req.headers.authorization || '';
    if (!header.startsWith('Bearer ')) throw new ApiError(401, 'Connexion requise.');
    req.token = header.slice(7);
    req.user = await identify(req.token);
    next();
  } catch (error) {
    next(error);
  }
}

/** Middleware : comme [requireAuth], mais laisse passer les visiteurs sans jeton. */
async function optionalAuth(req, res, next) {
  if (!req.headers.authorization) {
    req.token = null;
    req.user = null;
    return next();
  }
  return requireAuth(req, res, next);
}

module.exports = { requireAuth, optionalAuth };
