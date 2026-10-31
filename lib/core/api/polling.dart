import 'dart:async';

/// Signal « les données ont changé » : les flux qui interrogent l'API se rafraîchissent aussitôt
/// au lieu d'attendre leur prochain passage.
final _changes = StreamController<void>.broadcast();

void notifyApiDataChanged() => _changes.add(null);

/// Interroge [fetch] immédiatement puis toutes les [every], et à chaque [notifyApiDataChanged].
///
/// Chaque écoute relance sa propre boucle et s'arrête quand l'écouteur se désabonne. Le flux peut donc être
/// écouté plusieurs fois : une liste détruit puis recrée ses `StreamBuilder` au défilement, avec le même
/// flux (un flux ordinaire lèverait « Stream has already been listened to »).
Stream<T> poll<T>(Future<T> Function() fetch, {Duration every = const Duration(seconds: 8)}) {
  return Stream<T>.multi((controller) {
    var active = true;
    controller.onCancel = () => active = false;

    Future<void>(() async {
      while (active) {
        try {
          final value = await fetch();
          if (!active) return;
          controller.add(value);
        } catch (error, stackTrace) {
          if (active) controller.addError(error, stackTrace);
          break;
        }
        await Future.any([Future<void>.delayed(every), _changes.stream.first]);
      }
      if (active) await controller.close();
    });
  });
}
