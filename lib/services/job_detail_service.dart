import 'package:cloud_firestore/cloud_firestore.dart';

class JobDetailService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================================
  // COMPREHENSIVE JOB DETAILS
  // ============================================================================

  /// Get complete job details with all related data
  Future<Map<String, dynamic>?> getJobWithCompleteDetails(String jobId) async {
    try {
      // Get the main job document
      DocumentSnapshot jobDoc = await _firestore
          .collection('jobs')
          .doc(jobId)
          .get();

      if (!jobDoc.exists) {
        return null;
      }

      Map<String, dynamic> jobData = jobDoc.data() as Map<String, dynamic>;
      jobData['documentId'] = jobDoc.id;

      // Get customer details if customerId exists
      Map<String, dynamic>? customer;
      if (jobData['customerId'] != null) {
        customer = await getCustomerById(jobData['customerId']);
      }

      // Get vehicle details if vehicleId exists
      Map<String, dynamic>? vehicle;
      if (jobData['vehicleId'] != null) {
        vehicle = await getVehicleById(jobData['vehicleId']);
      }

      // Get equipment details if equipmentId exists
      Map<String, dynamic>? equipment;
      if (jobData['equipmentId'] != null) {
        equipment = await getEquipmentById(jobData['equipmentId']);
      }

      // Get tasks for this job
      List<Map<String, dynamic>> tasks = await getTasksByJobId(jobId);

      // Check if all tasks are completed
      bool allTasksCompleted =
          tasks.isNotEmpty &&
          tasks.every((task) => task['status'] == 'completed');

      // Get task counts
      int totalTasks = tasks.length;
      int completedTasks = tasks
          .where((task) => task['status'] == 'completed')
          .length;

      // Compile complete job details
      return {
        ...jobData,
        'customer': customer,
        'vehicle': vehicle,
        'equipment': equipment,
        'tasks': tasks,
        'totalTasks': totalTasks,
        'completedTasks': completedTasks,
        'allTasksCompleted': allTasksCompleted,
        'assetName': vehicle?['make'] != null && vehicle?['model'] != null
            ? '${vehicle!['make']} ${vehicle!['model']}'
            : equipment?['name'] ?? 'Unknown Asset',
        'customerName': customer?['name'] ?? 'Customer',
      };
    } catch (e) {
      print('Error getting job with complete details: $e');
      throw Exception('Failed to get job details: $e');
    }
  }

  // ============================================================================
  // JOB OPERATIONS
  // ============================================================================

  /// Get a single job by ID
  Future<Map<String, dynamic>?> getJobById(String jobId) async {
    try {
      DocumentSnapshot jobDoc = await _firestore
          .collection('jobs')
          .doc(jobId)
          .get();

      if (!jobDoc.exists) {
        return null;
      }

      Map<String, dynamic> jobData = jobDoc.data() as Map<String, dynamic>;
      jobData['documentId'] = jobDoc.id;

      return jobData;
    } catch (e) {
      print('Error getting job by ID: $e');
      throw Exception('Failed to get job: $e');
    }
  }

  /// Accept a job and assign it to a mechanic
  Future<bool> acceptJob(String jobId, String mechanicId) async {
    try {
      // First check if job is in assigned status
      DocumentSnapshot jobDoc = await _firestore
          .collection('jobs')
          .doc(jobId)
          .get();
      if (!jobDoc.exists) return false;

      Map<String, dynamic> jobData = jobDoc.data() as Map<String, dynamic>;
      if (jobData['status'] != 'assigned') {
        print('Job is not in assigned status, cannot accept');
        return false;
      }

      await _firestore.collection('jobs').doc(jobId).update({
        'status': 'accepted',
        'mechanicId': mechanicId,
        'acceptedAt': DateTime.now().toUtc().toIso8601String(),
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      });
      return true;
    } catch (e) {
      print('Error accepting job: $e');
      return false;
    }
  }

  /// Update job status
  Future<bool> updateJobStatus(String jobId, String newStatus) async {
    try {
      Map<String, dynamic> updateData = {
        'status': newStatus,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      };

      // Add timestamp fields based on status
      switch (newStatus) {
        case 'accepted':
          updateData['acceptedAt'] = DateTime.now().toUtc().toIso8601String();
          break;
        case 'inProgress':
          updateData['startedAt'] = DateTime.now().toUtc().toIso8601String();
          break;
        case 'completed':
          updateData['completedAt'] = DateTime.now().toUtc().toIso8601String();
          break;
        case 'onHold':
          updateData['onHoldAt'] = DateTime.now().toUtc().toIso8601String();
          break;
        case 'cancelled':
          updateData['cancelledAt'] = DateTime.now().toUtc().toIso8601String();
          break;
      }

      await _firestore.collection('jobs').doc(jobId).update(updateData);
      return true;
    } catch (e) {
      print('Error updating job status: $e');
      return false;
    }
  }

  /// Reject/Cancel a job and cancel all its tasks
  Future<bool> rejectJob(String jobId) async {
    try {
      // Update job status to cancelled
      bool jobUpdated = await updateJobStatus(jobId, 'cancelled');
      if (!jobUpdated) return false;

      // Cancel all tasks for this job
      QuerySnapshot tasksSnapshot = await _firestore
          .collection('tasks')
          .where('jobId', isEqualTo: jobId)
          .get();

      WriteBatch batch = _firestore.batch();
      final cancelledAt = DateTime.now().toUtc().toIso8601String();

      for (QueryDocumentSnapshot taskDoc in tasksSnapshot.docs) {
        batch.update(taskDoc.reference, {
          'status': 'cancelled',
          'cancelledAt': cancelledAt,
          'updatedAt': cancelledAt,
        });
      }

      await batch.commit();
      return true;
    } catch (e) {
      print('Error rejecting job: $e');
      return false;
    }
  }

  /// Check if all tasks for a job are completed
  Future<bool> areAllTasksCompleted(String jobId) async {
    try {
      QuerySnapshot tasksSnapshot = await _firestore
          .collection('tasks')
          .where('jobId', isEqualTo: jobId)
          .get();

      if (tasksSnapshot.docs.isEmpty) return false;

      for (QueryDocumentSnapshot taskDoc in tasksSnapshot.docs) {
        Map<String, dynamic> taskData = taskDoc.data() as Map<String, dynamic>;
        if (taskData['status'] != 'completed') {
          return false;
        }
      }

      return true;
    } catch (e) {
      print('Error checking task completion: $e');
      return false;
    }
  }

  /// Validate if status change is allowed
  Future<Map<String, dynamic>> validateStatusChange(
    String jobId,
    String newStatus,
  ) async {
    try {
      DocumentSnapshot jobDoc = await _firestore
          .collection('jobs')
          .doc(jobId)
          .get();
      if (!jobDoc.exists) {
        return {'allowed': false, 'reason': 'Job not found'};
      }

      Map<String, dynamic> jobData = jobDoc.data() as Map<String, dynamic>;
      String currentStatus = jobData['status'] ?? 'assigned';

      // Define allowed status transitions
      Map<String, List<String>> allowedTransitions = {
        'assigned': ['accepted', 'cancelled'],
        'accepted': ['inProgress', 'cancelled'],
        'inProgress': ['completed', 'onHold', 'cancelled'],
        'onHold': ['inProgress', 'cancelled'],
        'completed': [], // No transitions from completed
        'cancelled': [], // No transitions from cancelled
      };

      if (!allowedTransitions[currentStatus]!.contains(newStatus)) {
        return {
          'allowed': false,
          'reason': 'Cannot change status from $currentStatus to $newStatus',
        };
      }

      // Special validation for completed status
      if (newStatus == 'completed') {
        bool allTasksCompleted = await areAllTasksCompleted(jobId);
        if (!allTasksCompleted) {
          return {
            'allowed': false,
            'reason':
                'All tasks must be completed before marking job as completed',
          };
        }

        // Check if digital sign-off exists
        if (jobData['digitalSignOff'] == null) {
          return {
            'allowed': false,
            'reason': 'Digital sign-off is required before completing the job',
          };
        }

        // Check if customer rating exists
        if (jobData['customerRating'] == null) {
          return {
            'allowed': false,
            'reason': 'Customer rating is required before completing the job',
          };
        }
      }

      return {'allowed': true, 'reason': ''};
    } catch (e) {
      print('Error validating status change: $e');
      return {'allowed': false, 'reason': 'Error validating status change'};
    }
  }

  // ============================================================================
  // CUSTOMER OPERATIONS
  // ============================================================================

  /// Get customer by ID
  Future<Map<String, dynamic>?> getCustomerById(String customerId) async {
    try {
      DocumentSnapshot customerDoc = await _firestore
          .collection('customers')
          .doc(customerId)
          .get();

      if (!customerDoc.exists) {
        return null;
      }

      Map<String, dynamic> customerData =
          customerDoc.data() as Map<String, dynamic>;
      customerData['documentId'] = customerDoc.id;

      return customerData;
    } catch (e) {
      print('Error getting customer by ID: $e');
      return null;
    }
  }

  // ============================================================================
  // VEHICLE OPERATIONS
  // ============================================================================

  /// Get vehicle by ID
  Future<Map<String, dynamic>?> getVehicleById(String vehicleId) async {
    try {
      DocumentSnapshot vehicleDoc = await _firestore
          .collection('vehicles')
          .doc(vehicleId)
          .get();

      if (!vehicleDoc.exists) {
        return null;
      }

      Map<String, dynamic> vehicleData =
          vehicleDoc.data() as Map<String, dynamic>;
      vehicleData['documentId'] = vehicleDoc.id;

      return vehicleData;
    } catch (e) {
      print('Error getting vehicle by ID: $e');
      return null;
    }
  }

  // ============================================================================
  // EQUIPMENT OPERATIONS
  // ============================================================================

  /// Get equipment by ID
  Future<Map<String, dynamic>?> getEquipmentById(String equipmentId) async {
    try {
      DocumentSnapshot equipmentDoc = await _firestore
          .collection('equipment')
          .doc(equipmentId)
          .get();

      if (!equipmentDoc.exists) {
        return null;
      }

      Map<String, dynamic> equipmentData =
          equipmentDoc.data() as Map<String, dynamic>;
      equipmentData['documentId'] = equipmentDoc.id;

      return equipmentData;
    } catch (e) {
      print('Error getting equipment by ID: $e');
      return null;
    }
  }

  // ============================================================================
  // TASK OPERATIONS
  // ============================================================================

  /// Get all tasks for a specific job
  Future<List<Map<String, dynamic>>> getTasksByJobId(String jobId) async {
    try {
      QuerySnapshot taskSnapshot = await _firestore
          .collection('tasks')
          .where('jobId', isEqualTo: jobId)
          .get();

      List<Map<String, dynamic>> tasks = taskSnapshot.docs
          .map(
            (doc) => {
              'documentId': doc.id,
              'id': doc.id, // Ensure id field is present
              ...doc.data() as Map<String, dynamic>,
            },
          )
          .toList();

      // Sort by order if available, otherwise by creation time
      tasks.sort((a, b) {
        int orderA = a['order'] ?? 999;
        int orderB = b['order'] ?? 999;
        if (orderA != orderB) {
          return orderA.compareTo(orderB);
        }
        // If orders are the same, sort by creation time
        if (a['createdAt'] != null && b['createdAt'] != null) {
          return a['createdAt'].compareTo(b['createdAt']);
        }
        return 0;
      });

      return tasks;
    } catch (e) {
      print('Error getting tasks for job: $e');
      return [];
    }
  }

  /// Get task statistics for a job
  Future<Map<String, dynamic>> getTaskStatistics(String jobId) async {
    try {
      List<Map<String, dynamic>> tasks = await getTasksByJobId(jobId);

      int totalTasks = tasks.length;
      int completedTasks = tasks
          .where((task) => task['status'] == 'completed')
          .length;
      int inProgressTasks = tasks
          .where((task) => task['status'] == 'inProgress')
          .length;
      int pendingTasks = tasks
          .where((task) => task['status'] == 'pending')
          .length;

      double completionPercentage = totalTasks > 0
          ? (completedTasks / totalTasks) * 100
          : 0;
      bool allTasksCompleted = totalTasks > 0 && completedTasks == totalTasks;

      return {
        'totalTasks': totalTasks,
        'completedTasks': completedTasks,
        'inProgressTasks': inProgressTasks,
        'pendingTasks': pendingTasks,
        'completionPercentage': completionPercentage,
        'allTasksCompleted': allTasksCompleted,
      };
    } catch (e) {
      print('Error getting task statistics: $e');
      return {
        'totalTasks': 0,
        'completedTasks': 0,
        'inProgressTasks': 0,
        'pendingTasks': 0,
        'completionPercentage': 0.0,
        'allTasksCompleted': false,
      };
    }
  }

  // ============================================================================
  // SERVICE REQUEST OPERATIONS
  // ============================================================================

  /// Get service request for a specific job
  Future<Map<String, dynamic>?> getServiceRequestForJob(String jobId) async {
    try {
      QuerySnapshot serviceRequestSnapshot = await _firestore
          .collection('service_requests')
          .where('jobId', isEqualTo: jobId)
          .limit(1)
          .get();

      if (serviceRequestSnapshot.docs.isEmpty) {
        return null;
      }

      var doc = serviceRequestSnapshot.docs.first;
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      data['documentId'] = doc.id;

      return data;
    } catch (e) {
      print('Error getting service request for job: $e');
      return null;
    }
  }

  // ============================================================================
  // NOTES OPERATIONS
  // ============================================================================

  /// Get notes for a specific job (including task-specific notes)
  Future<List<Map<String, dynamic>>> getJobNotes(String jobId) async {
    try {
      // Query notes collection for both job-level and task-level notes
      QuerySnapshot notesSnapshot = await _firestore
          .collection('notes')
          .where('jobId', isEqualTo: jobId)
          .get();

      List<Map<String, dynamic>> notes = notesSnapshot.docs
          .map(
            (doc) => {
              'documentId': doc.id,
              'id': doc.id, // Ensure id field is present
              ...doc.data() as Map<String, dynamic>,
            },
          )
          .toList();

      // Sort by creation time (newest first)
      notes.sort((a, b) {
        if (a['createdAt'] != null && b['createdAt'] != null) {
          return b['createdAt'].compareTo(a['createdAt']);
        }
        return 0;
      });

      return notes;
    } catch (e) {
      print('Error getting job notes: $e');
      return [];
    }
  }

  /// Get notes for a specific task
  Future<List<Map<String, dynamic>>> getTaskNotes(
    String jobId,
    String taskId,
  ) async {
    try {
      QuerySnapshot notesSnapshot = await _firestore
          .collection('notes')
          .where('jobId', isEqualTo: jobId)
          .where('taskId', isEqualTo: taskId)
          .get();

      List<Map<String, dynamic>> notes = notesSnapshot.docs
          .map(
            (doc) => {
              'documentId': doc.id,
              'id': doc.id,
              ...doc.data() as Map<String, dynamic>,
            },
          )
          .toList();

      // Sort by creation time (newest first)
      notes.sort((a, b) {
        if (a['createdAt'] != null && b['createdAt'] != null) {
          return b['createdAt'].compareTo(a['createdAt']);
        }
        return 0;
      });

      return notes;
    } catch (e) {
      print('Error getting task notes: $e');
      return [];
    }
  }

  /// Add a note to a job
  Future<bool> addJobNote(String jobId, String mechanicId, String note) async {
    try {
      await _firestore.collection('job_notes').add({
        'jobId': jobId,
        'mechanicId': mechanicId,
        'note': note,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error adding job note: $e');
      return false;
    }
  }

  // ============================================================================
  // SERVICE HISTORY OPERATIONS
  // ============================================================================

  /// Get service history for a vehicle
  Future<List<Map<String, dynamic>>> getVehicleServiceHistory(
    String vehicleId,
  ) async {
    try {
      QuerySnapshot jobsSnapshot = await _firestore
          .collection('jobs')
          .where('vehicleId', isEqualTo: vehicleId)
          .where('status', isEqualTo: 'completed')
          .orderBy('completedAt', descending: true)
          .get();

      return jobsSnapshot.docs
          .map(
            (doc) => {
              'documentId': doc.id,
              ...doc.data() as Map<String, dynamic>,
            },
          )
          .toList();
    } catch (e) {
      print('Error getting vehicle service history: $e');
      return [];
    }
  }

  /// Get service history for equipment
  Future<List<Map<String, dynamic>>> getEquipmentServiceHistory(
    String equipmentId,
  ) async {
    try {
      QuerySnapshot jobsSnapshot = await _firestore
          .collection('jobs')
          .where('equipmentId', isEqualTo: equipmentId)
          .where('status', isEqualTo: 'completed')
          .orderBy('completedAt', descending: true)
          .get();

      return jobsSnapshot.docs
          .map(
            (doc) => {
              'documentId': doc.id,
              ...doc.data() as Map<String, dynamic>,
            },
          )
          .toList();
    } catch (e) {
      print('Error getting equipment service history: $e');
      return [];
    }
  }

  /// Save digital sign off to job
  Future<bool> saveDigitalSignOff(String jobId, String base64Signature) async {
    try {
      await _firestore.collection('jobs').doc(jobId).update({
        'digitalSignOff': base64Signature,
        'digitalSignOffAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      print('Error saving digital sign off: $e');
      return false;
    }
  }

  /// Save digital sign off with customer rating and feedback
  Future<bool> saveDigitalSignOffWithRating(
    String jobId,
    String base64Signature,
    double customerRating,
    String customerFeedback,
  ) async {
    try {
      Map<String, dynamic> updateData = {
        'digitalSignOff': base64Signature,
        'digitalSignOffAt': DateTime.now().toIso8601String(),
        'customerRating': customerRating,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      // Only add feedback if it's not empty
      if (customerFeedback.isNotEmpty) {
        updateData['customerFeedback'] = customerFeedback;
      }

      await _firestore.collection('jobs').doc(jobId).update(updateData);
      return true;
    } catch (e) {
      print('Error saving digital sign off with rating: $e');
      return false;
    }
  }
}
