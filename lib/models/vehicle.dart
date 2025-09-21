class Vehicle {
  final String id;
  final String customerId; // Foreign key to Customer
  final String make;
  final String model;
  final int year;
  final String vin;
  final String licensePlate;
  final String color;
  final int mileage;
  final List<String> photos; // URLs to vehicle photos
  final DateTime createdAt;
  final DateTime updatedAt;

  const Vehicle({
    required this.id,
    required this.customerId,
    required this.make,
    required this.model,
    required this.year,
    required this.vin,
    required this.licensePlate,
    required this.color,
    required this.mileage,
    this.photos = const [],
    required this.createdAt,
    required this.updatedAt,
  });
}
