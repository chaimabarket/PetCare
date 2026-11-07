import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projet_flutter/features/health/data/text_scanner.dart';
import 'package:projet_flutter/features/health/presentation/widgets/scan_prescription.dart';
import 'package:projet_flutter/l10n/app_localizations.dart';

Widget _app(Widget child) => MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('bouton affiché sur Android et iOS, masqué sur Windows, macOS et Linux', (tester) async {
    for (final (platform, visible) in [
      (TargetPlatform.android, true),
      (TargetPlatform.iOS, true),
      (TargetPlatform.windows, false),
      (TargetPlatform.macOS, false),
      (TargetPlatform.linux, false),
    ]) {
      debugDefaultTargetPlatformOverride = platform;
      expect(isTextScanSupported, visible, reason: '$platform');
      await tester.pumpWidget(_app(ScanPrescriptionButton(onResult: (_) {})));
      expect(find.text('Scanner une vignette ou une ordonnance'), visible ? findsOneWidget : findsNothing,
          reason: '$platform');
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('bandeau : champs pré-remplis à vérifier et conseil', (tester) async {
    await tester.pumpWidget(_app(const ScanReviewBanner(
      fields: ['vaccin', 'date'],
      hint: '« Synulox » ressemble à un médicament : ajoutez-le depuis « Traitements ».',
    )));
    expect(
      find.text('Pré-rempli par le scan : vaccin, date. Vérifiez et corrigez avant d\'enregistrer.'),
      findsOneWidget,
    );
    expect(find.textContaining('ressemble à un médicament'), findsOneWidget);
  });
}
