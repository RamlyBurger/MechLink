import 'package:cloud_firestore/cloud_firestore.dart';

class TasksService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get tasks for a specific job
  Future<List<Map<String, dynamic>>> getTasksByJobId(String jobId) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('tasks')
          .where('jobId', isEqualTo: jobId)
          .get();

      List<Map<String, dynamic>> tasks = querySnapshot.docs
          .map(
            (doc) => {
              'documentId': doc.id,
              'id': doc.id,
              ...doc.data() as Map<String, dynamic>,
            },
          )
          .toList();

      // Sort by order if available, otherwise by creation time
      tasks.sort((a, b) {
        int orderA = a['order'] ?? 999;
        int orderB = b['order'] ?? 999;
        if (orderA != orderB) {
          return orderA.compareTo(orderB);
        }
        if (a['createdAt'] != null && b['createdAt'] != null) {
          return a['createdAt'].compareTo(b['createdAt']);
        }
        return 0;
      });

      return tasks;
    } catch (e) {
      print('Error getting tasks for job: $e');
      return [];
    }
  }

  // Get task by ID
  Future<Map<String, dynamic>?> getTaskById(String taskId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('tasks')
          .doc(taskId)
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['documentId'] = doc.id;
        data['id'] = doc.id;
        return data;
      }
      return null;
    } catch (e) {
      print('Error getting task: $e');
      return null;
    }
  }

  // Update task status
  Future<bool> updateTaskStatus(String taskId, String status) async {
    try {
      Map<String, dynamic> updateData = {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Add timestamp fields based on status
      switch (status) {
        case 'inProgress':
          updateData['startedAt'] = FieldValue.serverTimestamp();
          break;
        case 'completed':
          updateData['completedAt'] = FieldValue.serverTimestamp();
          break;
      }

      await _firestore.collection('tasks').doc(taskId).update(updateData);
      return true;
    } catch (e) {
      print('Error updating task status: $e');
      return false;
    }
  }

  // Start a task
  Future<bool> startTask(String taskId) async {
    return await updateTaskStatus(taskId, 'inProgress');
  }

  // Complete a task
  Future<bool> completeTask(String taskId, {double? actualTime}) async {
    try {
      Map<String, dynamic> updateData = {
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (actualTime != null) {
        updateData['actualTime'] = actualTime;
      }

      await _firestore.collection('tasks').doc(taskId).update(updateData);
      return true;
    } catch (e) {
      print('Error completing task: $e');
      return false;
    }
  }

  // Create a new task
  Future<String?> createTask({
    required String jobId,
    required String title,
    required String description,
    String priority = 'medium',
    double? estimatedTime,
    int? order,
  }) async {
    try {
      DocumentReference docRef = await _firestore.collection('tasks').add({
        'jobId': jobId,
        'title': title,
        'description': description,
        'priority': priority,
        'status': 'pending',
        'estimatedTime': estimatedTime,
        'order': order,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update the document with its ID
      await docRef.update({'id': docRef.id});
      return docRef.id;
    } catch (e) {
      print('Error creating task: $e');
      return null;
    }
  }

  // Update task
  Future<bool> updateTask(String taskId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('tasks').doc(taskId).update({
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error updating task: $e');
      return false;
    }
  }

  // Delete task
  Future<bool> deleteTask(String taskId) async {
    try {
      await _firestore.collection('tasks').doc(taskId).delete();
      return true;
    } catch (e) {
      print('Error deleting task: $e');
      return false;
    }
  }

  // Get task statistics for a job
  Future<Map<String, int>> getTaskStatistics(String jobId) async {
    try {
      List<Map<String, dynamic>> tasks = await getTasksByJobId(jobId);

      int total = tasks.length;
      int completed = tasks
          .where((task) => task['status'] == 'completed')
          .length;
      int inProgress = tasks
          .where((task) => task['status'] == 'inProgress')
          .length;
      int pending = tasks.where((task) => task['status'] == 'pending').length;

      return {
        'total': total,
        'completed': completed,
        'inProgress': inProgress,
        'pending': pending,
      };
    } catch (e) {
      print('Error getting task statistics: $e');
      return {'total': 0, 'completed': 0, 'inProgress': 0, 'pending': 0};
    }
  }

  // Get job status by job ID
  Future<String?> getJobStatus(String jobId) async {
    try {
      DocumentSnapshot jobDoc = await _firestore
          .collection('jobs')
          .doc(jobId)
          .get();

      if (jobDoc.exists) {
        Map<String, dynamic> jobData = jobDoc.data() as Map<String, dynamic>;
        return jobData['status'] as String?;
      }
      return null;
    } catch (e) {
      print('Error getting job status: $e');
      return null;
    }
  }
}
