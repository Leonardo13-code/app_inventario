// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Método para obtener una referencia a una colección para StreamBuilder
  Query<Map<String, dynamic>> getCollection(String collectionPath, {String? orderByField}) {
    if (orderByField != null) {
      return _db.collection(collectionPath).orderBy(orderByField).withConverter<Map<String, dynamic>>(
        fromFirestore: (snapshot, _) => snapshot.data()!,
        toFirestore: (model, _) => model,
      );
    }
    return _db.collection(collectionPath).withConverter<Map<String, dynamic>>(
      fromFirestore: (snapshot, _) => snapshot.data()!,
      toFirestore: (model, _) => model,
    );
  }

  // Método para obtener los documentos de una colección una sola vez (para FutureBuilder o inicialización)
  Future<QuerySnapshot<Map<String, dynamic>>> getCollectionOnce(String collectionPath, {String? orderByField}) async {
    if (orderByField != null) {
      return _db.collection(collectionPath).orderBy(orderByField).get();
    }
    return _db.collection(collectionPath).get();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getDocument(String collectionPath, String documentId) {
    return _db.collection(collectionPath).doc(documentId).get();
  }

  Future<void> addDocument(String collectionPath, Map<String, dynamic> data) {
    return _db.collection(collectionPath).add(data);
  }

  // setDocument
  Future<void> setDocument(String collectionPath, String documentId, Map<String, dynamic> data) {
    return _db.collection(collectionPath).doc(documentId).set(data);
  }

  Future<void> updateDocument(String collectionPath, String documentId, Map<String, dynamic> data) {
    return _db.collection(collectionPath).doc(documentId).update(data);
  }

  Future<void> deleteDocument(String collectionPath, String documentId) {
    return _db.collection(collectionPath).doc(documentId).delete();
  }
}