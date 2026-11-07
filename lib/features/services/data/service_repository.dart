import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/polling.dart';
import 'service_models.dart';

/// Erreur affichable telle quelle (refus du serveur ou règle métier).
class ServiceException implements Exception {
  const ServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Annuaire des prestataires, prestations, disponibilités et réservations.
///
/// Tout passe par l'API REST PetCare (`/api/services`) ; si le serveur est injoignable, les mêmes
/// opérations passent directement par Firestore (mêmes règles de sécurité).
class ServiceRepository {
  ServiceRepository({FirebaseFirestore? firestore, FirebaseAuth? auth, ApiClient? api})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance,
      _api = api ?? ApiClient();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final ApiClient _api;

  static const _base = '/api/services';

  CollectionReference<Map<String, dynamic>> get _providers =>
      _firestore.collection('serviceProviders');
  CollectionReference<Map<String, dynamic>> get _bookings =>
      _firestore.collection('serviceBookings');

  /// Lit par l'API ; si le serveur est éteint, [viaFirestore] prend le relais.
  Future<T> _read<T>(
    Future<T> Function() viaApi,
    Future<T> Function() viaFirestore,
  ) async {
    try {
      return await viaApi();
    } on ApiException catch (e) {
      if (e.isUnreachable) return viaFirestore();
      rethrow;
    }
  }

  /// Écrit par l'API (ou par Firestore si le serveur est éteint), puis rafraîchit les écrans.
  Future<T> _write<T>(
    Future<T> Function() viaApi,
    Future<T> Function() viaFirestore,
  ) async {
    try {
      final result = await _read(viaApi, viaFirestore);
      notifyApiDataChanged();
      return result;
    } on ApiException catch (e) {
      throw ServiceException(e.message);
    }
  }

  static List<T> _list<T>(dynamic json, T Function(Map<String, dynamic>) parse) => [
    for (final item in json as List<dynamic>) parse(item as Map<String, dynamic>),
  ];

  // ---------------------------------------------------------------- Lectures

  /// Catégories de l'annuaire, dans l'ordre d'affichage ; les six historiques tant que la base est vide.
  Stream<List<ServiceCategory>> watchCategories() => poll(
    () async {
      final categories = await _read(
        () async => _list(await _api.get('$_base/categories'), ServiceCategory.fromJson),
        () async {
          final snapshot = await _firestore.collection('serviceCategories').orderBy('order').get();
          return [for (final d in snapshot.docs) ServiceCategory.fromData(d.id, d.data())];
        },
      );
      final result = categories.isEmpty ? ServiceCategory.defaults : categories;
      ServiceCategory.knownNames = [for (final c in result) c.name];
      return result;
    },
  );

  Stream<List<ServiceProvider>> watchPublishedProviders() => poll(
    () => _read(
      () async => _list(await _api.get('$_base/providers'), ServiceProvider.fromJson),
      () => _providers
          .where('status', isEqualTo: 'published')
          .snapshots()
          .map((s) => s.docs.map(ServiceProvider.fromDocument).toList())
          .first,
    ),
  );

  Stream<List<ServiceProvider>> watchPendingProviders() => poll(
    () => _read(
      () async => _list(await _api.get('$_base/providers/pending'), ServiceProvider.fromJson),
      () => _providers
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .map((s) => s.docs.map(ServiceProvider.fromDocument).toList())
          .first,
    ),
  );

  Stream<ServiceProvider?> watchProvider(String providerId) => poll(
    () => _read<ServiceProvider?>(
      () async {
        try {
          return ServiceProvider.fromJson(
            await _api.get('$_base/providers/$providerId') as Map<String, dynamic>,
          );
        } on ApiException catch (e) {
          if (e.statusCode == 404) return null;
          rethrow;
        }
      },
      () async {
        final doc = await _providers.doc(providerId).get();
        return doc.exists ? ServiceProvider.fromDocument(doc) : null;
      },
    ),
  );

  Stream<List<ProviderService>> watchServices(
    String providerId, {
    bool includeArchived = false,
  }) => poll(
    () => _read(
      () async => _list(
        await _api.get('$_base/providers/$providerId/services${includeArchived ? '?all=1' : ''}'),
        ProviderService.fromJson,
      ),
      () async {
        final collection = _providers.doc(providerId).collection('services');
        final snapshot = await (includeArchived
            ? collection
            : collection.where('status', isEqualTo: 'published')).get();
        return snapshot.docs.map(ProviderService.fromDocument).toList();
      },
    ),
  );

  Stream<List<ServiceBooking>> watchProviderBookings(String providerId) => poll(
    () => _read(
      () async => _list(await _api.get('$_base/bookings?as=provider'), ServiceBooking.fromJson),
      () async => _sortedBookings(await _bookings.where('providerUid', isEqualTo: providerId).get()),
    ),
  );

  Stream<List<ServiceBooking>> watchClientBookings(String clientId) => poll(
    () => _read(
      () async => _list(await _api.get('$_base/bookings?as=client'), ServiceBooking.fromJson),
      () async => _sortedBookings(await _bookings.where('clientUid', isEqualTo: clientId).get()),
    ),
  );

  Stream<Map<int, Map<String, dynamic>>> watchAvailability(String providerId) => poll(
    () => _read(
      () async {
        final json = await _api.get('$_base/providers/$providerId/availability') as Map<String, dynamic>;
        return {
          for (final entry in json.entries)
            int.tryParse(entry.key) ?? -1: Map<String, dynamic>.from(entry.value as Map),
        };
      },
      () async {
        final snapshot = await _providers.doc(providerId).collection('availability').get();
        return {
          for (final document in snapshot.docs) int.tryParse(document.id) ?? -1: document.data(),
        };
      },
    ),
  );

  List<ServiceBooking> _sortedBookings(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final bookings = snapshot.docs.map(ServiceBooking.fromDocument).toList();
    bookings.sort((left, right) => left.dateTime.compareTo(right.dateTime));
    return bookings;
  }

  // ---------------------------------------------------------------- Écritures

  /// Ajoute une catégorie (administrateur).
  Future<void> addCategory(String name, String icon) => _write(
    () => _api.post('$_base/categories', {'name': name, 'icon': icon}),
    () async {
      final snapshot = await _firestore.collection('serviceCategories').get();
      final orders = [
        for (final d in snapshot.docs)
          if (((d.data()['order'] as num?)?.toInt() ?? 99) < 99) (d.data()['order'] as num?)?.toInt() ?? 0,
      ];
      await _firestore.collection('serviceCategories').add({
        'name': name.trim(),
        'icon': icon,
        'order': orders.isEmpty ? 1 : orders.reduce((a, b) => a > b ? a : b) + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    },
  );

  /// Supprime une catégorie (administrateur) ; les prestataires déjà classés dedans gardent leur texte.
  Future<void> deleteCategory(String id) => _write(
    () => _api.delete('$_base/categories/$id'),
    () => _firestore.collection('serviceCategories').doc(id).delete(),
  );

  Future<void> saveProvider(ServiceProvider provider) => _write(
    () => _api.put('$_base/providers/me', {
      'name': provider.name,
      'category': provider.category,
      'city': provider.city,
      'description': provider.description,
      'phone': provider.phone,
      'email': provider.email,
      'photoUrl': provider.photoUrl,
      'address': provider.address,
    }),
    () => _providers.doc(provider.ownerId).set(provider.toFirestore(), SetOptions(merge: true)),
  );

  Future<void> setProviderStatus(String providerId, String status) => _write(
    () => _api.put('$_base/providers/$providerId/status', {'status': status}),
    () => _providers
        .doc(providerId)
        .update({'status': status, 'updatedAt': FieldValue.serverTimestamp()}),
  );

  Future<void> saveService(ProviderService service) => _write(
    () {
      final body = {
        'name': service.name,
        'category': service.category,
        'durationMinutes': service.durationMinutes,
        'price': service.price,
        'status': service.status,
        'description': service.description,
      };
      return service.id.isEmpty
          ? _api.post('$_base/providers/me/services', body)
          : _api.put('$_base/providers/me/services/${service.id}', body);
    },
    () {
      final services = _providers.doc(service.providerId).collection('services');
      final reference = service.id.isEmpty ? services.doc() : services.doc(service.id);
      return reference.set(service.toFirestore(), SetOptions(merge: true));
    },
  );

  Future<void> saveAvailability(int weekday, Map<String, dynamic> availability) => _write(
    () => _api.put('$_base/providers/me/availability/$weekday', {
      'enabled': availability['enabled'] == true,
      'ranges': availability['ranges'] ?? const [],
    }),
    () => _providers
        .doc(_auth.currentUser!.uid)
        .collection('availability')
        .doc('$weekday')
        .set(availability, SetOptions(merge: true)),
  );

  Future<void> createBooking({
    required ServiceProvider provider,
    required ProviderService service,
    required String animalName,
    required DateTime dateTime,
    required String notes,
  }) async {
    final client = _auth.currentUser;
    if (client == null) {
      throw const ServiceException('Connectez-vous pour demander une réservation.');
    }
    await _write(
      () => _api.post('$_base/bookings', {
        'providerId': provider.ownerId,
        'serviceId': service.id,
        'animalName': animalName.trim(),
        'dateTime': dateTime.toUtc().toIso8601String(),
        'notes': notes.trim(),
      }),
      () => _bookings.add({
        'providerUid': provider.ownerId,
        'providerName': provider.name,
        'clientUid': client.uid,
        'clientName': client.displayName ?? 'Utilisateur',
        'serviceId': service.id,
        'serviceName': service.name,
        'animalName': animalName.trim(),
        'dateTime': Timestamp.fromDate(dateTime),
        'notes': notes.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      }),
    );
  }

  Future<void> setBookingStatus(String bookingId, String status) => _write(
    () => _api.patch('$_base/bookings/$bookingId/status', {'status': status}),
    () => _bookings
        .doc(bookingId)
        .update({'status': status, 'updatedAt': FieldValue.serverTimestamp()}),
  );
}
