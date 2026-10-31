import 'package:flutter/material.dart';

import '../features/adoption/data/adoption_listing.dart';
import '../features/adoption/presentation/adoption_feed_screen.dart';
import '../features/adoption/presentation/application_form_screen.dart';
import '../features/adoption/presentation/application_review_screen.dart';
import '../features/adoption/presentation/favorites_screen.dart';
import '../features/adoption/presentation/happy_tails_screen.dart';
import '../features/adoption/presentation/listing_detail_screen.dart';
import '../features/adoption/presentation/listing_form_screen.dart';
import '../features/adoption/presentation/my_applications_screen.dart';
import '../features/adoption/presentation/my_listings_screen.dart';
import '../features/adoption/presentation/received_applications_screen.dart';
import '../features/adoption/presentation/share_happy_tail_screen.dart';

import '../features/appointments/presentation/agenda_screen.dart';
import '../features/appointments/presentation/appointment_detail_screen.dart';
import '../features/appointments/presentation/appointment_form_screen.dart';
import '../features/appointments/presentation/reminders_screen.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/health/data/health_sheet.dart';
import '../features/health/presentation/health_record_screen.dart';
import '../features/health/presentation/health_sheet_detail_screen.dart';
import '../features/health/presentation/health_sheets_screen.dart';
import '../features/health/presentation/medical_entry_form_screen.dart';
import '../features/health/presentation/treatment_form_screen.dart';
import '../features/health/presentation/treatments_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/home/presentation/main_shell.dart';
import '../features/notifications/presentation/notifications_screen.dart';
import '../features/profile/data/user_profile.dart';
import '../features/profile/presentation/edit_profile_screen.dart';
import '../features/profile/presentation/profile_screen.dart';

/// Noms des routes de l'application.
abstract final class AppRoutes {
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const home = '/home';
  static const profile = '/profile';
  static const editProfile = '/profile/edit';
  static const notifications = '/notifications';

  // Module 5 : Adoption. Les arguments sont indiqués à droite.
  static const adoption = '/adoption';
  static const adoptionListing = '/adoption/listing'; // String : id de l'annonce
  static const adoptionApply = '/adoption/apply'; // AdoptionListing
  static const adoptionPublish = '/adoption/publish'; // AdoptionListing? (modification)
  static const adoptionFavorites = '/adoption/favorites';
  static const myApplications = '/adoption/my-applications';
  static const myListings = '/adoption/my-listings';
  static const receivedApplications = '/adoption/received'; // AdoptionListing
  static const applicationReview = '/adoption/application'; // String : id de la candidature
  static const happyTails = '/happy-tails';
  static const shareHappyTail = '/happy-tails/share'; // AdoptionListing adoptée

  static Object? _args(BuildContext context) => ModalRoute.of(context)?.settings.arguments;

  // Module 3 (Rendez-vous et rappels).
  static const agenda = '/agenda';
  static const appointmentDetail = '/agenda/detail';
  static const appointmentForm = '/agenda/new';
  static const reminders = '/reminders';

  // Module 2 (Santé et dossier médical).
  static const healthRecord = '/health'; // String : id de l'animal (`pets/{id}`)
  static const healthEntryForm = '/health/entry'; // String : id de l'animal
  static const treatments = '/health/treatments'; // String : id de l'animal
  static const treatmentForm = '/health/treatments/new'; // String : id de l'animal
  static const healthSheets = '/health/sheets';
  static const healthSheetDetail = '/health/sheets/detail'; // HealthSheet

  static Map<String, WidgetBuilder> get all => {
        login: (_) => const LoginScreen(),
        register: (_) => const RegisterScreen(),
        forgotPassword: (context) => ForgotPasswordScreen(
              initialEmail: ModalRoute.of(context)?.settings.arguments as String?,
            ),
        home: (_) => const MainShell(),
        profile: (_) => const ProfileScreen(),
        editProfile: (context) => EditProfileScreen(
              profile: ModalRoute.of(context)!.settings.arguments! as UserProfile,
            ),
        notifications: (_) => const NotificationsScreen(),
        adoption: (_) => const AdoptionFeedScreen(),
        adoptionListing: (context) => ListingDetailScreen(listingId: _args(context)! as String),
        adoptionApply: (context) => ApplicationFormScreen(listing: _args(context)! as AdoptionListing),
        adoptionPublish: (context) => ListingFormScreen(listing: _args(context) as AdoptionListing?),
        adoptionFavorites: (_) => const FavoritesScreen(),
        myApplications: (_) => const MyApplicationsScreen(),
        myListings: (_) => const MyListingsScreen(),
        receivedApplications: (context) => ReceivedApplicationsScreen(listing: _args(context)! as AdoptionListing),
        applicationReview: (context) => ApplicationReviewScreen(applicationId: _args(context)! as String),
        happyTails: (_) => const HappyTailsScreen(),
        shareHappyTail: (context) => ShareHappyTailScreen(listing: _args(context)! as AdoptionListing),

        agenda: (context) => AgendaScreen(initialPet: ModalRoute.of(context)?.settings.arguments as String?),
        appointmentDetail: (context) => AppointmentDetailScreen(
              appointmentId: ModalRoute.of(context)!.settings.arguments! as String,
            ),
        appointmentForm: (context) => AppointmentFormScreen(
              args: ModalRoute.of(context)?.settings.arguments as AppointmentFormArgs? ?? const AppointmentFormArgs(),
            ),
        reminders: (_) => const RemindersScreen(),

        healthRecord: (context) => HealthRecordScreen(petId: _args(context)! as String),
        healthEntryForm: (context) => MedicalEntryFormScreen(petId: _args(context)! as String),
        treatments: (context) => TreatmentsScreen(petId: _args(context)! as String),
        treatmentForm: (context) => TreatmentFormScreen(petId: _args(context)! as String),
        healthSheets: (_) => const HealthSheetsScreen(),
        healthSheetDetail: (context) => HealthSheetDetailScreen(sheet: _args(context)! as HealthSheet),
      };
}
