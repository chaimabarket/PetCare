import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Numéros des onglets de la barre du bas.
///
/// Un écran ouvert depuis un onglet peut se fermer en renvoyant l'un de ces numéros
/// (`Navigator.pop(MainTab.services)`) : la structure principale affiche alors cet onglet.
abstract final class MainTab {
  static const home = 0;
  static const pets = 1;
  static const health = 2;
  static const community = 3;
  static const services = 4;
}

/// Les 5 onglets, dans l'ordre de [MainTab], partagés par toutes les barres du bas de l'application.
List<({String label, IconData icon, IconData activeIcon})> mainTabs(AppLocalizations l) => [
      (label: l.navHome, icon: Icons.home_outlined, activeIcon: Icons.home),
      (label: l.navPets, icon: Icons.pets_outlined, activeIcon: Icons.pets),
      (label: l.navHealth, icon: Icons.health_and_safety_outlined, activeIcon: Icons.health_and_safety),
      (label: l.navCommunity, icon: Icons.volunteer_activism_outlined, activeIcon: Icons.volunteer_activism),
      (label: l.navServices, icon: Icons.medical_services_outlined, activeIcon: Icons.medical_services),
    ];
