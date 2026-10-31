import 'dart:async';

import 'package:flutter/widgets.dart';

/// Signal « les données ont changé » : les flux qui interrogent l'API se rafraîchissent aussitôt
/// au lieu d'attendre leur prochain passage.
final _changes = StreamController<void>.broadcast();

void notifyApiDataChanged() => _changes.add(null);

// ------------------------------------------------------------------ Application au premier plan

var _foreground = true;
Completer<void>? _resumed;
var _observing = false;

class _LifecycleObserver with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      _resumed?.complete();
      _resumed = null;
    }
  }
}

/// Une application en arrière-plan n'interroge plus le serveur : on économise le quota de Firestore.
Future<void> _untilForeground() {
  if (!_observing) {
    _observing = true;
    WidgetsFlutterBinding.ensureInitialized().addObserver(_LifecycleObserver());
  }
  if (_foreground) return Future.value();
  return (_resumed ??= Completer<void>()).future;
}

/// Interroge [fetch] immédiatement puis toutes les [every], et à chaque [notifyApiDataChanged].
/// La lecture est suspendue tant que l'application est en arrière-plan.
///
/// Chaque écoute relance sa propre boucle et s'arrête quand l'écouteur se désabonne. Le flux peut donc être
/// écouté plusieurs fois : une liste détruit puis recrée ses `StreamBuilder` au défilement, avec le même
/// flux (un flux ordinaire lèverait « Stream has already been listened to »).
Stream<T> poll<T>(Future<T> Function() fetch, {Duration every = const Duration(seconds: 30)}) {
  return Stream<T>.multi((controller) {
    var active = true;
    controller.onCancel = () => active = false;

    Future<void>(() async {
      while (active) {
        try {
          await _untilForeground();
          if (!active) return;
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
