import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../locale/locale_controller.dart';

/// Bouton de l'en-tête pour passer l'interface en français ou en anglais.
class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key, this.color = const Color(0xFF3E4947)});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final current = LocaleController.instance.value.languageCode;

    return PopupMenuButton<Locale>(
      tooltip: l.languageTooltip,
      icon: Icon(Icons.translate, color: color),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: LocaleController.instance.change,
      itemBuilder: (_) => [
        for (final (locale, label) in [(const Locale('fr'), l.languageFrench), (const Locale('en'), l.languageEnglish)])
          CheckedPopupMenuItem(
            value: locale,
            checked: locale.languageCode == current,
            child: Text(label),
          ),
      ],
    );
  }
}
