import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================================
  // JOB STATISTICS OVERVIEW
  // ============================================================================

  /// Get job statistics by status
  Future<Map<String, int>> getJobStatistics({String? mechanicId}) async {
    try {
      Query query = _firestore.collection('jobs');

      // Filter by mechanic ID if provided
      if (mechanicId != null && mechanicId.isNotEmpty) {
        query = query.where('mechanicId', isEqualTo: mechanicId);
      }

      final QuerySnapshot snapshot = await query.get();

      Map<String, int> statistics = {
        'total': 0,
        'assigned': 0,
        'accepted': 0,
        'inProgress': 0,
        'completed': 0,
        'onHold': 0,
        'cancelled': 0,
      };

      statistics['total'] = snapshot.docs.length;

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final status = data['status'] as String? ?? 'assigned';

        switch (status) {
          case 'assigned':
            statistics['assigned'] = (statistics['assigned'] ?? 0) + 1;
            break;
          case 'accepted':
            statistics['accepted'] = (statistics['accepted'] ?? 0) + 1;
            break;
          case 'inProgress':
            statistics['inProgress'] = (statistics['inProgress'] ?? 0) + 1;
            break;
          case 'completed':
            statistics['completed'] = (statistics['completed'] ?? 0) + 1;
            break;
          case 'onHold':
            statistics['onHold'] = (statistics['onHold'] ?? 0) + 1;
            break;
          case 'cancelled':
            statistics['cancelled'] = (statistics['cancelled'] ?? 0) + 1;
            break;
        }
      }

      return statistics;
    } catch (e) {
      throw Exception('Failed to get job statistics: $e');
    }
  }

  // ============================================================================
  // JOB PRIORITY DISTRIBUTION
  // ============================================================================

  /// Get job priority distribution with counts and percentages
  Future<Map<String, dynamic>> getJobPriorityDistribution({
    String? mechanicId,
  }) async {
    try {
      Query query = _firestore.collection('jobs');

      // Filter by mechanic ID if provided
      if (mechanicId != null && mechanicId.isNotEmpty) {
        query = query.where('mechanicId', isEqualTo: mechanicId);
      }

      final QuerySnapshot snapshot = await query.get();

      Map<String, int> priorityCounts = {'high': 0, 'medium': 0, 'low': 0};

      final totalJobs = snapshot.docs.length;

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final priority = data['priority'] as String? ?? 'medium';
        priorityCounts[priority] = (priorityCounts[priority] ?? 0) + 1;
      }

      // Calculate percentages
      Map<String, dynamic> distribution = {};
      priorityCounts.forEach((priority, count) {
        distribution[priority] = {
          'count': count,
          'percentage': totalJobs > 0 ? (count / totalJobs * 100).round() : 0,
        };
      });

      return distribution;
    } catch (e) {
      throw Exception('Failed to get priority distribution: $e');
    }
  }

  // ============================================================================
  // SERVICE TYPE ANALYSIS
  // ============================================================================

  /// Get service type breakdown (vehicle vs equipment)
  Future<Map<String, dynamic>> getServiceTypeBreakdown({
    String? mechanicId,
  }) async {
    try {
      Query query = _firestore.collection('jobs');

      // Filter by mechanic ID if provided
      if (mechanicId != null && mechanicId.isNotEmpty) {
        query = query.where('mechanicId', isEqualTo: mechanicId);
      }

      final QuerySnapshot snapshot = await query.get();

      Map<String, int> serviceTypeCounts = {'vehicle': 0, 'equipment': 0};

      final totalJobs = snapshot.docs.length;

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final serviceType = data['serviceType'] as String? ?? 'vehicle';
        serviceTypeCounts[serviceType] =
            (serviceTypeCounts[serviceType] ?? 0) + 1;
      }

      // Calculate percentages
      Map<String, dynamic> breakdown = {};
      serviceTypeCounts.forEach((type, count) {
        breakdown[type] = {
          'count': count,
          'percentage': totalJobs > 0 ? (count / totalJobs * 100).round() : 0,
        };
      });

      return breakdown;
    } catch (e) {
      throw Exception('Failed to get service type breakdown: $e');
    }
  }

  // ============================================================================
  // TIME PERFORMANCE METRICS
  // ============================================================================

  /// Get time performance metrics comparing estimated vs actual duration
  Future<Map<String, dynamic>> getTimePerformanceMetrics({
    String? mechanicId,
  }) async {
    try {
      Query query = _firestore.collection('jobs');

      // Filter by mechanic ID if provided
      if (mechanicId != null && mechanicId.isNotEmpty) {
        query = query.where('mechanicId', isEqualTo: mechanicId);
      }

      final QuerySnapshot snapshot = await query.get();

      double totalEstimatedHours = 0;
      double totalActualHours = 0;
      int jobsWithBothTimes = 0;
      int jobsWithinEstimate = 0;
      int jobsOverEstimate = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final estimatedDuration = data['estimatedDuration']?.toDouble();
        final actualDuration = data['actualDuration']?.toDouble();

        if (estimatedDuration != null) {
          totalEstimatedHours += estimatedDuration;
        }

        if (actualDuration != null) {
          totalActualHours += actualDuration;
        }

        if (estimatedDuration != null && actualDuration != null) {
          jobsWithBothTimes++;
          if (actualDuration <= estimatedDuration) {
            jobsWithinEstimate++;
          } else {
            jobsOverEstimate++;
          }
        }
      }

      final timeVariance = totalActualHours - totalEstimatedHours;
      final timeVariancePercentage = totalEstimatedHours > 0
          ? (timeVariance / totalEstimatedHours * 100)
          : 0;
      final averageJobDuration =
          totalActualHours > 0 && snapshot.docs.isNotEmpty
          ? totalActualHours / snapshot.docs.length
          : 0;

      return {
        'totalEstimatedHours': totalEstimatedHours,
        'totalActualHours': totalActualHours,
        'timeVariance': timeVariance,
        'timeVariancePercentage': timeVariancePercentage,
        'averageJobDuration': averageJobDuration,
        'jobsWithinEstimate': jobsWithinEstimate,
        'jobsOverEstimate': jobsOverEstimate,
        'totalJobsWithTimes': jobsWithBothTimes,
        'withinEstimatePercentage': jobsWithBothTimes > 0
            ? (jobsWithinEstimate / jobsWithBothTimes * 100).round()
            : 0,
        'overEstimatePercentage': jobsWithBothTimes > 0
            ? (jobsOverEstimate / jobsWithBothTimes * 100).round()
            : 0,
      };
    } catch (e) {
      throw Exception('Failed to get time performance metrics: $e');
    }
  }

  // ============================================================================
  // COST ANALYSIS
  // ============================================================================

  /// Get cost analysis comparing estimated vs actual costs
  Future<Map<String, dynamic>> getCostAnalysis({String? mechanicId}) async {
    try {
      Query query = _firestore.collection('jobs');

      // Filter by mechanic ID if provided
      if (mechanicId != null && mechanicId.isNotEmpty) {
        query = query.where('mechanicId', isEqualTo: mechanicId);
      }

      final QuerySnapshot snapshot = await query.get();

      double totalEstimatedCost = 0;
      double totalActualCost = 0;
      int jobsWithBothCosts = 0;
      int jobsUnderBudget = 0;
      int jobsOverBudget = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final estimatedCost = data['estimatedCost']?.toDouble();
        final actualCost = data['actualCost']?.toDouble();

        if (estimatedCost != null) {
          totalEstimatedCost += estimatedCost;
        }

        if (actualCost != null) {
          totalActualCost += actualCost;
        }

        if (estimatedCost != null && actualCost != null) {
          jobsWithBothCosts++;
          if (actualCost <= estimatedCost) {
            jobsUnderBudget++;
          } else {
            jobsOverBudget++;
          }
        }
      }

      final costVariance = totalActualCost - totalEstimatedCost;
      final costVariancePercentage = totalEstimatedCost > 0
          ? (costVariance / totalEstimatedCost * 100)
          : 0;
      final averageJobCost = totalActualCost > 0 && snapshot.docs.isNotEmpty
          ? totalActualCost / snapshot.docs.length
          : 0;

      return {
        'totalEstimatedCost': totalEstimatedCost,
        'totalActualCost': totalActualCost,
        'costVariance': costVariance,
        'costVariancePercentage': costVariancePercentage,
        'averageJobCost': averageJobCost,
        'jobsUnderBudget': jobsUnderBudget,
        'jobsOverBudget': jobsOverBudget,
        'totalJobsWithCosts': jobsWithBothCosts,
        'underBudgetPercentage': jobsWithBothCosts > 0
            ? (jobsUnderBudget / jobsWithBothCosts * 100).round()
            : 0,
        'overBudgetPercentage': jobsWithBothCosts > 0
            ? (jobsOverBudget / jobsWithBothCosts * 100).round()
            : 0,
      };
    } catch (e) {
      throw Exception('Failed to get cost analysis: $e');
    }
  }

  // ============================================================================
  // TASK ANALYTICS
  // ============================================================================

  /// Get task performance analytics
  Future<Map<String, dynamic>> getTaskAnalytics({String? mechanicId}) async {
    try {
      // For tasks, we need to filter by jobs that belong to the mechanic
      List<String> jobIds = [];
      if (mechanicId != null && mechanicId.isNotEmpty) {
        final jobSnapshot = await _firestore
            .collection('jobs')
            .where('mechanicId', isEqualTo: mechanicId)
            .get();
        jobIds = jobSnapshot.docs.map((doc) => doc.id).toList();
      }

      final QuerySnapshot snapshot = await _firestore.collection('tasks').get();

      Map<String, int> taskStatusCounts = {
        'completed': 0,
        'inProgress': 0,
        'pending': 0,
      };

      double totalEstimatedTime = 0;
      double totalActualTime = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;

        // Filter by mechanic's jobs if mechanicId is provided
        if (mechanicId != null && mechanicId.isNotEmpty) {
          final taskJobId = data?['jobId'] as String?;
          if (taskJobId == null || !jobIds.contains(taskJobId)) {
            continue;
          }
        }

        final status = data?['status'] as String? ?? 'pending';
        final estimatedTime = data?['estimatedTime']?.toDouble();
        final actualTime = data?['actualTime']?.toDouble();

        taskStatusCounts[status] = (taskStatusCounts[status] ?? 0) + 1;

        if (estimatedTime != null) {
          totalEstimatedTime += estimatedTime;
        }

        if (actualTime != null) {
          totalActualTime += actualTime;
        }
      }

      final totalTasks = snapshot.docs.length;
      final timeVariance = totalActualTime - totalEstimatedTime;
      final timeVariancePercentage = totalEstimatedTime > 0
          ? (timeVariance / totalEstimatedTime * 100)
          : 0;
      final averageEstimatedTime = totalEstimatedTime > 0 && totalTasks > 0
          ? totalEstimatedTime / totalTasks
          : 0;
      final averageActualTime = totalActualTime > 0 && totalTasks > 0
          ? totalActualTime / totalTasks
          : 0;

      return {
        'totalTasks': totalTasks,
        'completedTasks': taskStatusCounts['completed'] ?? 0,
        'inProgressTasks': taskStatusCounts['inProgress'] ?? 0,
        'pendingTasks': taskStatusCounts['pending'] ?? 0,
        'completedPercentage': totalTasks > 0
            ? ((taskStatusCounts['completed'] ?? 0) / totalTasks * 100).round()
            : 0,
        'inProgressPercentage': totalTasks > 0
            ? ((taskStatusCounts['inProgress'] ?? 0) / totalTasks * 100).round()
            : 0,
        'pendingPercentage': totalTasks > 0
            ? ((taskStatusCounts['pending'] ?? 0) / totalTasks * 100).round()
            : 0,
        'averageEstimatedTime': averageEstimatedTime,
        'averageActualTime': averageActualTime,
        'timeVariance': timeVariance,
        'timeVariancePercentage': timeVariancePercentage,
      };
    } catch (e) {
      throw Exception('Failed to get task analytics: $e');
    }
  }

  // ============================================================================
  // NOTES & ISSUES ANALYSIS
  // ============================================================================

  /// Get notes and issues analysis
  Future<Map<String, dynamic>> getNotesAnalysis({String? mechanicId}) async {
    try {
      // For notes, we need to filter by jobs that belong to the mechanic
      List<String> jobIds = [];
      if (mechanicId != null && mechanicId.isNotEmpty) {
        final jobSnapshot = await _firestore
            .collection('jobs')
            .where('mechanicId', isEqualTo: mechanicId)
            .get();
        jobIds = jobSnapshot.docs.map((doc) => doc.id).toList();
      }

      final QuerySnapshot snapshot = await _firestore.collection('notes').get();

      Map<String, int> noteTypeCounts = {
        'problem': 0,
        'request': 0,
        'completion': 0,
      };

      Map<String, int> noteStatusCounts = {
        'pending': 0,
        'solved': 0,
        'completed': 0,
      };

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        // Filter by mechanic's jobs if mechanicId is provided
        if (mechanicId != null && mechanicId.isNotEmpty) {
          final noteJobId = data['jobId'] as String?;
          if (noteJobId == null || !jobIds.contains(noteJobId)) {
            continue;
          }
        }

        final noteType = data['noteType'] as String? ?? 'request';
        final noteStatus = data['status'] as String? ?? 'pending';

        noteTypeCounts[noteType] = (noteTypeCounts[noteType] ?? 0) + 1;
        noteStatusCounts[noteStatus] = (noteStatusCounts[noteStatus] ?? 0) + 1;
      }

      final totalNotes = snapshot.docs.length;
      final resolvedNotes =
          (noteStatusCounts['accepted'] ?? 0) +
          (noteStatusCounts['solved'] ?? 0);
      final resolutionRate = totalNotes > 0
          ? (resolvedNotes / totalNotes * 100).round()
          : 0;

      return {
        'totalNotes': totalNotes,
        'problemNotes': noteTypeCounts['problem'] ?? 0,
        'requestNotes': noteTypeCounts['request'] ?? 0,
        'completionNotes': noteTypeCounts['completion'] ?? 0,
        'pendingNotes': noteStatusCounts['pending'] ?? 0,
        'solvedNotes': noteStatusCounts['solved'] ?? 0,
        'acceptedNotes': noteStatusCounts['accepted'] ?? 0,
        'resolutionRate': resolutionRate,
        'problemPercentage': totalNotes > 0
            ? ((noteTypeCounts['problem'] ?? 0) / totalNotes * 100).round()
            : 0,
        'requestPercentage': totalNotes > 0
            ? ((noteTypeCounts['request'] ?? 0) / totalNotes * 100).round()
            : 0,
      };
    } catch (e) {
      throw Exception('Failed to get notes analysis: $e');
    }
  }

  // ============================================================================
  // TIMELINE ANALYTICS
  // ============================================================================

  /// Get timeline analytics for job progression
  Future<Map<String, dynamic>> getTimelineAnalytics({
    String? mechanicId,
  }) async {
    try {
      Query query = _firestore.collection('jobs');

      // Filter by mechanic ID if provided
      if (mechanicId != null && mechanicId.isNotEmpty) {
        query = query.where('mechanicId', isEqualTo: mechanicId);
      }

      final QuerySnapshot snapshot = await query.get();

      List<double> assignedToStartedDays = [];
      List<double> startedToCompletedDays = [];

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final thisWeekStart = today.subtract(Duration(days: today.weekday - 1));

      int jobsStartedToday = 0;
      int jobsCompletedToday = 0;
      int jobsAssignedThisWeek = 0;
      int jobsCompletedThisWeek = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        final assignedAt = data['assignedAt'] != null
            ? DateTime.parse(data['assignedAt'])
            : null;
        final startedAt = data['startedAt'] != null
            ? DateTime.parse(data['startedAt'])
            : null;
        final completedAt = data['completedAt'] != null
            ? DateTime.parse(data['completedAt'])
            : null;

        // Calculate time differences
        if (assignedAt != null && startedAt != null) {
          final daysDiff = startedAt.difference(assignedAt).inDays.toDouble();
          assignedToStartedDays.add(daysDiff);
        }

        if (startedAt != null && completedAt != null) {
          final daysDiff = completedAt.difference(startedAt).inDays.toDouble();
          startedToCompletedDays.add(daysDiff);
        }

        // Count today's activities
        if (startedAt != null && _isSameDay(startedAt, today)) {
          jobsStartedToday++;
        }

        if (completedAt != null && _isSameDay(completedAt, today)) {
          jobsCompletedToday++;
        }

        // Count this week's activities
        if (assignedAt != null && assignedAt.isAfter(thisWeekStart)) {
          jobsAssignedThisWeek++;
        }

        if (completedAt != null && completedAt.isAfter(thisWeekStart)) {
          jobsCompletedThisWeek++;
        }
      }

      final averageAssignedToStarted = assignedToStartedDays.isNotEmpty
          ? assignedToStartedDays.reduce((a, b) => a + b) /
                assignedToStartedDays.length
          : 0;

      final averageStartedToCompleted = startedToCompletedDays.isNotEmpty
          ? startedToCompletedDays.reduce((a, b) => a + b) /
                startedToCompletedDays.length
          : 0;

      return {
        'averageAssignedToStartedDays': averageAssignedToStarted,
        'averageStartedToCompletedDays': averageStartedToCompleted,
        'jobsStartedToday': jobsStartedToday,
        'jobsCompletedToday': jobsCompletedToday,
        'jobsAssignedThisWeek': jobsAssignedThisWeek,
        'jobsCompletedThisWeek': jobsCompletedThisWeek,
      };
    } catch (e) {
      throw Exception('Failed to get timeline analytics: $e');
    }
  }

  // ============================================================================
  // PARTS USAGE ANALYSIS
  // ============================================================================

  /// Get parts usage analysis from job parts lists
  Future<Map<String, dynamic>> getPartsAnalysis({String? mechanicId}) async {
    try {
      Query query = _firestore.collection('jobs');

      // Filter by mechanic ID if provided
      if (mechanicId != null && mechanicId.isNotEmpty) {
        query = query.where('mechanicId', isEqualTo: mechanicId);
      }

      final QuerySnapshot snapshot = await query.get();

      Map<String, int> partsCounts = {};
      int totalPartsUsed = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final parts = data['parts'] as List<dynamic>? ?? [];

        totalPartsUsed += parts.length;

        for (var part in parts) {
          final partName = part.toString();
          partsCounts[partName] = (partsCounts[partName] ?? 0) + 1;
        }
      }

      // Sort parts by usage count
      final sortedParts = partsCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final topParts = sortedParts.take(10).toList();
      final totalJobs = snapshot.docs.length;
      final averagePartsPerJob = totalJobs > 0 ? totalPartsUsed / totalJobs : 0;

      return {
        'totalPartTypes': partsCounts.length,
        'totalPartsUsed': totalPartsUsed,
        'averagePartsPerJob': averagePartsPerJob,
        'topParts': topParts
            .map((entry) => {'name': entry.key, 'count': entry.value})
            .toList(),
      };
    } catch (e) {
      throw Exception('Failed to get parts analysis: $e');
    }
  }

  // ============================================================================
  // VEHICLE ANALYTICS
  // ============================================================================

  /// Get vehicle analytics
  Future<Map<String, dynamic>> getVehicleAnalytics({String? mechanicId}) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('vehicles')
          .get();

      Map<String, int> makesCounts = {};
      List<int> years = [];
      List<int> mileages = [];

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final make = data['make'] as String? ?? 'Unknown';
        final year = data['year'] as int? ?? 0;
        final mileage = data['mileage'] as int? ?? 0;

        makesCounts[make] = (makesCounts[make] ?? 0) + 1;

        if (year > 0) years.add(year);
        if (mileage > 0) mileages.add(mileage);
      }

      // Sort makes by count
      final sortedMakes = makesCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final totalVehicles = snapshot.docs.length;
      final averageYear = years.isNotEmpty
          ? (years.reduce((a, b) => a + b) / years.length).round()
          : 0;
      final oldestYear = years.isNotEmpty
          ? years.reduce((a, b) => a < b ? a : b)
          : 0;
      final newestYear = years.isNotEmpty
          ? years.reduce((a, b) => a > b ? a : b)
          : 0;
      final averageMileage = mileages.isNotEmpty
          ? (mileages.reduce((a, b) => a + b) / mileages.length).round()
          : 0;

      return {
        'totalVehicles': totalVehicles,
        'averageYear': averageYear,
        'oldestYear': oldestYear,
        'newestYear': newestYear,
        'averageMileage': averageMileage,
        'topMakes': sortedMakes
            .take(5)
            .map((entry) => {'make': entry.key, 'count': entry.value})
            .toList(),
      };
    } catch (e) {
      throw Exception('Failed to get vehicle analytics: $e');
    }
  }

  // ============================================================================
  // EQUIPMENT ANALYTICS
  // ============================================================================

  /// Get equipment analytics
  Future<Map<String, dynamic>> getEquipmentAnalytics({
    String? mechanicId,
  }) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('equipment')
          .get();

      Map<String, int> categoryCounts = {};
      Map<String, int> conditionCounts = {};
      Map<String, int> manufacturerCounts = {};
      List<int> years = [];

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final category = data['category'] as String? ?? 'Unknown';
        final condition = data['condition'] as String? ?? 'Unknown';
        final manufacturer = data['manufacturer'] as String? ?? 'Unknown';
        final year = data['year'] as int? ?? 0;

        categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
        conditionCounts[condition] = (conditionCounts[condition] ?? 0) + 1;
        manufacturerCounts[manufacturer] =
            (manufacturerCounts[manufacturer] ?? 0) + 1;

        if (year > 0) years.add(year);
      }

      final totalEquipment = snapshot.docs.length;
      final averageYear = years.isNotEmpty
          ? (years.reduce((a, b) => a + b) / years.length).round()
          : 0;

      return {
        'totalEquipment': totalEquipment,
        'averageYear': averageYear,
        'categories': categoryCounts,
        'conditions': conditionCounts,
        'topManufacturers': manufacturerCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)),
      };
    } catch (e) {
      throw Exception('Failed to get equipment analytics: $e');
    }
  }

  // ============================================================================
  // CUSTOMER INSIGHTS
  // ============================================================================

  /// Get customer insights and analytics
  Future<Map<String, dynamic>> getCustomerInsights({String? mechanicId}) async {
    try {
      final customerSnapshot = await _firestore.collection('customers').get();
      Query jobQuery = _firestore.collection('jobs');

      // Filter by mechanic ID if provided
      if (mechanicId != null && mechanicId.isNotEmpty) {
        jobQuery = jobQuery.where('mechanicId', isEqualTo: mechanicId);
      }

      final jobSnapshot = await jobQuery.get();

      final totalCustomers = customerSnapshot.docs.length;
      Map<String, int> customerJobCounts = {};

      final thisMonth = DateTime.now().subtract(const Duration(days: 30));
      int newCustomersThisMonth = 0;

      // Count jobs per customer
      for (var jobDoc in jobSnapshot.docs) {
        final jobData = jobDoc.data() as Map<String, dynamic>?;
        final customerId = jobData?['customerId'] as String? ?? '';

        if (customerId.isNotEmpty) {
          customerJobCounts[customerId] =
              (customerJobCounts[customerId] ?? 0) + 1;
        }
      }

      // Count new customers this month
      for (var customerDoc in customerSnapshot.docs) {
        final customerData = customerDoc.data() as Map<String, dynamic>?;
        final createdAt = customerData?['createdAt'] != null
            ? DateTime.parse(customerData?['createdAt'])
            : null;

        if (createdAt != null && createdAt.isAfter(thisMonth)) {
          newCustomersThisMonth++;
        }
      }

      final customersWithMultipleJobs = customerJobCounts.values
          .where((count) => count > 1)
          .length;
      final totalJobs = customerJobCounts.values.fold(
        0,
        (sum, count) => sum + count,
      );
      final averageJobsPerCustomer = totalCustomers > 0
          ? totalJobs / totalCustomers
          : 0;
      final maxJobsPerCustomer = customerJobCounts.values.isNotEmpty
          ? customerJobCounts.values.reduce((a, b) => a > b ? a : b)
          : 0;
      final retentionRate = totalCustomers > 0
          ? (customersWithMultipleJobs / totalCustomers * 100).round()
          : 0;

      return {
        'totalCustomers': totalCustomers,
        'customersWithMultipleJobs': customersWithMultipleJobs,
        'newCustomersThisMonth': newCustomersThisMonth,
        'averageJobsPerCustomer': averageJobsPerCustomer,
        'maxJobsPerCustomer': maxJobsPerCustomer,
        'retentionRate': retentionRate,
      };
    } catch (e) {
      throw Exception('Failed to get customer insights: $e');
    }
  }

  // ============================================================================
  // MECHANIC PERFORMANCE
  // ============================================================================

  /// Get mechanic performance metrics for a specific mechanic
  Future<Map<String, dynamic>> getMechanicPerformance(String mechanicId) async {
    try {
      final jobSnapshot = await _firestore
          .collection('jobs')
          .where('mechanicId', isEqualTo: mechanicId)
          .get();

      final mechanicSnapshot = await _firestore
          .collection('mechanics')
          .doc(mechanicId)
          .get();

      final mechanicData = mechanicSnapshot.data() ?? {};

      int assignedJobs = 0;
      int completedJobs = 0;
      double totalEstimatedTime = 0;
      double totalActualTime = 0;
      int jobsWithBothTimes = 0;

      for (var doc in jobSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        final status = data?['status'] as String? ?? 'assigned';

        assignedJobs++;

        if (status == 'completed') {
          completedJobs++;
        }

        final estimatedDuration = data?['estimatedDuration']?.toDouble();
        final actualDuration = data?['actualDuration']?.toDouble();

        if (estimatedDuration != null) {
          totalEstimatedTime += estimatedDuration;
        }

        if (actualDuration != null) {
          totalActualTime += actualDuration;
        }

        if (estimatedDuration != null && actualDuration != null) {
          jobsWithBothTimes++;
        }
      }

      final efficiency = jobsWithBothTimes > 0 && totalEstimatedTime > 0
          ? ((totalEstimatedTime / totalActualTime) * 100).round()
          : 0;

      return {
        'assignedJobs': assignedJobs,
        'completedJobs': completedJobs,
        'efficiency': efficiency,
        'specialization': mechanicData['specialization'] ?? 'N/A',
        'department': mechanicData['department'] ?? 'N/A',
        'completionRate': assignedJobs > 0
            ? (completedJobs / assignedJobs * 100).round()
            : 0,
      };
    } catch (e) {
      throw Exception('Failed to get mechanic performance: $e');
    }
  }

  // ============================================================================
  // DIGITAL SIGNOFF ANALYTICS
  // ============================================================================

  /// Get digital signoff status analytics
  Future<Map<String, dynamic>> getDigitalSignoffAnalytics({
    String? mechanicId,
  }) async {
    try {
      Query query = _firestore.collection('jobs');

      // Filter by mechanic ID if provided
      if (mechanicId != null && mechanicId.isNotEmpty) {
        query = query.where('mechanicId', isEqualTo: mechanicId);
      }

      final QuerySnapshot snapshot = await query.get();

      int jobsWithSignoff = 0;
      int jobsPendingSignoff = 0;
      List<double> daysToSignoff = [];

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final digitalSignOff = data['digitalSignOff'] as String?;
        final completedAt = data['completedAt'] != null
            ? DateTime.parse(data['completedAt'])
            : null;
        final digitalSignOffAt = data['digitalSignOffAt'] != null
            ? DateTime.parse(data['digitalSignOffAt'])
            : null;

        if (digitalSignOff != null && digitalSignOff.isNotEmpty) {
          jobsWithSignoff++;

          if (completedAt != null && digitalSignOffAt != null) {
            final daysDiff = digitalSignOffAt
                .difference(completedAt)
                .inDays
                .toDouble();
            daysToSignoff.add(daysDiff);
          }
        } else if (completedAt != null) {
          jobsPendingSignoff++;
        }
      }

      final totalJobs = snapshot.docs.length;
      final signoffRate = totalJobs > 0
          ? (jobsWithSignoff / totalJobs * 100).round()
          : 0;
      final averageDaysToSignoff = daysToSignoff.isNotEmpty
          ? daysToSignoff.reduce((a, b) => a + b) / daysToSignoff.length
          : 0;

      return {
        'jobsWithSignoff': jobsWithSignoff,
        'jobsPendingSignoff': jobsPendingSignoff,
        'signoffRate': signoffRate,
        'averageDaysToSignoff': averageDaysToSignoff,
      };
    } catch (e) {
      throw Exception('Failed to get digital signoff analytics: $e');
    }
  }

  // ============================================================================
  // CUSTOMER SATISFACTION ANALYTICS
  // ============================================================================

  /// Get customer satisfaction metrics based on job ratings
  Future<Map<String, dynamic>> getCustomerSatisfactionAnalytics({
    String? mechanicId,
  }) async {
    try {
      Query query = _firestore.collection('jobs');

      // Filter by mechanic ID if provided
      if (mechanicId != null && mechanicId.isNotEmpty) {
        query = query.where('mechanicId', isEqualTo: mechanicId);
      }

      final QuerySnapshot snapshot = await query.get();

      List<double> ratings = [];
      Map<String, int> ratingDistribution = {
        '1': 0,
        '2': 0,
        '3': 0,
        '4': 0,
        '5': 0,
      };

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        final rating = data?['customerRating']?.toDouble();

        if (rating != null && rating >= 1.0 && rating <= 5.0) {
          ratings.add(rating);
          final roundedRating = rating.round();
          final ratingKey = roundedRating.toString();
          ratingDistribution[ratingKey] =
              (ratingDistribution[ratingKey] ?? 0) + 1;
        }
      }

      final totalRatedJobs = ratings.length;
      final averageRating = totalRatedJobs > 0
          ? ratings.reduce((a, b) => a + b) / totalRatedJobs
          : 0;

      return {
        'totalRatedJobs': totalRatedJobs,
        'averageRating': averageRating,
        'ratingDistribution': ratingDistribution,
        'fiveStarPercentage': totalRatedJobs > 0
            ? ((ratingDistribution['5'] ?? 0) / totalRatedJobs * 100).round()
            : 0,
        'fourPlusStarPercentage': totalRatedJobs > 0
            ? (((ratingDistribution['4'] ?? 0) +
                          (ratingDistribution['5'] ?? 0)) /
                      totalRatedJobs *
                      100)
                  .round()
            : 0,
      };
    } catch (e) {
      throw Exception('Failed to get customer satisfaction analytics: $e');
    }
  }

  // ============================================================================
  // FINANCIAL ANALYTICS (based on mechanic salaries)
  // ============================================================================

  /// Get financial and labor cost analysis
  Future<Map<String, dynamic>> getFinancialAnalytics({
    String? mechanicId,
  }) async {
    try {
      Query mechanicQuery = _firestore.collection('mechanics');
      Query jobQuery = _firestore.collection('jobs');

      // Filter by mechanic ID if provided
      if (mechanicId != null && mechanicId.isNotEmpty) {
        mechanicQuery = mechanicQuery.where(
          FieldPath.documentId,
          isEqualTo: mechanicId,
        );
        jobQuery = jobQuery.where('mechanicId', isEqualTo: mechanicId);
      }

      final mechanicSnapshot = await mechanicQuery.get();
      final jobSnapshot = await jobQuery.get();

      List<double> salaries = [];
      double totalMonthlySalary = 0;

      for (var doc in mechanicSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        final salary = data?['monthlySalary']?.toDouble();

        if (salary != null) {
          salaries.add(salary);
          totalMonthlySalary += salary;
        }
      }

      final totalMechanics = mechanicSnapshot.docs.length;
      final averageSalary = totalMechanics > 0
          ? totalMonthlySalary / totalMechanics
          : 0;

      // Calculate labor cost per hour (assuming 160 hours per month)
      final laborCostPerHour = averageSalary > 0 ? averageSalary / 160 : 0;

      // Get total job hours for labor cost calculation
      double totalJobHours = 0;
      int completedJobs = 0;

      for (var doc in jobSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        final actualDuration = data?['actualDuration']?.toDouble();
        final status = data?['status'] as String?;

        if (actualDuration != null) {
          totalJobHours += actualDuration;
        }

        if (status == 'completed') {
          completedJobs++;
        }
      }

      final totalLaborCosts = totalJobHours * laborCostPerHour;
      final laborCostPerJob = completedJobs > 0
          ? totalLaborCosts / completedJobs
          : 0;

      return {
        'totalMonthlySalary': totalMonthlySalary,
        'averageSalary': averageSalary,
        'laborCostPerHour': laborCostPerHour,
        'totalLaborCosts': totalLaborCosts,
        'laborCostPerJob': laborCostPerJob,
        'totalMechanics': totalMechanics,
      };
    } catch (e) {
      throw Exception('Failed to get financial analytics: $e');
    }
  }

  // ============================================================================
  // CALENDAR DATA
  // ============================================================================

  /// Get jobs grouped by date for calendar display
  Future<Map<DateTime, List<Map<String, dynamic>>>> getJobsByDate({
    String? mechanicId,
    String dateField = 'assignedAt', // 'assignedAt', 'startedAt', 'completedAt'
  }) async {
    try {
      Query query = _firestore.collection('jobs');

      // Filter by mechanic ID if provided
      if (mechanicId != null && mechanicId.isNotEmpty) {
        query = query.where('mechanicId', isEqualTo: mechanicId);
      }

      final QuerySnapshot snapshot = await query.get();
      Map<DateTime, List<Map<String, dynamic>>> jobsByDate = {};

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        // Use the selected date field - only show jobs that have the exact field
        DateTime? jobDate;

        // Only include jobs that have the specific date field we're filtering by
        if (data[dateField] != null) {
          try {
            jobDate = DateTime.parse(data[dateField]);
          } catch (e) {
            // Skip if date parsing fails
            continue;
          }
        } else {
          // Skip jobs that don't have the required date field
          continue;
        }

        // Normalize to date only (remove time)
        final dateOnly = DateTime(jobDate.year, jobDate.month, jobDate.day);

        if (!jobsByDate.containsKey(dateOnly)) {
          jobsByDate[dateOnly] = [];
        }

        jobsByDate[dateOnly]!.add({
          'id': doc.id,
          'title': data['title'] ?? 'Untitled Job',
          'status': data['status'] ?? 'assigned',
          'priority': data['priority'] ?? 'medium',
          'customerName': data['customerName'] ?? 'Unknown Customer',
          'mechanicId': data['mechanicId'] ?? '',
        });
      }

      return jobsByDate;
    } catch (e) {
      throw Exception('Failed to get jobs by date: $e');
    }
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Helper method to check if two dates are on the same day
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  /// Get comprehensive dashboard data (all analytics combined)
  Future<Map<String, dynamic>> getComprehensiveDashboardData({
    String? mechanicId,
  }) async {
    try {
      // Build futures list with proper indexing
      List<Future> futuresList = [
        getJobStatistics(mechanicId: mechanicId),
        getJobPriorityDistribution(mechanicId: mechanicId),
        getServiceTypeBreakdown(mechanicId: mechanicId),
        getTimePerformanceMetrics(mechanicId: mechanicId),
        getCostAnalysis(mechanicId: mechanicId),
        getTaskAnalytics(mechanicId: mechanicId),
        getTimelineAnalytics(mechanicId: mechanicId),
        getNotesAnalysis(mechanicId: mechanicId),
        getPartsAnalysis(mechanicId: mechanicId),
        getVehicleAnalytics(mechanicId: mechanicId),
        getEquipmentAnalytics(mechanicId: mechanicId),
        getCustomerInsights(mechanicId: mechanicId),
        getDigitalSignoffAnalytics(mechanicId: mechanicId),
        getCustomerSatisfactionAnalytics(mechanicId: mechanicId),
        getFinancialAnalytics(mechanicId: mechanicId),
        getJobsByDate(mechanicId: mechanicId),
      ];
      
      // Add mechanic performance if mechanicId is provided
      if (mechanicId != null) {
        futuresList.add(getMechanicPerformance(mechanicId));
      }

      final futures = await Future.wait(futuresList);
      
      // Build result map with proper indexing
      Map<String, dynamic> result = {
        'jobStatistics': futures[0],
        'priorityDistribution': futures[1],
        'serviceTypeBreakdown': futures[2],
        'timePerformance': futures[3],
        'costAnalysis': futures[4],
        'taskAnalytics': futures[5],
        'timelineAnalytics': futures[6],
        'notesAnalysis': futures[7],
        'partsAnalysis': futures[8],
        'vehicleAnalytics': futures[9],
        'equipmentAnalytics': futures[10],
        'customerInsights': futures[11],
        'digitalSignoffAnalytics': futures[12],
        'customerSatisfactionAnalytics': futures[13],
        'financialAnalytics': futures[14],
        'jobsByDate': futures[15],
      };
      
      // Add mechanic performance if it was included
      if (mechanicId != null && futures.length > 16) {
        result['mechanicPerformance'] = futures[16];
      }
      
      return result;
    } catch (e) {
      throw Exception('Failed to get comprehensive dashboard data: $e');
    }
  }
}
