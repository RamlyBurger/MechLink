import 'package:cloud_firestore/cloud_firestore.dart';

class NotesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get notes for a specific job
  Future<List<Map<String, dynamic>>> getNotesByJobId(String jobId) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('notes')
          .where('jobId', isEqualTo: jobId)
          .get();

      List<Map<String, dynamic>> notes = querySnapshot.docs
          .map(
            (doc) => {
              'documentId': doc.id,
              'id': doc.id,
              ...doc.data() as Map<String, dynamic>,
            },
          )
          .toList();

      // Sort by creation time (newest first)
      notes.sort((a, b) {
        if (a['createdAt'] != null && b['createdAt'] != null) {
          return b['createdAt'].compareTo(a['createdAt']);
        }
        return 0;
      });

      return notes;
    } catch (e) {
      print('Error getting notes for job: $e');
      return [];
    }
  }

  /// Get all notes with advanced filtering, sorting, and search
  Future<List<Map<String, dynamic>>> getAllNotes({
    String? mechanicId,
    String? noteType,
    String? status,
    String? searchQuery,
    String? sortBy,
    bool descending = true,
  }) async {
    try {
      Query query = _firestore.collection('notes');

      // Filter by mechanic if provided - get notes from jobs assigned to mechanic
      if (mechanicId != null) {
        QuerySnapshot jobsSnapshot = await _firestore
            .collection('jobs')
            .where('mechanicId', isEqualTo: mechanicId)
            .get();

        List<String> jobIds = jobsSnapshot.docs.map((doc) => doc.id).toList();

        if (jobIds.isNotEmpty) {
          query = query.where('jobId', whereIn: jobIds);
        } else {
          return []; // No jobs for this mechanic
        }
      }

      // Filter by note type if provided
      if (noteType != null && noteType != 'all') {
        query = query.where('noteType', isEqualTo: noteType);
      }

      // Filter by status if provided
      if (status != null && status != 'all') {
        query = query.where('status', isEqualTo: status);
      }

      QuerySnapshot notesSnapshot = await query.get();

      List<Map<String, dynamic>> notes = notesSnapshot.docs
          .map(
            (doc) => {
              'documentId': doc.id,
              'id': doc.id,
              ...doc.data() as Map<String, dynamic>,
            },
          )
          .toList();

      // Apply search filter if provided
      if (searchQuery != null && searchQuery.isNotEmpty) {
        notes = notes.where((note) {
          final name = (note['name'] ?? '').toString().toLowerCase();
          final description = (note['description'] ?? '')
              .toString()
              .toLowerCase();
          final search = searchQuery.toLowerCase();
          return name.contains(search) || description.contains(search);
        }).toList();
      }

      // Apply sorting
      _sortNotes(notes, sortBy ?? 'createdAt', descending);

      return notes;
    } catch (e) {
      print('Error getting all notes: $e');
      throw Exception('Failed to get notes: $e');
    }
  }

  /// Sort notes based on the specified criteria
  void _sortNotes(
    List<Map<String, dynamic>> notes,
    String sortBy,
    bool descending,
  ) {
    notes.sort((a, b) {
      dynamic aValue, bValue;

      switch (sortBy) {
        case 'name':
          aValue = a['name'] ?? '';
          bValue = b['name'] ?? '';
          break;
        case 'noteType':
          aValue = a['noteType'] ?? '';
          bValue = b['noteType'] ?? '';
          break;
        case 'status':
          aValue = a['status'] ?? '';
          bValue = b['status'] ?? '';
          break;
        case 'createdAt':
        default:
          aValue = a['createdAt'];
          bValue = b['createdAt'];
          break;
      }

      if (aValue == null && bValue == null) return 0;
      if (aValue == null) return descending ? 1 : -1;
      if (bValue == null) return descending ? -1 : 1;

      int comparison = aValue.compareTo(bValue);
      return descending ? -comparison : comparison;
    });
  }

  // Get note by ID
  Future<Map<String, dynamic>?> getNoteById(String noteId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('notes')
          .doc(noteId)
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['documentId'] = doc.id;
        data['id'] = doc.id;
        return data;
      }
      return null;
    } catch (e) {
      print('Error getting note: $e');
      return null;
    }
  }

  // Create a new note
  Future<String?> createNote({
    required String jobId,
    String? taskId,
    required String name,
    required String description,
    String noteType = 'request',
    List<String>? photos,
  }) async {
    try {
      DocumentReference docRef = await _firestore.collection('notes').add({
        'jobId': jobId,
        'taskId': taskId,
        'name': name,
        'description': description,
        'noteType': noteType,
        'photos': photos ?? [],
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update the document with its ID
      await docRef.update({'id': docRef.id});
      return docRef.id;
    } catch (e) {
      print('Error creating note: $e');
      return null;
    }
  }

  // Update note status
  Future<bool> updateNoteStatus(String noteId, String status) async {
    try {
      await _firestore.collection('notes').doc(noteId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error updating note status: $e');
      return false;
    }
  }

  // Delete note
  Future<bool> deleteNote(String noteId) async {
    try {
      await _firestore.collection('notes').doc(noteId).delete();
      return true;
    } catch (e) {
      print('Error deleting note: $e');
      return false;
    }
  }

  /// Get filter options for notes
  Map<String, List<String>> getFilterOptions() {
    return {
      'noteType': ['all', 'request', 'problem', 'completion'],
      'status': ['all', 'pending', 'solved', 'completed'],
    };
  }

  /// Get sorting options for notes
  Map<String, List<String>> getSortOptions() {
    return {
      'sortBy': ['createdAt', 'name', 'noteType', 'status'],
    };
  }

  /// Get notes with enriched data (similar to JobsService.getJobsWithDetails)
  Future<List<Map<String, dynamic>>> getNotesWithDetails({
    String? mechanicId,
    String? noteType,
    String? status,
    String? searchQuery,
    String? sortBy,
    bool descending = true,
  }) async {
    try {
      List<Map<String, dynamic>> notes = await getAllNotes(
        mechanicId: mechanicId,
        noteType: noteType,
        status: status,
        searchQuery: searchQuery,
        sortBy: sortBy,
        descending: descending,
      );

      // Enrich notes with job and task information
      for (var note in notes) {
        // Get job information
        if (note['jobId'] != null) {
          try {
            DocumentSnapshot jobDoc = await _firestore
                .collection('jobs')
                .doc(note['jobId'])
                .get();
            if (jobDoc.exists) {
              Map<String, dynamic> jobData =
                  jobDoc.data() as Map<String, dynamic>;
              note['jobTitle'] = jobData['title'] ?? 'Unknown Job';
              note['jobStatus'] = jobData['status'] ?? 'unknown';
            }
          } catch (e) {
            print('Error getting job data for note: $e');
          }
        }

        // Get task information if taskId exists
        if (note['taskId'] != null) {
          try {
            DocumentSnapshot taskDoc = await _firestore
                .collection('tasks')
                .doc(note['taskId'])
                .get();
            if (taskDoc.exists) {
              Map<String, dynamic> taskData =
                  taskDoc.data() as Map<String, dynamic>;
              note['taskTitle'] = taskData['title'] ?? 'Unknown Task';
            }
          } catch (e) {
            print('Error getting task data for note: $e');
          }
        }
      }

      return notes;
    } catch (e) {
      print('Error getting notes with details: $e');
      throw Exception('Failed to get notes with details: $e');
    }
  }

  /// Get note statistics for dashboard
  Future<Map<String, dynamic>> getNoteStatistics(String? mechanicId) async {
    try {
      List<Map<String, dynamic>> notes = await getAllNotes(
        mechanicId: mechanicId,
      );

      int totalNotes = notes.length;
      int pendingNotes = notes
          .where((note) => note['status'] == 'pending')
          .length;
      int solvedNotes = notes
          .where((note) => note['status'] == 'solved')
          .length;
      int acceptedNotes = notes
          .where((note) => note['status'] == 'completed')
          .length;

      int problemNotes = notes
          .where((note) => note['noteType'] == 'problem')
          .length;
      int requestNotes = notes
          .where((note) => note['noteType'] == 'request')
          .length;
      int completionNotes = notes
          .where((note) => note['noteType'] == 'completion')
          .length;

      return {
        'totalNotes': totalNotes,
        'pendingNotes': pendingNotes,
        'solvedNotes': solvedNotes,
        'acceptedNotes': acceptedNotes,
        'problemNotes': problemNotes,
        'requestNotes': requestNotes,
        'completionNotes': completionNotes,
      };
    } catch (e) {
      print('Error getting note statistics: $e');
      return {
        'totalNotes': 0,
        'pendingNotes': 0,
        'solvedNotes': 0,
        'acceptedNotes': 0,
        'problemNotes': 0,
        'requestNotes': 0,
        'completionNotes': 0,
      };
    }
  }

  // Get job details by job ID for note filtering
  Future<Map<String, dynamic>?> getJobByIdForNote(String jobId) async {
    try {
      DocumentSnapshot jobDoc = await _firestore
          .collection('jobs')
          .doc(jobId)
          .get();

      if (jobDoc.exists) {
        Map<String, dynamic> jobData = jobDoc.data() as Map<String, dynamic>;
        jobData['documentId'] = jobDoc.id;
        return jobData;
      }
      return null;
    } catch (e) {
      print('Error getting job for note filtering: $e');
      return null;
    }
  }
}
