import 'package:cloud_firestore/cloud_firestore.dart';

class JobsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================================
  // SIMPLIFIED JOB DATA RETRIEVAL
  // ============================================================================

  /// Get jobs with essential details only for better performance
  Future<List<Map<String, dynamic>>> getJobsWithDetails({
    String? mechanicId,
    String? status,
    String? priority,
    String? serviceType,
    String? searchQuery,
    String? sortBy,
    bool descending = false,
  }) async {
    try {
      // Get all jobs first
      QuerySnapshot jobSnapshot = await _firestore.collection('jobs').get();

      List<Map<String, dynamic>> jobs = [];

      // Get all customers, vehicles, and equipment in parallel for better performance
      final Future<QuerySnapshot> customersFuture = _firestore
          .collection('customers')
          .get();
      final Future<QuerySnapshot> vehiclesFuture = _firestore
          .collection('vehicles')
          .get();
      final Future<QuerySnapshot> equipmentFuture = _firestore
          .collection('equipment')
          .get();
      final Future<QuerySnapshot> tasksFuture = _firestore
          .collection('tasks')
          .get();

      final results = await Future.wait([
        customersFuture,
        vehiclesFuture,
        equipmentFuture,
        tasksFuture,
      ]);

      // Create lookup maps for faster access
      final Map<String, Map<String, dynamic>> customersMap = {};
      final Map<String, Map<String, dynamic>> vehiclesMap = {};
      final Map<String, Map<String, dynamic>> equipmentMap = {};
      final Map<String, int> taskCountMap = {};

      // Build customers map
      for (var doc in results[0].docs) {
        final data = doc.data() as Map<String, dynamic>;
        customersMap[doc.id] = data;
      }

      // Build vehicles map
      for (var doc in results[1].docs) {
        final data = doc.data() as Map<String, dynamic>;
        vehiclesMap[doc.id] = data;
      }

      // Build equipment map
      for (var doc in results[2].docs) {
        final data = doc.data() as Map<String, dynamic>;
        equipmentMap[doc.id] = data;
      }

      // Build task count map with completed tasks
      final Map<String, int> completedTaskCountMap = {};
      for (var doc in results[3].docs) {
        final data = doc.data() as Map<String, dynamic>;
        final jobId = data['jobId'] as String?;
        final status = data['status'] as String?;
        if (jobId != null) {
          taskCountMap[jobId] = (taskCountMap[jobId] ?? 0) + 1;
          if (status == 'completed') {
            completedTaskCountMap[jobId] =
                (completedTaskCountMap[jobId] ?? 0) + 1;
          }
        }
      }

      // Process each job
      for (var jobDoc in jobSnapshot.docs) {
        Map<String, dynamic> jobData = jobDoc.data() as Map<String, dynamic>;
        jobData['documentId'] = jobDoc.id;

        // Get related data using lookup maps
        final customerId = jobData['customerId'] as String?;
        final vehicleId = jobData['vehicleId'] as String?;
        final equipmentId = jobData['equipmentId'] as String?;

        final customerData = customerId != null
            ? customersMap[customerId]
            : null;
        final vehicleData = vehicleId != null ? vehiclesMap[vehicleId] : null;
        final equipmentData = equipmentId != null
            ? equipmentMap[equipmentId]
            : null;
        final taskCount = taskCountMap[jobDoc.id] ?? 0;
        final completedTaskCount = completedTaskCountMap[jobDoc.id] ?? 0;

        // Get all photos from photos array
        String? assetPhoto;
        List<String> assetPhotos = [];
        if (vehicleData != null && vehicleData['photos'] is List) {
          final photos = vehicleData['photos'] as List;
          assetPhotos = photos.map((photo) => photo.toString()).toList();
          if (photos.isNotEmpty) {
            assetPhoto = photos.first.toString();
          }
        } else if (equipmentData != null && equipmentData['photos'] is List) {
          final photos = equipmentData['photos'] as List;
          assetPhotos = photos.map((photo) => photo.toString()).toList();
          if (photos.isNotEmpty) {
            assetPhoto = photos.first.toString();
          }
        }

        // Create enriched job data
        Map<String, dynamic> enrichedJob = {
          ...jobData,
          'taskCount': taskCount,
          'completedTaskCount': completedTaskCount,
          // Computed fields for display
          'customerName': customerData?['name'] ?? 'Customer',
          'vehicleName': vehicleData != null
              ? '${vehicleData['year']} ${vehicleData['make']} ${vehicleData['model']}'
              : null,
          'equipmentName': equipmentData != null
              ? '${equipmentData['manufacturer']} ${equipmentData['model']}'
              : null,
          'assetName': vehicleData != null
              ? '${vehicleData['year']} ${vehicleData['make']} ${vehicleData['model']}'
              : equipmentData != null
              ? '${equipmentData['manufacturer']} ${equipmentData['model']}'
              : 'No Asset',
          'assetPhoto': assetPhoto,
          'assetPhotos': assetPhotos,
          // Include vehicle/equipment details for search
          'vehicleMake': vehicleData?['make'],
          'vehicleModel': vehicleData?['model'],
          'vehicleYear': vehicleData?['year'],
          'equipmentManufacturer': equipmentData?['manufacturer'],
          'equipmentModel': equipmentData?['model'],
        };

        jobs.add(enrichedJob);
      }

      // Apply filters
      List<Map<String, dynamic>> filteredJobs = jobs;

      // Filter by mechanic ID
      if (mechanicId != null && mechanicId.isNotEmpty) {
        filteredJobs = filteredJobs
            .where((job) => job['mechanicId'] == mechanicId)
            .toList();
      }

      // Filter by status
      if (status != null && status != 'all') {
        filteredJobs = filteredJobs
            .where((job) => job['status'] == status)
            .toList();
      }

      // Filter by priority
      if (priority != null && priority != 'all') {
        filteredJobs = filteredJobs
            .where((job) => job['priority'] == priority)
            .toList();
      }

      // Filter by service type
      if (serviceType != null && serviceType != 'all') {
        filteredJobs = filteredJobs
            .where((job) => job['serviceType'] == serviceType)
            .toList();
      }

      // Filter by search query (job title, customer name, vehicle/equipment details)
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        filteredJobs = filteredJobs.where((job) {
          return (job['title']?.toString().toLowerCase().contains(query) ??
                  false) ||
              (job['customerName']?.toString().toLowerCase().contains(query) ??
                  false) ||
              (job['vehicleMake']?.toString().toLowerCase().contains(query) ??
                  false) ||
              (job['vehicleModel']?.toString().toLowerCase().contains(query) ??
                  false) ||
              (job['vehicleYear']?.toString().contains(query) ?? false) ||
              (job['equipmentManufacturer']?.toString().toLowerCase().contains(
                    query,
                  ) ??
                  false) ||
              (job['equipmentModel']?.toString().toLowerCase().contains(
                    query,
                  ) ??
                  false);
        }).toList();
      }

      // Apply sorting
      if (sortBy != null) {
        filteredJobs.sort((a, b) {
          dynamic aValue = a[sortBy];
          dynamic bValue = b[sortBy];

          // Handle priority sorting specially
          if (sortBy == 'priority') {
            final priorityOrder = {'low': 1, 'medium': 2, 'high': 3};
            aValue = priorityOrder[aValue?.toString().toLowerCase()] ?? 0;
            bValue = priorityOrder[bValue?.toString().toLowerCase()] ?? 0;
          }

          if (aValue == null && bValue == null) return 0;
          if (aValue == null) return descending ? 1 : -1;
          if (bValue == null) return descending ? -1 : 1;

          int comparison;
          if (aValue is String && bValue is String) {
            // Handle date strings
            if (sortBy.contains('At')) {
              try {
                final aDate = DateTime.parse(aValue);
                final bDate = DateTime.parse(bValue);
                comparison = aDate.compareTo(bDate);
              } catch (e) {
                comparison = aValue.compareTo(bValue);
              }
            } else {
              comparison = aValue.compareTo(bValue);
            }
          } else if (aValue is num && bValue is num) {
            comparison = aValue.compareTo(bValue);
          } else {
            comparison = aValue.toString().compareTo(bValue.toString());
          }

          return descending ? -comparison : comparison;
        });
      }

      return filteredJobs;
    } catch (e) {
      print('Error getting jobs with details: $e');
      throw Exception('Failed to get jobs: $e');
    }
  }

  /// Get basic jobs list (lightweight version)
  Future<List<Map<String, dynamic>>> getJobs({
    String? mechanicId,
    String? status,
    String? priority,
    String? searchQuery,
    String? sortBy,
    bool descending = false,
  }) async {
    try {
      QuerySnapshot querySnapshot = await _firestore.collection('jobs').get();

      List<Map<String, dynamic>> jobs = querySnapshot.docs
          .map(
            (doc) => {
              'documentId': doc.id,
              ...doc.data() as Map<String, dynamic>,
            },
          )
          .toList();

      // Apply filters
      List<Map<String, dynamic>> filteredJobs = jobs;

      if (mechanicId != null && mechanicId.isNotEmpty) {
        filteredJobs = filteredJobs
            .where((job) => job['mechanicId'] == mechanicId)
            .toList();
      }

      if (status != null && status != 'all') {
        filteredJobs = filteredJobs
            .where((job) => job['status'] == status)
            .toList();
      }

      if (priority != null && priority != 'all') {
        filteredJobs = filteredJobs
            .where((job) => job['priority'] == priority)
            .toList();
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        filteredJobs = filteredJobs.where((job) {
          return (job['title']?.toString().toLowerCase().contains(query) ??
                  false) ||
              (job['description']?.toString().toLowerCase().contains(query) ??
                  false);
        }).toList();
      }

      // Apply sorting
      if (sortBy != null) {
        filteredJobs.sort((a, b) {
          dynamic aValue = a[sortBy];
          dynamic bValue = b[sortBy];

          if (aValue == null && bValue == null) return 0;
          if (aValue == null) return descending ? 1 : -1;
          if (bValue == null) return descending ? -1 : 1;

          int comparison;
          if (aValue is String && bValue is String) {
            comparison = aValue.compareTo(bValue);
          } else if (aValue is num && bValue is num) {
            comparison = aValue.compareTo(bValue);
          } else {
            comparison = aValue.toString().compareTo(bValue.toString());
          }

          return descending ? -comparison : comparison;
        });
      }

      return filteredJobs;
    } catch (e) {
      print('Error getting jobs: $e');
      throw Exception('Failed to get jobs: $e');
    }
  }

  // ============================================================================
  // FILTERING AND SORTING OPTIONS
  // ============================================================================

  /// Get available filter options
  Map<String, List<String>> getFilterOptions() {
    return {
      'status': [
        'all',
        'assigned',
        'accepted',
        'inProgress',
        'completed',
        'onHold',
        'cancelled',
      ],
      'priority': ['all', 'low', 'medium', 'high'],
      'serviceType': ['all', 'vehicle', 'equipment'],
    };
  }

  /// Get available sort options
  Map<String, String> getSortOptions() {
    return {
      'assignedAt': 'Assigned Date',
      'startedAt': 'Started Date',
      'completedAt': 'Completed Date',
      'priority': 'Priority',
      'taskCount': 'Total Tasks',
    };
  }

  // ============================================================================
  // STATISTICS AND ANALYTICS
  // ============================================================================

  /// Get job statistics for the jobs screen
  Future<Map<String, dynamic>> getJobStatistics({String? mechanicId}) async {
    try {
      List<Map<String, dynamic>> jobs = await getJobs(mechanicId: mechanicId);

      Map<String, int> statusCounts = {};
      Map<String, int> priorityCounts = {};
      Map<String, int> serviceTypeCounts = {};

      for (var job in jobs) {
        // Count by status
        String status = job['status'] ?? 'unknown';
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;

        // Count by priority
        String priority = job['priority'] ?? 'unknown';
        priorityCounts[priority] = (priorityCounts[priority] ?? 0) + 1;

        // Count by service type
        String serviceType = job['serviceType'] ?? 'unknown';
        serviceTypeCounts[serviceType] =
            (serviceTypeCounts[serviceType] ?? 0) + 1;
      }

      return {
        'totalJobs': jobs.length,
        'statusCounts': statusCounts,
        'priorityCounts': priorityCounts,
        'serviceTypeCounts': serviceTypeCounts,
      };
    } catch (e) {
      print('Error getting job statistics: $e');
      throw Exception('Failed to get job statistics: $e');
    }
  }

  // ============================================================================
  // INDIVIDUAL JOB OPERATIONS
  // ============================================================================

  /// Get a single job by ID with full details
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

  /// Update job status
  Future<bool> updateJobStatus(String jobId, String newStatus) async {
    try {
      await _firestore.collection('jobs').doc(jobId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        if (newStatus == 'inProgress')
          'startedAt': FieldValue.serverTimestamp(),
        if (newStatus == 'completed')
          'completedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error updating job status: $e');
      return false;
    }
  }

  /// Get tasks for a specific job
  Future<List<Map<String, dynamic>>> getTasksForJob(String jobId) async {
    try {
      QuerySnapshot taskSnapshot = await _firestore
          .collection('tasks')
          .where('jobId', isEqualTo: jobId)
          .get();

      return taskSnapshot.docs
          .map(
            (doc) => {
              'documentId': doc.id,
              ...doc.data() as Map<String, dynamic>,
            },
          )
          .toList();
    } catch (e) {
      print('Error getting tasks for job: $e');
      throw Exception('Failed to get tasks: $e');
    }
  }

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
}
