enum MechanicStatus { online, away, busy, offline }

enum MechanicRole { manager, mechanic }

class Mechanic {
  final String id;
  final String name;
  final String? avatar;
  final String? phone;
  final String? email;
  final String? bio;
  final MechanicStatus status;
  final MechanicRole role;
  final String? employeeId;
  final String? department;
  final String specialization;
  final String? passwordHash;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastLoginAt;
  // NEW FIELDS FOR ENHANCED ANALYTICS
  final double? monthlySalary; // Monthly salary in USD for financial analytics

  const Mechanic({
    required this.id,
    required this.name,
    this.avatar,
    this.phone,
    this.email,
    this.bio,
    required this.status,
    required this.role,
    this.employeeId,
    this.department,
    required this.specialization,
    this.passwordHash,
    required this.createdAt,
    required this.updatedAt,
    this.lastLoginAt,
    this.monthlySalary,
  });

  factory Mechanic.fromMap(Map<String, dynamic> map) {
    return Mechanic(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      avatar: map['avatar'],
      phone: map['phone'],
      email: map['email'],
      bio: map['bio'],
      status: MechanicStatus.values.firstWhere(
            (e) => e.toString().split('.').last == (map['status'] ?? 'offline'),
        orElse: () => MechanicStatus.offline,
      ),
      role: MechanicRole.values.firstWhere(
            (e) => e.toString().split('.').last == (map['role'] ?? 'mechanic'),
        orElse: () => MechanicRole.mechanic,
      ),
      employeeId: map['employeeId'],
      department: map['department'],
      specialization: map['specialization'] ?? '',
      passwordHash: map['passwordHash'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
      lastLoginAt: map['lastLoginAt'] != null
          ? DateTime.parse(map['lastLoginAt'])
          : null,
      monthlySalary: map['monthlySalary']?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'avatar': avatar,
      'phone': phone,
      'email': email,
      'bio': bio,
      'status': status.toString().split('.').last,
      'role': role.toString().split('.').last,
      'employeeId': employeeId,
      'department': department,
      'specialization': specialization,
      'passwordHash': passwordHash,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'monthlySalary': monthlySalary,
    };
  }
}
