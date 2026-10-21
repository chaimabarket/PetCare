import 'package:flutter/material.dart';

import '../features/auth/presentation/forgot_password_screen.dart';
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
      };
}
