import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class CustomerDetailService {
  // Private constructor
  CustomerDetailService._();

  // Singleton instance
  static final CustomerDetailService _instance = CustomerDetailService._();

  // Factory constructor to return the singleton instance
  factory CustomerDetailService() => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get customer details by ID
  Future<Map<String, dynamic>?> getCustomerById(String customerId) async {
    try {
      debugPrint('🔍 Fetching customer details for ID: $customerId');

      DocumentSnapshot doc = await _firestore
          .collection('customers')
          .doc(customerId)
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        debugPrint('✅ Customer details loaded successfully');
        return data;
      } else {
        debugPrint('❌ Customer not found');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error fetching customer details: $e');
      return null;
    }
  }

  // Get customer's service requests
  Future<List<Map<String, dynamic>>> getCustomerServiceRequests(
    String customerId,
  ) async {
    try {
      debugPrint('🔍 Fetching service requests for customer: $customerId');

      QuerySnapshot querySnapshot = await _firestore
          .collection('service_requests')
          .where('customerId', isEqualTo: customerId)
          .get();

      List<Map<String, dynamic>> serviceRequests = querySnapshot.docs.map((
        doc,
      ) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();

      // Sort manually by requestedAt descending
      serviceRequests.sort((a, b) {
        try {
          DateTime dateA = DateTime.parse(a['requestedAt'] ?? '');
          DateTime dateB = DateTime.parse(b['requestedAt'] ?? '');
          return dateB.compareTo(dateA); // Descending order
        } catch (e) {
          return 0;
        }
      });

      debugPrint(
        '✅ Found ${serviceRequests.length} service requests for customer',
      );
      return serviceRequests;
    } catch (e) {
      debugPrint('❌ Error fetching customer service requests: $e');
      return [];
    }
  }

  // Get customer's job history based on service request IDs
  Future<List<Map<String, dynamic>>> getCustomerJobHistory(
    String customerId,
  ) async {
    try {
      debugPrint('🔍 Fetching job history for customer: $customerId');

      // First get service requests for this customer
      List<Map<String, dynamic>> serviceRequests =
          await getCustomerServiceRequests(customerId);
      List<String> serviceRequestIds = serviceRequests
          .map((sr) => sr['id'] as String)
          .toList();

      if (serviceRequestIds.isEmpty) {
        debugPrint('✅ No service requests found, trying direct customer query');
        // Fallback: try to get jobs directly by customerId
        try {
          QuerySnapshot directQuery = await _firestore
              .collection('jobs')
              .where('customerId', isEqualTo: customerId)
              .get();

          List<Map<String, dynamic>> directJobs = directQuery.docs.map((doc) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return data;
          }).toList();

          // Sort manually by assignedAt descending
          directJobs.sort((a, b) {
            try {
              DateTime dateA = DateTime.parse(a['assignedAt'] ?? '');
              DateTime dateB = DateTime.parse(b['assignedAt'] ?? '');
              return dateB.compareTo(dateA); // Descending order
            } catch (e) {
              return 0;
            }
          });

          debugPrint(
            '✅ Found ${directJobs.length} jobs via direct customer query',
          );
          return directJobs;
        } catch (directError) {
          debugPrint('❌ Direct customer query also failed: $directError');
          return [];
        }
      }

      // Get jobs based on service request IDs
      QuerySnapshot querySnapshot = await _firestore
          .collection('jobs')
          .where('serviceRequestId', whereIn: serviceRequestIds)
          .get();

      List<Map<String, dynamic>> jobs = querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();

      // Sort manually by assignedAt descending
      jobs.sort((a, b) {
        try {
          DateTime dateA = DateTime.parse(a['assignedAt'] ?? '');
          DateTime dateB = DateTime.parse(b['assignedAt'] ?? '');
          return dateB.compareTo(dateA); // Descending order
        } catch (e) {
          return 0;
        }
      });

      debugPrint('✅ Found ${jobs.length} jobs via service requests');
      return jobs;
    } catch (e) {
      debugPrint('❌ Error fetching customer job history: $e');
      return [];
    }
  }

  // Get customer's vehicles
  Future<List<Map<String, dynamic>>> getCustomerVehicles(
    String customerId,
  ) async {
    try {
      debugPrint('🔍 Fetching vehicles for customer: $customerId');

      QuerySnapshot querySnapshot = await _firestore
          .collection('vehicles')
          .where('customerId', isEqualTo: customerId)
          .get();

      List<Map<String, dynamic>> vehicles = querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();

      debugPrint('✅ Found ${vehicles.length} vehicles for customer');
      return vehicles;
    } catch (e) {
      debugPrint('❌ Error fetching customer vehicles: $e');
      return [];
    }
  }

  // Get customer's equipment
  Future<List<Map<String, dynamic>>> getCustomerEquipment(
    String customerId,
  ) async {
    try {
      debugPrint('🔍 Fetching equipment for customer: $customerId');

      QuerySnapshot querySnapshot = await _firestore
          .collection('equipment')
          .where('customerId', isEqualTo: customerId)
          .get();

      List<Map<String, dynamic>> equipment = querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();

      debugPrint('✅ Found ${equipment.length} equipment items for customer');
      return equipment;
    } catch (e) {
      debugPrint('❌ Error fetching customer equipment: $e');
      return [];
    }
  }

  // Update customer information
  Future<bool> updateCustomer(
    String customerId,
    Map<String, dynamic> updates,
  ) async {
    try {
      debugPrint('🔄 Updating customer: $customerId');

      await _firestore.collection('customers').doc(customerId).update({
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Customer updated successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating customer: $e');
      return false;
    }
  }

  // Get customer statistics
  Map<String, dynamic> getCustomerStats(List<Map<String, dynamic>> jobs) {
    int totalJobs = jobs.length;
    int completedJobs = jobs
        .where((job) => job['status'] == 'completed')
        .length;
    int pendingJobs = jobs.where((job) => job['status'] == 'pending').length;
    int inProgressJobs = jobs
        .where((job) => job['status'] == 'inProgress')
        .length;

    double totalSpent = 0.0;
    for (var job in jobs) {
      if (job['actualCost'] != null) {
        totalSpent += (job['actualCost'] as num).toDouble();
      } else if (job['estimatedCost'] != null) {
        totalSpent += (job['estimatedCost'] as num).toDouble();
      }
    }

    // Calculate average rating
    List<num> ratings = jobs
        .where((job) => job['customerRating'] != null)
        .map((job) => job['customerRating'] as num)
        .toList();

    double averageRating = ratings.isNotEmpty
        ? ratings.reduce((a, b) => a + b) / ratings.length
        : 0.0;

    return {
      'totalJobs': totalJobs,
      'completedJobs': completedJobs,
      'pendingJobs': pendingJobs,
      'inProgressJobs': inProgressJobs,
      'totalSpent': totalSpent,
      'averageRating': averageRating,
      'hasRatings': ratings.isNotEmpty,
    };
  }

  // Launch email app
  Future<bool> launchEmail(String email) async {
    final String emailUrl = 'mailto:$email';

    try {
      final Uri emailUri = Uri.parse(emailUrl);

      // Try the new API first
      try {
        if (await canLaunchUrl(emailUri)) {
          await launchUrl(emailUri, mode: LaunchMode.externalApplication);
          debugPrint('✅ Email app launched for: $email');
          return true;
        }
      } catch (e) {
        debugPrint('⚠️ New API failed, trying legacy API: $e');
        // Fallback to legacy API
        if (await canLaunch(emailUrl)) {
          await launch(emailUrl);
          debugPrint('✅ Email app launched for: $email (legacy)');
          return true;
        }
      }

      debugPrint('❌ Could not launch email app');
      return false;
    } catch (e) {
      debugPrint('❌ Error launching email: $e');
      return false;
    }
  }

  // Launch phone app
  Future<bool> launchPhone(String phone) async {
    final String phoneUrl = 'tel:$phone';

    try {
      final Uri phoneUri = Uri.parse(phoneUrl);

      // Try the new API first
      try {
        if (await canLaunchUrl(phoneUri)) {
          await launchUrl(phoneUri, mode: LaunchMode.externalApplication);
          debugPrint('✅ Phone app launched for: $phone');
          return true;
        }
      } catch (e) {
        debugPrint('⚠️ New API failed, trying legacy API: $e');
        // Fallback to legacy API
        if (await canLaunch(phoneUrl)) {
          await launch(phoneUrl);
          debugPrint('✅ Phone app launched for: $phone (legacy)');
          return true;
        }
      }

      debugPrint('❌ Could not launch phone app');
      return false;
    } catch (e) {
      debugPrint('❌ Error launching phone: $e');
      return false;
    }
  }
}
