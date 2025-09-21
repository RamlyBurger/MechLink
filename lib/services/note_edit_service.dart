import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class NoteEditService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Random _random = Random();

  // Create a new note
  Future<bool> createNote({
    required String jobId,
    required String name,
    required String description,
    required String noteType,
    String status = 'pending',
    List<String> photos = const [],
  }) async {
    try {
      final noteId = _generateNoteId();
      final now = DateTime.now();

      await _firestore.collection('notes').doc(noteId).set({
        'id': noteId,
        'jobId': jobId,
        'name': name,
        'description': description,
        'photos': photos,
        'noteType': noteType,
        'status': status,
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      });

      return true;
    } catch (e) {
      print('Error creating note: $e');
      return false;
    }
  }

  // Update an existing note
  Future<bool> updateNote({
    required String noteId,
    required String name,
    required String description,
    required String noteType,
    required String status,
    List<String> photos = const [],
  }) async {
    try {
      final now = DateTime.now();

      await _firestore.collection('notes').doc(noteId).update({
        'name': name,
        'description': description,
        'photos': photos,
        'noteType': noteType,
        'status': status,
        'updatedAt': now.toIso8601String(),
      });

      return true;
    } catch (e) {
      print('Error updating note: $e');
      return false;
    }
  }

  // Delete a note
  Future<bool> deleteNote(String noteId) async {
    try {
      await _firestore.collection('notes').doc(noteId).delete();
      return true;
    } catch (e) {
      print('Error deleting note: $e');
      return false;
    }
  }

  // Get a single note by ID
  Future<Map<String, dynamic>?> getNoteById(String noteId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('notes')
          .doc(noteId)
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['documentId'] = doc.id;
        return data;
      }
      return null;
    } catch (e) {
      print('Error getting note: $e');
      return null;
    }
  }

  // Get all jobs for the current mechanic (for job selection)
  Future<List<Map<String, dynamic>>> getJobsForMechanic(String mechanicId) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('jobs')
          .where('mechanicId', isEqualTo: mechanicId)
          .get();

      List<Map<String, dynamic>> jobs = querySnapshot.docs
          .map((doc) => {
                'documentId': doc.id,
                'id': doc.id,
                ...doc.data() as Map<String, dynamic>,
              })
          .toList();

      // Sort by assigned date (newest first)
      jobs.sort((a, b) {
        if (a['assignedAt'] != null && b['assignedAt'] != null) {
          return DateTime.parse(b['assignedAt'])
              .compareTo(DateTime.parse(a['assignedAt']));
        }
        return 0;
      });

      return jobs;
    } catch (e) {
      print('Error getting jobs for mechanic: $e');
      return [];
    }
  }

  // Upload photo (placeholder - would integrate with actual image upload service)
  Future<String?> uploadPhoto(String imagePath) async {
    try {
      // This is a placeholder implementation
      // In a real app, you would upload to Firebase Storage or another service
      // For now, return a placeholder URL
      await Future.delayed(const Duration(seconds: 1)); // Simulate upload time
      return 'https://via.placeholder.com/400x300?text=Uploaded+Photo';
    } catch (e) {
      print('Error uploading photo: $e');
      return null;
    }
  }

  // Validate note data
  Map<String, String?> validateNoteData({
    required String name,
    required String description,
    required String noteType,
    required String jobId,
  }) {
    Map<String, String?> errors = {};

    if (name.trim().isEmpty) {
      errors['name'] = 'Note title is required';
    } else if (name.trim().length < 3) {
      errors['name'] = 'Note title must be at least 3 characters';
    } else if (name.trim().length > 100) {
      errors['name'] = 'Note title must be less than 100 characters';
    }

    if (description.trim().isEmpty) {
      errors['description'] = 'Note description is required';
    } else if (description.trim().length < 10) {
      errors['description'] = 'Note description must be at least 10 characters';
    } else if (description.trim().length > 1000) {
      errors['description'] = 'Note description must be less than 1000 characters';
    }

    if (noteType.isEmpty) {
      errors['noteType'] = 'Note type is required';
    }

    if (jobId.isEmpty) {
      errors['jobId'] = 'Job selection is required';
    }

    return errors;
  }

  // Generate a unique note ID
  String _generateNoteId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomSuffix = _random.nextInt(9999).toString().padLeft(4, '0');
    return 'note_${timestamp}_$randomSuffix';
  }
}
