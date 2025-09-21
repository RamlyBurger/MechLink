enum RequestStatus { pending, approved, rejected, completed }

enum Priority { low, medium, high }

enum ServiceType { vehicle, equipment }

class ServiceRequest {
  final String id;
  final String customerId; // Foreign key to Customer
  final ServiceType serviceType; // Whether this is for a vehicle or equipment
  final String?
  vehicleId; // Foreign key to Vehicle (when serviceType is vehicle)
  final String?
  equipmentId; // Foreign key to Equipment (when serviceType is equipment)
  final String title;
  final String description;
  final Priority priority;
  final RequestStatus status;
  final DateTime requestedAt;
  final DateTime? approvedAt;
  final String? approvedBy; // Mechanic ID who approved
  final String? rejectionReason;

  const ServiceRequest({
    required this.id,
    required this.customerId,
    required this.serviceType,
    this.vehicleId,
    this.equipmentId,
    required this.title,
    required this.description,
    required this.priority,
    this.status = RequestStatus.pending,
    required this.requestedAt,
    this.approvedAt,
    this.approvedBy,
    this.rejectionReason,
  });
}
