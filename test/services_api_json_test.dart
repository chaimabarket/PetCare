import 'package:flutter_test/flutter_test.dart';
import 'package:projet_flutter/features/services/data/service_models.dart';

void main() {
  test("un prestataire renvoyé par l'API se lit comme un document Firestore", () {
    final provider = ServiceProvider.fromJson({
      'id': 'u1',
      'ownerId': 'u1',
      'name': 'Salon Amine',
      'category': 'Toiletteurs',
      'city': 'Tunis',
      'status': 'published',
      'photoUrl': null,
    });

    expect(provider.name, 'Salon Amine');
    expect(provider.ownerId, 'u1');
    expect(provider.status, 'published');
    expect(provider.phone, '');
  });

  test('une prestation garde sa durée et son prix', () {
    final service = ProviderService.fromJson({
      'id': 's1',
      'providerId': 'u1',
      'name': 'Bain complet',
      'durationMinutes': 45,
      'price': 35,
      'status': 'archived',
    });

    expect(service.durationMinutes, 45);
    expect(service.price, 35.0);
    expect(service.status, 'archived');
  });

  test("une réservation de l'API a sa date convertie", () {
    final booking = ServiceBooking.fromJson({
      'id': 'b1',
      'providerUid': 'u1',
      'clientUid': 'u2',
      'animalName': 'Milo',
      'dateTime': '2026-11-12T09:30:00.000Z',
      'status': 'pending',
    });

    expect(booking.dateTime.toUtc().hour, 9);
    expect(booking.status, 'pending');
    expect(booking.animalName, 'Milo');
  });
}
