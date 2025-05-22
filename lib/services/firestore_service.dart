// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Método para obtener un stream de una colección (útil para StreamBuilder)
  Stream<QuerySnapshot<Map<String, dynamic>>> getCollectionStream(String path, {String? orderByField, bool descending = false}) {
    if (orderByField != null) {
      return _db.collection(path).orderBy(orderByField, descending: descending).snapshots();
    }
    return _db.collection(path).snapshots();
  }

  // Método para obtener una colección una sola vez (si es necesario)
  Future<QuerySnapshot<Map<String, dynamic>>> getCollectionOnce(String path, {String? orderByField, bool descending = false}) {
    if (orderByField != null) {
      return _db.collection(path).orderBy(orderByField, descending: descending).get();
    }
    return _db.collection(path).get();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getDocument(String collectionPath, String docId) async {
    return await _db.collection(collectionPath).doc(docId).get();
  }

  // Métodos para añadir, actualizar y eliminar (los usaremos en Entrada/Salida)
  Future<void> addDocument(String collectionPath, Map<String, dynamic> data) async {
    await _db.collection(collectionPath).add(data);
  }

  Future<void> updateDocument(String collectionPath, String docId, Map<String, dynamic> data) async {
    await _db.collection(collectionPath).doc(docId).update(data);
  }

  Future<void> deleteDocument(String collectionPath, String docId) async {
    await _db.collection(collectionPath).doc(docId).delete();
  }
}