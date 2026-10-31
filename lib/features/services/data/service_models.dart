import 'package:cloud_firestore/cloud_firestore.dart';

/// Date venue de Firestore (`Timestamp`) ou de l'API REST (texte ISO).
DateTime? _toDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value)?.toLocal();
  return null;
}

class ServiceProvider {
  const ServiceProvider({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.category,
    required this.city,
    required this.description,
    required this.phone,
    required this.email,
    required this.status,
    this.photoUrl,
    this.address,
  });

  factory ServiceProvider.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) => ServiceProvider.fromData(
    document.id,
    document.data() ?? const <String, dynamic>{},
  );

  /// Prestataire renvoyé par l'API REST (`GET /api/services/providers`).
  factory ServiceProvider.fromJson(Map<String, dynamic> json) =>
      ServiceProvider.fromData(json['id'] as String? ?? '', json);

  factory ServiceProvider.fromData(String id, Map<String, dynamic> data) {
    return ServiceProvider(
      id: id,
      ownerId: data['ownerId'] as String? ?? id,
      name: data['name'] as String? ?? '',
      category: data['category'] as String? ?? 'Autres',
      city: data['city'] as String? ?? '',
      description: data['description'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      email: data['email'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      photoUrl: data['photoUrl'] as String?,
      address: data['address'] as String?,
    );
  }

  final String id;
  final String ownerId;
  final String name;
  final String category;
  final String city;
  final String description;
  final String phone;
  final String email;
  final String status;
  final String? photoUrl;
  final String? address;

  Map<String, dynamic> toFirestore() => {
    'ownerId': ownerId,
    'name': name.trim(),
    'category': category,
    'city': city.trim(),
    'description': description.trim(),
    'phone': phone.trim(),
    'email': email.trim(),
    'status': status,
    'photoUrl': photoUrl,
    'address': address?.trim(),
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

class ProviderService {
  const ProviderService({
    required this.id,
    required this.providerId,
    required this.name,
    required this.category,
    required this.durationMinutes,
    required this.price,
    required this.status,
    this.description = '',
  });

  factory ProviderService.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) => ProviderService.fromData(
    document.id,
    document.data() ?? const <String, dynamic>{},
  );

  /// Prestation renvoyée par l'API REST.
  factory ProviderService.fromJson(Map<String, dynamic> json) =>
      ProviderService.fromData(json['id'] as String? ?? '', json);

  factory ProviderService.fromData(String id, Map<String, dynamic> data) {
    return ProviderService(
      id: id,
      providerId: data['providerId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      category: data['category'] as String? ?? 'Autres',
      durationMinutes: (data['durationMinutes'] as num?)?.toInt() ?? 30,
      price: (data['price'] as num?)?.toDouble() ?? 0,
      status: data['status'] as String? ?? 'published',
      description: data['description'] as String? ?? '',
    );
  }

  final String id;
  final String providerId;
  final String name;
  final String category;
  final int durationMinutes;
  final double price;
  final String status;
  final String description;

  Map<String, dynamic> toFirestore() => {
    'providerId': providerId,
    'name': name.trim(),
    'category': category,
    'durationMinutes': durationMinutes,
    'price': price,
    'status': status,
    'description': description.trim(),
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

class ServiceBooking {
  const ServiceBooking({
    required this.id,
    required this.providerUid,
    required this.clientUid,
    required this.clientName,
    required this.providerName,
    required this.serviceId,
    required this.serviceName,
    required this.animalName,
    required this.dateTime,
    required this.status,
    this.notes = '',
  });

  factory ServiceBooking.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) => ServiceBooking.fromData(
    document.id,
    document.data() ?? const <String, dynamic>{},
  );

  /// Réservation renvoyée par l'API REST.
  factory ServiceBooking.fromJson(Map<String, dynamic> json) =>
      ServiceBooking.fromData(json['id'] as String? ?? '', json);

  factory ServiceBooking.fromData(String id, Map<String, dynamic> data) {
    return ServiceBooking(
      id: id,
      providerUid: data['providerUid'] as String? ?? '',
      clientUid: data['clientUid'] as String? ?? '',
      clientName: data['clientName'] as String? ?? '',
      providerName: data['providerName'] as String? ?? '',
      serviceId: data['serviceId'] as String? ?? '',
      serviceName: data['serviceName'] as String? ?? '',
      animalName: data['animalName'] as String? ?? '',
      dateTime: _toDate(data['dateTime']) ?? DateTime.now(),
      status: data['status'] as String? ?? 'pending',
      notes: data['notes'] as String? ?? '',
    );
  }

  final String id;
  final String providerUid;
  final String clientUid;
  final String clientName;
  final String providerName;
  final String serviceId;
  final String serviceName;
  final String animalName;
  final DateTime dateTime;
  final String status;
  final String notes;
}
