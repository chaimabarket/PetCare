// Remplit l'annuaire Services avec des professionnels de démonstration, par l'API REST.
//
// Usage (le serveur doit tourner : `npm start`) :
//   ADMIN_EMAIL=admin@gmail.com ADMIN_PASSWORD=... DEMO_PASSWORD=... node scripts/seed-services.js
//
// - ADMIN_EMAIL / ADMIN_PASSWORD : compte au rôle `admin` ; il enregistre les catégories et publie les profils.
// - DEMO_PASSWORD : mot de passe commun des comptes fictifs `*@petcare.test` (un compte par professionnel,
//   car un profil appartient toujours à son propriétaire).
// Le script peut être relancé : il réutilise les comptes et ne recrée ni les profils ni les prestations.

const API = process.env.API_URL || 'http://localhost:3000/api';
const KEY = process.env.FIREBASE_API_KEY || 'AIzaSyBQ6NPS05TgD8qoAKkiQEPbZpxAvEN1Sh0';
const { ADMIN_EMAIL, ADMIN_PASSWORD, DEMO_PASSWORD } = process.env;

if (!ADMIN_EMAIL || !ADMIN_PASSWORD || !DEMO_PASSWORD) {
  console.error('Définissez ADMIN_EMAIL, ADMIN_PASSWORD et DEMO_PASSWORD.');
  process.exit(1);
}

const CATEGORIES = [
  { name: 'Vétérinaires', icon: 'veterinaire' },
  { name: 'Toiletteurs', icon: 'toilettage' },
  { name: 'Promeneurs', icon: 'promenade' },
  { name: 'Pensions', icon: 'pension' },
  { name: 'Boutiques', icon: 'boutique' },
  { name: 'Éducateurs canins', icon: 'education' },
  { name: 'Autres', icon: 'autre', order: 99 },
];

const WEEK = [1, 2, 3, 4, 5, 6];
const day = (...ranges) => ranges.map(([start, end]) => ({ start, end }));

const PROVIDERS = [
  {
    email: 'veto-carthage@petcare.test', name: 'Clinique Vétérinaire de Carthage', category: 'Vétérinaires', city: 'Tunis',
    phone: '+216 71 100 201', address: 'Avenue Habib Bourguiba, Tunis',
    description: 'Consultations, vaccins, chirurgie et urgences pour chiens, chats et NAC.',
    hours: day(['08:30', '12:30'], ['14:30', '18:00']),
    services: [['Consultation générale', 40, 45], ['Vaccination annuelle', 20, 60], ['Stérilisation', 120, 250]],
  },
  {
    email: 'veto-sousse@petcare.test', name: 'Cabinet Dr Ben Youssef', category: 'Vétérinaires', city: 'Sousse',
    phone: '+216 73 200 202', address: 'Rue de la Corniche, Sousse',
    description: 'Médecine préventive, dentisterie et suivi des animaux âgés.',
    hours: day(['09:00', '13:00'], ['15:00', '18:30']),
    services: [['Consultation', 30, 40], ['Détartrage', 60, 120], ['Bilan sanguin', 30, 80]],
  },
  {
    email: 'veto-sfax@petcare.test', name: 'Urgences Vétérinaires Sfax', category: 'Vétérinaires', city: 'Sfax',
    phone: '+216 74 300 203', address: 'Route de Tunis km 3, Sfax',
    description: 'Prise en charge rapide des urgences, hospitalisation et radiographie.',
    hours: day(['08:00', '20:00']),
    services: [['Consultation d’urgence', 30, 70], ['Radiographie', 30, 90]],
  },
  {
    email: 'toilettage-pattes@petcare.test', name: 'Salon Pattes Propres', category: 'Toiletteurs', city: 'Tunis',
    phone: '+216 71 400 204', address: 'Lac 2, Tunis',
    description: 'Bain, coupe, brossage et soins des griffes, avec produits doux.',
    hours: day(['09:00', '12:30'], ['14:00', '18:00']),
    services: [['Bain et brossage', 45, 35], ['Toilettage complet', 90, 60], ['Coupe des griffes', 15, 10]],
  },
  {
    email: 'toilettage-mimi@petcare.test', name: 'Toilettage Mimi', category: 'Toiletteurs', city: 'Ariana',
    phone: '+216 71 500 205', address: 'Ennasr 2, Ariana',
    description: 'Toilettage à domicile pour chiens et chats.',
    hours: day(['10:00', '17:00']),
    services: [['Toilettage à domicile', 90, 70], ['Bain', 45, 40]],
  },
  {
    email: 'promenade-marsa@petcare.test', name: 'Promenades La Marsa', category: 'Promeneurs', city: 'La Marsa',
    phone: '+216 71 600 206', address: 'La Marsa Plage',
    description: 'Promenades quotidiennes en petits groupes, bord de mer.',
    hours: day(['07:30', '11:30'], ['16:00', '19:00']),
    services: [['Promenade 30 min', 30, 12], ['Promenade 1 heure', 60, 20]],
  },
  {
    email: 'promenade-tunis@petcare.test', name: 'Dog Walker Tunis', category: 'Promeneurs', city: 'Tunis', pending: true,
    phone: '+216 20 700 207', address: 'El Menzah 6, Tunis',
    description: 'Promeneur indépendant, sorties individuelles et visites à domicile.',
    hours: day(['08:00', '12:00'], ['15:00', '19:00']),
    services: [['Sortie individuelle', 45, 18]],
  },
  {
    email: 'pension-calins@petcare.test', name: 'Pension Les Câlins', category: 'Pensions', city: 'Hammamet',
    phone: '+216 72 800 208', address: 'Route de Nabeul, Hammamet',
    description: 'Pension familiale avec jardin pour chiens et chats, photos quotidiennes.',
    hours: day(['08:00', '19:00']),
    services: [['Pension chien (nuit)', 1440, 30], ['Pension chat (nuit)', 1440, 20]],
  },
  {
    email: 'pension-villa@petcare.test', name: 'Villa Canine', category: 'Pensions', city: 'Nabeul',
    phone: '+216 72 900 209', address: 'Zone touristique, Nabeul',
    description: 'Grande villa avec parc, adaptée aux chiens de grande taille.',
    hours: day(['09:00', '18:00']),
    services: [['Pension grand chien (nuit)', 1440, 40]],
  },
  {
    email: 'boutique-zooplus@petcare.test', name: 'Animalerie Zoo Plus', category: 'Boutiques', city: 'Tunis',
    phone: '+216 71 110 210', address: 'Centre Urbain Nord, Tunis',
    description: 'Croquettes, litières, jouets, accessoires et conseils nutrition.',
    hours: day(['09:00', '19:00']),
    services: [['Conseil nutrition', 20, 0], ['Retrait de commande', 10, 0]],
  },
  {
    email: 'boutique-croquettes@petcare.test', name: 'Croquettes & Co', category: 'Boutiques', city: 'Sousse',
    phone: '+216 73 120 211', address: 'Khezama, Sousse',
    description: 'Alimentation premium, compléments et produits d’hygiène.',
    hours: day(['09:30', '13:00'], ['15:00', '19:00']),
    services: [['Conseil alimentation', 15, 0]],
  },
  {
    email: 'educateur-karim@petcare.test', name: 'Karim, éducateur canin', category: 'Éducateurs canins', city: 'Tunis', pending: true,
    phone: '+216 20 130 212', address: 'Parc du Belvédère, Tunis',
    description: 'Éducation positive, socialisation des chiots et rappel.',
    hours: day(['09:00', '12:00'], ['14:00', '18:00']),
    services: [['Séance d’éducation', 60, 50], ['Cours chiot (5 séances)', 60, 220]],
  },
];

async function post(url, body, token) {
  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  return response.json();
}

/** Connecte le compte, ou le crée s'il n'existe pas encore. */
async function signIn(email, password, { create = false } = {}) {
  const base = 'https://identitytoolkit.googleapis.com/v1/accounts';
  let result = await post(`${base}:signInWithPassword?key=${KEY}`, { email, password, returnSecureToken: true });
  if (result.idToken) return result.idToken;
  if (!create) throw new Error(`Connexion impossible pour ${email} : ${result.error?.message}`);
  result = await post(`${base}:signUp?key=${KEY}`, { email, password, returnSecureToken: true });
  if (!result.idToken) throw new Error(`Création impossible pour ${email} : ${result.error?.message}`);
  return result.idToken;
}

async function api(method, path, token, body) {
  const response = await fetch(`${API}${path}`, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const data = response.status === 204 ? null : await response.json().catch(() => null);
  if (!response.ok) throw new Error(`${method} ${path} -> ${response.status} ${data?.error ?? ''}`);
  return data;
}

async function seedCategories(admin) {
  const current = await api('GET', '/services/categories', admin);
  const stored = current.filter((c) => !c.isDefault);
  const known = new Set(stored.map((c) => c.name));
  let created = 0;
  for (const category of CATEGORIES) {
    if (known.has(category.name)) continue;
    const added = await api('POST', '/services/categories', admin, { name: category.name, icon: category.icon });
    if (category.order) {
      await api('PUT', `/services/categories/${added.id}`, admin, { name: category.name, icon: category.icon, order: category.order });
    }
    created += 1;
  }
  console.log(`Catégories : ${created} créée(s), ${CATEGORIES.length - created} déjà présente(s).`);
}

async function seedProvider(admin, entry) {
  const token = await signIn(entry.email, DEMO_PASSWORD, { create: true });

  try {
    await api('GET', '/users/me', token);
  } catch {
    await api('POST', '/users/me', token, { fullName: entry.name, city: entry.city, role: 'prestataire' });
  }

  const profile = await api('PUT', '/services/providers/me', token, {
    name: entry.name, category: entry.category, city: entry.city, description: entry.description,
    phone: entry.phone, email: entry.email, address: entry.address,
  });

  const services = await api('GET', '/services/providers/me/services', token);
  if (services.length === 0) {
    for (const [name, durationMinutes, price] of entry.services) {
      await api('POST', '/services/providers/me/services', token, {
        name, category: entry.category, durationMinutes, price, status: 'published', description: '',
      });
    }
  }
  for (const weekday of WEEK) {
    await api('PUT', `/services/providers/me/availability/${weekday}`, token, { enabled: true, ranges: entry.hours });
  }

  let status = profile.status;
  if (!entry.pending && status !== 'published') {
    await api('PUT', `/services/providers/${profile.id}/status`, admin, { status: 'published' });
    status = 'published';
  }
  console.log(`  ${status === 'published' ? 'publié   ' : 'en attente'}  ${entry.category.padEnd(18)} ${entry.name}`);
}

(async () => {
  const admin = await signIn(ADMIN_EMAIL, ADMIN_PASSWORD);
  await seedCategories(admin);
  console.log('Professionnels :');
  for (const entry of PROVIDERS) await seedProvider(admin, entry);
  console.log('Terminé.');
})().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
