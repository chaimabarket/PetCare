import 'package:cloud_firestore/cloud_firestore.dart';

import 'health_sheet.dart';
import 'health_sheets_starter.dart';

/// Fiches santé publiques et marque-pages de l'utilisateur.
class HealthSheetRepository {
  HealthSheetRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Fiches publiées dans `healthSheets`, complétées par les fiches de départ
  /// (une fiche Firestore de même identifiant remplace la fiche de départ).
  /// Si la collection est vide ou illisible, seules les fiches de départ s'affichent.
  Stream<List<HealthSheet>> watchSheets() async* {
    yield starterHealthSheets;
    try {
      await for (final snap in _firestore.collection('healthSheets').snapshots()) {
        final remote = [
          for (final doc in snap.docs)
            if (doc.data()['published'] != false) HealthSheet.fromFirestore(doc),
        ];
        final ids = remote.map((s) => s.id).toSet();
        yield [...remote, ...starterHealthSheets.where((s) => !ids.contains(s.id))];
      }
    } on FirebaseException {
      // Règles pas encore déployées ou hors ligne : on garde les fiches de départ.
    }
  }

  CollectionReference<Map<String, dynamic>> _bookmarks(String uid) =>
      _firestore.collection('users').doc(uid).collection('healthBookmarks');

  Stream<Set<String>> watchBookmarks(String uid) => _bookmarks(uid)
      .snapshots()
      .map((snap) => snap.docs.map((d) => d.id).toSet())
      .handleError((Object _) {});

  Future<void> setBookmarked(String uid, String sheetId, {required bool bookmarked}) => bookmarked
      ? _bookmarks(uid).doc(sheetId).set({'createdAt': FieldValue.serverTimestamp()})
      : _bookmarks(uid).doc(sheetId).delete();
}
