// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get languageTooltip => 'Langue';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageEnglish => 'English';

  @override
  String get comingSoon => 'Bientôt disponible';

  @override
  String get navHome => 'Accueil';

  @override
  String get navPets => 'Mes animaux';

  @override
  String get navCommunity => 'Communauté';

  @override
  String get navServices => 'Services';

  @override
  String get shellSignIn => 'Se connecter';

  @override
  String get shellNotifications => 'Notifications';

  @override
  String shellNotificationsUnread(int count) {
    return 'Notifications ($count non lues)';
  }

  @override
  String get shellMyProfile => 'Mon profil';

  @override
  String get speciesDog => 'Chien';

  @override
  String get speciesCat => 'Chat';

  @override
  String get speciesRabbit => 'Lapin';

  @override
  String get speciesRodent => 'Rongeur';

  @override
  String get speciesBird => 'Oiseau';

  @override
  String get speciesOther => 'Autre';

  @override
  String get sexMale => 'Mâle';

  @override
  String get sexFemale => 'Femelle';

  @override
  String get petsAgeUnknown => 'Âge inconnu';

  @override
  String get petsAgeNewborn => 'Nouveau-né';

  @override
  String petsAgeWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count semaines',
      one: '1 semaine',
    );
    return '$_temp0';
  }

  @override
  String petsAgeMonths(int count) {
    return '$count mois';
  }

  @override
  String petsAgeYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ans',
      one: '1 an',
    );
    return '$_temp0';
  }

  @override
  String petsAgeYearsHalf(String years) {
    return '$years et demi';
  }

  @override
  String petsAgeYearsMonths(String years, int months) {
    return '$years et $months mois';
  }

  @override
  String get petsSinceToday => 'aujourd\'hui';

  @override
  String get petsSinceYesterday => 'hier';

  @override
  String petsSinceDays(int count) {
    return 'il y a $count j';
  }

  @override
  String petsSinceWeeks(int count) {
    return 'il y a $count sem';
  }

  @override
  String get petsSinceLastMonth => 'le mois dernier';

  @override
  String petsSinceMonths(int count) {
    return 'il y a $count mois';
  }

  @override
  String get petsSinceOverYear => 'il y a plus d\'un an';

  @override
  String petsDaysAgo(int count) {
    return 'il y a $count jours';
  }

  @override
  String get petsSterilizedMale => 'Stérilisé';

  @override
  String get petsSterilizedFemale => 'Stérilisée';

  @override
  String get petsPhotoFromGallery => 'Choisir dans la galerie';

  @override
  String get petsPhotoFromCamera => 'Prendre une photo';

  @override
  String get petsPhotoTooLarge =>
      'Photo trop lourde. Choisissez une autre image.';

  @override
  String get petsLoadError =>
      'Impossible de charger vos animaux. Vérifiez votre connexion.';

  @override
  String get petsAddPetFab => 'Ajouter un animal';

  @override
  String get petsAddPetTooltip => 'Ajouter un nouvel animal';

  @override
  String petsRegisteredCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count animaux enregistrés',
      one: '1 animal enregistré',
      zero: '0 animal enregistré',
    );
    return '$_temp0';
  }

  @override
  String get petsHealthNotificationsTooltip =>
      'Gérer les notifications de santé';

  @override
  String get petsListIntro =>
      'Gérez la santé, l\'alimentation et le suivi vétérinaire de vos fidèles compagnons au quotidien.';

  @override
  String get petsSearchHint => 'Rechercher par nom, race...';

  @override
  String get petsSearchClear => 'Effacer la recherche';

  @override
  String petsFilterActive(int count) {
    return 'Actifs ($count)';
  }

  @override
  String petsFilterArchived(int count) {
    return 'Archivés ($count)';
  }

  @override
  String get petsSortRecent => 'Récents';

  @override
  String get petsSortName => 'Nom (A-Z)';

  @override
  String petsNoMatch(String query) {
    return 'Aucun animal ne correspond à « $query ».';
  }

  @override
  String get petsNoArchived => 'Aucun animal archivé.';

  @override
  String get petsNoActive =>
      'Aucun animal actif. Ajoutez un compagnon avec le bouton ci-dessous.';

  @override
  String get petsResetSearch => 'Réinitialiser la recherche';

  @override
  String get petsReminderLabel => 'PROCHAIN RAPPEL';

  @override
  String get petsReminderTitle => 'Rappels de santé';

  @override
  String get petsReminderBody =>
      'Vos vaccins, vermifuges et soins s\'afficheront ici.';

  @override
  String get petsReminderDone => 'Marquer fait';

  @override
  String get petsReminderPostpone => 'Décaler';

  @override
  String get petsWeightLast => 'Dernier poids : ';

  @override
  String petsChipped(String chip) {
    return 'Pucé (ICAD : $chip)';
  }

  @override
  String get petsActionHealth => 'Santé';

  @override
  String get petsActionAppointments => 'Rendez-vous';

  @override
  String get petsActionProfile => 'Profil';

  @override
  String get petsFosterTitle => 'Famille d\'accueil ou bénévole ?';

  @override
  String get petsFosterBody =>
      'Liez les fiches temporaires de votre association';

  @override
  String get petsFosterAction => 'Synchroniser une association';

  @override
  String get petsVisitorText =>
      'Connectez-vous pour créer le profil de vos animaux et suivre leur santé.';

  @override
  String get petsEmptyHeader => 'Mes compagnons';

  @override
  String get petsEmptyHeaderBody =>
      'Gérez la santé et le suivi de vos fidèles amis au quotidien.';

  @override
  String get petsEmptySearchHint => 'Rechercher par nom, race, puce...';

  @override
  String get petsEmptyActive => 'Actifs';

  @override
  String get petsEmptyArchived => 'Archivés';

  @override
  String get petsEmptyBadge => 'Nouveau départ';

  @override
  String get petsEmptyTitle => 'Vous n\'avez pas encore ajouté d\'animal';

  @override
  String get petsEmptyBody =>
      'Créez le profil de votre protégé pour gérer son carnet de santé, planifier ses vaccins et veiller sur son bien-être en toute quiétude.';

  @override
  String get petsEmptyCta => 'Ajouter mon premier compagnon';

  @override
  String get petsEmptyImportQuestion => 'Vous venez d\'adopter sur PetCare ? ';

  @override
  String get petsEmptyImportLink => 'Importer la fiche';

  @override
  String get petsBenefitsTitle => 'Ce qui vous attend avec PetCare';

  @override
  String get petsBenefitsCount => '3 outils clés';

  @override
  String get petsBenefit1Title => 'Carnet de santé numérique';

  @override
  String get petsBenefit1Body =>
      'Poids, antécédents, stérilisation et ordonnances toujours accessibles.';

  @override
  String get petsBenefit2Title => 'Rappels intelligents';

  @override
  String get petsBenefit2Body =>
      'Alertes automatiques pour vermifuges, vaccins et visites médicales.';

  @override
  String get petsBenefit3Title => 'Réseau bienveillant';

  @override
  String get petsBenefit3Body =>
      'Garde entre passionnés vérifiés et conseils certifiés.';

  @override
  String get petsHelpTitle => 'Besoin d\'aide pour démarrer ?';

  @override
  String get petsHelpBody => 'Consultez notre guide de bienvenue';

  @override
  String get petsScreenHealthBook => 'Carnet de santé';

  @override
  String get petsScreenAppointments => 'Rendez-vous';

  @override
  String get petsScreenReminders => 'Rappels de santé';

  @override
  String get petsScreenFoster => 'Famille d\'accueil';

  @override
  String get petsScreenImport => 'Importer une fiche';

  @override
  String get petsScreenGuide => 'Guide de bienvenue';

  @override
  String get petsCancel => 'Annuler';

  @override
  String get petsSave => 'Enregistrer';

  @override
  String get petsAdd => 'Ajouter';

  @override
  String get petsDelete => 'Supprimer';

  @override
  String get petsRemove => 'Retirer';

  @override
  String get petsClose => 'Fermer';

  @override
  String get petsConfirm => 'Confirmer';

  @override
  String get petsFix => 'Corriger';

  @override
  String get petsNo => 'Non';

  @override
  String get petsFormTitleAdd => 'Ajouter Un Animal';

  @override
  String get petsFormTitleEdit => 'Modifier Un Animal';

  @override
  String get petsFormBadge => 'Carnet de santé & profil';

  @override
  String get petsFormHeadingNew => 'Nouveau compagnon';

  @override
  String petsFormHeadingEdit(String name) {
    return 'Modifier $name';
  }

  @override
  String get petsFormIntro =>
      'Renseignez les informations essentielles pour créer son profil et suivre sa santé au quotidien.';

  @override
  String get petsFormPhotosTitle => 'Photos de votre animal';

  @override
  String petsFormPhotosCount(int count, int max) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ajoutées',
      one: 'ajoutée',
      zero: 'ajoutée',
    );
    return '$count / $max $_temp0';
  }

  @override
  String get petsFormPhotoMain => 'Principale';

  @override
  String get petsFormPhotoReplace => 'Remplacer la photo';

  @override
  String get petsFormPhotoRemove => 'Retirer la photo';

  @override
  String get petsFormPhotoMakeMain => 'Définir comme photo principale';

  @override
  String get petsFormPhotoMainSlot => 'Photo principale';

  @override
  String get petsFormPhotoTip =>
      'Une photo nette, de face et lumineuse facilite la reconnaissance visuelle et le suivi en clinique.';

  @override
  String get petsFormIdentity => 'Identité';

  @override
  String get petsFormName => 'Nom de l\'animal';

  @override
  String get petsFormNameHint => 'Ex: Rio, Bella, Pixel...';

  @override
  String get petsFormNameError =>
      '⚠️ Le nom de votre animal est obligatoire (au moins 2 caractères).';

  @override
  String get petsFormNameTooLong =>
      '⚠️ Le nom ne doit pas dépasser 80 caractères.';

  @override
  String get petsFormSpecies => 'Espèce';

  @override
  String get petsFormBreed => 'Race';

  @override
  String get petsFormBreedHint => 'Ex: Golden Retriever, Européen, Bélier...';

  @override
  String get petsFormBreedHelp => 'Laissez vide si croisé ou race inconnue.';

  @override
  String get petsFormSex => 'Sexe';

  @override
  String get petsFormSterilized => 'Animal stérilisé / castré';

  @override
  String get petsFormHealth => 'Santé & Mensurations';

  @override
  String get petsFormBirthDate => 'Date de naissance';

  @override
  String get petsFormDateHint => 'JJ / MM / AAAA';

  @override
  String get petsFormBirthError => '⚠️ La date de naissance est obligatoire.';

  @override
  String get petsFormBirthEstimated =>
      'Date approximative / estimée par un vétérinaire';

  @override
  String get petsFormWeight => 'Poids actuel';

  @override
  String get petsFormWeightHint => 'Ex: 8.5';

  @override
  String get petsFormWeightHelp =>
      'Permet de calculer le dosage des antiparasitaires et vaccins.';

  @override
  String get petsFormWeightError =>
      '⚠️ Indiquez un poids entre 0,01 et 500 kg.';

  @override
  String get petsFormWeightDecimals => '⚠️ Deux décimales au maximum.';

  @override
  String get petsFormIdentification => 'Identification';

  @override
  String get petsFormOptional => 'Optionnel';

  @override
  String get petsFormChipHint =>
      'Numéro de puce ou tatouage (15 chiffres I-CAD)';

  @override
  String get petsFormChipError =>
      '⚠️ Le numéro I-CAD doit contenir exactement 15 chiffres.';

  @override
  String get petsFormNotes => 'Notes du maître';

  @override
  String get petsFormNotesLabel => 'Particularités & tempérament';

  @override
  String get petsFormNotesHint =>
      'Caractère, habitudes, allergies connues, friandises favorites, vétérinaire habituel...';

  @override
  String get petsFormNotesPrivate => 'Visible uniquement sur votre carnet';

  @override
  String get petsFormHeartTitle => 'Un engagement de cœur';

  @override
  String get petsFormHeartBody =>
      'Toutes les données de santé restent privées et protégées.';

  @override
  String get petsFormSave => 'Enregistrer le compagnon';

  @override
  String get petsFormCheckFields => 'Vérifiez les champs signalés en rouge.';

  @override
  String petsFormSaved(String name) {
    return 'La fiche de $name est enregistrée.';
  }

  @override
  String get petsFormSaveError =>
      'L\'enregistrement a échoué. Vérifiez votre connexion et réessayez.';

  @override
  String petsDetailTitle(String name) {
    return 'Profil De $name';
  }

  @override
  String get petsBackTooltip => 'Retour à Mes animaux';

  @override
  String get petsFavoriteAdd => 'Ajouter aux favoris';

  @override
  String get petsFavoriteRemove => 'Retirer des favoris';

  @override
  String get petsMoreOptions => 'Plus d\'options';

  @override
  String get petsMenuEdit => 'Modifier le profil';

  @override
  String get petsMenuArchive => 'Archiver';

  @override
  String get petsMenuRestore => 'Réactiver';

  @override
  String get petsNotFound => 'Fiche introuvable ou inaccessible.';

  @override
  String get petsDeleted => 'Cette fiche n\'existe plus.';

  @override
  String get petsOpError =>
      'L\'opération a échoué. Vérifiez votre connexion et réessayez.';

  @override
  String petsArchivedDone(String name, String female) {
    String _temp0 = intl.Intl.selectLogic(female, {
      'true': 'archivée',
      'other': 'archivé',
    });
    return '$name a été $_temp0.';
  }

  @override
  String petsRestoredDone(String name, String female) {
    String _temp0 = intl.Intl.selectLogic(female, {
      'true': 'active',
      'other': 'actif',
    });
    return '$name est de nouveau $_temp0.';
  }

  @override
  String get petsPhotoDeleted => 'Photo supprimée.';

  @override
  String get petsPhotoDelete => 'Supprimer la photo';

  @override
  String get petsNotesSaved => 'Notes enregistrées.';

  @override
  String get petsContactAdded => 'Contact ajouté.';

  @override
  String get petsContactRemoveTitle => 'Retirer ce contact ?';

  @override
  String petsContactRemoveBody(String name) {
    return '$name ne sera plus affiché sur la fiche.';
  }

  @override
  String get petsCallError => 'Impossible d\'ouvrir l\'application Téléphone.';

  @override
  String get petsShareFooter => 'Fiche partagée depuis PetCare Community';

  @override
  String petsShareCopied(String name) {
    return 'Fiche de $name copiée dans le presse-papier.';
  }

  @override
  String get petsArchivedBadge => 'Archivé';

  @override
  String get petsHealthStatusBadge => 'État de santé : bientôt';

  @override
  String petsIcad(String chip) {
    return 'ICAD : $chip';
  }

  @override
  String get petsFullscreen => 'Agrandir les photos';

  @override
  String get petsSpecSterilization => 'Stérilisation';

  @override
  String petsSpecYes(String label) {
    return 'Oui ($label)';
  }

  @override
  String get petsSpecBirth => 'Naissance';

  @override
  String get petsSpecBirthUnknown => 'Inconnue';

  @override
  String get petsSpecEstimated => '(estimée)';

  @override
  String get petsSpecNotProvided => 'Non renseignée';

  @override
  String get petsNotesTitle => 'NOTES DU MAÎTRE';

  @override
  String get petsNotesEdit => 'Modifier les notes';

  @override
  String get petsNotesEmpty => 'Aucune note pour l\'instant.';

  @override
  String get petsNotesHint => 'Caractère, habitudes, friandises favorites...';

  @override
  String get petsWeightTitle => 'Poids & Croissance';

  @override
  String get petsWeightNone => 'Aucune pesée enregistrée';

  @override
  String petsWeightLastAgo(String when) {
    return 'Dernière pesée $when';
  }

  @override
  String get petsWeightThisMonth => 'ce mois';

  @override
  String petsWeightSince(String month) {
    return 'depuis $month';
  }

  @override
  String petsWeightStable(String period) {
    return 'Stable $period';
  }

  @override
  String get petsWeightAdd => 'Ajouter une pesée';

  @override
  String get petsWeightCurrent => '(Actuel)';

  @override
  String get petsHealthSubtitle => 'Vaccins, traitements et antécédents';

  @override
  String get petsHealthAlertTitle => 'Rappels vaccins';

  @override
  String get petsHealthAlertBody =>
      'Le carnet de santé sera bientôt relié à cette fiche.';

  @override
  String petsCounterSoon(String label) {
    return '$label : bientôt';
  }

  @override
  String get petsCounterVaccines => 'Vaccins';

  @override
  String get petsCounterTreatments => 'Traitements';

  @override
  String get petsAppointmentsSubtitle => 'Prochaine consultation programmée';

  @override
  String get petsAppointmentNext => 'Prochain rendez-vous';

  @override
  String get petsAppointmentBody =>
      'L\'agenda sera bientôt relié à cette fiche.';

  @override
  String get petsAppointmentNew => 'Prendre un nouveau rendez-vous';

  @override
  String get petsContactsTitle => 'Contacts de confiance';

  @override
  String get petsContactAdd => 'Ajouter un contact';

  @override
  String get petsContactsEmpty =>
      'Ajoutez le vétérinaire traitant et un numéro d\'urgence pour les retrouver en un geste.';

  @override
  String petsCall(String name) {
    return 'Appeler $name';
  }

  @override
  String petsEditInfo(String name) {
    return 'Modifier les informations de $name';
  }

  @override
  String get petsShare => 'Partager la fiche';

  @override
  String petsArchiveName(String name) {
    return 'Archiver $name';
  }

  @override
  String petsRestoreName(String name) {
    return 'Réactiver $name';
  }

  @override
  String get petsWeightUnusualTitle => 'Valeur inhabituelle';

  @override
  String petsWeightUnusualBody(String previous, String value) {
    return 'La dernière pesée était de $previous kg. Confirmez-vous $value kg ?';
  }

  @override
  String petsWeightDuplicate(String date) {
    return 'Une pesée existe déjà le $date.';
  }

  @override
  String get petsWeightSaveError => 'L\'enregistrement a échoué. Réessayez.';

  @override
  String get petsWeightLabel => 'Poids';

  @override
  String get petsDate => 'Date';

  @override
  String get petsNoteOptional => 'Note (facultatif)';

  @override
  String get petsWeightDateHelp => 'Date de la pesée';

  @override
  String get petsWeightHistory => 'Historique des pesées';

  @override
  String get petsWeightDeleteTitle => 'Supprimer cette pesée ?';

  @override
  String petsWeightDeleteBody(String weight, String date) {
    return 'La pesée de $weight kg du $date sera supprimée.';
  }

  @override
  String get petsWeightDeleteTooltip => 'Supprimer la pesée';

  @override
  String get petsContactNew => 'Nouveau contact';

  @override
  String get petsContactName => 'Nom';

  @override
  String get petsContactNameHint => 'Dr. Mercier (Vétérinaire traitant)';

  @override
  String get petsContactNameError => 'Indiquez un nom.';

  @override
  String get petsContactPlace => 'Établissement (facultatif)';

  @override
  String get petsContactPlaceHint => 'Clinique des Lilas';

  @override
  String get petsContactPhone => 'Téléphone';

  @override
  String get petsContactPhoneError => 'Numéro invalide (8 à 15 chiffres).';

  @override
  String get petsContactEmergency => 'Numéro d\'urgence';

  @override
  String petsArchiveTitle(String name) {
    return 'Archiver la fiche de $name ?';
  }

  @override
  String petsArchiveBody(String name) {
    return 'L\'historique médical, les pesées et les souvenirs de $name restent précieusement conservés. Il ne sera plus affiché dans votre liste principale d\'animaux actifs mais restera accessible à tout moment dans l\'onglet « Archivés ».';
  }

  @override
  String get petsArchiveCloseTooltip => 'Fermer la boîte de dialogue';

  @override
  String petsArchiveBlockersTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Avant d\'archiver : $count éléments en cours',
      one: 'Avant d\'archiver : 1 élément en cours',
    );
    return '$_temp0';
  }

  @override
  String get petsArchiveBlockersBody =>
      'Pour éviter tout conflit ou oubli, vous devez d\'abord traiter ou annuler ces éléments en cours :';

  @override
  String petsArchiveBlockersFooter(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'L\'archivage sera débloqué dès la résolution de ces $count éléments.',
      one: 'L\'archivage sera débloqué dès la résolution de cet élément.',
    );
    return '$_temp0';
  }

  @override
  String get petsArchiveLockedTooltip =>
      'Complétez les actions en suspens pour pouvoir archiver';

  @override
  String get petsArchiveChecksTitle =>
      'Avant d\'archiver : rendez-vous et annonces';

  @override
  String get petsArchiveChecksBody =>
      'La vérification des rendez-vous à venir et des annonces ouvertes sera bientôt disponible.';
}
