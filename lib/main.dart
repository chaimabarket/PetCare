import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/routes.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const PetCareApp());
}

class PetCareApp extends StatelessWidget {
  const PetCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PetCare Community',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      // Firebase garde la session : un utilisateur déjà connecté arrive directement sur l'accueil.
      initialRoute: FirebaseAuth.instance.currentUser == null ? AppRoutes.login : AppRoutes.home,
      routes: AppRoutes.all,
    );
  }
}
