import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'weight_alert.dart';

/// Alertes de poids « ignorées » : mémorisées sur cet appareil seulement, pour ne pas ajouter de collection ni de
/// règle Firestore. Un nouvel épisode (autre règle ou autre pesée de référence) s'affiche de nouveau.
abstract final class WeightAlertDismissals {
  static const _key = 'pets.weightAlertsDismissed';

  /// Garde les plus récentes : une liste qui grandirait sans fin n'apporte rien.
  static const _max = 100;

  /// Change à chaque alerte ignorée : la fiche et la liste se mettent à jour ensemble.
  static final changes = ValueNotifier<int>(0);

  static String keyFor(String petId, WeightAlert alert) => '$petId:${alert.id}';

  static Future<Set<String>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList(_key) ?? const []).toSet();
    } on Exception {
      return {};
    }
  }

  static Future<void> dismiss(String petId, WeightAlert alert) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = [...?prefs.getStringList(_key), keyFor(petId, alert)];
      await prefs.setStringList(_key, keys.skip(keys.length > _max ? keys.length - _max : 0).toList());
    } on Exception {
      // Stockage indisponible : l'alerte reste simplement affichée.
    }
    changes.value++;
  }
}
