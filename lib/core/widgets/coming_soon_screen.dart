import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Écran provisoire pour les pages dont la maquette n'est pas encore développée.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.title, this.embedded = false});

  final String title;

  /// Vrai quand l'écran est affiché dans un onglet (sans sa propre barre de titre).
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    const body = Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.pets, size: 48, color: AppColors.teal),
          SizedBox(height: 12),
          Text('Bientôt disponible', style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
    if (embedded) return body;

    return Scaffold(
      appBar: AppBar(title: Text(title), backgroundColor: AppColors.background),
      body: body,
    );
  }
}
