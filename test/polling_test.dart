import 'package:flutter_test/flutter_test.dart';
import 'package:projet_flutter/core/api/polling.dart';

void main() {
  test('un flux poll peut être écouté plusieurs fois (liste qui recrée ses StreamBuilder)', () async {
    var calls = 0;
    final stream = poll(() async => ++calls, every: const Duration(milliseconds: 10));

    final first = await stream.first;
    final second = await stream.first;

    expect(first, 1);
    expect(second, 2);
  });

  test('plusieurs écouteurs en même temps reçoivent chacun les valeurs', () async {
    final stream = poll(() async => 'ok', every: const Duration(milliseconds: 10));

    final results = await Future.wait([stream.first, stream.first]);

    expect(results, ['ok', 'ok']);
  });

  test("une erreur de lecture arrive à l'écouteur puis le flux se termine", () async {
    final stream = poll<int>(() async => throw StateError('hors ligne'), every: const Duration(milliseconds: 10));

    await expectLater(stream, emitsInOrder([emitsError(isA<StateError>()), emitsDone]));
  });

  test('notifyApiDataChanged relance la lecture sans attendre', () async {
    var calls = 0;
    final stream = poll(() async => ++calls, every: const Duration(seconds: 30));
    final values = <int>[];
    final subscription = stream.listen(values.add);

    await Future<void>.delayed(const Duration(milliseconds: 50));
    notifyApiDataChanged();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await subscription.cancel();

    expect(values, [1, 2]);
  });
}
