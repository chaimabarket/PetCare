import 'dart:async';

/// Signal « les données ont changé » : les flux qui interrogent l'API se rafraîchissent aussitôt
/// au lieu d'attendre leur prochain passage.
final _changes = StreamController<void>.broadcast();

void notifyApiDataChanged() => _changes.add(null);

/// Interroge [fetch] immédiatement puis toutes les [every], et à chaque [notifyApiDataChanged].
/// S'arrête quand plus personne n'écoute.
Stream<T> poll<T>(Future<T> Function() fetch, {Duration every = const Duration(seconds: 8)}) async* {
  while (true) {
    yield await fetch();
    await Future.any([Future<void>.delayed(every), _changes.stream.first]);
  }
}
