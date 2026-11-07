import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Langue de l'interface choisie par l'utilisateur (français ou anglais), mémorisée sur l'appareil.
class LocaleController extends ValueNotifier<Locale> {
  LocaleController._() : super(const Locale('fr'));

  static final instance = LocaleController._();

  static const supported = [Locale('fr'), Locale('en')];
  static const _prefsKey = 'app_locale';

  /// Charge la langue enregistrée ; à défaut, celle de l'appareil si elle est prise en charge, sinon le français.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    final device = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final code = saved ?? device;
    value = supported.firstWhere((l) => l.languageCode == code, orElse: () => supported.first);
  }

  Future<void> change(Locale locale) async {
    value = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, locale.languageCode);
  }
}
