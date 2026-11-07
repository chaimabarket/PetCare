import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:projet_flutter/core/api/api_client.dart';

class _NoUserAuth implements FirebaseAuth {
  @override
  User? get currentUser => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('des lectures identiques et simultanées ne font partir qu\'une requête, les suivantes sont servies par la mémoire', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls += 1;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return http.Response('{"n": $calls}', 200);
    });
    final api = ApiClient(client: client, auth: _NoUserAuth());

    final results = await Future.wait([api.get('/api/x'), api.get('/api/x'), api.get('/api/x')]);
    expect(calls, 1);
    expect(results.every((r) => (r as Map)['n'] == 1), isTrue);

    await api.get('/api/x');
    expect(calls, 1, reason: 'servie par la mémoire pendant quelques secondes');

    await api.get('/api/y');
    expect(calls, 2, reason: 'une autre adresse fait une nouvelle requête');
  });

  test('une écriture réussie vide la mémoire : la lecture suivante interroge le serveur', () async {
    var gets = 0;
    final client = MockClient((request) async {
      if (request.method == 'GET') {
        gets += 1;
        return http.Response('{"n": $gets}', 200);
      }
      return http.Response('{}', 200);
    });
    final api = ApiClient(client: client, auth: _NoUserAuth());

    await api.get('/api/z');
    await api.put('/api/z', {'a': 1});
    final after = await api.get('/api/z') as Map;

    expect(gets, 2);
    expect(after['n'], 2);
  });
}
