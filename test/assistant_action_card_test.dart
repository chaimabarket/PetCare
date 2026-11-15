import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projet_flutter/core/theme/app_theme.dart';
import 'package:projet_flutter/features/assistant/data/assistant_actions.dart';
import 'package:projet_flutter/features/assistant/presentation/widgets/action_card.dart';

void main() {
  testWidgets('carte en attente : « Confirmer » et « Annuler » s\'affichent avec le thème de l\'app', (tester) async {
    var confirmed = false;
    var cancelled = false;
    final action = AssistantAction.fromCall('ajouter_soin', {
      'animal': 'Nala',
      'type': 'allergie',
      'titre': 'Allergie canard',
      'date': '2026-11-14',
    })!;

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: SizedBox(
          width: 300,
          child: ActionCard(
            action: action,
            petId: 'p1',
            onConfirm: () => confirmed = true,
            onCancel: () => cancelled = true,
          ),
        ),
      ),
    ));

    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Confirmer'));
    await tester.tap(find.text('Annuler'));
    expect(confirmed, isTrue);
    expect(cancelled, isTrue);
  });
}
