const { ApiError } = require('../firestore');
const E = require('./enums');

const MAX_PHOTOS = 5;
const MAX_BADGES = 5;
// 350 Ko d'image : environ 467 000 caractères en base64.
const MAX_PHOTO_CHARS = 480000;
const BASE64 = /^[A-Za-z0-9+/]+={0,2}$/;

function text(value, label, { min = 0, max = 80 } = {}) {
  const clean = typeof value === 'string' ? value.trim() : '';
  if (clean.length < min) throw new ApiError(400, min <= 1 ? `${label} est obligatoire.` : `${label} est trop court.`);
  if (clean.length > max) throw new ApiError(400, `${label} est trop long (${max} caractères maximum).`);
  return clean;
}

function oneOf(value, allowed, label) {
  if (!allowed.includes(value)) throw new ApiError(400, `${label} est invalide.`);
  return value;
}

function bool(value) {
  return value === true;
}

function integer(value, label, { min, max, fallback }) {
  const n = value === undefined || value === null ? fallback : Number(value);
  if (!Number.isInteger(n) || n < min || n > max) throw new ApiError(400, `${label} est invalide.`);
  return n;
}

function pastDate(value, label) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime()) || date > new Date()) throw new ApiError(400, `${label} est invalide.`);
  return date;
}

/** Vérifie les photos (liste de textes base64) et renvoie la liste nettoyée. */
function photos(value) {
  const list = value === undefined ? [] : value;
  if (!Array.isArray(list) || list.length > MAX_PHOTOS) {
    throw new ApiError(400, `Une annonce accepte ${MAX_PHOTOS} photos au maximum.`);
  }
  for (const photo of list) {
    if (typeof photo !== 'string' || !BASE64.test(photo)) throw new ApiError(400, 'Une photo est invalide.');
    if (photo.length > MAX_PHOTO_CHARS) throw new ApiError(400, 'Une photo est trop lourde (350 Ko maximum).');
  }
  return list;
}

/** Champs d'une annonce, tels que l'écran « Publier une annonce » les envoie. */
function listingFields(body = {}) {
  const badges = Array.isArray(body.badges) ? [...new Set(body.badges)] : [];
  if (badges.length > MAX_BADGES) throw new ApiError(400, `Choisissez ${MAX_BADGES} badges au maximum.`);
  badges.forEach((b) => oneOf(b, E.BADGES, 'Un badge'));

  return {
    name: text(body.name, "Le nom de l'animal", { min: 1, max: 60 }),
    species: oneOf(body.species, E.SPECIES, "L'espèce"),
    breed: text(body.breed, 'La race', { max: 80 }),
    sex: oneOf(body.sex, E.SEX, 'Le sexe'),
    birthDate: pastDate(body.birthDate, 'La date de naissance'),
    size: oneOf(body.size, E.SIZE, 'La taille'),
    city: text(body.city, 'La ville', { min: 1, max: 80 }),
    title: text(body.title, "Le titre de l'annonce", { min: 1, max: 120 }),
    story: text(body.story, "L'histoire", { max: 2000 }),
    needs: text(body.needs, 'Les besoins', { max: 1000 }),
    conditions: text(body.conditions, "Les conditions d'adoption", { max: 1000 }),
    badges,
    goodWithKids: bool(body.goodWithKids),
    goodWithCats: bool(body.goodWithCats),
    goodWithDogs: bool(body.goodWithDogs),
    needsGarden: bool(body.needsGarden),
    energy: oneOf(body.energy, E.ENERGY, "Le niveau d'énergie"),
    okAloneHours: integer(body.okAloneHours, 'Le temps seul', { min: 0, max: 24, fallback: 4 }),
  };
}

/** Réponses du questionnaire d'adoption, comme `ApplicationAnswers.toMap` (Dart). */
function applicationAnswers(body = {}) {
  const tenure = oneOf(body.tenure, E.TENURE, 'Le statut du logement');
  const kids = integer(body.kids, "Le nombre d'enfants", { min: 0, max: 20, fallback: 0 });
  const kidsAges = Array.isArray(body.kidsAges) ? body.kidsAges.filter((a) => E.KIDS_AGE_RANGES.includes(a)) : [];

  return {
    housing: oneOf(body.housing, E.HOUSING, 'Le type de logement'),
    hasGarden: bool(body.hasGarden),
    tenure,
    landlordAgrees: tenure === 'locataire' && bool(body.landlordAgrees),
    city: text(body.city, 'La ville', { max: 80 }),
    adults: integer(body.adults, "Le nombre d'adultes", { min: 1, max: 20, fallback: 1 }),
    kids,
    kidsAges: kids === 0 ? [] : kidsAges,
    cats: integer(body.cats, 'Le nombre de chats', { min: 0, max: 50, fallback: 0 }),
    dogs: integer(body.dogs, 'Le nombre de chiens', { min: 0, max: 50, fallback: 0 }),
    otherPets: integer(body.otherPets, "Le nombre d'autres animaux", { min: 0, max: 50, fallback: 0 }),
    allergies: bool(body.allergies),
    hoursAlone: integer(body.hoursAlone, 'Le temps seul', { min: 0, max: 24, fallback: 4 }),
    lifestyle: oneOf(body.lifestyle, E.LIFESTYLE, 'Le rythme de vie'),
    experience: oneOf(body.experience, E.EXPERIENCE, "L'expérience"),
    motivation: text(body.motivation, 'La motivation', { max: 1500 }),
  };
}

module.exports = { listingFields, applicationAnswers, photos, MAX_PHOTOS };
