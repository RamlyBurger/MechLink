class Equipment {
  final String id;
  final String customerId; // Foreign key to Customer
  final String name;
  final String model;
  final String manufacturer;
  final String serialNumber;
  final int year;
  final String
  category; // e.g., "Heavy Machinery", "Tools", "Diagnostic Equipment"
  final String condition; // e.g., "Excellent", "Good", "Fair", "Poor"
  final List<String> photos; // URLs to equipment photos
  final DateTime createdAt;
  final DateTime updatedAt;

  const Equipment({
    required this.id,
    required this.customerId,
    required this.name,
    required this.model,
    required this.manufacturer,
    required this.serialNumber,
    required this.year,
    required this.category,
    required this.condition,
    this.photos = const [],
    required this.createdAt,
    required this.updatedAt,
  });
}
