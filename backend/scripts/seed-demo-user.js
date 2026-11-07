// Remplit un compte de test avec des données de démonstration pour parcourir toute l'application :
// animaux (avec photos, pesées et carnet de santé), rendez-vous et rappels, annonces d'adoption (publiées,
// brouillon, candidatures, favoris), réservations de services et notifications.
//
// Usage (le serveur doit tourner : `npm start`, et `seed-services.js` doit avoir été lancé) :
//   USER_EMAIL=lina@gmail.com USER_PASSWORD=... DEMO_PASSWORD=... node scripts/seed-demo-user.js
//
// DEMO_PASSWORD est le mot de passe des comptes fictifs `*@petcare.test` (créés par seed-services.js, plus
// `refuge-amis@petcare.test`, créé ici pour publier des annonces d'adoption). Le script peut être relancé :
// il ne recrée pas ce qui existe déjà.

const zlib = require('node:zlib');
const { writeOp, commit, queryCollection, newId } = require('../src/firestore');

const API = process.env.API_URL || 'http://localhost:3000/api';
const KEY = process.env.FIREBASE_API_KEY || 'AIzaSyBQ6NPS05TgD8qoAKkiQEPbZpxAvEN1Sh0';
const { USER_EMAIL, USER_PASSWORD, DEMO_PASSWORD } = process.env;

if (!USER_EMAIL || !USER_PASSWORD || !DEMO_PASSWORD) {
  console.error('Définissez USER_EMAIL, USER_PASSWORD et DEMO_PASSWORD.');
  process.exit(1);
}

const DAY = 86400000;
const inDays = (n, hour = 10) => {
  const d = new Date(Date.now() + n * DAY);
  d.setUTCHours(hour, 0, 0, 0);
  return d;
};
const ymd = (d) => d.toISOString().slice(0, 10);

// ----------------------------------------------------------------------------- images (PNG sans dépendance)

const CRC = (() => {
  const table = new Uint32Array(256);
  for (let n = 0; n < 256; n += 1) {
    let c = n;
    for (let k = 0; k < 8; k += 1) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    table[n] = c >>> 0;
  }
  return (buffer) => {
    let c = 0xffffffff;
    for (const byte of buffer) c = table[(c ^ byte) & 0xff] ^ (c >>> 8);
    return (c ^ 0xffffffff) >>> 0;
  };
})();

function chunk(type, data) {
  const body = Buffer.concat([Buffer.from(type), data]);
  const out = Buffer.alloc(body.length + 8);
  out.writeUInt32BE(data.length, 0);
  body.copy(out, 4);
  out.writeUInt32BE(CRC(body), body.length + 4);
  return out;
}

/** Image 480x360 : dégradé vertical avec un disque clair au centre (une silhouette d'animal stylisée). */
function image([r1, g1, b1], [r2, g2, b2]) {
  const w = 480;
  const h = 360;
  const raw = Buffer.alloc((w * 3 + 1) * h);
  for (let y = 0; y < h; y += 1) {
    const row = y * (w * 3 + 1);
    const t = y / (h - 1);
    for (let x = 0; x < w; x += 1) {
      const inDisc = (x - 240) ** 2 + (y - 170) ** 2 < 90 ** 2;
      const earLeft = (x - 185) ** 2 + (y - 85) ** 2 < 28 ** 2;
      const earRight = (x - 295) ** 2 + (y - 85) ** 2 < 28 ** 2;
      const light = inDisc || earLeft || earRight;
      const base = [r1 + (r2 - r1) * t, g1 + (g2 - g1) * t, b1 + (b2 - b1) * t];
      const px = light ? base.map((v) => Math.min(255, v + 70)) : base;
      raw[row + 1 + x * 3] = px[0];
      raw[row + 2 + x * 3] = px[1];
      raw[row + 3 + x * 3] = px[2];
    }
  }
  const header = Buffer.alloc(13);
  header.writeUInt32BE(w, 0);
  header.writeUInt32BE(h, 4);
  header[8] = 8; // 8 bits
  header[9] = 2; // RVB
  const png = Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', header),
    chunk('IDAT', zlib.deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
  return png.toString('base64');
}

const PHOTO = {
  orange: image([240, 150, 80], [200, 90, 50]),
  brown: image([170, 120, 80], [110, 70, 40]),
  grey: image([160, 170, 185], [100, 110, 130]),
  cream: image([240, 215, 170], [200, 170, 120]),
  teal: image([90, 170, 165], [30, 110, 105]),
  rose: image([235, 170, 175], [190, 110, 125]),
};

// ----------------------------------------------------------------------------- accès

async function post(url, body) {
  const response = await fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
  return response.json();
}

async function signIn(email, password) {
  const base = 'https://identitytoolkit.googleapis.com/v1/accounts';
  let result = await post(`${base}:signInWithPassword?key=${KEY}`, { email, password, returnSecureToken: true });
  if (!result.idToken) result = await post(`${base}:signUp?key=${KEY}`, { email, password, returnSecureToken: true });
  if (!result.idToken) throw new Error(`Connexion impossible pour ${email} : ${result.error?.message}`);
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

const step = (text) => console.log(`\n${text}`);
const done = (text) => console.log(`  + ${text}`);
const skip = (text) => console.log(`  = ${text} (déjà présent)`);

// ----------------------------------------------------------------------------- animaux et carnet de santé

const PETS = [
  {
    name: 'Milo', species: 'cat', sex: 'male', birthDate: '2022-03-14', breed: 'Européen', sterilized: true,
    notes: 'Aime dormir au soleil. Craintif chez le vétérinaire.', photo: PHOTO.orange, weights: [4.0, 4.2, 4.3, 4.4],
  },
  {
    name: 'Rex', species: 'dog', sex: 'male', birthDate: '2020-06-02', breed: 'Labrador', sterilized: true,
    notes: 'Très énergique, deux sorties par jour.', photo: PHOTO.brown, weights: [29.5, 30.2, 30.8, 31.0],
  },
  {
    name: 'Nala', species: 'rabbit', sex: 'female', birthDate: '2023-09-20', breed: 'Nain bélier', sterilized: false,
    notes: 'Foin à volonté, légumes frais le matin.', photo: PHOTO.grey, weights: [1.6, 1.7, 1.8, 1.8],
  },
];

const HEALTH = {
  Milo: [
    { type: 'vaccin', title: 'CHPPiL Rappel Annuel', date: -300, next: 65, vaccineName: 'CHPPiL Rappel Annuel', batchNumber: 'VX-20431', practitioner: 'Clinique Vétérinaire de Carthage', cost: 45 },
    { type: 'visite', title: 'Contrôle annuel', date: -120, practitioner: 'Clinique Vétérinaire de Carthage', cost: 35, description: 'Bon état général, poids stable.' },
    { type: 'allergie', title: 'Poulet', date: -200, practitioner: 'Cabinet Dr Ben Youssef', description: 'Gravité : Modérée\nDémangeaisons après les croquettes au poulet.' },
    { type: 'examen', title: 'Prise de sang', date: -45, practitioner: 'Clinique Vétérinaire de Carthage', cost: 80, description: 'Résultats normaux.' },
  ],
  Rex: [
    { type: 'vaccin', title: 'Rabisin (Rage)', date: -200, next: 165, vaccineName: 'Rabisin (Rage)', batchNumber: 'RB-7781', practitioner: 'Cabinet Dr Ben Youssef', cost: 30 },
    { type: 'visite', title: 'Boiterie patte arrière', date: -30, next: 14, practitioner: 'Urgences Vétérinaires Sfax', cost: 60, description: 'Repos conseillé, contrôle dans deux semaines.' },
    { type: 'note', title: 'Changement de croquettes', date: -10, description: 'Passage aux croquettes sans céréales.' },
  ],
  Nala: [
    { type: 'visite', title: 'Contrôle dentaire', date: -60, practitioner: 'Cabinet Dr Ben Youssef', cost: 25, description: 'Dents en bon état.' },
    { type: 'vaccin', title: 'Myxomatose', date: -150, next: 30, vaccineName: 'Myxomatose', batchNumber: 'MX-1290', practitioner: 'Cabinet Dr Ben Youssef', cost: 28 },
  ],
};

async function seedPets(token, uid) {
  step('Animaux, pesées et carnet de santé');
  const existing = await api('GET', '/pets', token);
  const ids = {};

  for (const pet of PETS) {
    const found = existing.find((p) => p.name === pet.name && p.status === 'active');
    if (found) {
      ids[pet.name] = found.id;
      skip(`animal ${pet.name}`);
      continue;
    }
    const created = await api('POST', '/pets', token, {
      name: pet.name, species: pet.species, sex: pet.sex, birthDate: pet.birthDate, breed: pet.breed,
      sterilized: pet.sterilized, notes: pet.notes, photos: [{ data: pet.photo }],
    });
    ids[pet.name] = created.id;
    for (const [i, weightKg] of pet.weights.entries()) {
      const date = ymd(new Date(Date.now() - (90 - i * 30) * DAY));
      await api('POST', `/pets/${created.id}/weights`, token, { date, measuredOn: `${date}T00:00:00.000Z`, weightKg });
    }
    done(`animal ${pet.name} (photo, ${pet.weights.length} pesées)`);
  }

  for (const [name, entries] of Object.entries(HEALTH)) {
    const petId = ids[name];
    const present = await queryCollection(token, `pets/${petId}`, 'healthEntries');
    if (present.length > 0) {
      skip(`carnet de ${name}`);
      continue;
    }
    for (const e of entries) {
      const data = {
        ownerId: uid, type: e.type, title: e.title, date: inDays(e.date, 9), attachments: [], reminderDone: false,
      };
      for (const key of ['description', 'practitioner', 'cost', 'vaccineName', 'batchNumber']) {
        if (e[key] !== undefined) data[key] = e[key];
      }
      if (e.next !== undefined) data.nextReminderAt = inDays(e.next, 9);
      await commit(token, [writeOp(`pets/${petId}/healthEntries/${newId()}`, data, { serverTimestamps: ['createdAt'], mustNotExist: true })]);
    }
    done(`carnet de ${name} (${entries.length} soins)`);
  }
  return ids;
}

// ----------------------------------------------------------------------------- rendez-vous et rappels

async function seedAgenda(token) {
  step('Rendez-vous et rappels');
  const appointments = await api('GET', '/appointments', token);
  const wanted = [
    { petName: 'Milo', title: 'Vaccin annuel', type: 'vaccin', startsAt: inDays(3, 9), durationMinutes: 30, place: 'exterieur', location: 'Clinique Vétérinaire de Carthage', notes: 'Apporter le carnet de santé', reminderMinutes: 1440 },
    { petName: 'Rex', title: 'Toilettage complet', type: 'toilettage', startsAt: inDays(5, 14), durationMinutes: 60, place: 'domicile', location: 'À la maison', notes: '', reminderMinutes: 60 },
    { petName: 'Nala', title: 'Contrôle vétérinaire', type: 'veterinaire', startsAt: inDays(9, 10), durationMinutes: 45, place: 'exterieur', location: 'Cabinet Dr Ben Youssef', notes: 'Pesée et dents', reminderMinutes: 1440 },
  ];
  for (const a of wanted) {
    if (appointments.some((x) => x.title === a.title && x.petName === a.petName && x.status !== 'cancelled')) {
      skip(`rendez-vous ${a.title}`);
      continue;
    }
    await api('POST', '/appointments', token, { ...a, startsAt: a.startsAt.toISOString() });
    done(`rendez-vous ${a.title} (${a.petName})`);
  }

  const reminders = await api('GET', '/reminders', token);
  const care = [
    { petName: 'Milo', title: 'Vermifuge mensuel', category: 'medicament', dueAt: inDays(4, 8) },
    { petName: 'Rex', title: 'Antipuces', category: 'soin', dueAt: inDays(10, 8) },
    { petName: 'Nala', title: 'Brossage des dents', category: 'hygiene', dueAt: inDays(2, 18) },
  ];
  for (const r of care) {
    if (reminders.some((x) => x.title === r.title && x.petName === r.petName)) {
      skip(`rappel ${r.title}`);
      continue;
    }
    await api('POST', '/reminders', token, { ...r, dueAt: r.dueAt.toISOString() });
    done(`rappel ${r.title} (${r.petName})`);
  }
}

// ----------------------------------------------------------------------------- adoption

const base = {
  badges: [], goodWithKids: true, goodWithCats: true, goodWithDogs: false, needsGarden: false,
  energy: 'moyen', okAloneHours: 6, needs: 'Visites régulières chez le vétérinaire.', conditions: 'Visite à domicile avant adoption.',
};

const SHELTER_LISTINGS = [
  { ...base, name: 'Luna', species: 'chat', breed: 'Européen', sex: 'femelle', birthDate: inDays(-240).toISOString(), size: 'petit', city: 'Tunis', title: 'Luna, douce et câline', story: 'Luna a été trouvée à huit semaines. Elle adore les genoux et les jeux de plumes, et s’entend très bien avec les enfants.', badges: ['affectueux', 'calme', 'ok_enfants'], energy: 'faible', photos: [PHOTO.rose, PHOTO.cream] },
  { ...base, name: 'Max', species: 'chien', breed: 'Berger croisé', sex: 'male', birthDate: inDays(-1100).toISOString(), size: 'grand', city: 'Ariana', title: 'Max cherche un jardin', story: 'Max est un grand chien joueur et fidèle. Il a besoin de longues promenades et d’un foyer actif.', badges: ['energique', 'joueur', 'exterieur'], needsGarden: true, goodWithCats: false, energy: 'eleve', okAloneHours: 3, photos: [PHOTO.brown, PHOTO.orange] },
  { ...base, name: 'Biscuit', species: 'lapin', breed: 'Nain', sex: 'male', birthDate: inDays(-300).toISOString(), size: 'petit', city: 'La Marsa', title: 'Biscuit, petit gourmand', story: 'Biscuit est un lapin nain curieux et propre. Il aime le foin, les carottes et courir dans l’appartement.', badges: ['joueur', 'interieur'], goodWithDogs: false, energy: 'moyen', photos: [PHOTO.grey] },
];

const LINA_LISTING = { ...base, name: 'Cannelle', species: 'chat', breed: 'Siamois croisé', sex: 'femelle', birthDate: inDays(-500).toISOString(), size: 'petit', city: 'Tunis', title: 'Cannelle cherche une famille', story: 'Cannelle a eu une portée et ne peut pas rester chez nous. Très sociable, elle est stérilisée et vaccinée.', badges: ['affectueux', 'eduque', 'ok_chats'], energy: 'faible', goodWithDogs: true, photos: [PHOTO.cream, PHOTO.teal] };

async function seedAdoption(linaToken, linaUid) {
  step('Adoption');
  const shelter = await signIn('refuge-amis@petcare.test', DEMO_PASSWORD);
  try {
    await api('GET', '/users/me', shelter);
  } catch {
    await api('POST', '/users/me', shelter, { fullName: 'Refuge Les Amis', city: 'Tunis', role: 'refuge' });
    done('compte refuge-amis@petcare.test (rôle refuge)');
  }

  const shelterListings = await api('GET', '/adoptions/mine', shelter);
  const ids = {};
  for (const listing of SHELTER_LISTINGS) {
    const found = shelterListings.find((l) => l.name === listing.name);
    if (found) {
      ids[listing.name] = found.id;
      skip(`annonce ${listing.name}`);
      continue;
    }
    const created = await api('POST', '/adoptions', shelter, { ...listing, publish: true });
    ids[listing.name] = created.id;
    done(`annonce ${listing.name} (refuge)`);
  }

  const mine = await api('GET', '/adoptions/mine', linaToken);
  if (mine.some((l) => l.name === LINA_LISTING.name)) skip(`annonce ${LINA_LISTING.name}`);
  else {
    await api('POST', '/adoptions', linaToken, { ...LINA_LISTING, publish: true });
    done(`annonce ${LINA_LISTING.name} (Lina)`);
  }
  if (mine.some((l) => l.name === 'Brouillon Pixel')) skip('brouillon Pixel');
  else {
    await api('POST', '/adoptions', linaToken, { ...LINA_LISTING, name: 'Brouillon Pixel', title: 'Annonce en préparation', publish: false, photos: [PHOTO.teal] });
    done('brouillon Pixel (Lina)');
  }

  const answers = {
    housing: 'appartement', hasGarden: false, tenure: 'proprietaire', city: 'Tunis', adults: 2, kids: 0, kidsAges: [],
    cats: 1, dogs: 0, otherPets: 0, allergies: false, hoursAlone: 4, lifestyle: 'modere', experience: 'familier',
    motivation: 'Nous cherchons un compagnon doux pour tenir compagnie à notre chat et rester à la maison.',
  };
  for (const name of ['Luna', 'Biscuit']) {
    const existing = await api('GET', `/adoptions/${ids[name]}/applications/me`, linaToken);
    if (existing) skip(`candidature pour ${name}`);
    else {
      await api('POST', `/adoptions/${ids[name]}/applications`, linaToken, answers);
      done(`candidature de Lina pour ${name}`);
    }
  }

  const favorites = (await api('GET', '/adoptions/favorites', linaToken)).ids;
  for (const name of ['Max', 'Biscuit']) {
    if (favorites.includes(ids[name])) continue;
    await api('PUT', `/adoptions/${ids[name]}/favorite`, linaToken, {});
    done(`favori ${name}`);
  }
  return shelter;
}

// ----------------------------------------------------------------------------- services

async function seedServices(linaToken) {
  step('Réservations de services');
  const bookings = await api('GET', '/services/bookings?as=client', linaToken);
  const providers = await api('GET', '/services/providers', linaToken);
  const wanted = [
    { provider: 'Salon Pattes Propres', email: 'toilettage-pattes@petcare.test', animal: 'Rex', day: 4, hour: 15, confirm: true },
    { provider: 'Pension Les Câlins', email: 'pension-calins@petcare.test', animal: 'Milo', day: 20, hour: 9, confirm: false },
  ];
  for (const w of wanted) {
    const provider = providers.find((p) => p.name === w.provider);
    if (!provider) {
      console.log(`  ! ${w.provider} introuvable (lancez d'abord seed-services.js)`);
      continue;
    }
    if (bookings.some((b) => b.providerName === w.provider && b.status !== 'cancelled' && b.animalName === w.animal)) {
      skip(`réservation ${w.provider}`);
      continue;
    }
    const services = await api('GET', `/services/providers/${provider.id}/services`, linaToken);
    const booking = await api('POST', '/services/bookings', linaToken, {
      providerId: provider.id, serviceId: services[0].id, animalName: w.animal, dateTime: inDays(w.day, w.hour).toISOString(), notes: 'Réservation de démonstration',
    });
    if (w.confirm) {
      const providerToken = await signIn(w.email, DEMO_PASSWORD);
      await api('PATCH', `/services/bookings/${booking.id}/status`, providerToken, { status: 'confirmed' });
    }
    done(`réservation ${w.provider} (${w.confirm ? 'confirmée' : 'en attente'})`);
  }
}

// ----------------------------------------------------------------------------- notifications

async function seedNotifications(linaToken, linaUid, shelterToken) {
  step('Notifications');
  const current = await api('GET', '/users/me/notifications', linaToken);
  const titles = new Set(current.map((n) => n.title));
  const veto = await signIn('veto-carthage@petcare.test', DEMO_PASSWORD);
  const wanted = [
    { from: shelterToken, title: 'Nouvelles annonces près de chez vous', body: 'Luna, Max et Biscuit attendent une famille au Refuge Les Amis.', category: 'adoption' },
    { from: veto, title: 'Rappel : vaccin de Milo', body: 'Le rappel annuel de Milo approche. Pensez à prendre rendez-vous.', category: 'sante' },
    { from: veto, title: 'Rendez-vous confirmé', body: 'Votre rendez-vous du vaccin de Milo est bien enregistré.', category: 'rendezvous' },
  ];
  for (const n of wanted) {
    if (titles.has(n.title)) continue;
    await commit(n.from, [writeOp(`users/${linaUid}/notifications/${newId()}`, {
      title: n.title, body: n.body, category: n.category, read: false,
    }, { serverTimestamps: ['createdAt'], mustNotExist: true })]);
    done(`notification « ${n.title} »`);
  }
}

(async () => {
  const token = await signIn(USER_EMAIL, USER_PASSWORD);
  const profile = await api('GET', '/users/me', token);
  console.log(`Compte : ${profile.fullName} (${profile.email}, rôle ${profile.role})`);

  await seedPets(token, profile.uid);
  await seedAgenda(token);
  const shelter = await seedAdoption(token, profile.uid);
  await seedServices(token);
  await seedNotifications(token, profile.uid, shelter);
  console.log('\nTerminé.');
})().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
