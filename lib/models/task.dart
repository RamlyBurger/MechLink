import 'service_request.dart'; // For Priority enum

enum TaskStatus { pending, inProgress, completed, cancelled }

enum DifficultyLevel { low, medium, high }

class Task {
  final String id;
  final String jobId; // Foreign key to Job
  final String title;
  final String description;
  final Priority priority;
  final TaskStatus status;
  final double? estimatedTime; // in hours
  final double? actualTime; // in seconds (changed from hours for better precision)
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final int? order; // Order of task within the job
  // NEW FIELDS FOR TASK QUALITY AND COMPLEXITY ANALYTICS
  final double?
  qualityRating; // Quality rating (1.0 to 5.0 stars) for task execution
  final DifficultyLevel difficultyLevel; // Complexity level of the task

  const Task({
    required this.id,
    required this.jobId,
    required this.title,
    required this.description,
    required this.priority,
    this.status = TaskStatus.pending,
    this.estimatedTime,
    this.actualTime,
    this.startedAt,
    this.completedAt,
    this.cancelledAt,
    this.order,
    this.qualityRating,
    this.difficultyLevel = DifficultyLevel.medium,
  });

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] ?? '',
      jobId: map['jobId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      priority: Priority.values.firstWhere(
        (e) => e.toString().split('.').last == (map['priority'] ?? 'medium'),
        orElse: () => Priority.medium,
      ),
      status: TaskStatus.values.firstWhere(
        (e) => e.toString().split('.').last == (map['status'] ?? 'pending'),
        orElse: () => TaskStatus.pending,
      ),
      estimatedTime: map['estimatedTime']?.toDouble(),
      actualTime: map['actualTime']?.toDouble(),
      startedAt: map['startedAt'] != null
          ? DateTime.parse(map['startedAt'])
          : null,
      completedAt: map['completedAt'] != null
          ? DateTime.parse(map['completedAt'])
          : null,
      cancelledAt: map['cancelledAt'] != null
          ? DateTime.parse(map['cancelledAt'])
          : null,
      order: map['order'],
      qualityRating: map['qualityRating']?.toDouble(),
      difficultyLevel: DifficultyLevel.values.firstWhere(
        (e) =>
            e.toString().split('.').last ==
            (map['difficultyLevel'] ?? 'medium'),
        orElse: () => DifficultyLevel.medium,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'jobId': jobId,
      'title': title,
      'description': description,
      'priority': priority.toString().split('.').last,
      'status': status.toString().split('.').last,
      'estimatedTime': estimatedTime,
      'actualTime': actualTime,
      'startedAt': startedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'cancelledAt': cancelledAt?.toIso8601String(),
      'order': order,
      'qualityRating': qualityRating,
      'difficultyLevel': difficultyLevel.toString().split('.').last,
    };
  }
}
