import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/locale/locale_controller.dart';
import 'core/routes.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await LocaleController.instance.load();
  runApp(const PetCareApp());
}

class PetCareApp extends StatelessWidget {
  const PetCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    // La langue (français ou anglais) suit le choix de l'utilisateur, voir LanguageButton.
    return ValueListenableBuilder<Locale>(
      valueListenable: LocaleController.instance,
      builder: (context, locale, _) => MaterialApp(
        title: 'PetCare Community',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        // Firebase garde la session : un utilisateur déjà connecté arrive directement sur l'accueil.
        initialRoute: FirebaseAuth.instance.currentUser == null ? AppRoutes.login : AppRoutes.home,
        routes: AppRoutes.all,
      ),
    );
  }
}
