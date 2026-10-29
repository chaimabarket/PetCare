import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Client de l'API REST PetCare (dossier `backend/`).
///
/// L'adresse du serveur se règle au lancement :
/// `flutter run --dart-define=API_URL=http://192.168.1.20:3000` (téléphone réel sur le même Wi-Fi).
/// Par défaut, `10.0.2.2` est l'adresse du PC vue depuis l'émulateur Android.
class ApiClient {
  ApiClient({http.Client? client, FirebaseAuth? auth})
      : _client = client ?? http.Client(),
        _auth = auth ?? FirebaseAuth.instance;

  static const baseUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:3000');
  static const _timeout = Duration(seconds: 8);

  final http.Client _client;
  final FirebaseAuth _auth;

  Future<dynamic> get(String path) => _send('GET', path);

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) => _send('POST', path, body);

  Future<dynamic> put(String path, Map<String, dynamic> body) => _send('PUT', path, body);

  Future<dynamic> patch(String path, [Map<String, dynamic>? body]) => _send('PATCH', path, body);

  Future<dynamic> _send(String method, String path, [Map<String, dynamic>? body]) async {
    final user = _auth.currentUser;
    if (user == null) throw const ApiException(401, 'Connexion requise.');

    final request = http.Request(method, Uri.parse('$baseUrl$path'))
      ..headers['Authorization'] = 'Bearer ${await user.getIdToken()}'
      ..headers['Content-Type'] = 'application/json';
    if (body != null) request.body = jsonEncode(body);

    final http.Response response;
    try {
      response = await http.Response.fromStream(await _client.send(request).timeout(_timeout));
    } on Exception {
      // Serveur éteint, mauvaise adresse ou pas de réseau.
      throw const ApiException.unreachable();
    }

    final decoded = response.body.isEmpty ? null : jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode >= 200 && response.statusCode < 300) return decoded;

    final message = decoded is Map && decoded['error'] is String
        ? decoded['error'] as String
        : 'Erreur du serveur (${response.statusCode}).';
    throw ApiException(response.statusCode, message);
  }
}

/// Erreur renvoyée par l'API, avec un message prêt à afficher.
class ApiException implements Exception {
  const ApiException(this.statusCode, this.message);

  /// Le serveur n'a pas répondu.
  const ApiException.unreachable()
      : statusCode = 0,
        message = "Le serveur PetCare n'est pas joignable.";

  final int statusCode;
  final String message;

  bool get isUnreachable => statusCode == 0;

  @override
  String toString() => message;
}
