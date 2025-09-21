import 'package:cloud_firestore/cloud_firestore.dart';

class NoteDetailService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get complete note details with job information
  Future<Map<String, dynamic>?> getNoteWithDetails(String noteId) async {
    try {
      // Get the note
      DocumentSnapshot noteDoc = await _firestore
          .collection('notes')
          .doc(noteId)
          .get();

      if (!noteDoc.exists) {
        return null;
      }

      Map<String, dynamic> noteData = noteDoc.data() as Map<String, dynamic>;
      noteData['documentId'] = noteDoc.id;

      // Get job details for this note
      final jobId = noteData['jobId'] as String?;
      if (jobId != null) {
        final jobData = await getJobById(jobId);
        if (jobData != null) {
          noteData['job'] = jobData;

          // Get customer details if available
          final customerId = jobData['customerId'] as String?;
          if (customerId != null) {
            final customerData = await getCustomerById(customerId);
            if (customerData != null) {
              noteData['customer'] = customerData;
            }
          }

          // Get vehicle details if available
          final vehicleId = jobData['vehicleId'] as String?;
          if (vehicleId != null) {
            final vehicleData = await getVehicleById(vehicleId);
            if (vehicleData != null) {
              noteData['vehicle'] = vehicleData;
            }
          }

          // Get equipment details if available
          final equipmentId = jobData['equipmentId'] as String?;
          if (equipmentId != null) {
            final equipmentData = await getEquipmentById(equipmentId);
            if (equipmentData != null) {
              noteData['equipment'] = equipmentData;
            }
          }
        }
      }

      return noteData;
    } catch (e) {
      print('Error getting note with details: $e');
      return null;
    }
  }

  // Get job by ID
  Future<Map<String, dynamic>?> getJobById(String jobId) async {
    try {
      DocumentSnapshot jobDoc = await _firestore
          .collection('jobs')
          .doc(jobId)
          .get();

      if (jobDoc.exists) {
        Map<String, dynamic> jobData = jobDoc.data() as Map<String, dynamic>;
        jobData['documentId'] = jobDoc.id;
        return jobData;
      }
      return null;
    } catch (e) {
      print('Error getting job: $e');
      return null;
    }
  }

  // Get customer by ID
  Future<Map<String, dynamic>?> getCustomerById(String customerId) async {
    try {
      DocumentSnapshot customerDoc = await _firestore
          .collection('customers')
          .doc(customerId)
          .get();

      if (customerDoc.exists) {
        Map<String, dynamic> customerData = customerDoc.data() as Map<String, dynamic>;
        customerData['documentId'] = customerDoc.id;
        return customerData;
      }
      return null;
    } catch (e) {
      print('Error getting customer: $e');
      return null;
    }
  }

  // Get vehicle by ID
  Future<Map<String, dynamic>?> getVehicleById(String vehicleId) async {
    try {
      DocumentSnapshot vehicleDoc = await _firestore
          .collection('vehicles')
          .doc(vehicleId)
          .get();

      if (vehicleDoc.exists) {
        Map<String, dynamic> vehicleData = vehicleDoc.data() as Map<String, dynamic>;
        vehicleData['documentId'] = vehicleDoc.id;
        return vehicleData;
      }
      return null;
    } catch (e) {
      print('Error getting vehicle: $e');
      return null;
    }
  }

  // Get equipment by ID
  Future<Map<String, dynamic>?> getEquipmentById(String equipmentId) async {
    try {
      DocumentSnapshot equipmentDoc = await _firestore
          .collection('equipment')
          .doc(equipmentId)
          .get();

      if (equipmentDoc.exists) {
        Map<String, dynamic> equipmentData = equipmentDoc.data() as Map<String, dynamic>;
        equipmentData['documentId'] = equipmentDoc.id;
        return equipmentData;
      }
      return null;
    } catch (e) {
      print('Error getting equipment: $e');
      return null;
    }
  }

  // Update note status
  Future<bool> updateNoteStatus(String noteId, String status) async {
    try {
      await _firestore.collection('notes').doc(noteId).update({
        'status': status,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      print('Error updating note status: $e');
      return false;
    }
  }

  // Delete note
  Future<bool> deleteNote(String noteId) async {
    try {
      await _firestore.collection('notes').doc(noteId).delete();
      return true;
    } catch (e) {
      print('Error deleting note: $e');
      return false;
    }
  }

  // Get related notes for the same job
  Future<List<Map<String, dynamic>>> getRelatedNotes(String jobId, String excludeNoteId) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('notes')
          .where('jobId', isEqualTo: jobId)
          .get();

      List<Map<String, dynamic>> notes = querySnapshot.docs
          .where((doc) => doc.id != excludeNoteId) // Exclude current note
          .map((doc) => {
                'documentId': doc.id,
                'id': doc.id,
                ...doc.data() as Map<String, dynamic>,
              })
          .toList();

      // Sort by creation time (newest first)
      notes.sort((a, b) {
        if (a['createdAt'] != null && b['createdAt'] != null) {
          return DateTime.parse(b['createdAt'])
              .compareTo(DateTime.parse(a['createdAt']));
        }
        return 0;
      });

      return notes;
    } catch (e) {
      print('Error getting related notes: $e');
      return [];
    }
  }
}
