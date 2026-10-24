import 'package:cloud_firestore/cloud_firestore.dart';

/// Un animal que l'on peut choisir pour un rendez-vous ou un rappel.
///
/// Les fiches complètes appartiennent au module 1 (Profils des animaux). Ici on ne garde que
/// ce qui s'affiche dans l'agenda ; ces valeurs sont recopiées dans chaque rendez-vous pour
/// que l'agenda reste lisible même si la fiche change.
class PetOption {
  const PetOption({required this.name, this.id, this.breed, this.photoUrl});

  final String? id;
  final String name;
  final String? breed;
  final String? photoUrl;

  @override
  bool operator ==(Object other) =>
      other is PetOption && other.name == name && other.id == id;

  @override
  int get hashCode => Object.hash(id, name);
}

/// Lit les animaux de l'utilisateur dans la collection `pets` du module 1.
///
/// Contrat attendu avec le module 1 : `pets/{id}` avec `ownerId`, `name`, `breed`, `photoUrl`
/// et `status` (« archived » pour un animal archivé, qui ne reçoit plus de rendez-vous, RG-06).
/// Tant que cette collection n'existe pas ou n'est pas lisible, la liste est vide et
/// l'utilisateur peut saisir le nom avec « Autre compagnon ».
class PetDirectory {
  PetDirectory({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<PetOption>> watch(String uid) => _firestore
      .collection('pets')
      .where('ownerId', isEqualTo: uid)
      .snapshots()
      .map((snap) => [
            for (final doc in snap.docs)
              if (doc.data()['status'] != 'archived' && (doc.data()['name'] as String?)?.isNotEmpty == true)
                PetOption(
                  id: doc.id,
                  name: doc.data()['name'] as String,
                  breed: doc.data()['breed'] as String?,
                  photoUrl: doc.data()['photoUrl'] as String?,
                ),
          ])
      // Collection absente ou fermée par les règles : on continue sans erreur.
      .handleError((Object _) {});
}
