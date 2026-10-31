import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'service_models.dart';

class ServiceRepository {
  ServiceRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _providers =>
      _firestore.collection('serviceProviders');
  CollectionReference<Map<String, dynamic>> get _bookings =>
      _firestore.collection('serviceBookings');

  Stream<List<ServiceProvider>> watchPublishedProviders() => _providers
      .where('status', isEqualTo: 'published')
      .snapshots()
      .map(
        (snapshot) => snapshot.docs.map(ServiceProvider.fromDocument).toList(),
      );

  Stream<List<ServiceProvider>> watchPendingProviders() => _providers
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map(
        (snapshot) => snapshot.docs.map(ServiceProvider.fromDocument).toList(),
      );

  Stream<ServiceProvider?> watchProvider(String providerId) => _providers
      .doc(providerId)
      .snapshots()
      .map((doc) => doc.exists ? ServiceProvider.fromDocument(doc) : null);

  Stream<List<ProviderService>> watchServices(
    String providerId, {
    bool includeArchived = false,
  }) {
    final collection = _providers.doc(providerId).collection('services');
    final query = includeArchived
        ? collection
        : collection.where('status', isEqualTo: 'published');
    return query.snapshots().map((snapshot) {
      final services = snapshot.docs.map(ProviderService.fromDocument).toList();
      return includeArchived
          ? services
          : services.where((service) => service.status == 'published').toList();
    });
  }

  Stream<List<ServiceBooking>> watchProviderBookings(String providerId) =>
      _bookings
          .where('providerUid', isEqualTo: providerId)
          .snapshots()
          .map(_sortedBookings);

  Stream<List<ServiceBooking>> watchClientBookings(String clientId) => _bookings
      .where('clientUid', isEqualTo: clientId)
      .snapshots()
      .map(_sortedBookings);

  Stream<Map<int, Map<String, dynamic>>> watchAvailability(String providerId) =>
      _providers
          .doc(providerId)
          .collection('availability')
          .snapshots()
          .map(
            (snapshot) => {
              for (final document in snapshot.docs)
                int.tryParse(document.id) ?? -1: document.data(),
            },
          );

  List<ServiceBooking> _sortedBookings(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final bookings = snapshot.docs.map(ServiceBooking.fromDocument).toList();
    bookings.sort((left, right) => left.dateTime.compareTo(right.dateTime));
    return bookings;
  }

  Future<void> saveProvider(ServiceProvider provider) async {
    await _providers
        .doc(provider.ownerId)
        .set(provider.toFirestore(), SetOptions(merge: true));
  }

  Future<void> setProviderStatus(String providerId, String status) => _providers
      .doc(providerId)
      .update({'status': status, 'updatedAt': FieldValue.serverTimestamp()});

  Future<void> saveService(ProviderService service) async {
    final services = _providers.doc(service.providerId).collection('services');
    final reference = service.id.isEmpty
        ? services.doc()
        : services.doc(service.id);
    await reference.set(service.toFirestore(), SetOptions(merge: true));
  }

  Future<void> saveAvailability(
    int weekday,
    Map<String, dynamic> availability,
  ) => _providers
      .doc(_auth.currentUser!.uid)
      .collection('availability')
      .doc('$weekday')
      .set(availability, SetOptions(merge: true));

  Future<void> createBooking({
    required ServiceProvider provider,
    required ProviderService service,
    required String animalName,
    required DateTime dateTime,
    required String notes,
  }) async {
    final client = _auth.currentUser;
    if (client == null) {
      throw StateError('Connectez-vous pour demander une réservation.');
    }
    await _bookings.add({
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
    });
  }

  Future<void> setBookingStatus(String bookingId, String status) => _bookings
      .doc(bookingId)
      .update({'status': status, 'updatedAt': FieldValue.serverTimestamp()});
}
