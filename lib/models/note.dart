enum NoteType { request, problem, completion }

enum NoteStatus { pending, solved, completed }

class Note {
  final String id;
  final String jobId; // Foreign key to Job
  final String name;
  final String description;
  final List<String> photos; // URLs to related photos
  final NoteType noteType;
  final NoteStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Note({
    required this.id,
    required this.jobId,
    required this.name,
    required this.description,
    this.photos = const [],
    required this.noteType,
    this.status = NoteStatus.pending,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'] ?? '',
      jobId: map['jobId'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      photos: List<String>.from(map['photos'] ?? []),
      noteType: NoteType.values.firstWhere(
        (e) => e.toString().split('.').last == (map['noteType'] ?? 'request'),
        orElse: () => NoteType.request,
      ),
      status: NoteStatus.values.firstWhere(
        (e) => e.toString().split('.').last == (map['status'] ?? 'pending'),
        orElse: () => NoteStatus.pending,
      ),
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'jobId': jobId,
      'name': name,
      'description': description,
      'photos': photos,
      'noteType': noteType.toString().split('.').last,
      'status': status.toString().split('.').last,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
