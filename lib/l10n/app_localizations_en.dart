// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get languageTooltip => 'Language';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageEnglish => 'English';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get navHome => 'Home';

  @override
  String get navPets => 'My pets';

  @override
  String get navCommunity => 'Community';

  @override
  String get navServices => 'Services';

  @override
  String get shellSignIn => 'Sign in';

  @override
  String get shellNotifications => 'Notifications';

  @override
  String shellNotificationsUnread(int count) {
    return 'Notifications ($count unread)';
  }

  @override
  String get shellMyProfile => 'My profile';

  @override
  String get speciesDog => 'Dog';

  @override
  String get speciesCat => 'Cat';

  @override
  String get speciesRabbit => 'Rabbit';

  @override
  String get speciesRodent => 'Rodent';

  @override
  String get speciesBird => 'Bird';

  @override
  String get speciesOther => 'Other';

  @override
  String get sexMale => 'Male';

  @override
  String get sexFemale => 'Female';

  @override
  String get petsAgeUnknown => 'Age unknown';

  @override
  String get petsAgeNewborn => 'Newborn';

  @override
  String petsAgeWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weeks',
      one: '1 week',
    );
    return '$_temp0';
  }

  @override
  String petsAgeMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months',
      one: '1 month',
    );
    return '$_temp0';
  }

  @override
  String petsAgeYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count years',
      one: '1 year',
    );
    return '$_temp0';
  }

  @override
  String petsAgeYearsHalf(String years) {
    return '$years and a half';
  }

  @override
  String petsAgeYearsMonths(String years, int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '$months months',
      one: '1 month',
    );
    return '$years and $_temp0';
  }

  @override
  String get petsSinceToday => 'today';

  @override
  String get petsSinceYesterday => 'yesterday';

  @override
  String petsSinceDays(int count) {
    return '$count d ago';
  }

  @override
  String petsSinceWeeks(int count) {
    return '$count wk ago';
  }

  @override
  String get petsSinceLastMonth => 'last month';

  @override
  String petsSinceMonths(int count) {
    return '$count mo ago';
  }

  @override
  String get petsSinceOverYear => 'over a year ago';

  @override
  String petsDaysAgo(int count) {
    return '$count days ago';
  }

  @override
  String get petsSterilizedMale => 'Neutered';

  @override
  String get petsSterilizedFemale => 'Spayed';

  @override
  String get petsPhotoFromGallery => 'Choose from gallery';

  @override
  String get petsPhotoFromCamera => 'Take a photo';

  @override
  String get petsPhotoTooLarge =>
      'Photo too large. Please choose another image.';

  @override
  String get petsLoadError =>
      'Unable to load your pets. Check your connection.';

  @override
  String get petsAddPetFab => 'Add a pet';

  @override
  String get petsAddPetTooltip => 'Add a new pet';

  @override
  String petsRegisteredCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pets registered',
      one: '1 pet registered',
    );
    return '$_temp0';
  }

  @override
  String get petsHealthNotificationsTooltip => 'Manage health notifications';

  @override
  String get petsListIntro =>
      'Manage your loyal companions\' health, food and veterinary follow-up every day.';

  @override
  String get petsSearchHint => 'Search by name, breed...';

  @override
  String get petsSearchClear => 'Clear search';

  @override
  String petsFilterActive(int count) {
    return 'Active ($count)';
  }

  @override
  String petsFilterArchived(int count) {
    return 'Archived ($count)';
  }

  @override
  String get petsSortRecent => 'Recent';

  @override
  String get petsSortName => 'Name (A-Z)';

  @override
  String petsNoMatch(String query) {
    return 'No pet matches \"$query\".';
  }

  @override
  String get petsNoArchived => 'No archived pets.';

  @override
  String get petsNoActive =>
      'No active pets. Add a companion with the button below.';

  @override
  String get petsResetSearch => 'Reset search';

  @override
  String get petsReminderLabel => 'NEXT REMINDER';

  @override
  String get petsReminderTitle => 'Health reminders';

  @override
  String get petsReminderBody =>
      'Your vaccines, dewormers and care will appear here.';

  @override
  String get petsReminderDone => 'Mark as done';

  @override
  String get petsReminderPostpone => 'Postpone';

  @override
  String get petsWeightLast => 'Last weight: ';

  @override
  String petsChipped(String chip) {
    return 'Microchipped (ICAD: $chip)';
  }

  @override
  String get petsActionHealth => 'Health';

  @override
  String get petsActionAppointments => 'Appointments';

  @override
  String get petsActionProfile => 'Profile';

  @override
  String get petsFosterTitle => 'Foster family or volunteer?';

  @override
  String get petsFosterBody => 'Link your association\'s temporary profiles';

  @override
  String get petsFosterAction => 'Link an association';

  @override
  String get petsVisitorText =>
      'Sign in to create your pets\' profiles and track their health.';

  @override
  String get petsEmptyHeader => 'My companions';

  @override
  String get petsEmptyHeaderBody =>
      'Manage the health and care of your loyal friends every day.';

  @override
  String get petsEmptySearchHint => 'Search by name, breed, chip...';

  @override
  String get petsEmptyActive => 'Active';

  @override
  String get petsEmptyArchived => 'Archived';

  @override
  String get petsEmptyBadge => 'Fresh start';

  @override
  String get petsEmptyTitle => 'You haven\'t added a pet yet';

  @override
  String get petsEmptyBody =>
      'Create your companion\'s profile to manage their health record, plan their vaccines and look after their well-being with peace of mind.';

  @override
  String get petsEmptyCta => 'Add my first companion';

  @override
  String get petsEmptyImportQuestion => 'Just adopted on PetCare? ';

  @override
  String get petsEmptyImportLink => 'Import the profile';

  @override
  String get petsBenefitsTitle => 'What awaits you with PetCare';

  @override
  String get petsBenefitsCount => '3 key tools';

  @override
  String get petsBenefit1Title => 'Digital health record';

  @override
  String get petsBenefit1Body =>
      'Weight, history, sterilization and prescriptions always at hand.';

  @override
  String get petsBenefit2Title => 'Smart reminders';

  @override
  String get petsBenefit2Body =>
      'Automatic alerts for dewormers, vaccines and vet visits.';

  @override
  String get petsBenefit3Title => 'Caring network';

  @override
  String get petsBenefit3Body =>
      'Pet sitting between verified enthusiasts and certified advice.';

  @override
  String get petsHelpTitle => 'Need help getting started?';

  @override
  String get petsHelpBody => 'Read our welcome guide';

  @override
  String get petsScreenHealthBook => 'Health record';

  @override
  String get petsScreenAppointments => 'Appointments';

  @override
  String get petsScreenReminders => 'Health reminders';

  @override
  String get petsScreenFoster => 'Foster family';

  @override
  String get petsScreenImport => 'Import a profile';

  @override
  String get petsScreenGuide => 'Welcome guide';

  @override
  String get petsCancel => 'Cancel';

  @override
  String get petsSave => 'Save';

  @override
  String get petsAdd => 'Add';

  @override
  String get petsDelete => 'Delete';

  @override
  String get petsRemove => 'Remove';

  @override
  String get petsClose => 'Close';

  @override
  String get petsConfirm => 'Confirm';

  @override
  String get petsFix => 'Correct';

  @override
  String get petsNo => 'No';

  @override
  String get petsFormTitleAdd => 'Add A Pet';

  @override
  String get petsFormTitleEdit => 'Edit A Pet';

  @override
  String get petsFormBadge => 'Health record & profile';

  @override
  String get petsFormHeadingNew => 'New companion';

  @override
  String petsFormHeadingEdit(String name) {
    return 'Edit $name';
  }

  @override
  String get petsFormIntro =>
      'Fill in the essentials to create their profile and follow their health every day.';

  @override
  String get petsFormPhotosTitle => 'Your pet\'s photos';

  @override
  String petsFormPhotosCount(int count, int max) {
    return '$count / $max added';
  }

  @override
  String get petsFormPhotoMain => 'Main';

  @override
  String get petsFormPhotoReplace => 'Replace photo';

  @override
  String get petsFormPhotoRemove => 'Remove photo';

  @override
  String get petsFormPhotoMakeMain => 'Set as main photo';

  @override
  String get petsFormPhotoMainSlot => 'Main photo';

  @override
  String get petsFormPhotoTip =>
      'A sharp, front-facing and well-lit photo makes visual recognition and clinic follow-up easier.';

  @override
  String get petsFormIdentity => 'Identity';

  @override
  String get petsFormName => 'Pet\'s name';

  @override
  String get petsFormNameHint => 'E.g. Rio, Bella, Pixel...';

  @override
  String get petsFormNameError =>
      '⚠️ Your pet\'s name is required (at least 2 characters).';

  @override
  String get petsFormNameTooLong =>
      '⚠️ The name must not exceed 80 characters.';

  @override
  String get petsFormSpecies => 'Species';

  @override
  String get petsAdvice => 'Advice';

  @override
  String get petsFormKind => 'Which animal?';

  @override
  String get petsFormKindHint => 'E.g. Tortoise, Ferret, Bear, Tiger...';

  @override
  String get petsFormKindError => 'Tell us which animal this is.';

  @override
  String get petsFormBreed => 'Breed';

  @override
  String get petsFormBreedHint => 'E.g. Golden Retriever, European, Lop...';

  @override
  String get petsFormBreedHelp => 'Leave empty if mixed or unknown breed.';

  @override
  String get petsFormSex => 'Sex';

  @override
  String get petsFormSterilized => 'Spayed / neutered';

  @override
  String get petsFormHealth => 'Health & Measurements';

  @override
  String get petsFormBirthDate => 'Date of birth';

  @override
  String get petsFormDateHint => 'DD / MM / YYYY';

  @override
  String get petsFormBirthError => '⚠️ Date of birth is required.';

  @override
  String get petsFormBirthEstimated => 'Approximate date / estimated by a vet';

  @override
  String get petsFormWeight => 'Current weight';

  @override
  String get petsFormWeightHint => 'E.g. 8.5';

  @override
  String get petsFormWeightHelp =>
      'Used to calculate parasite treatment and vaccine dosage.';

  @override
  String get petsFormWeightError =>
      '⚠️ Enter a weight between 0.01 and 500 kg.';

  @override
  String get petsFormWeightDecimals => '⚠️ Two decimals maximum.';

  @override
  String get petsFormIdentification => 'Identification';

  @override
  String get petsFormOptional => 'Optional';

  @override
  String get petsFormChipHint => 'Microchip or tattoo number (15 I-CAD digits)';

  @override
  String get petsFormChipError =>
      '⚠️ The I-CAD number must contain exactly 15 digits.';

  @override
  String get petsFormNotes => 'Owner\'s notes';

  @override
  String get petsFormNotesLabel => 'Traits & temperament';

  @override
  String get petsFormNotesHint =>
      'Personality, habits, known allergies, favourite treats, usual vet...';

  @override
  String get petsFormNotesPrivate => 'Only visible in your record';

  @override
  String get petsFormHeartTitle => 'A heartfelt commitment';

  @override
  String get petsFormHeartBody =>
      'All health data stays private and protected.';

  @override
  String get petsFormSave => 'Save companion';

  @override
  String get petsFormCheckFields => 'Please check the fields marked in red.';

  @override
  String petsFormSaved(String name) {
    return '$name\'s profile has been saved.';
  }

  @override
  String get petsFormSaveError =>
      'Saving failed. Check your connection and try again.';

  @override
  String petsDetailTitle(String name) {
    return '$name\'s Profile';
  }

  @override
  String get petsBackTooltip => 'Back to My pets';

  @override
  String get petsFavoriteAdd => 'Add to favourites';

  @override
  String get petsFavoriteRemove => 'Remove from favourites';

  @override
  String get petsMoreOptions => 'More options';

  @override
  String get petsMenuEdit => 'Edit profile';

  @override
  String get petsMenuArchive => 'Archive';

  @override
  String get petsMenuRestore => 'Reactivate';

  @override
  String get petsNotFound => 'Profile not found or not accessible.';

  @override
  String get petsDeleted => 'This profile no longer exists.';

  @override
  String get petsOpError =>
      'The operation failed. Check your connection and try again.';

  @override
  String petsArchivedDone(String name, String female) {
    return '$name has been archived.';
  }

  @override
  String petsRestoredDone(String name, String female) {
    return '$name is active again.';
  }

  @override
  String get petsPhotoDeleted => 'Photo deleted.';

  @override
  String get petsPhotoDelete => 'Delete photo';

  @override
  String get petsNotesSaved => 'Notes saved.';

  @override
  String get petsContactAdded => 'Contact added.';

  @override
  String get petsContactRemoveTitle => 'Remove this contact?';

  @override
  String petsContactRemoveBody(String name) {
    return '$name will no longer be shown on the profile.';
  }

  @override
  String get petsCallError => 'Unable to open the Phone app.';

  @override
  String get petsShareFooter => 'Profile shared from PetCare Community';

  @override
  String petsShareCopied(String name) {
    return '$name\'s profile copied to the clipboard.';
  }

  @override
  String get petsArchivedBadge => 'Archived';

  @override
  String get petsHealthStatusBadge => 'Health status: coming soon';

  @override
  String petsIcad(String chip) {
    return 'ICAD: $chip';
  }

  @override
  String get petsFullscreen => 'Enlarge photos';

  @override
  String get petsSpecSterilization => 'Sterilization';

  @override
  String petsSpecYes(String label) {
    return 'Yes ($label)';
  }

  @override
  String get petsSpecBirth => 'Birth';

  @override
  String get petsSpecBirthUnknown => 'Unknown';

  @override
  String get petsSpecEstimated => '(estimated)';

  @override
  String get petsSpecNotProvided => 'Not provided';

  @override
  String get petsNotesTitle => 'OWNER\'S NOTES';

  @override
  String get petsNotesEdit => 'Edit notes';

  @override
  String get petsNotesEmpty => 'No notes yet.';

  @override
  String get petsNotesHint => 'Personality, habits, favourite treats...';

  @override
  String get petsWeightTitle => 'Weight & Growth';

  @override
  String get petsWeightNone => 'No weigh-in recorded';

  @override
  String petsWeightLastAgo(String when) {
    return 'Last weigh-in $when';
  }

  @override
  String get petsWeightThisMonth => 'this month';

  @override
  String petsWeightSince(String month) {
    return 'since $month';
  }

  @override
  String petsWeightStable(String period) {
    return 'Stable $period';
  }

  @override
  String get petsWeightAdd => 'Add a weigh-in';

  @override
  String get petsWeightEdit => 'Correct weigh-in';

  @override
  String get petsWeightCurrent => '(Current)';

  @override
  String get petsHealthSubtitle => 'Vaccines, treatments and history';

  @override
  String get petsHealthAlertTitle => 'Vaccine reminders';

  @override
  String get petsHealthAlertBody =>
      'The health record will soon be linked to this profile.';

  @override
  String petsCounterSoon(String label) {
    return '$label: coming soon';
  }

  @override
  String get petsCounterVaccines => 'Vaccines';

  @override
  String get petsCounterTreatments => 'Treatments';

  @override
  String get petsAppointmentsSubtitle => 'Next scheduled visit';

  @override
  String get petsAppointmentNext => 'Next appointment';

  @override
  String get petsAppointmentBody =>
      'The calendar will soon be linked to this profile.';

  @override
  String get petsAppointmentNew => 'Book a new appointment';

  @override
  String get petsContactsTitle => 'Trusted contacts';

  @override
  String get petsContactAdd => 'Add a contact';

  @override
  String get petsContactsEmpty =>
      'Add your regular vet and an emergency number to reach them in one tap.';

  @override
  String petsCall(String name) {
    return 'Call $name';
  }

  @override
  String petsEditInfo(String name) {
    return 'Edit $name\'s information';
  }

  @override
  String get petsShare => 'Share profile';

  @override
  String petsArchiveName(String name) {
    return 'Archive $name';
  }

  @override
  String petsRestoreName(String name) {
    return 'Reactivate $name';
  }

  @override
  String get petsWeightUnusualTitle => 'Unusual value';

  @override
  String petsWeightUnusualBody(String previous, String value) {
    return 'The last weigh-in was $previous kg. Do you confirm $value kg?';
  }

  @override
  String petsWeightDuplicate(String date) {
    return 'A weigh-in already exists on $date.';
  }

  @override
  String get petsWeightSaveError => 'Saving failed. Try again.';

  @override
  String get petsWeightLabel => 'Weight';

  @override
  String get petsDate => 'Date';

  @override
  String get petsNoteOptional => 'Note (optional)';

  @override
  String get petsWeightDateHelp => 'Weigh-in date';

  @override
  String get petsWeightHistory => 'Weigh-in history';

  @override
  String get petsWeightDeleteTitle => 'Delete this weigh-in?';

  @override
  String petsWeightDeleteBody(String weight, String date) {
    return 'The $weight kg weigh-in of $date will be deleted.';
  }

  @override
  String get petsWeightDeleteTooltip => 'Delete weigh-in';

  @override
  String get petsContactNew => 'New contact';

  @override
  String get petsContactName => 'Name';

  @override
  String get petsContactNameHint => 'Dr. Mercier (Regular vet)';

  @override
  String get petsContactNameError => 'Enter a name.';

  @override
  String get petsContactPlace => 'Clinic (optional)';

  @override
  String get petsContactPlaceHint => 'Lilac Clinic';

  @override
  String get petsContactPhone => 'Phone';

  @override
  String get petsContactPhoneError => 'Invalid number (8 to 15 digits).';

  @override
  String get petsContactEmergency => 'Emergency number';

  @override
  String petsArchiveTitle(String name) {
    return 'Archive $name\'s profile?';
  }

  @override
  String petsArchiveBody(String name) {
    return '$name\'s medical history, weigh-ins and memories are carefully kept. They will no longer appear in your main list of active pets but remain available at any time in the \"Archived\" tab.';
  }

  @override
  String get petsArchiveCloseTooltip => 'Close dialog';

  @override
  String petsArchiveBlockersTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Before archiving: $count pending items',
      one: 'Before archiving: 1 pending item',
    );
    return '$_temp0';
  }

  @override
  String get petsArchiveBlockersBody =>
      'To avoid any conflict or oversight, first handle or cancel these pending items:';

  @override
  String petsArchiveBlockersFooter(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Archiving will be unlocked once these $count items are resolved.',
      one: 'Archiving will be unlocked once this item is resolved.',
    );
    return '$_temp0';
  }

  @override
  String get petsArchiveLockedTooltip =>
      'Complete the pending actions to be able to archive';

  @override
  String get petsArchiveChecksTitle =>
      'Before archiving: appointments and listings';

  @override
  String get petsArchiveChecksBody =>
      'Checking upcoming appointments and open listings will be available soon.';
}
