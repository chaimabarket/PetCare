import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:projet_flutter/features/pets/data/pet.dart';
import 'package:projet_flutter/features/pets/data/pet_media.dart';

void main() {
  test('une fiche renvoyée par l\'API REST se lit comme une fiche Firestore', () {
    final pet = Pet.fromJson({
      'id': 'p1',
      'ownerId': 'u1',
      'name': 'Milo',
      'species': 'cat',
      'sex': 'female',
      'breed': null,
      'birthDate': '2023-03-01T23:00:00Z',
      'birthDateEstimated': true,
      'chipNumber': '250269812345678',
      'sterilized': true,
      'notes': 'Calme',
      'status': 'archived',
      'favorite': true,
      'contacts': [
        {'name': 'Dr Ben', 'detail': 'Vétérinaire', 'phone': '20 123 456', 'emergency': true},
      ],
      'createdAt': '2026-01-02T10:00:00.123456Z',
    });

    expect(pet.id, 'p1');
    expect(pet.species, PetSpecies.cat);
    expect(pet.isFemale, isTrue);
    expect(pet.isArchived, isTrue);
    expect(pet.birthDate!.isUtc, isFalse);
    expect(pet.birthDate!.toUtc(), DateTime.utc(2023, 3, 1, 23));
    expect(pet.contacts.single.emergency, isTrue);
  });

  test('le jour de naissance saisi est envoyé en minuit local', () {
    final json = PetDraft(
      name: '  Milo ',
      species: PetSpecies.dog,
      sex: PetSex.male,
      birthDate: DateTime(2023, 3, 2, 15, 30),
      breed: '  ',
      chipNumber: '',
    ).toJson();

    expect(json['name'], 'Milo');
    expect(json['breed'], isNull);
    expect(json['chipNumber'], isNull);
    expect(DateTime.parse(json['birthDate'] as String).toLocal(), DateTime(2023, 3, 2));
  });

  test('une photo arrive en base64 et une pesée garde son jour', () {
    final photo = PetPhoto.fromJson({'id': 'a', 'data': base64Encode([1, 2, 3]), 'sortOrder': 2});
    expect(photo.bytes, [1, 2, 3]);
    expect(photo.sortOrder, 2);

    final day = DateTime(2026, 10, 30);
    final entry = WeightEntry.fromJson({
      'id': WeightEntry.idFor(day),
      'measuredOn': day.toUtc().toIso8601String(),
      'weightKg': 5,
      'note': null,
    });
    expect(entry.id, '2026-10-30');
    expect(entry.measuredOn, day);
    expect(entry.weightKg, 5.0);
  });
}
