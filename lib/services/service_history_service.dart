import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class ServiceHistoryService {
  // Private constructor
  ServiceHistoryService._();

  // Singleton instance
  static final ServiceHistoryService _instance = ServiceHistoryService._();

  // Factory constructor to return the singleton instance
  factory ServiceHistoryService() => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get all jobs for a specific asset ID (vehicle or equipment) with their associated tasks
  Future<List<Map<String, dynamic>>> getVehicleServiceHistory(
    String assetId,
  ) async {
    try {
      debugPrint('🔍 Fetching service history for asset: $assetId');

      QuerySnapshot jobsSnapshot;

      try {
        // Try vehicle query first with indexed query
        jobsSnapshot = await _firestore
            .collection('jobs')
            .where('vehicleId', isEqualTo: assetId)
            .orderBy(
              'assignedAt',
              descending: false,
            ) // Changed to ascending (oldest first)
            .get();

        // If no results, try equipment query
        if (jobsSnapshot.docs.isEmpty) {
          jobsSnapshot = await _firestore
              .collection('jobs')
              .where('equipmentId', isEqualTo: assetId)
              .orderBy(
                'assignedAt',
                descending: false,
              ) // Changed to ascending (oldest first)
              .get();
        }
      } catch (indexError) {
        debugPrint('⚠️ Index not available, using fallback query: $indexError');
        // Fallback: Get jobs without ordering for both vehicle and equipment
        jobsSnapshot = await _firestore
            .collection('jobs')
            .where('vehicleId', isEqualTo: assetId)
            .get();

        // If no results, try equipment query
        if (jobsSnapshot.docs.isEmpty) {
          jobsSnapshot = await _firestore
              .collection('jobs')
              .where('equipmentId', isEqualTo: assetId)
              .get();
        }
      }

      List<Map<String, dynamic>> jobsWithTasks = [];

      for (var jobDoc in jobsSnapshot.docs) {
        Map<String, dynamic> jobData = jobDoc.data() as Map<String, dynamic>;
        jobData['id'] = jobDoc.id;

        // Get tasks for this job
        List<Map<String, dynamic>> tasks = await getJobTasks(jobDoc.id);
        jobData['tasks'] = tasks;

        // Get mechanic details
        if (jobData['mechanicId'] != null) {
          Map<String, dynamic>? mechanic = await getMechanicDetails(
            jobData['mechanicId'],
          );
          jobData['mechanic'] = mechanic;
        }

        // Get asset details (vehicle or equipment)
        if (jobData['vehicleId'] != null) {
          Map<String, dynamic>? vehicle = await getVehicleDetails(
            jobData['vehicleId'],
          );
          jobData['vehicle'] = vehicle;
        } else if (jobData['equipmentId'] != null) {
          Map<String, dynamic>? equipment = await getEquipmentDetails(
            jobData['equipmentId'],
          );
          jobData['equipment'] = equipment;
        }

        jobsWithTasks.add(jobData);
      }

      // Sort manually if we used the fallback query
      jobsWithTasks.sort((a, b) {
        try {
          DateTime dateA = DateTime.parse(a['assignedAt'] ?? '');
          DateTime dateB = DateTime.parse(b['assignedAt'] ?? '');
          return dateA.compareTo(dateB); // Ascending order (oldest first)
        } catch (e) {
          return 0;
        }
      });

      debugPrint('✅ Found ${jobsWithTasks.length} jobs with tasks for vehicle');
      return jobsWithTasks;
    } catch (e) {
      debugPrint('❌ Error fetching vehicle service history: $e');
      return [];
    }
  }

  /// Get all tasks for a specific job
  Future<List<Map<String, dynamic>>> getJobTasks(String jobId) async {
    try {
      QuerySnapshot tasksSnapshot = await _firestore
          .collection('tasks')
          .where('jobId', isEqualTo: jobId)
          .orderBy('order', descending: false)
          .get();

      List<Map<String, dynamic>> tasks = tasksSnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();

      return tasks;
    } catch (e) {
      debugPrint('❌ Error fetching tasks for job $jobId: $e');
      return [];
    }
  }

  /// Get mechanic details by ID
  Future<Map<String, dynamic>?> getMechanicDetails(String mechanicId) async {
    try {
      DocumentSnapshot mechanicDoc = await _firestore
          .collection('mechanics')
          .doc(mechanicId)
          .get();

      if (mechanicDoc.exists) {
        Map<String, dynamic> data = mechanicDoc.data() as Map<String, dynamic>;
        data['id'] = mechanicDoc.id;
        return data;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error fetching mechanic details: $e');
      return null;
    }
  }

  /// Get vehicle details by ID
  Future<Map<String, dynamic>?> getVehicleDetails(String vehicleId) async {
    try {
      DocumentSnapshot vehicleDoc = await _firestore
          .collection('vehicles')
          .doc(vehicleId)
          .get();

      if (vehicleDoc.exists) {
        Map<String, dynamic> data = vehicleDoc.data() as Map<String, dynamic>;
        data['id'] = vehicleDoc.id;
        return data;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error fetching vehicle details: $e');
      return null;
    }
  }

  /// Get equipment details by ID
  Future<Map<String, dynamic>?> getEquipmentDetails(String equipmentId) async {
    try {
      DocumentSnapshot equipmentDoc = await _firestore
          .collection('equipment')
          .doc(equipmentId)
          .get();

      if (equipmentDoc.exists) {
        Map<String, dynamic> data = equipmentDoc.data() as Map<String, dynamic>;
        data['id'] = equipmentDoc.id;
        return data;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error fetching equipment details: $e');
      return null;
    }
  }

  /// Get service statistics for the vehicle
  Map<String, dynamic> getServiceStatistics(List<Map<String, dynamic>> jobs) {
    int totalJobs = jobs.length;
    int completedJobs = jobs
        .where((job) => job['status'] == 'completed')
        .length;
    int inProgressJobs = jobs
        .where((job) => job['status'] == 'inProgress')
        .length;
    int pendingJobs = jobs
        .where(
          (job) => job['status'] == 'assigned' || job['status'] == 'pending',
        )
        .length;

    double totalCost = 0.0;
    double totalTime = 0.0;
    int totalTasks = 0;
    int completedTasks = 0;

    for (var job in jobs) {
      // Calculate costs
      if (job['actualCost'] != null) {
        totalCost += (job['actualCost'] as num).toDouble();
      } else if (job['estimatedCost'] != null) {
        totalCost += (job['estimatedCost'] as num).toDouble();
      }

      // Calculate time
      if (job['actualDuration'] != null) {
        totalTime += (job['actualDuration'] as num).toDouble();
      } else if (job['estimatedDuration'] != null) {
        totalTime += (job['estimatedDuration'] as num).toDouble();
      }

      // Count tasks
      List<dynamic> tasks = job['tasks'] ?? [];
      totalTasks += tasks.length;
      completedTasks += tasks
          .where((task) => task['status'] == 'completed')
          .length;
    }

    return {
      'totalJobs': totalJobs,
      'completedJobs': completedJobs,
      'inProgressJobs': inProgressJobs,
      'pendingJobs': pendingJobs,
      'totalCost': totalCost,
      'totalTime': totalTime,
      'totalTasks': totalTasks,
      'completedTasks': completedTasks,
      'taskCompletionRate': totalTasks > 0
          ? (completedTasks / totalTasks * 100)
          : 0.0,
    };
  }
}
