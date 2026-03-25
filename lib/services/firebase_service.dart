import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/document_model.dart';

class FirebaseService {
  FirebaseAuth? get _auth {
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  FirebaseFirestore? get _firestore {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  FirebaseStorage? get _storage {
    try {
      return FirebaseStorage.instance;
    } catch (_) {
      return null;
    }
  }

  // Authentication
  Future<User?> signInAnonymously() async {
    try {
      final userCredential = await _auth!.signInAnonymously();
      return userCredential.user;
    } catch (e) {
      print("Auth error: $e");
      return null;
    }
  }

  User? get currentUser => _auth?.currentUser;

  // Firestore & Storage
  Future<DocumentModel> saveDocument({
    required Uint8List imageBytes,
    required String fileName,
    required Map<String, dynamic> aiData,
  }) async {
    if (_storage == null || _firestore == null) {
      throw Exception('Firebase is not configured.');
    }
    final userId = currentUser?.uid ?? 'local_user';
    final uploadedFileName =
        '${DateTime.now().millisecondsSinceEpoch}_$fileName';
    final storageRef = _storage!
        .ref()
        .child('documents')
        .child(userId)
        .child(uploadedFileName);

    // Upload Image
    await storageRef.putData(
      imageBytes,
      SettableMetadata(contentType: _inferContentType(fileName)),
    );
    final imageUrl = await storageRef.getDownloadURL();

    // Save metadata
    final docRef = _firestore!
        .collection('users')
        .doc(userId)
        .collection('documents')
        .doc();

    final document = DocumentModel(
      id: docRef.id,
      userId: userId,
      imageUrl: imageUrl,
      documentType: aiData['documentType'] ?? 'Other',
      totalAmount: aiData['totalAmount'] != null
          ? (aiData['totalAmount'] as num).toDouble()
          : null,
      keyDate: aiData['keyDate'],
      summary: aiData['summary'] ?? '',
      createdAt: DateTime.now(),
    );

    await docRef.set(document.toMap());
    return document;
  }

  String _inferContentType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Stream<List<DocumentModel>> get userDocuments {
    final userId = currentUser?.uid;
    if (userId == null || _firestore == null) return const Stream.empty();

    return _firestore!
        .collection('users')
        .doc(userId)
        .collection('documents')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DocumentModel.fromMap(doc.data(), doc.id))
            .toList());
  }
}
