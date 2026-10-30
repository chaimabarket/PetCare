import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @languageTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get languageTooltip;

  /// No description provided for @languageFrench.
  ///
  /// In fr, this message translates to:
  /// **'Français'**
  String get languageFrench;

  /// No description provided for @languageEnglish.
  ///
  /// In fr, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @comingSoon.
  ///
  /// In fr, this message translates to:
  /// **'Bientôt disponible'**
  String get comingSoon;

  /// No description provided for @navHome.
  ///
  /// In fr, this message translates to:
  /// **'Accueil'**
  String get navHome;

  /// No description provided for @navPets.
  ///
  /// In fr, this message translates to:
  /// **'Mes animaux'**
  String get navPets;

  /// No description provided for @navCommunity.
  ///
  /// In fr, this message translates to:
  /// **'Communauté'**
  String get navCommunity;

  /// No description provided for @navServices.
  ///
  /// In fr, this message translates to:
  /// **'Services'**
  String get navServices;

  /// No description provided for @shellSignIn.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter'**
  String get shellSignIn;

  /// No description provided for @shellNotifications.
  ///
  /// In fr, this message translates to:
  /// **'Notifications'**
  String get shellNotifications;

  /// No description provided for @shellNotificationsUnread.
  ///
  /// In fr, this message translates to:
  /// **'Notifications ({count} non lues)'**
  String shellNotificationsUnread(int count);

  /// No description provided for @shellMyProfile.
  ///
  /// In fr, this message translates to:
  /// **'Mon profil'**
  String get shellMyProfile;

  /// No description provided for @speciesDog.
  ///
  /// In fr, this message translates to:
  /// **'Chien'**
  String get speciesDog;

  /// No description provided for @speciesCat.
  ///
  /// In fr, this message translates to:
  /// **'Chat'**
  String get speciesCat;

  /// No description provided for @speciesRabbit.
  ///
  /// In fr, this message translates to:
  /// **'Lapin'**
  String get speciesRabbit;

  /// No description provided for @speciesRodent.
  ///
  /// In fr, this message translates to:
  /// **'Rongeur'**
  String get speciesRodent;

  /// No description provided for @speciesBird.
  ///
  /// In fr, this message translates to:
  /// **'Oiseau'**
  String get speciesBird;

  /// No description provided for @speciesOther.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get speciesOther;

  /// No description provided for @sexMale.
  ///
  /// In fr, this message translates to:
  /// **'Mâle'**
  String get sexMale;

  /// No description provided for @sexFemale.
  ///
  /// In fr, this message translates to:
  /// **'Femelle'**
  String get sexFemale;

  /// No description provided for @petsAgeUnknown.
  ///
  /// In fr, this message translates to:
  /// **'Âge inconnu'**
  String get petsAgeUnknown;

  /// No description provided for @petsAgeNewborn.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau-né'**
  String get petsAgeNewborn;

  /// No description provided for @petsAgeWeeks.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 semaine} other{{count} semaines}}'**
  String petsAgeWeeks(int count);

  /// No description provided for @petsAgeMonths.
  ///
  /// In fr, this message translates to:
  /// **'{count} mois'**
  String petsAgeMonths(int count);

  /// No description provided for @petsAgeYears.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 an} other{{count} ans}}'**
  String petsAgeYears(int count);

  /// No description provided for @petsAgeYearsHalf.
  ///
  /// In fr, this message translates to:
  /// **'{years} et demi'**
  String petsAgeYearsHalf(String years);

  /// No description provided for @petsAgeYearsMonths.
  ///
  /// In fr, this message translates to:
  /// **'{years} et {months} mois'**
  String petsAgeYearsMonths(String years, int months);

  /// No description provided for @petsSinceToday.
  ///
  /// In fr, this message translates to:
  /// **'aujourd\'hui'**
  String get petsSinceToday;

  /// No description provided for @petsSinceYesterday.
  ///
  /// In fr, this message translates to:
  /// **'hier'**
  String get petsSinceYesterday;

  /// No description provided for @petsSinceDays.
  ///
  /// In fr, this message translates to:
  /// **'il y a {count} j'**
  String petsSinceDays(int count);

  /// No description provided for @petsSinceWeeks.
  ///
  /// In fr, this message translates to:
  /// **'il y a {count} sem'**
  String petsSinceWeeks(int count);

  /// No description provided for @petsSinceLastMonth.
  ///
  /// In fr, this message translates to:
  /// **'le mois dernier'**
  String get petsSinceLastMonth;

  /// No description provided for @petsSinceMonths.
  ///
  /// In fr, this message translates to:
  /// **'il y a {count} mois'**
  String petsSinceMonths(int count);

  /// No description provided for @petsSinceOverYear.
  ///
  /// In fr, this message translates to:
  /// **'il y a plus d\'un an'**
  String get petsSinceOverYear;

  /// No description provided for @petsDaysAgo.
  ///
  /// In fr, this message translates to:
  /// **'il y a {count} jours'**
  String petsDaysAgo(int count);

  /// No description provided for @petsSterilizedMale.
  ///
  /// In fr, this message translates to:
  /// **'Stérilisé'**
  String get petsSterilizedMale;

  /// No description provided for @petsSterilizedFemale.
  ///
  /// In fr, this message translates to:
  /// **'Stérilisée'**
  String get petsSterilizedFemale;

  /// No description provided for @petsPhotoFromGallery.
  ///
  /// In fr, this message translates to:
  /// **'Choisir dans la galerie'**
  String get petsPhotoFromGallery;

  /// No description provided for @petsPhotoFromCamera.
  ///
  /// In fr, this message translates to:
  /// **'Prendre une photo'**
  String get petsPhotoFromCamera;

  /// No description provided for @petsPhotoTooLarge.
  ///
  /// In fr, this message translates to:
  /// **'Photo trop lourde. Choisissez une autre image.'**
  String get petsPhotoTooLarge;

  /// No description provided for @petsLoadError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger vos animaux. Vérifiez votre connexion.'**
  String get petsLoadError;

  /// No description provided for @petsAddPetFab.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un animal'**
  String get petsAddPetFab;

  /// No description provided for @petsAddPetTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un nouvel animal'**
  String get petsAddPetTooltip;

  /// No description provided for @petsRegisteredCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{0 animal enregistré} =1{1 animal enregistré} other{{count} animaux enregistrés}}'**
  String petsRegisteredCount(int count);

  /// No description provided for @petsHealthNotificationsTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Gérer les notifications de santé'**
  String get petsHealthNotificationsTooltip;

  /// No description provided for @petsListIntro.
  ///
  /// In fr, this message translates to:
  /// **'Gérez la santé, l\'alimentation et le suivi vétérinaire de vos fidèles compagnons au quotidien.'**
  String get petsListIntro;

  /// No description provided for @petsSearchHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher par nom, race...'**
  String get petsSearchHint;

  /// No description provided for @petsSearchClear.
  ///
  /// In fr, this message translates to:
  /// **'Effacer la recherche'**
  String get petsSearchClear;

  /// No description provided for @petsFilterActive.
  ///
  /// In fr, this message translates to:
  /// **'Actifs ({count})'**
  String petsFilterActive(int count);

  /// No description provided for @petsFilterArchived.
  ///
  /// In fr, this message translates to:
  /// **'Archivés ({count})'**
  String petsFilterArchived(int count);

  /// No description provided for @petsSortRecent.
  ///
  /// In fr, this message translates to:
  /// **'Récents'**
  String get petsSortRecent;

  /// No description provided for @petsSortName.
  ///
  /// In fr, this message translates to:
  /// **'Nom (A-Z)'**
  String get petsSortName;

  /// No description provided for @petsNoMatch.
  ///
  /// In fr, this message translates to:
  /// **'Aucun animal ne correspond à « {query} ».'**
  String petsNoMatch(String query);

  /// No description provided for @petsNoArchived.
  ///
  /// In fr, this message translates to:
  /// **'Aucun animal archivé.'**
  String get petsNoArchived;

  /// No description provided for @petsNoActive.
  ///
  /// In fr, this message translates to:
  /// **'Aucun animal actif. Ajoutez un compagnon avec le bouton ci-dessous.'**
  String get petsNoActive;

  /// No description provided for @petsResetSearch.
  ///
  /// In fr, this message translates to:
  /// **'Réinitialiser la recherche'**
  String get petsResetSearch;

  /// No description provided for @petsReminderLabel.
  ///
  /// In fr, this message translates to:
  /// **'PROCHAIN RAPPEL'**
  String get petsReminderLabel;

  /// No description provided for @petsReminderTitle.
  ///
  /// In fr, this message translates to:
  /// **'Rappels de santé'**
  String get petsReminderTitle;

  /// No description provided for @petsReminderBody.
  ///
  /// In fr, this message translates to:
  /// **'Vos vaccins, vermifuges et soins s\'afficheront ici.'**
  String get petsReminderBody;

  /// No description provided for @petsReminderDone.
  ///
  /// In fr, this message translates to:
  /// **'Marquer fait'**
  String get petsReminderDone;

  /// No description provided for @petsReminderPostpone.
  ///
  /// In fr, this message translates to:
  /// **'Décaler'**
  String get petsReminderPostpone;

  /// No description provided for @petsWeightLast.
  ///
  /// In fr, this message translates to:
  /// **'Dernier poids : '**
  String get petsWeightLast;

  /// No description provided for @petsChipped.
  ///
  /// In fr, this message translates to:
  /// **'Pucé (ICAD : {chip})'**
  String petsChipped(String chip);

  /// No description provided for @petsActionHealth.
  ///
  /// In fr, this message translates to:
  /// **'Santé'**
  String get petsActionHealth;

  /// No description provided for @petsActionAppointments.
  ///
  /// In fr, this message translates to:
  /// **'Rendez-vous'**
  String get petsActionAppointments;

  /// No description provided for @petsActionProfile.
  ///
  /// In fr, this message translates to:
  /// **'Profil'**
  String get petsActionProfile;

  /// No description provided for @petsFosterTitle.
  ///
  /// In fr, this message translates to:
  /// **'Famille d\'accueil ou bénévole ?'**
  String get petsFosterTitle;

  /// No description provided for @petsFosterBody.
  ///
  /// In fr, this message translates to:
  /// **'Liez les fiches temporaires de votre association'**
  String get petsFosterBody;

  /// No description provided for @petsFosterAction.
  ///
  /// In fr, this message translates to:
  /// **'Synchroniser une association'**
  String get petsFosterAction;

  /// No description provided for @petsVisitorText.
  ///
  /// In fr, this message translates to:
  /// **'Connectez-vous pour créer le profil de vos animaux et suivre leur santé.'**
  String get petsVisitorText;

  /// No description provided for @petsEmptyHeader.
  ///
  /// In fr, this message translates to:
  /// **'Mes compagnons'**
  String get petsEmptyHeader;

  /// No description provided for @petsEmptyHeaderBody.
  ///
  /// In fr, this message translates to:
  /// **'Gérez la santé et le suivi de vos fidèles amis au quotidien.'**
  String get petsEmptyHeaderBody;

  /// No description provided for @petsEmptySearchHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher par nom, race, puce...'**
  String get petsEmptySearchHint;

  /// No description provided for @petsEmptyActive.
  ///
  /// In fr, this message translates to:
  /// **'Actifs'**
  String get petsEmptyActive;

  /// No description provided for @petsEmptyArchived.
  ///
  /// In fr, this message translates to:
  /// **'Archivés'**
  String get petsEmptyArchived;

  /// No description provided for @petsEmptyBadge.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau départ'**
  String get petsEmptyBadge;

  /// No description provided for @petsEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'avez pas encore ajouté d\'animal'**
  String get petsEmptyTitle;

  /// No description provided for @petsEmptyBody.
  ///
  /// In fr, this message translates to:
  /// **'Créez le profil de votre protégé pour gérer son carnet de santé, planifier ses vaccins et veiller sur son bien-être en toute quiétude.'**
  String get petsEmptyBody;

  /// No description provided for @petsEmptyCta.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter mon premier compagnon'**
  String get petsEmptyCta;

  /// No description provided for @petsEmptyImportQuestion.
  ///
  /// In fr, this message translates to:
  /// **'Vous venez d\'adopter sur PetCare ? '**
  String get petsEmptyImportQuestion;

  /// No description provided for @petsEmptyImportLink.
  ///
  /// In fr, this message translates to:
  /// **'Importer la fiche'**
  String get petsEmptyImportLink;

  /// No description provided for @petsBenefitsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ce qui vous attend avec PetCare'**
  String get petsBenefitsTitle;

  /// No description provided for @petsBenefitsCount.
  ///
  /// In fr, this message translates to:
  /// **'3 outils clés'**
  String get petsBenefitsCount;

  /// No description provided for @petsBenefit1Title.
  ///
  /// In fr, this message translates to:
  /// **'Carnet de santé numérique'**
  String get petsBenefit1Title;

  /// No description provided for @petsBenefit1Body.
  ///
  /// In fr, this message translates to:
  /// **'Poids, antécédents, stérilisation et ordonnances toujours accessibles.'**
  String get petsBenefit1Body;

  /// No description provided for @petsBenefit2Title.
  ///
  /// In fr, this message translates to:
  /// **'Rappels intelligents'**
  String get petsBenefit2Title;

  /// No description provided for @petsBenefit2Body.
  ///
  /// In fr, this message translates to:
  /// **'Alertes automatiques pour vermifuges, vaccins et visites médicales.'**
  String get petsBenefit2Body;

  /// No description provided for @petsBenefit3Title.
  ///
  /// In fr, this message translates to:
  /// **'Réseau bienveillant'**
  String get petsBenefit3Title;

  /// No description provided for @petsBenefit3Body.
  ///
  /// In fr, this message translates to:
  /// **'Garde entre passionnés vérifiés et conseils certifiés.'**
  String get petsBenefit3Body;

  /// No description provided for @petsHelpTitle.
  ///
  /// In fr, this message translates to:
  /// **'Besoin d\'aide pour démarrer ?'**
  String get petsHelpTitle;

  /// No description provided for @petsHelpBody.
  ///
  /// In fr, this message translates to:
  /// **'Consultez notre guide de bienvenue'**
  String get petsHelpBody;

  /// No description provided for @petsScreenHealthBook.
  ///
  /// In fr, this message translates to:
  /// **'Carnet de santé'**
  String get petsScreenHealthBook;

  /// No description provided for @petsScreenAppointments.
  ///
  /// In fr, this message translates to:
  /// **'Rendez-vous'**
  String get petsScreenAppointments;

  /// No description provided for @petsScreenReminders.
  ///
  /// In fr, this message translates to:
  /// **'Rappels de santé'**
  String get petsScreenReminders;

  /// No description provided for @petsScreenFoster.
  ///
  /// In fr, this message translates to:
  /// **'Famille d\'accueil'**
  String get petsScreenFoster;

  /// No description provided for @petsScreenImport.
  ///
  /// In fr, this message translates to:
  /// **'Importer une fiche'**
  String get petsScreenImport;

  /// No description provided for @petsScreenGuide.
  ///
  /// In fr, this message translates to:
  /// **'Guide de bienvenue'**
  String get petsScreenGuide;

  /// No description provided for @petsCancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get petsCancel;

  /// No description provided for @petsSave.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get petsSave;

  /// No description provided for @petsAdd.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get petsAdd;

  /// No description provided for @petsDelete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get petsDelete;

  /// No description provided for @petsRemove.
  ///
  /// In fr, this message translates to:
  /// **'Retirer'**
  String get petsRemove;

  /// No description provided for @petsClose.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get petsClose;

  /// No description provided for @petsConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer'**
  String get petsConfirm;

  /// No description provided for @petsFix.
  ///
  /// In fr, this message translates to:
  /// **'Corriger'**
  String get petsFix;

  /// No description provided for @petsNo.
  ///
  /// In fr, this message translates to:
  /// **'Non'**
  String get petsNo;

  /// No description provided for @petsFormTitleAdd.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter Un Animal'**
  String get petsFormTitleAdd;

  /// No description provided for @petsFormTitleEdit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier Un Animal'**
  String get petsFormTitleEdit;

  /// No description provided for @petsFormBadge.
  ///
  /// In fr, this message translates to:
  /// **'Carnet de santé & profil'**
  String get petsFormBadge;

  /// No description provided for @petsFormHeadingNew.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau compagnon'**
  String get petsFormHeadingNew;

  /// No description provided for @petsFormHeadingEdit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier {name}'**
  String petsFormHeadingEdit(String name);

  /// No description provided for @petsFormIntro.
  ///
  /// In fr, this message translates to:
  /// **'Renseignez les informations essentielles pour créer son profil et suivre sa santé au quotidien.'**
  String get petsFormIntro;

  /// No description provided for @petsFormPhotosTitle.
  ///
  /// In fr, this message translates to:
  /// **'Photos de votre animal'**
  String get petsFormPhotosTitle;

  /// No description provided for @petsFormPhotosCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} / {max} {count, plural, =0{ajoutée} =1{ajoutée} other{ajoutées}}'**
  String petsFormPhotosCount(int count, int max);

  /// No description provided for @petsFormPhotoMain.
  ///
  /// In fr, this message translates to:
  /// **'Principale'**
  String get petsFormPhotoMain;

  /// No description provided for @petsFormPhotoReplace.
  ///
  /// In fr, this message translates to:
  /// **'Remplacer la photo'**
  String get petsFormPhotoReplace;

  /// No description provided for @petsFormPhotoRemove.
  ///
  /// In fr, this message translates to:
  /// **'Retirer la photo'**
  String get petsFormPhotoRemove;

  /// No description provided for @petsFormPhotoMakeMain.
  ///
  /// In fr, this message translates to:
  /// **'Définir comme photo principale'**
  String get petsFormPhotoMakeMain;

  /// No description provided for @petsFormPhotoMainSlot.
  ///
  /// In fr, this message translates to:
  /// **'Photo principale'**
  String get petsFormPhotoMainSlot;

  /// No description provided for @petsFormPhotoTip.
  ///
  /// In fr, this message translates to:
  /// **'Une photo nette, de face et lumineuse facilite la reconnaissance visuelle et le suivi en clinique.'**
  String get petsFormPhotoTip;

  /// No description provided for @petsFormIdentity.
  ///
  /// In fr, this message translates to:
  /// **'Identité'**
  String get petsFormIdentity;

  /// No description provided for @petsFormName.
  ///
  /// In fr, this message translates to:
  /// **'Nom de l\'animal'**
  String get petsFormName;

  /// No description provided for @petsFormNameHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: Rio, Bella, Pixel...'**
  String get petsFormNameHint;

  /// No description provided for @petsFormNameError.
  ///
  /// In fr, this message translates to:
  /// **'⚠️ Le nom de votre animal est obligatoire (au moins 2 caractères).'**
  String get petsFormNameError;

  /// No description provided for @petsFormNameTooLong.
  ///
  /// In fr, this message translates to:
  /// **'⚠️ Le nom ne doit pas dépasser 80 caractères.'**
  String get petsFormNameTooLong;

  /// No description provided for @petsFormSpecies.
  ///
  /// In fr, this message translates to:
  /// **'Espèce'**
  String get petsFormSpecies;

  /// No description provided for @petsFormBreed.
  ///
  /// In fr, this message translates to:
  /// **'Race'**
  String get petsFormBreed;

  /// No description provided for @petsFormBreedHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: Golden Retriever, Européen, Bélier...'**
  String get petsFormBreedHint;

  /// No description provided for @petsFormBreedHelp.
  ///
  /// In fr, this message translates to:
  /// **'Laissez vide si croisé ou race inconnue.'**
  String get petsFormBreedHelp;

  /// No description provided for @petsFormSex.
  ///
  /// In fr, this message translates to:
  /// **'Sexe'**
  String get petsFormSex;

  /// No description provided for @petsFormSterilized.
  ///
  /// In fr, this message translates to:
  /// **'Animal stérilisé / castré'**
  String get petsFormSterilized;

  /// No description provided for @petsFormHealth.
  ///
  /// In fr, this message translates to:
  /// **'Santé & Mensurations'**
  String get petsFormHealth;

  /// No description provided for @petsFormBirthDate.
  ///
  /// In fr, this message translates to:
  /// **'Date de naissance'**
  String get petsFormBirthDate;

  /// No description provided for @petsFormDateHint.
  ///
  /// In fr, this message translates to:
  /// **'JJ / MM / AAAA'**
  String get petsFormDateHint;

  /// No description provided for @petsFormBirthError.
  ///
  /// In fr, this message translates to:
  /// **'⚠️ La date de naissance est obligatoire.'**
  String get petsFormBirthError;

  /// No description provided for @petsFormBirthEstimated.
  ///
  /// In fr, this message translates to:
  /// **'Date approximative / estimée par un vétérinaire'**
  String get petsFormBirthEstimated;

  /// No description provided for @petsFormWeight.
  ///
  /// In fr, this message translates to:
  /// **'Poids actuel'**
  String get petsFormWeight;

  /// No description provided for @petsFormWeightHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex: 8.5'**
  String get petsFormWeightHint;

  /// No description provided for @petsFormWeightHelp.
  ///
  /// In fr, this message translates to:
  /// **'Permet de calculer le dosage des antiparasitaires et vaccins.'**
  String get petsFormWeightHelp;

  /// No description provided for @petsFormWeightError.
  ///
  /// In fr, this message translates to:
  /// **'⚠️ Indiquez un poids entre 0,01 et 500 kg.'**
  String get petsFormWeightError;

  /// No description provided for @petsFormWeightDecimals.
  ///
  /// In fr, this message translates to:
  /// **'⚠️ Deux décimales au maximum.'**
  String get petsFormWeightDecimals;

  /// No description provided for @petsFormIdentification.
  ///
  /// In fr, this message translates to:
  /// **'Identification'**
  String get petsFormIdentification;

  /// No description provided for @petsFormOptional.
  ///
  /// In fr, this message translates to:
  /// **'Optionnel'**
  String get petsFormOptional;

  /// No description provided for @petsFormChipHint.
  ///
  /// In fr, this message translates to:
  /// **'Numéro de puce ou tatouage (15 chiffres I-CAD)'**
  String get petsFormChipHint;

  /// No description provided for @petsFormChipError.
  ///
  /// In fr, this message translates to:
  /// **'⚠️ Le numéro I-CAD doit contenir exactement 15 chiffres.'**
  String get petsFormChipError;

  /// No description provided for @petsFormNotes.
  ///
  /// In fr, this message translates to:
  /// **'Notes du maître'**
  String get petsFormNotes;

  /// No description provided for @petsFormNotesLabel.
  ///
  /// In fr, this message translates to:
  /// **'Particularités & tempérament'**
  String get petsFormNotesLabel;

  /// No description provided for @petsFormNotesHint.
  ///
  /// In fr, this message translates to:
  /// **'Caractère, habitudes, allergies connues, friandises favorites, vétérinaire habituel...'**
  String get petsFormNotesHint;

  /// No description provided for @petsFormNotesPrivate.
  ///
  /// In fr, this message translates to:
  /// **'Visible uniquement sur votre carnet'**
  String get petsFormNotesPrivate;

  /// No description provided for @petsFormHeartTitle.
  ///
  /// In fr, this message translates to:
  /// **'Un engagement de cœur'**
  String get petsFormHeartTitle;

  /// No description provided for @petsFormHeartBody.
  ///
  /// In fr, this message translates to:
  /// **'Toutes les données de santé restent privées et protégées.'**
  String get petsFormHeartBody;

  /// No description provided for @petsFormSave.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer le compagnon'**
  String get petsFormSave;

  /// No description provided for @petsFormCheckFields.
  ///
  /// In fr, this message translates to:
  /// **'Vérifiez les champs signalés en rouge.'**
  String get petsFormCheckFields;

  /// No description provided for @petsFormSaved.
  ///
  /// In fr, this message translates to:
  /// **'La fiche de {name} est enregistrée.'**
  String petsFormSaved(String name);

  /// No description provided for @petsFormSaveError.
  ///
  /// In fr, this message translates to:
  /// **'L\'enregistrement a échoué. Vérifiez votre connexion et réessayez.'**
  String get petsFormSaveError;

  /// No description provided for @petsDetailTitle.
  ///
  /// In fr, this message translates to:
  /// **'Profil De {name}'**
  String petsDetailTitle(String name);

  /// No description provided for @petsBackTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Retour à Mes animaux'**
  String get petsBackTooltip;

  /// No description provided for @petsFavoriteAdd.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter aux favoris'**
  String get petsFavoriteAdd;

  /// No description provided for @petsFavoriteRemove.
  ///
  /// In fr, this message translates to:
  /// **'Retirer des favoris'**
  String get petsFavoriteRemove;

  /// No description provided for @petsMoreOptions.
  ///
  /// In fr, this message translates to:
  /// **'Plus d\'options'**
  String get petsMoreOptions;

  /// No description provided for @petsMenuEdit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le profil'**
  String get petsMenuEdit;

  /// No description provided for @petsMenuArchive.
  ///
  /// In fr, this message translates to:
  /// **'Archiver'**
  String get petsMenuArchive;

  /// No description provided for @petsMenuRestore.
  ///
  /// In fr, this message translates to:
  /// **'Réactiver'**
  String get petsMenuRestore;

  /// No description provided for @petsNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Fiche introuvable ou inaccessible.'**
  String get petsNotFound;

  /// No description provided for @petsDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Cette fiche n\'existe plus.'**
  String get petsDeleted;

  /// No description provided for @petsOpError.
  ///
  /// In fr, this message translates to:
  /// **'L\'opération a échoué. Vérifiez votre connexion et réessayez.'**
  String get petsOpError;

  /// No description provided for @petsArchivedDone.
  ///
  /// In fr, this message translates to:
  /// **'{name} a été {female, select, true{archivée} other{archivé}}.'**
  String petsArchivedDone(String name, String female);

  /// No description provided for @petsRestoredDone.
  ///
  /// In fr, this message translates to:
  /// **'{name} est de nouveau {female, select, true{active} other{actif}}.'**
  String petsRestoredDone(String name, String female);

  /// No description provided for @petsPhotoDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Photo supprimée.'**
  String get petsPhotoDeleted;

  /// No description provided for @petsPhotoDelete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la photo'**
  String get petsPhotoDelete;

  /// No description provided for @petsNotesSaved.
  ///
  /// In fr, this message translates to:
  /// **'Notes enregistrées.'**
  String get petsNotesSaved;

  /// No description provided for @petsContactAdded.
  ///
  /// In fr, this message translates to:
  /// **'Contact ajouté.'**
  String get petsContactAdded;

  /// No description provided for @petsContactRemoveTitle.
  ///
  /// In fr, this message translates to:
  /// **'Retirer ce contact ?'**
  String get petsContactRemoveTitle;

  /// No description provided for @petsContactRemoveBody.
  ///
  /// In fr, this message translates to:
  /// **'{name} ne sera plus affiché sur la fiche.'**
  String petsContactRemoveBody(String name);

  /// No description provided for @petsCallError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'ouvrir l\'application Téléphone.'**
  String get petsCallError;

  /// No description provided for @petsShareFooter.
  ///
  /// In fr, this message translates to:
  /// **'Fiche partagée depuis PetCare Community'**
  String get petsShareFooter;

  /// No description provided for @petsShareCopied.
  ///
  /// In fr, this message translates to:
  /// **'Fiche de {name} copiée dans le presse-papier.'**
  String petsShareCopied(String name);

  /// No description provided for @petsArchivedBadge.
  ///
  /// In fr, this message translates to:
  /// **'Archivé'**
  String get petsArchivedBadge;

  /// No description provided for @petsHealthStatusBadge.
  ///
  /// In fr, this message translates to:
  /// **'État de santé : bientôt'**
  String get petsHealthStatusBadge;

  /// No description provided for @petsIcad.
  ///
  /// In fr, this message translates to:
  /// **'ICAD : {chip}'**
  String petsIcad(String chip);

  /// No description provided for @petsFullscreen.
  ///
  /// In fr, this message translates to:
  /// **'Agrandir les photos'**
  String get petsFullscreen;

  /// No description provided for @petsSpecSterilization.
  ///
  /// In fr, this message translates to:
  /// **'Stérilisation'**
  String get petsSpecSterilization;

  /// No description provided for @petsSpecYes.
  ///
  /// In fr, this message translates to:
  /// **'Oui ({label})'**
  String petsSpecYes(String label);

  /// No description provided for @petsSpecBirth.
  ///
  /// In fr, this message translates to:
  /// **'Naissance'**
  String get petsSpecBirth;

  /// No description provided for @petsSpecBirthUnknown.
  ///
  /// In fr, this message translates to:
  /// **'Inconnue'**
  String get petsSpecBirthUnknown;

  /// No description provided for @petsSpecEstimated.
  ///
  /// In fr, this message translates to:
  /// **'(estimée)'**
  String get petsSpecEstimated;

  /// No description provided for @petsSpecNotProvided.
  ///
  /// In fr, this message translates to:
  /// **'Non renseignée'**
  String get petsSpecNotProvided;

  /// No description provided for @petsNotesTitle.
  ///
  /// In fr, this message translates to:
  /// **'NOTES DU MAÎTRE'**
  String get petsNotesTitle;

  /// No description provided for @petsNotesEdit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier les notes'**
  String get petsNotesEdit;

  /// No description provided for @petsNotesEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune note pour l\'instant.'**
  String get petsNotesEmpty;

  /// No description provided for @petsNotesHint.
  ///
  /// In fr, this message translates to:
  /// **'Caractère, habitudes, friandises favorites...'**
  String get petsNotesHint;

  /// No description provided for @petsWeightTitle.
  ///
  /// In fr, this message translates to:
  /// **'Poids & Croissance'**
  String get petsWeightTitle;

  /// No description provided for @petsWeightNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucune pesée enregistrée'**
  String get petsWeightNone;

  /// No description provided for @petsWeightLastAgo.
  ///
  /// In fr, this message translates to:
  /// **'Dernière pesée {when}'**
  String petsWeightLastAgo(String when);

  /// No description provided for @petsWeightThisMonth.
  ///
  /// In fr, this message translates to:
  /// **'ce mois'**
  String get petsWeightThisMonth;

  /// No description provided for @petsWeightSince.
  ///
  /// In fr, this message translates to:
  /// **'depuis {month}'**
  String petsWeightSince(String month);

  /// No description provided for @petsWeightStable.
  ///
  /// In fr, this message translates to:
  /// **'Stable {period}'**
  String petsWeightStable(String period);

  /// No description provided for @petsWeightAdd.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une pesée'**
  String get petsWeightAdd;

  /// No description provided for @petsWeightEdit.
  ///
  /// In fr, this message translates to:
  /// **'Corriger la pesée'**
  String get petsWeightEdit;

  /// No description provided for @petsWeightCurrent.
  ///
  /// In fr, this message translates to:
  /// **'(Actuel)'**
  String get petsWeightCurrent;

  /// No description provided for @petsHealthSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Vaccins, traitements et antécédents'**
  String get petsHealthSubtitle;

  /// No description provided for @petsHealthAlertTitle.
  ///
  /// In fr, this message translates to:
  /// **'Rappels vaccins'**
  String get petsHealthAlertTitle;

  /// No description provided for @petsHealthAlertBody.
  ///
  /// In fr, this message translates to:
  /// **'Le carnet de santé sera bientôt relié à cette fiche.'**
  String get petsHealthAlertBody;

  /// No description provided for @petsCounterSoon.
  ///
  /// In fr, this message translates to:
  /// **'{label} : bientôt'**
  String petsCounterSoon(String label);

  /// No description provided for @petsCounterVaccines.
  ///
  /// In fr, this message translates to:
  /// **'Vaccins'**
  String get petsCounterVaccines;

  /// No description provided for @petsCounterTreatments.
  ///
  /// In fr, this message translates to:
  /// **'Traitements'**
  String get petsCounterTreatments;

  /// No description provided for @petsAppointmentsSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Prochaine consultation programmée'**
  String get petsAppointmentsSubtitle;

  /// No description provided for @petsAppointmentNext.
  ///
  /// In fr, this message translates to:
  /// **'Prochain rendez-vous'**
  String get petsAppointmentNext;

  /// No description provided for @petsAppointmentBody.
  ///
  /// In fr, this message translates to:
  /// **'L\'agenda sera bientôt relié à cette fiche.'**
  String get petsAppointmentBody;

  /// No description provided for @petsAppointmentNew.
  ///
  /// In fr, this message translates to:
  /// **'Prendre un nouveau rendez-vous'**
  String get petsAppointmentNew;

  /// No description provided for @petsContactsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Contacts de confiance'**
  String get petsContactsTitle;

  /// No description provided for @petsContactAdd.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un contact'**
  String get petsContactAdd;

  /// No description provided for @petsContactsEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez le vétérinaire traitant et un numéro d\'urgence pour les retrouver en un geste.'**
  String get petsContactsEmpty;

  /// No description provided for @petsCall.
  ///
  /// In fr, this message translates to:
  /// **'Appeler {name}'**
  String petsCall(String name);

  /// No description provided for @petsEditInfo.
  ///
  /// In fr, this message translates to:
  /// **'Modifier les informations de {name}'**
  String petsEditInfo(String name);

  /// No description provided for @petsShare.
  ///
  /// In fr, this message translates to:
  /// **'Partager la fiche'**
  String get petsShare;

  /// No description provided for @petsArchiveName.
  ///
  /// In fr, this message translates to:
  /// **'Archiver {name}'**
  String petsArchiveName(String name);

  /// No description provided for @petsRestoreName.
  ///
  /// In fr, this message translates to:
  /// **'Réactiver {name}'**
  String petsRestoreName(String name);

  /// No description provided for @petsWeightUnusualTitle.
  ///
  /// In fr, this message translates to:
  /// **'Valeur inhabituelle'**
  String get petsWeightUnusualTitle;

  /// No description provided for @petsWeightUnusualBody.
  ///
  /// In fr, this message translates to:
  /// **'La dernière pesée était de {previous} kg. Confirmez-vous {value} kg ?'**
  String petsWeightUnusualBody(String previous, String value);

  /// No description provided for @petsWeightDuplicate.
  ///
  /// In fr, this message translates to:
  /// **'Une pesée existe déjà le {date}.'**
  String petsWeightDuplicate(String date);

  /// No description provided for @petsWeightSaveError.
  ///
  /// In fr, this message translates to:
  /// **'L\'enregistrement a échoué. Réessayez.'**
  String get petsWeightSaveError;

  /// No description provided for @petsWeightLabel.
  ///
  /// In fr, this message translates to:
  /// **'Poids'**
  String get petsWeightLabel;

  /// No description provided for @petsDate.
  ///
  /// In fr, this message translates to:
  /// **'Date'**
  String get petsDate;

  /// No description provided for @petsNoteOptional.
  ///
  /// In fr, this message translates to:
  /// **'Note (facultatif)'**
  String get petsNoteOptional;

  /// No description provided for @petsWeightDateHelp.
  ///
  /// In fr, this message translates to:
  /// **'Date de la pesée'**
  String get petsWeightDateHelp;

  /// No description provided for @petsWeightHistory.
  ///
  /// In fr, this message translates to:
  /// **'Historique des pesées'**
  String get petsWeightHistory;

  /// No description provided for @petsWeightDeleteTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer cette pesée ?'**
  String get petsWeightDeleteTitle;

  /// No description provided for @petsWeightDeleteBody.
  ///
  /// In fr, this message translates to:
  /// **'La pesée de {weight} kg du {date} sera supprimée.'**
  String petsWeightDeleteBody(String weight, String date);

  /// No description provided for @petsWeightDeleteTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la pesée'**
  String get petsWeightDeleteTooltip;

  /// No description provided for @petsContactNew.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau contact'**
  String get petsContactNew;

  /// No description provided for @petsContactName.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get petsContactName;

  /// No description provided for @petsContactNameHint.
  ///
  /// In fr, this message translates to:
  /// **'Dr. Mercier (Vétérinaire traitant)'**
  String get petsContactNameHint;

  /// No description provided for @petsContactNameError.
  ///
  /// In fr, this message translates to:
  /// **'Indiquez un nom.'**
  String get petsContactNameError;

  /// No description provided for @petsContactPlace.
  ///
  /// In fr, this message translates to:
  /// **'Établissement (facultatif)'**
  String get petsContactPlace;

  /// No description provided for @petsContactPlaceHint.
  ///
  /// In fr, this message translates to:
  /// **'Clinique des Lilas'**
  String get petsContactPlaceHint;

  /// No description provided for @petsContactPhone.
  ///
  /// In fr, this message translates to:
  /// **'Téléphone'**
  String get petsContactPhone;

  /// No description provided for @petsContactPhoneError.
  ///
  /// In fr, this message translates to:
  /// **'Numéro invalide (8 à 15 chiffres).'**
  String get petsContactPhoneError;

  /// No description provided for @petsContactEmergency.
  ///
  /// In fr, this message translates to:
  /// **'Numéro d\'urgence'**
  String get petsContactEmergency;

  /// No description provided for @petsArchiveTitle.
  ///
  /// In fr, this message translates to:
  /// **'Archiver la fiche de {name} ?'**
  String petsArchiveTitle(String name);

  /// No description provided for @petsArchiveBody.
  ///
  /// In fr, this message translates to:
  /// **'L\'historique médical, les pesées et les souvenirs de {name} restent précieusement conservés. Il ne sera plus affiché dans votre liste principale d\'animaux actifs mais restera accessible à tout moment dans l\'onglet « Archivés ».'**
  String petsArchiveBody(String name);

  /// No description provided for @petsArchiveCloseTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Fermer la boîte de dialogue'**
  String get petsArchiveCloseTooltip;

  /// No description provided for @petsArchiveBlockersTitle.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Avant d\'archiver : 1 élément en cours} other{Avant d\'archiver : {count} éléments en cours}}'**
  String petsArchiveBlockersTitle(int count);

  /// No description provided for @petsArchiveBlockersBody.
  ///
  /// In fr, this message translates to:
  /// **'Pour éviter tout conflit ou oubli, vous devez d\'abord traiter ou annuler ces éléments en cours :'**
  String get petsArchiveBlockersBody;

  /// No description provided for @petsArchiveBlockersFooter.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{L\'archivage sera débloqué dès la résolution de cet élément.} other{L\'archivage sera débloqué dès la résolution de ces {count} éléments.}}'**
  String petsArchiveBlockersFooter(int count);

  /// No description provided for @petsArchiveLockedTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Complétez les actions en suspens pour pouvoir archiver'**
  String get petsArchiveLockedTooltip;

  /// No description provided for @petsArchiveChecksTitle.
  ///
  /// In fr, this message translates to:
  /// **'Avant d\'archiver : rendez-vous et annonces'**
  String get petsArchiveChecksTitle;

  /// No description provided for @petsArchiveChecksBody.
  ///
  /// In fr, this message translates to:
  /// **'La vérification des rendez-vous à venir et des annonces ouvertes sera bientôt disponible.'**
  String get petsArchiveChecksBody;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
