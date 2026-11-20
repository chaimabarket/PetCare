// Jeu de données de démonstration complet : un compte par rôle, et des données qui montrent chaque fonctionnalité
// de chaque module (animaux + alerte de poids, santé + traitements, rendez-vous dans tous les états, adoption de
// bout en bout avec Happy Tail, services côté client et côté prestataire, notifications).
//
// Usage (le serveur doit tourner : `npm start`) :
//   DEMO_PASSWORD=... node scripts/seed-demo-complet.js
//   ADMIN_EMAIL=... ADMIN_PASSWORD=... DEMO_PASSWORD=... node scripts/seed-demo-complet.js   (publie aussi le vétérinaire)
//   PHOTOS_DIR=chemin/vers/photos : photos JPEG facultatives (rocky.jpg, mimi.jpg, oscar.jpg, nina.jpg, tango.jpg...)
//
// Comptes créés (mot de passe DEMO_PASSWORD) :
//   sarra@petcare.test    propriétaire : compte principal de la démo
//   youssef@petcare.test  propriétaire : adoptant (candidature acceptée, adoption confirmée, Happy Tail)
//   refuge@petcare.test   refuge       : annonces dans tous les états, candidatures reçues
//   veto@petcare.test     prestataire  : profil vétérinaire, prestations, horaires, demandes reçues
// Le script peut être relancé : il ne recrée pas ce qui existe déjà.

const fs = require('node:fs');
const path = require('node:path');
const zlib = require('node:zlib');
const { writeOp, commit, getDocument, queryCollection, newId } = require('../src/firestore');

const API = process.env.API_URL || 'http://localhost:3000/api';
const KEY = process.env.FIREBASE_API_KEY || 'AIzaSyBQ6NPS05TgD8qoAKkiQEPbZpxAvEN1Sh0';
const { DEMO_PASSWORD, ADMIN_EMAIL, ADMIN_PASSWORD, PHOTOS_DIR } = process.env;

if (!DEMO_PASSWORD) {
  console.error('Définissez DEMO_PASSWORD (mot de passe des comptes de démonstration).');
  process.exit(1);
}

const DAY = 86400000;
const at = (days, hour = 10, minute = 0) => {
  const d = new Date(Date.now() + days * DAY);
  d.setHours(hour, minute, 0, 0);
  return d;
};
const ymd = (d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
const localMidnight = (days) => { const d = at(days, 0); return d; };

// ----------------------------------------------------------------------------- photos

function crcTable() {
  const table = new Uint32Array(256);
  for (let n = 0; n < 256; n += 1) {
    let c = n;
    for (let k = 0; k < 8; k += 1) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    table[n] = c >>> 0;
  }
  return table;
}
const TABLE = crcTable();
const crc = (buf) => { let c = 0xffffffff; for (const b of buf) c = TABLE[(c ^ b) & 0xff] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; };
function chunk(type, data) {
  const body = Buffer.concat([Buffer.from(type), data]);
  const out = Buffer.alloc(body.length + 8);
  out.writeUInt32BE(data.length, 0); body.copy(out, 4); out.writeUInt32BE(crc(body), body.length + 4);
  return out;
}
/** Image de repli (dégradé + silhouette) quand aucune photo n'est fournie. */
function generated([r1, g1, b1], [r2, g2, b2]) {
  const w = 480; const h = 360; const raw = Buffer.alloc((w * 3 + 1) * h);
  for (let y = 0; y < h; y += 1) {
    const t = y / (h - 1);
    for (let x = 0; x < w; x += 1) {
      const light = (x - 240) ** 2 + (y - 170) ** 2 < 8100 || (x - 185) ** 2 + (y - 85) ** 2 < 784 || (x - 295) ** 2 + (y - 85) ** 2 < 784;
      const base = [r1 + (r2 - r1) * t, g1 + (g2 - g1) * t, b1 + (b2 - b1) * t];
      const px = light ? base.map((v) => Math.min(255, v + 70)) : base;
      const i = y * (w * 3 + 1) + 1 + x * 3;
      raw[i] = px[0]; raw[i + 1] = px[1]; raw[i + 2] = px[2];
    }
  }
  const header = Buffer.alloc(13); header.writeUInt32BE(w, 0); header.writeUInt32BE(h, 4); header[8] = 8; header[9] = 2;
  return Buffer.concat([Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]), chunk('IHDR', header),
    chunk('IDAT', zlib.deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0))]).toString('base64');
}
const FALLBACK = {
  rocky: [[170, 120, 80], [110, 70, 40]], rocky2: [[150, 110, 70], [90, 60, 30]], mimi: [[240, 215, 170], [200, 170, 120]],
  mimi2: [[235, 200, 160], [190, 150, 110]], coco: [[120, 180, 120], [60, 120, 70]], speedy: [[150, 160, 100], [90, 100, 60]],
  felix: [[60, 60, 70], [30, 30, 40]], oscar: [[200, 160, 110], [150, 100, 60]], pirouette: [[200, 200, 210], [140, 140, 160]],
  nina: [[240, 150, 80], [200, 90, 50]], tango: [[230, 200, 140], [180, 140, 80]], tango2: [[220, 190, 130], [170, 130, 70]],
  caramel: [[235, 170, 175], [190, 110, 125]], kiwi: [[90, 170, 165], [30, 110, 105]],
};
function photo(name) {
  const file = PHOTOS_DIR && path.join(PHOTOS_DIR, `${name}.jpg`);
  if (file && fs.existsSync(file)) return fs.readFileSync(file).toString('base64');
  return generated(...FALLBACK[name]);
}

// ----------------------------------------------------------------------------- accès

async function post(url, body) {
  const r = await fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
  return r.json();
}

/** Connecte le compte ou le crée ; renvoie { token, uid }. */
async function account(email, password) {
  const base = 'https://identitytoolkit.googleapis.com/v1/accounts';
  let r = await post(`${base}:signInWithPassword?key=${KEY}`, { email, password, returnSecureToken: true });
  if (!r.idToken) r = await post(`${base}:signUp?key=${KEY}`, { email, password, returnSecureToken: true });
  if (!r.idToken) throw new Error(`Connexion impossible pour ${email} : ${r.error?.message}`);
  return { token: r.idToken, uid: r.localId, email };
}

async function api(method, route, token, body) {
  const r = await fetch(`${API}${route}`, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const data = r.status === 204 ? null : await r.json().catch(() => null);
  if (!r.ok) throw new Error(`${method} ${route} -> ${r.status} ${data?.error ?? ''}`);
  return data;
}

const step = (t) => console.log(`\n${t}`);
const done = (t) => console.log(`  + ${t}`);
const skip = (t) => console.log(`  = ${t} (déjà présent)`);
const warn = (t) => console.log(`  ! ${t}`);

/** Notification dans l'application, écrite comme le fait l'application (n'importe quel membre peut notifier). */
async function notify(from, toUid, title, body, category) {
  await commit(from.token, [writeOp(`users/${toUid}/notifications/${newId()}`, { title, body, category, read: false },
    { serverTimestamps: ['createdAt'], mustNotExist: true })]);
}

// ----------------------------------------------------------------------------- comptes

const PEOPLE = {
  sarra: { email: 'sarra@petcare.test', fullName: 'Sarra Ben Ali', city: 'Tunis', role: 'proprietaire', phone: '+216 22 345 678' },
  youssef: { email: 'youssef@petcare.test', fullName: 'Youssef Trabelsi', city: 'Ariana', role: 'proprietaire', phone: '+216 98 765 432' },
  refuge: { email: 'refuge@petcare.test', fullName: 'Refuge Espoir Animal', city: 'Tunis', role: 'refuge', phone: '+216 71 222 333' },
  veto: { email: 'veto@petcare.test', fullName: 'Dr Amine Gharbi', city: 'Tunis', role: 'prestataire', phone: '+216 71 444 555' },
};

async function seedAccounts() {
  step('Comptes');
  const out = {};
  for (const [key, p] of Object.entries(PEOPLE)) {
    const acc = await account(p.email, DEMO_PASSWORD);
    try {
      const profile = await api('GET', '/users/me', acc.token);
      skip(`${p.email} (${profile.role})`);
    } catch {
      await api('POST', '/users/me', acc.token, { fullName: p.fullName, city: p.city, role: p.role, phone: p.phone });
      done(`${p.email} (${p.role})`);
    }
    out[key] = { ...acc, ...p };
  }
  return out;
}

// ----------------------------------------------------------------------------- module Animaux

// Rocky : perte de 11 % en 12 semaines -> alerte « consulter un vétérinaire » (règle loss-10, source VCA).
// Mimi : poids stable -> pas d'alerte. Félix : archivé (montre l'onglet Archives et la restauration).
const PETS = [
  {
    key: 'rocky', name: 'Rocky', species: 'dog', sex: 'male', birthDate: '2019-04-12', breed: 'Berger allemand', sterilized: true,
    chipNumber: '788100000123456', notes: 'Très protecteur, adore courir à la plage. Mange 2 fois par jour.',
    photos: ['rocky', 'rocky2'], favorite: true,
    weights: [[-84, 32.0], [-56, 31.9], [-28, 31.0], [-12, 30.1], [-2, 28.5, 'Mange moins depuis quelques jours']],
    contacts: [{ name: 'Dr Amine Gharbi', detail: 'Vétérinaire traitant', phone: '+216 71 444 555', emergency: false },
      { name: 'Urgences Vétérinaires Sfax', detail: 'Urgences 24 h/24', phone: '+216 74 300 203', emergency: true }],
  },
  {
    key: 'mimi', name: 'Mimi', species: 'cat', sex: 'female', birthDate: '2021-07-03', breed: 'Persan', sterilized: true,
    chipNumber: '788100000654321', notes: 'Brossage quotidien. Craintive avec les inconnus.', photos: ['mimi', 'mimi2'],
    weights: [[-80, 4.1], [-50, 4.2], [-20, 4.1], [-3, 4.2]],
    contacts: [{ name: 'Dr Amine Gharbi', detail: 'Vétérinaire traitant', phone: '+216 71 444 555', emergency: false }],
  },
  {
    key: 'coco', name: 'Coco', species: 'bird', sex: 'male', birthDate: '2018-02-20', breed: 'Perroquet gris du Gabon', sterilized: false,
    notes: 'Parle beaucoup le matin. Fruits frais chaque jour.', photos: ['coco'], weights: [[-60, 0.45], [-5, 0.46]],
  },
  {
    key: 'speedy', name: 'Speedy', species: 'other', sex: 'female', birthDate: '2015-05-01', birthDateEstimated: true,
    breed: "Tortue d'Hermann", sterilized: false, notes: 'Hibernation de novembre à mars.', photos: ['speedy'], weights: [[-30, 1.2]],
  },
  {
    key: 'felix', name: 'Félix', species: 'cat', sex: 'male', birthDate: '2010-01-15', breed: 'Européen', sterilized: true,
    notes: 'Parti en 2025, son carnet reste consultable.', photos: ['felix'], weights: [[-200, 5.1]], archive: true,
  },
];

async function seedPets(sarra) {
  step('Animaux (Sarra) : fiches, photos, pesées, contacts, alerte de poids, archive');
  const existing = await api('GET', '/pets', sarra.token);
  const ids = {};
  for (const pet of PETS) {
    const found = existing.find((p) => p.name === pet.name);
    if (found) { ids[pet.key] = found.id; skip(`animal ${pet.name}`); continue; }
    const created = await api('POST', '/pets', sarra.token, {
      name: pet.name, species: pet.species, sex: pet.sex, birthDate: pet.birthDate, breed: pet.breed,
      birthDateEstimated: pet.birthDateEstimated === true, chipNumber: pet.chipNumber ?? null, sterilized: pet.sterilized,
      notes: pet.notes, photos: pet.photos.map((p) => ({ data: photo(p) })),
    });
    ids[pet.key] = created.id;
    for (const [days, weightKg, note] of pet.weights) {
      const d = localMidnight(days);
      await api('POST', `/pets/${created.id}/weights`, sarra.token, { date: ymd(d), measuredOn: d.toISOString(), weightKg, note: note ?? null });
    }
    const patch = {};
    if (pet.contacts) patch.contacts = pet.contacts;
    if (pet.favorite) patch.favorite = true;
    if (Object.keys(patch).length) await api('PATCH', `/pets/${created.id}`, sarra.token, patch);
    done(`${pet.name} (${pet.photos.length} photo(s), ${pet.weights.length} pesée(s))`);
  }
  return ids;
}

// ----------------------------------------------------------------------------- module Santé

const HEALTH = {
  rocky: [
    { type: 'vaccin', title: 'Rage', date: -330, next: 35, vaccineName: 'Rabisin (Rage)', batchNumber: 'RB-55120', practitioner: 'Dr Amine Gharbi', cost: 35 },
    { type: 'vaccin', title: 'CHPPiL', date: -380, next: -15, vaccineName: 'CHPPiL Rappel annuel', batchNumber: 'VX-88213', practitioner: 'Dr Amine Gharbi', cost: 45 },
    { type: 'visite', title: 'Perte d’appétit', date: -2, next: 7, practitioner: 'Dr Amine Gharbi', cost: 40, description: 'Appétit en baisse et perte de poids. Prise de sang demandée, contrôle dans une semaine.' },
    { type: 'examen', title: 'Prise de sang', date: -1, practitioner: 'Dr Amine Gharbi', cost: 80, description: 'Bilan hépatique et rénal : résultats attendus sous 48 h.' },
    { type: 'allergie', title: 'Puces (DAPP)', date: -400, practitioner: 'Dr Amine Gharbi', description: 'Gravité : Modérée\nDermatite allergique aux piqûres de puces.' },
    { type: 'note', title: 'Changement d’alimentation', date: -20, description: 'Passage à des croquettes pour chien senior.' },
  ],
  mimi: [
    { type: 'vaccin', title: 'Typhus coryza', date: -355, next: 10, vaccineName: 'Typhus Coryza Leucose', batchNumber: 'TC-34001', practitioner: 'Clinique Vétérinaire de Carthage', cost: 50 },
    { type: 'visite', title: 'Contrôle annuel', date: -90, practitioner: 'Clinique Vétérinaire de Carthage', cost: 35, description: 'Bon état général. Surveiller les yeux (larmoiement fréquent chez le Persan).' },
    { type: 'allergie', title: 'Poulet', date: -200, practitioner: 'Clinique Vétérinaire de Carthage', description: 'Gravité : Légère\nDémangeaisons après les croquettes au poulet.' },
  ],
  coco: [
    { type: 'visite', title: 'Contrôle du bec et des griffes', date: -40, practitioner: 'Dr Amine Gharbi', cost: 30, description: 'Griffes coupées, bec en bon état.' },
  ],
  felix: [
    { type: 'visite', title: 'Suivi rénal', date: -400, practitioner: 'Cabinet Dr Ben Youssef', cost: 60, description: 'Insuffisance rénale chronique, régime adapté.' },
  ],
};

const TREATMENTS = {
  rocky: [
    // En cours : apparaît dans le tableau du jour (prises à cocher).
    { category: 'Antibiotique', name: 'Amoxicilline 500 mg', subtitle: 'Amoxicilline', form: 'comprime', practitioner: 'Dr Amine Gharbi',
      posology: '1 comprimé matin et soir pendant le repas, 7 jours.', start: -2, end: 5, doseTimes: ['08:00', '20:00'], doses: [[-2, '20:00'], [-1, '08:00'], [-1, '20:00']] },
    { category: 'Antiparasitaire', name: 'Bravecto 1000 mg', subtitle: 'Fluralaner', form: 'comprime', practitioner: 'Dr Amine Gharbi',
      posology: '1 comprimé à croquer tous les 3 mois.', start: -60, end: -60, doseTimes: ['09:00'], renewal: 30, doses: [[-60, '09:00']] },
  ],
  mimi: [
    { category: 'Anti-inflammatoire', name: 'Collyre Tévémyxine', subtitle: 'Néomycine', form: 'gouttes', practitioner: 'Clinique Vétérinaire de Carthage',
      posology: '1 goutte dans chaque œil 3 fois par jour, 5 jours.', start: -30, end: -25, doseTimes: ['08:00', '14:00', '20:00'], doses: [] },
    // Arrêté avant la fin, avec une raison.
    { category: 'Complément', name: 'Malt pour chat', form: 'autre', practitioner: 'Clinique Vétérinaire de Carthage',
      posology: '2 cm de pâte par jour contre les boules de poils.', start: -10, end: 20, doseTimes: ['19:00'], doses: [], stop: 'Mimi refuse la pâte, remplacé par une alimentation adaptée.' },
  ],
};

async function seedHealth(sarra, petIds) {
  step('Santé (Sarra) : carnet, vaccins (à jour / en retard), traitements (en cours / terminé / arrêté)');
  for (const [key, entries] of Object.entries(HEALTH)) {
    const petId = petIds[key];
    const present = await api('GET', `/pets/${petId}/health/entries`, sarra.token);
    if (present.length > 0) { skip(`carnet de ${key}`); continue; }
    for (const e of entries) {
      const body = { type: e.type, title: e.title, date: at(e.date, 9).toISOString() };
      for (const k of ['description', 'practitioner', 'cost', 'vaccineName', 'batchNumber']) if (e[k] !== undefined) body[k] = e[k];
      if (e.next !== undefined) body.nextReminderAt = at(e.next, 9).toISOString();
      await api('POST', `/pets/${petId}/health/entries`, sarra.token, body);
    }
    done(`carnet de ${key} (${entries.length} soins)`);
  }
  for (const [key, list] of Object.entries(TREATMENTS)) {
    const petId = petIds[key];
    const present = await api('GET', `/pets/${petId}/health/treatments`, sarra.token);
    for (const t of list) {
      if (present.some((x) => x.name === t.name)) { skip(`traitement ${t.name}`); continue; }
      const created = await api('POST', `/pets/${petId}/health/treatments`, sarra.token, {
        category: t.category, name: t.name, subtitle: t.subtitle ?? null, form: t.form, practitioner: t.practitioner, posology: t.posology,
        startDate: at(t.start, 0).toISOString(), endDate: at(t.end, 23, 59).toISOString(), doseTimes: t.doseTimes,
        renewalAt: t.renewal !== undefined ? at(t.renewal, 9).toISOString() : null,
      });
      for (const [day, time] of t.doses) {
        const [h, m] = time.split(':').map(Number);
        await api('POST', `/pets/${petId}/health/treatments/${created.id}/doses`, sarra.token, { at: at(day, h, m).toISOString() });
      }
      if (t.stop) await api('POST', `/pets/${petId}/health/treatments/${created.id}/stop`, sarra.token, { reason: t.stop });
      done(`traitement ${t.name} (${key})`);
    }
  }
  // Félix est archivé après son carnet (un carnet archivé ne se modifie plus).
  const felix = (await api('GET', '/pets', sarra.token)).find((p) => p.id === petIds.felix);
  if (felix && felix.status === 'active') {
    await api('POST', `/pets/${petIds.felix}/archive`, sarra.token, {});
    done('Félix archivé');
  }
}

// ----------------------------------------------------------------------------- module Rendez-vous

async function seedAgenda(sarra) {
  step('Rendez-vous et rappels (Sarra)');
  const current = await api('GET', '/appointments', sarra.token);
  const exists = (title, petName) => current.find((x) => x.title === title && x.petName === petName);
  const toComplete = [];

  const wanted = [
    { petName: 'Rocky', title: 'Contrôle poids et résultats', type: 'veterinaire', startsAt: at(1, 10), durationMinutes: 30, place: 'exterieur', location: 'Cabinet Dr Amine Gharbi, Tunis', notes: 'Apporter le carnet et les résultats de la prise de sang', reminderMinutes: 1440 },
    { petName: 'Mimi', title: 'Rappel vaccin Typhus', type: 'vaccin', startsAt: at(10, 9, 30), durationMinutes: 30, place: 'exterieur', location: 'Clinique Vétérinaire de Carthage', notes: '', reminderMinutes: 2880 },
    { petName: 'Mimi', title: 'Toilettage', type: 'toilettage', startsAt: at(4, 15), durationMinutes: 60, place: 'exterieur', location: 'Salon Pattes Propres, Lac 2', notes: 'Coupe sanitaire', reminderMinutes: 60, reschedule: at(6, 16) },
    { petName: 'Coco', title: 'Coupe des griffes', type: 'soin', startsAt: at(3, 11), durationMinutes: 15, place: 'domicile', location: 'À la maison', notes: '', reminderMinutes: 0, cancel: 'Fait à la maison finalement' },
    { petName: 'Rocky', title: 'Séance d’éducation', type: 'education', startsAt: at(14, 17), durationMinutes: 60, place: 'exterieur', location: 'Parc du Belvédère', notes: 'Travail du rappel', reminderMinutes: 120 },
    // Démarre dans 90 s pour 5 min : il sera « terminé » à la fin du script (historique).
    { petName: 'Speedy', title: 'Bain tiède', type: 'soin', startsAt: new Date(Date.now() + 90000), durationMinutes: 5, place: 'domicile', location: 'À la maison', notes: '', reminderMinutes: 0, complete: true },
  ];
  for (const a of wanted) {
    const found = exists(a.title, a.petName);
    if (found) { skip(`rendez-vous ${a.title}`); continue; }
    const { reschedule, cancel, complete, ...body } = a;
    let appt = await api('POST', '/appointments', sarra.token, { ...body, startsAt: a.startsAt.toISOString() });
    let state = 'confirmé';
    if (reschedule) {
      appt = await api('POST', `/appointments/${appt.id}/reschedule`, sarra.token, { startsAt: reschedule.toISOString(), reason: 'Le salon a décalé ses horaires', version: appt.version });
      state = 'reporté';
    }
    if (cancel) {
      await api('POST', `/appointments/${appt.id}/cancel`, sarra.token, { reason: cancel, version: appt.version });
      state = 'annulé';
    }
    if (complete) { toComplete.push(appt); state = 'à terminer en fin de script'; }
    done(`${a.title} (${a.petName}) : ${state}`);
  }

  const reminders = await api('GET', '/reminders', sarra.token);
  const care = [
    { petName: 'Rocky', title: 'Vermifuge', category: 'medicament', dueAt: at(2, 8), description: 'Milbemax 1 comprimé' },
    { petName: 'Mimi', title: 'Brossage', category: 'hygiene', dueAt: at(0, 19) },
    { petName: 'Rocky', title: 'Pesée de contrôle', category: 'controle', dueAt: at(5, 9), description: 'Vérifier que la perte de poids s’arrête' },
    { petName: 'Coco', title: 'Nettoyer la cage', category: 'hygiene', dueAt: at(-1, 10), done: true },
  ];
  for (const r of care) {
    if (reminders.some((x) => x.title === r.title && x.petName === r.petName)) { skip(`rappel ${r.title}`); continue; }
    const { done: isDone, ...body } = r;
    const created = await api('POST', '/reminders', sarra.token, { ...body, dueAt: r.dueAt.toISOString() });
    if (isDone) await api('PATCH', `/reminders/${created.id}`, sarra.token, { done: true });
    done(`rappel ${r.title} (${r.petName})${isDone ? ' : fait' : ''}`);
  }
  return toComplete;
}

// ----------------------------------------------------------------------------- module Adoption

const base = {
  badges: [], goodWithKids: true, goodWithCats: true, goodWithDogs: true, needsGarden: false, energy: 'moyen', okAloneHours: 5,
  needs: 'Vaccins à jour, visite chez le vétérinaire une fois par an.', conditions: 'Rencontre préalable et visite du logement.',
};
const LISTINGS = {
  refuge: [
    { ...base, key: 'oscar', name: 'Oscar', species: 'chien', breed: 'Beagle', sex: 'male', birthDate: at(-730).toISOString(), size: 'moyen', city: 'Tunis', title: 'Oscar, beagle joyeux et gourmand', story: 'Oscar a été abandonné sur une aire d’autoroute. Il est propre, adore les enfants et les longues balades.', badges: ['joueur', 'ok_enfants', 'ok_chiens'], energy: 'eleve', okAloneHours: 4, photos: ['oscar'] },
    { ...base, key: 'pirouette', name: 'Pirouette', species: 'lapin', breed: 'Bélier', sex: 'femelle', birthDate: at(-400).toISOString(), size: 'petit', city: 'Ariana', title: 'Pirouette, lapine curieuse', story: 'Pirouette aime explorer et grignoter du foin. Elle a besoin d’un enclos spacieux.', badges: ['calme', 'interieur'], energy: 'faible', goodWithDogs: false, photos: ['pirouette'] },
    { ...base, key: 'nina', name: 'Nina', species: 'chat', breed: 'Européenne tigrée', sex: 'femelle', birthDate: at(-500).toISOString(), size: 'petit', city: 'Tunis', title: 'Nina, câline et douce', story: 'Nina a été recueillie avec ses chatons. Elle est stérilisée, vaccinée et adore les genoux.', badges: ['affectueux', 'calme', 'ok_chats'], energy: 'faible', photos: ['nina'] },
    { ...base, key: 'tango', name: 'Tango', species: 'chien', breed: 'Labrador', sex: 'male', birthDate: at(-1200).toISOString(), size: 'grand', city: 'La Marsa', title: 'Tango cherche une famille active', story: 'Tango est un labrador fidèle et joueur qui adore l’eau. Il lui faut un jardin et des sorties quotidiennes.', badges: ['energique', 'exterieur', 'eduque'], energy: 'eleve', needsGarden: true, goodWithCats: false, okAloneHours: 3, photos: ['tango'] },
    { ...base, key: 'kiwi', name: 'Kiwi', species: 'oiseau', breed: 'Perruche ondulée', sex: 'male', birthDate: at(-200).toISOString(), size: 'petit', city: 'Tunis', title: 'Kiwi (en préparation)', story: 'Annonce en cours de rédaction.', badges: [], photos: ['kiwi'], draft: true },
  ],
  sarra: [
    { ...base, key: 'caramel', name: 'Caramel', species: 'chat', breed: 'Persan croisé', sex: 'male', birthDate: at(-120).toISOString(), size: 'petit', city: 'Tunis', title: 'Caramel, chaton de Mimi', story: 'Caramel est un des chatons de Mimi. Il est sevré, joueur et très câlin.', badges: ['joueur', 'affectueux', 'ok_enfants'], energy: 'moyen', photos: ['caramel'] },
  ],
};

const ANSWERS = {
  sarra: { housing: 'maison', hasGarden: true, tenure: 'proprietaire', city: 'Tunis', adults: 2, kids: 1, kidsAges: ['6 - 12 ans'], cats: 1, dogs: 1, otherPets: 2, allergies: false, hoursAlone: 4, lifestyle: 'dynamique', experience: 'connaisseur', motivation: 'Nous avons déjà un berger allemand et une chatte, et un grand jardin. Nous voulons offrir un foyer à un animal du refuge.' },
  youssef: { housing: 'maison', hasGarden: true, tenure: 'proprietaire', city: 'Ariana', adults: 2, kids: 2, kidsAges: ['6 - 12 ans', '13+ ans'], cats: 0, dogs: 0, otherPets: 0, allergies: false, hoursAlone: 3, lifestyle: 'dynamique', experience: 'familier', motivation: 'Nos enfants rêvent d’un chien. Nous faisons du sport tous les week-ends et avons une maison avec jardin près de la plage.' },
};

async function seedAdoption(people) {
  step('Adoption : annonces, candidatures (tous les statuts), réservation, adoption, Happy Tail, favoris');
  const { refuge, sarra, youssef } = people;
  const ids = {};
  for (const owner of ['refuge', 'sarra']) {
    const acc = people[owner];
    const mine = await api('GET', '/adoptions/mine', acc.token);
    for (const l of LISTINGS[owner]) {
      const found = mine.find((x) => x.name === l.name);
      if (found) { ids[l.key] = found.id; skip(`annonce ${l.name}`); continue; }
      const { key, draft, photos, ...fields } = l;
      const created = await api('POST', '/adoptions', acc.token, { ...fields, photos: photos.map(photo), publish: !draft });
      ids[key] = created.id;
      done(`annonce ${l.name} (${owner}${draft ? ', brouillon' : ''})`);
    }
  }

  // Candidatures : [candidat, annonce]
  const applications = [['sarra', 'oscar'], ['sarra', 'pirouette'], ['sarra', 'nina'], ['sarra', 'tango'], ['youssef', 'nina'], ['youssef', 'tango'], ['youssef', 'caramel']];
  for (const [who, listing] of applications) {
    const acc = people[who];
    const mine = await api('GET', `/adoptions/${ids[listing]}/applications/me`, acc.token);
    if (mine) { skip(`candidature ${who} -> ${listing}`); continue; }
    const listingDoc = await api('GET', `/adoptions/${ids[listing]}`, acc.token);
    if (!['disponible', 'reservee'].includes(listingDoc.status)) { skip(`candidature ${who} -> ${listing} (annonce ${listingDoc.status})`); continue; }
    const app = await api('POST', `/adoptions/${ids[listing]}/applications`, acc.token, ANSWERS[who]);
    done(`candidature ${who} -> ${listing} (score ${app.score ?? '?'})`);
  }

  const appId = (listing, who) => `${ids[listing]}_${people[who].uid}`;
  const appDoc = (listing, who) => getDocument(people[who].token, `adoptionApplications/${appId(listing, who)}`);
  const listingPath = (listing) => `adoptions/${ids[listing]}`;
  const ts = { serverTimestamps: ['updatedAt'] };

  // Oscar : le refuge étudie le dossier de Sarra.
  if ((await appDoc('oscar', 'sarra'))?.status === 'envoyee') {
    await commit(refuge.token, [writeOp(`adoptionApplications/${appId('oscar', 'sarra')}`, { status: 'en_etude' }, ts)]);
    done('Oscar : dossier de Sarra « en cours d’étude »');
  }
  // Pirouette : refusée avec un motif.
  if ((await appDoc('pirouette', 'sarra'))?.status === 'envoyee') {
    await commit(refuge.token, [writeOp(`adoptionApplications/${appId('pirouette', 'sarra')}`, { status: 'refusee', refusalReason: 'Pirouette ne peut pas vivre avec un chien.' }, ts)]);
    await notify(refuge, sarra.uid, 'Candidature non retenue', 'Votre demande pour Pirouette n\'a pas été retenue.', 'adoption');
    done('Pirouette : candidature de Sarra refusée (motif)');
  }
  // Nina : le refuge accepte Youssef -> annonce réservée ; la candidature de Sarra reste en attente.
  if ((await appDoc('nina', 'youssef'))?.status === 'envoyee') {
    await commit(refuge.token, [
      writeOp(`adoptionApplications/${appId('nina', 'youssef')}`, { status: 'acceptee' }, ts),
      writeOp(listingPath('nina'), { status: 'reservee', acceptedApplicationId: appId('nina', 'youssef') }, ts),
    ]);
    await notify(refuge, youssef.uid, 'Candidature acceptée 🎉', 'Refuge Espoir Animal a accepté votre demande pour Nina.', 'adoption');
    done('Nina : Youssef accepté, annonce réservée');
  }
  // Tango : accepté puis adoption confirmée pour Youssef ; Sarra refusée automatiquement.
  if ((await appDoc('tango', 'youssef'))?.status === 'envoyee') {
    await commit(refuge.token, [
      writeOp(`adoptionApplications/${appId('tango', 'youssef')}`, { status: 'acceptee' }, ts),
      writeOp(listingPath('tango'), { status: 'reservee', acceptedApplicationId: appId('tango', 'youssef') }, ts),
    ]);
    await commit(refuge.token, [
      writeOp(listingPath('tango'), { status: 'adoptee', adopterId: youssef.uid, adopterName: youssef.fullName }, { serverTimestamps: ['adoptedAt', 'updatedAt'] }),
      writeOp(`adoptionApplications/${appId('tango', 'youssef')}`, { status: 'adoptee' }, ts),
      writeOp(`adoptionApplications/${appId('tango', 'sarra')}`, { status: 'refusee', refusalReason: 'Tango a trouvé une famille.' }, ts),
    ]);
    await notify(refuge, youssef.uid, 'Adoption confirmée 🐾', 'Tango fait maintenant partie de votre famille. Partagez votre Happy Tail !', 'adoption');
    await notify(refuge, sarra.uid, 'Tango a trouvé une famille', "Merci pour votre candidature. D'autres compagnons attendent un foyer.", 'adoption');
    done('Tango : adopté par Youssef (candidature de Sarra refusée)');
  }

  // Happy Tail de Youssef sur Tango, aimée par Sarra.
  const tail = await getDocument(null, `happyTails/${ids.tango}`);
  if (tail) skip('Happy Tail de Tango');
  else {
    await commit(youssef.token, [writeOp(`happyTails/${ids.tango}`, {
      listingId: ids.tango, authorId: youssef.uid, authorName: youssef.fullName, publisherName: refuge.fullName,
      animalName: 'Tango', species: 'chien', breed: 'Labrador', title: 'Tango, le roi de la plage',
      story: 'Trois semaines après son arrivée, Tango a déjà appris à nager avec les enfants. Il dort au pied du lit et accueille tout le monde à la porte. Merci au Refuge Espoir Animal !',
      before: photo('tango'), after: photo('tango2'), likeCount: 0,
    }, { serverTimestamps: ['createdAt', 'updatedAt'], mustNotExist: true })]);
    await commit(sarra.token, [
      writeOp(`users/${sarra.uid}/likedHappyTails/${ids.tango}`, {}, { serverTimestamps: ['createdAt'], mustNotExist: true }),
      writeOp(`happyTails/${ids.tango}`, { likeCount: 1 }),
    ]);
    done('Happy Tail « Tango, le roi de la plage » (1 j’aime de Sarra)');
  }

  const favorites = (await api('GET', '/adoptions/favorites', sarra.token)).ids;
  for (const key of ['oscar', 'nina']) {
    if (favorites.includes(ids[key])) continue;
    await api('PUT', `/adoptions/${ids[key]}/favorite`, sarra.token, {});
    done(`favori de Sarra : ${key}`);
  }
}

// ----------------------------------------------------------------------------- module Services

const VET_SERVICES = [
  ['Consultation générale', 30, 45, 'Examen complet, conseils et ordonnance.'],
  ['Vaccination', 20, 60, 'Vaccin et mise à jour du carnet.'],
  ['Bilan sanguin', 30, 80, 'Prise de sang et analyse.'],
  ['Visite à domicile', 45, 90, 'Consultation chez vous, Grand Tunis.'],
];

async function seedServices(people, admin) {
  step('Services : profil prestataire (Dr Amine), prestations, horaires, réservations');
  const { veto, sarra, youssef } = people;
  const profile = await api('PUT', '/services/providers/me', veto.token, {
    name: 'Cabinet Vétérinaire Dr Amine Gharbi', category: 'Vétérinaires', city: 'Tunis',
    description: 'Médecine générale, vaccins, suivi nutritionnel et visites à domicile pour chiens, chats et NAC.',
    phone: veto.phone, email: veto.email, address: 'Rue du Lac Biwa, Les Berges du Lac, Tunis',
  });
  const mine = await api('GET', '/services/providers/me/services', veto.token);
  for (const [name, durationMinutes, price, description] of VET_SERVICES) {
    if (mine.some((s) => s.name === name)) continue;
    await api('POST', '/services/providers/me/services', veto.token, { name, category: 'Vétérinaires', durationMinutes, price, status: 'published', description });
  }
  for (const day of [1, 2, 3, 4, 5]) {
    await api('PUT', `/services/providers/me/availability/${day}`, veto.token, { enabled: true, ranges: [{ start: '08:30', end: '12:30' }, { start: '14:30', end: '18:30' }] });
  }
  await api('PUT', '/services/providers/me/availability/6', veto.token, { enabled: true, ranges: [{ start: '09:00', end: '13:00' }] });
  done(`profil, ${VET_SERVICES.length} prestations, horaires lun-sam (statut : ${profile.status})`);

  let published = profile.status === 'published';
  if (!published && admin) {
    await api('PUT', `/services/providers/${profile.id}/status`, admin.token, { status: 'published' });
    published = true;
    done('profil publié par l’administrateur');
  }

  const sarraBookings = await api('GET', '/services/bookings?as=client', sarra.token);
  const providers = await api('GET', '/services/providers', sarra.token);
  const bookings = [];
  // Annuaire existant (comptes de l'équipe) : demandes en attente côté client.
  const salon = providers.find((p) => p.name === 'Salon Pattes Propres');
  if (salon) bookings.push({ client: sarra, provider: salon, animal: 'Mimi', day: 6, hour: 10 });
  const pension = providers.find((p) => p.name === 'Pension Les Câlins');
  if (pension) bookings.push({ client: sarra, provider: pension, animal: 'Rocky', day: 21, hour: 9 });
  if (published) {
    const me = { id: profile.id, name: 'Cabinet Vétérinaire Dr Amine Gharbi' };
    bookings.push({ client: sarra, provider: me, service: 'Bilan sanguin', animal: 'Rocky', day: 2, hour: 9, status: 'confirmed' });
    bookings.push({ client: sarra, provider: me, service: 'Vaccination', animal: 'Mimi', day: 8, hour: 15 });
    bookings.push({ client: sarra, provider: me, service: 'Visite à domicile', animal: 'Coco', day: 5, hour: 11, status: 'declined' });
    bookings.push({ client: youssef, provider: me, service: 'Consultation générale', animal: 'Tango', day: 3, hour: 16 });
    bookings.push({ client: youssef, provider: me, service: 'Vaccination', animal: 'Tango', day: 12, hour: 10 });
  } else {
    warn('profil du Dr Amine en attente : relancez avec ADMIN_EMAIL/ADMIN_PASSWORD pour le publier et créer ses réservations');
  }

  const youssefBookings = await api('GET', '/services/bookings?as=client', youssef.token);
  for (const b of bookings) {
    const already = (b.client === sarra ? sarraBookings : youssefBookings)
      .some((x) => x.providerName === b.provider.name && x.animalName === b.animal);
    if (already) { skip(`réservation ${b.provider.name} (${b.animal})`); continue; }
    const services = await api('GET', `/services/providers/${b.provider.id}/services`, b.client.token);
    const service = services.find((s) => s.name === b.service) ?? services[0];
    const booking = await api('POST', '/services/bookings', b.client.token, {
      providerId: b.provider.id, serviceId: service.id, animalName: b.animal, dateTime: at(b.day, b.hour).toISOString(),
      notes: b.animal === 'Rocky' ? 'Suite à la perte de poids signalée par l’application' : '',
    });
    if (b.status) await api('PATCH', `/services/bookings/${booking.id}/status`, veto.token, { status: b.status });
    done(`réservation ${service.name} chez ${b.provider.name} (${b.client.fullName}, ${b.animal}) : ${b.status ?? 'en attente'}`);
  }

  // Rendez-vous réservé auprès du prestataire (agenda partagé) : en attente de confirmation.
  if (published) {
    const agenda = await api('GET', '/appointments', youssef.token);
    if (!agenda.some((a) => a.title === 'Bilan de santé Tango')) {
      const services = await api('GET', `/services/providers/${profile.id}/services`, youssef.token);
      await api('POST', '/appointments', youssef.token, {
        petName: 'Tango', title: 'Bilan de santé Tango', type: 'veterinaire', startsAt: at(7, 11).toISOString(), durationMinutes: 30,
        place: 'exterieur', location: 'Cabinet Vétérinaire Dr Amine Gharbi', notes: 'Premier bilan après adoption', reminderMinutes: 1440,
        providerId: profile.id, providerName: 'Cabinet Vétérinaire Dr Amine Gharbi', serviceId: services[0].id,
      });
      done('rendez-vous « Bilan de santé Tango » réservé chez le Dr Amine (en attente)');
    }
  }
}

// ----------------------------------------------------------------------------- notifications d'accueil

async function seedWelcome(people) {
  step('Notifications');
  const { sarra, veto, refuge } = people;
  const current = await api('GET', '/users/me/notifications', sarra.token);
  const titles = new Set(current.map((n) => n.title));
  const wanted = [
    [refuge, sarra.uid, 'Nouveaux compagnons à adopter', 'Oscar, Nina et Pirouette attendent une famille au Refuge Espoir Animal.', 'adoption'],
    [veto, sarra.uid, 'Résultats de Rocky', 'Les résultats de la prise de sang de Rocky arrivent demain. Pensez au rendez-vous de contrôle.', 'sante'],
  ];
  for (const [from, to, title, body, category] of wanted) {
    if (titles.has(title)) continue;
    await notify(from, to, title, body, category);
    done(`notification « ${title} »`);
  }
}

// ----------------------------------------------------------------------------- lancement

(async () => {
  const people = await seedAccounts();
  const admin = ADMIN_EMAIL && ADMIN_PASSWORD ? await account(ADMIN_EMAIL, ADMIN_PASSWORD) : null;

  const petIds = await seedPets(people.sarra);
  await seedHealth(people.sarra, petIds);
  const toComplete = await seedAgenda(people.sarra);
  await seedAdoption(people);
  await seedServices(people, admin);
  await seedWelcome(people);

  for (const appt of toComplete) {
    const wait = new Date(appt.endsAt).getTime() + 5000 - Date.now();
    if (wait > 0) {
      console.log(`\nAttente de ${Math.ceil(wait / 1000)} s pour terminer « ${appt.title} »...`);
      await new Promise((r) => setTimeout(r, wait));
    }
    const fresh = await api('GET', `/appointments/${appt.id}`, people.sarra.token);
    await api('POST', `/appointments/${appt.id}/complete`, people.sarra.token, { version: fresh.version });
    done(`« ${appt.title} » terminé (historique)`);
  }

  const alerts = (await api('GET', '/users/me/notifications', people.sarra.token)).filter((n) => /poids/i.test(n.title));
  console.log(`\nAlerte de poids de Rocky : ${alerts.length ? `notification « ${alerts[0].title} »` : 'aucune notification (vérifiez le serveur)'}`);
  console.log('\nTerminé.');
})().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
