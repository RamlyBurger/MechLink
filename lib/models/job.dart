import 'service_request.dart'; // For Priority enum

enum JobStatus { assigned, accepted, inProgress, completed, onHold, cancelled }

class Job {
  final String id;
  final String customerId; // Foreign key to Customer
  final String? serviceRequestId; // Foreign key to ServiceRequest
  final ServiceType
  serviceType; // Whether this job is for a vehicle or equipment
  final String?
  vehicleId; // Foreign key to Vehicle (when serviceType is vehicle)
  final String?
  equipmentId; // Foreign key to Equipment (when serviceType is equipment)
  final String title;
  final String description;
  final Priority priority;
  final String mechanicId; // Foreign key to Mechanic
  final JobStatus status;
  final double? estimatedDuration; // in hours
  final double? estimatedCost;
  final double? actualDuration; // in hours
  final double? actualCost;
  final DateTime assignedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final List<String> parts; // List of part names/descriptions
  final String? digitalSignOff; // Base64 encoded signature image
  final DateTime? digitalSignOffAt; // When the job was signed off
  // NEW FIELD FOR CUSTOMER SATISFACTION ANALYTICS
  final double?
  customerRating; // Customer satisfaction rating (1.0 to 5.0 stars)

  const Job({
    required this.id,
    required this.customerId,
    this.serviceRequestId,
    required this.serviceType,
    this.vehicleId,
    this.equipmentId,
    required this.title,
    required this.description,
    required this.priority,
    required this.mechanicId,
    this.status = JobStatus.assigned,
    this.estimatedDuration,
    this.estimatedCost,
    this.actualDuration,
    this.actualCost,
    required this.assignedAt,
    this.startedAt,
    this.completedAt,
    this.cancelledAt,
    this.parts = const [],
    this.digitalSignOff,
    this.digitalSignOffAt,
    this.customerRating,
  });

  factory Job.fromMap(Map<String, dynamic> map) {
    return Job(
      id: map['id'] ?? '',
      customerId: map['customerId'] ?? '',
      serviceRequestId: map['serviceRequestId'],
      serviceType: ServiceType.values.firstWhere(
        (e) =>
            e.toString().split('.').last == (map['serviceType'] ?? 'vehicle'),
        orElse: () => ServiceType.vehicle,
      ),
      vehicleId: map['vehicleId'],
      equipmentId: map['equipmentId'],
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      priority: Priority.values.firstWhere(
        (e) => e.toString().split('.').last == (map['priority'] ?? 'medium'),
        orElse: () => Priority.medium,
      ),
      mechanicId: map['mechanicId'] ?? '',
      status: JobStatus.values.firstWhere(
        (e) => e.toString().split('.').last == (map['status'] ?? 'assigned'),
        orElse: () => JobStatus.assigned,
      ),
      estimatedDuration: map['estimatedDuration']?.toDouble(),
      estimatedCost: map['estimatedCost']?.toDouble(),
      actualDuration: map['actualDuration']?.toDouble(),
      actualCost: map['actualCost']?.toDouble(),
      assignedAt: DateTime.parse(map['assignedAt']),
      startedAt: map['startedAt'] != null
          ? DateTime.parse(map['startedAt'])
          : null,
      completedAt: map['completedAt'] != null
          ? DateTime.parse(map['completedAt'])
          : null,
      cancelledAt: map['cancelledAt'] != null
          ? DateTime.parse(map['cancelledAt'])
          : null,
      parts: List<String>.from(map['parts'] ?? []),
      digitalSignOff: map['digitalSignOff'],
      digitalSignOffAt: map['digitalSignOffAt'] != null
          ? DateTime.parse(map['digitalSignOffAt'])
          : null,
      customerRating: map['customerRating']?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerId': customerId,
      'serviceRequestId': serviceRequestId,
      'serviceType': serviceType.toString().split('.').last,
      'vehicleId': vehicleId,
      'equipmentId': equipmentId,
      'title': title,
      'description': description,
      'priority': priority.toString().split('.').last,
      'mechanicId': mechanicId,
      'status': status.toString().split('.').last,
      'estimatedDuration': estimatedDuration,
      'estimatedCost': estimatedCost,
      'actualDuration': actualDuration,
      'actualCost': actualCost,
      'assignedAt': assignedAt.toIso8601String(),
      'startedAt': startedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'cancelledAt': cancelledAt?.toIso8601String(),
      'parts': parts,
      'digitalSignOff': digitalSignOff,
      'digitalSignOffAt': digitalSignOffAt?.toIso8601String(),
      'customerRating': customerRating,
    };
  }
}
