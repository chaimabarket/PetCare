import 'package:cloud_firestore/cloud_firestore.dart';

import '../../auth/data/user_role.dart';

/// Profil d'un utilisateur, stocké dans `users/{uid}`.
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.city,
    required this.role,
    this.phone,
    this.createdAt,
  });

  factory UserProfile.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return UserProfile(
      uid: doc.id,
      fullName: data['fullName'] as String? ?? '',
      email: data['email'] as String? ?? '',
      city: data['city'] as String? ?? '',
      phone: data['phone'] as String?,
      role: UserRole.fromFirestore(data['role'] as String?),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Profil renvoyé par l'API REST (`GET /api/users/me`).
  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        uid: json['uid'] as String? ?? '',
        fullName: json['fullName'] as String? ?? '',
        email: json['email'] as String? ?? '',
        city: json['city'] as String? ?? '',
        phone: json['phone'] as String?,
        role: UserRole.fromFirestore(json['role'] as String?),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      );

  final String uid;
  final String fullName;
  final String email;
  final String city;
  final String? phone;
  final UserRole role;
  final DateTime? createdAt;

  String get firstName => fullName.trim().split(RegExp(r'\s+')).first;

  /// Initiales affichées dans l'avatar (ex. « LM » pour Lina Mercier).
  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }
}
