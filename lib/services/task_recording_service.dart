import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task.dart';
import '../models/job.dart';
import '../services/auth_service.dart';
import '../services/global_recording_service.dart';

class TaskRecordingService {
  static final TaskRecordingService _instance = TaskRecordingService._internal();
  factory TaskRecordingService() => _instance;
  TaskRecordingService._internal();
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  final GlobalRecordingService _globalRecordingService = GlobalRecordingService();
  
  // Stream controllers for UI updates (duration comes from GlobalRecordingService)
  final StreamController<Duration> _durationController = StreamController<Duration>.broadcast();
  final StreamController<bool> _recordingStateController = StreamController<bool>.broadcast();
  final StreamController<bool> _pauseStateController = StreamController<bool>.broadcast();
  
  // Real-time subscription to GlobalRecordingService
  StreamSubscription? _globalRecordingSubscription;
  
  // Current UI state (mirrors GlobalRecordingService state)
  bool _isRecording = false;
  bool _isPaused = false;
  Duration _currentDuration = Duration.zero;
  String? _currentRecordingTaskId;
  
  // Flag to track if the service has been disposed
  bool _isDisposed = false;
  
  // Getters for streams
  Stream<Duration> get durationStream => _durationController.stream;
  Stream<bool> get recordingStateStream => _recordingStateController.stream;
  Stream<bool> get pauseStateStream => _pauseStateController.stream;
  
  // Getters for current state
  bool get isRecording => _isRecording;
  bool get isPaused => _isPaused;
  Duration get currentDuration => _currentDuration;
  
  /// Get all tasks for a specific job, ordered by their order field
  Future<List<Task>> getTasksForJob(String jobId) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('tasks')
          .where('jobId', isEqualTo: jobId)
          .get();
      
      final jobTasks = querySnapshot.docs
          .map((doc) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            
            // Convert Firestore Timestamps to UTC ISO8601 strings (expected by Task.fromMap)
            if (data['startedAt'] is Timestamp) {
              data['startedAt'] = (data['startedAt'] as Timestamp).toDate().toUtc().toIso8601String();
            }
            if (data['completedAt'] is Timestamp) {
              data['completedAt'] = (data['completedAt'] as Timestamp).toDate().toUtc().toIso8601String();
            }
            if (data['cancelledAt'] is Timestamp) {
              data['cancelledAt'] = (data['cancelledAt'] as Timestamp).toDate().toUtc().toIso8601String();
            }
            if (data['createdAt'] is Timestamp) {
              data['createdAt'] = (data['createdAt'] as Timestamp).toDate().toUtc().toIso8601String();
            }
            if (data['updatedAt'] is Timestamp) {
              data['updatedAt'] = (data['updatedAt'] as Timestamp).toDate().toUtc().toIso8601String();
            }
            
            return Task.fromMap(data);
          })
          .toList();
      
      // Sort by order field, with null values at the end
      jobTasks.sort((a, b) {
        if (a.order == null && b.order == null) return 0;
        if (a.order == null) return 1;
        if (b.order == null) return -1;
        return a.order!.compareTo(b.order!);
      });
      
      return jobTasks;
    } catch (e) {
      print('Error getting tasks for job: $e');
      return [];
    }
  }
  
  /// Get job details by job ID
  Future<Job?> getJobById(String jobId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('jobs')
          .doc(jobId)
          .get();
      
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Job.fromMap(data);
      }
      return null;
    } catch (e) {
      print('Error getting job: $e');
      return null;
    }
  }
  
  /// Find the index of a specific task in the job's task list
  int findTaskIndex(List<Task> tasks, String taskId) {
    return tasks.indexWhere((task) => task.id == taskId);
  }
  
  /// Get the next task in the sequence
  Task? getNextTask(List<Task> tasks, int currentIndex) {
    if (currentIndex < tasks.length - 1) {
      return tasks[currentIndex + 1];
    }
    return null;
  }
  
  /// Get the previous task in the sequence
  Task? getPreviousTask(List<Task> tasks, int currentIndex) {
    if (currentIndex > 0) {
      return tasks[currentIndex - 1];
    }
    return null;
  }
  
  /// Initialize listener for existing recording (used after app restart)
  Future<void> initializeForExistingRecording(String taskId) async {
    final mechanicId = _authService.currentMechanicId;
    if (mechanicId != null) {
      // Check if there's an active recording for this task
      final activeRecording = await _globalRecordingService.getActiveRecordingForMechanic(mechanicId);
      
      if (activeRecording != null && activeRecording['taskId'] == taskId) {
        // Initialize internal state from database
        final durationFromDB = activeRecording['duration'] as int? ?? 0;
        final statusFromDB = activeRecording['status'] as String? ?? 'running';
        
        _isRecording = true;
        _isPaused = statusFromDB == 'paused';
        _currentDuration = Duration(seconds: durationFromDB);
        _currentRecordingTaskId = taskId;
        
        // Update UI streams
        _safeAddToController(_recordingStateController, _isRecording);
        _safeAddToController(_pauseStateController, _isPaused);
        _safeAddToController(_durationController, _currentDuration);
        
        // Set up listener for ongoing updates
        _setupGlobalRecordingListener(taskId);
      }
    }
  }
  
  /// Set up listener to GlobalRecordingService for UI updates
  void _setupGlobalRecordingListener(String taskId) {
    final mechanicId = _authService.currentMechanicId;
    if (mechanicId != null) {
      _globalRecordingSubscription = _globalRecordingService.listenToMechanicRecordings(mechanicId).listen((recordingData) {
        if (recordingData != null && recordingData['taskId'] == taskId) {
          // This task is being recorded - update UI state
          final durationFromDB = recordingData['duration'] as int? ?? 0;
          final statusFromDB = recordingData['status'] as String? ?? 'running';
          
          _isRecording = true;
          _isPaused = statusFromDB == 'paused';
          _currentDuration = Duration(seconds: durationFromDB);
          _currentRecordingTaskId = taskId;
          
          // Update UI streams
          _safeAddToController(_recordingStateController, _isRecording);
          _safeAddToController(_pauseStateController, _isPaused);
          _safeAddToController(_durationController, _currentDuration);
        } else if (_currentRecordingTaskId == taskId) {
          // This task was being recorded but no longer - reset UI state
          _isRecording = false;
          _isPaused = false;
          _currentRecordingTaskId = null;
          
          // Update UI streams
          _safeAddToController(_recordingStateController, _isRecording);
          _safeAddToController(_pauseStateController, _isPaused);
        }
      });
    }
  }
  
  /// Start recording for a task (delegates to GlobalRecordingService)
  Future<bool> startRecording(String taskId, String jobId, {int initialDurationSeconds = 0}) async {
    final mechanicId = _authService.currentMechanicId;
    if (mechanicId == null) return false;
    
    try {
      // Update task status to inProgress in Firestore
      await updateTaskStatus(taskId, TaskStatus.inProgress, startedAt: DateTime.now());
      
      // Start recording in GlobalRecordingService (handles Realtime DB and timer)
      final success = await _globalRecordingService.startTaskRecording(taskId, mechanicId, jobId, initialDuration: initialDurationSeconds);
      
      if (success) {
        // Set up listener for this task
        _setupGlobalRecordingListener(taskId);
        
        // Initial UI state
        _isRecording = true;
        _isPaused = false;
        _currentDuration = Duration(seconds: initialDurationSeconds); // Start with initial duration
        _currentRecordingTaskId = taskId;
        
        _safeAddToController(_recordingStateController, _isRecording);
        _safeAddToController(_pauseStateController, _isPaused);
        _safeAddToController(_durationController, _currentDuration);
      }
      
      return success;
    } catch (e) {
      print('Error starting recording: $e');
      return false;
    }
  }
  
  /// Pause recording (delegates to GlobalRecordingService)
  Future<void> pauseRecording() async {
    final mechanicId = _authService.currentMechanicId;
    if (mechanicId != null) {
      // Check actual database state instead of relying on internal state
      final activeRecording = await _globalRecordingService.getActiveRecordingForMechanic(mechanicId);
      if (activeRecording != null && activeRecording['status'] != 'paused') {
        await _globalRecordingService.pauseRecording(mechanicId);
        // UI will be updated via the listener
      }
    }
  }
  
  /// Resume recording (delegates to GlobalRecordingService)
  Future<void> resumeRecording() async {
    final mechanicId = _authService.currentMechanicId;
    if (mechanicId != null) {
      // Check actual database state instead of relying on internal state
      final activeRecording = await _globalRecordingService.getActiveRecordingForMechanic(mechanicId);
      if (activeRecording != null && activeRecording['status'] == 'paused') {
        await _globalRecordingService.resumeRecording(mechanicId);
        // UI will be updated via the listener
      } else if (activeRecording != null && activeRecording['status'] == 'running') {
        // There's already an active recording running - don't allow resume
        print('Cannot resume: Another task is currently being recorded');
      }
    }
  }
  
  /// Finish recording (delegates to GlobalRecordingService)
  Future<bool> finishRecording(String taskId) async {
    final mechanicId = _authService.currentMechanicId;
    if (mechanicId == null) return false;
    
    // Check actual database state instead of relying on internal state
    final activeRecording = await _globalRecordingService.getActiveRecordingForMechanic(mechanicId);
    if (activeRecording == null || activeRecording['taskId'] != taskId) return false;
    
    try {
      // Get actual duration from database instead of potentially stale internal state
      final durationFromDB = activeRecording['duration'] as int? ?? 0;
      final totalDuration = Duration(seconds: durationFromDB);
      final completedAt = DateTime.now();
      
      // Store actualTime in seconds for better precision
      final actualTimeInSeconds = totalDuration.inSeconds;
      await updateTaskStatus(
        taskId, 
        TaskStatus.completed,
        completedAt: completedAt,
        actualTime: actualTimeInSeconds.toDouble(), // Convert to double for consistency
      );

      
      // Stop recording in GlobalRecordingService (removes from Realtime DB)
      await _globalRecordingService.stopTaskRecording(taskId, mechanicId, actualTime: actualTimeInSeconds.toDouble());
      
      // Clean up listener
      _globalRecordingSubscription?.cancel();
      
      // Reset UI state
      _isRecording = false;
      _isPaused = false;
      _currentDuration = Duration.zero;
      _currentRecordingTaskId = null;
      
      _safeAddToController(_recordingStateController, _isRecording);
      _safeAddToController(_pauseStateController, _isPaused);
      _safeAddToController(_durationController, _currentDuration);
      
      return true;
    } catch (e) {
      print('Error finishing recording: $e');
      return false;
    }
  }
  
  /// Cancel recording (delegates to GlobalRecordingService)
  Future<bool> cancelRecording(String taskId) async {
    final mechanicId = _authService.currentMechanicId;
    if (mechanicId == null) return false;
    
    // Check actual database state instead of relying on internal state
    final activeRecording = await _globalRecordingService.getActiveRecordingForMechanic(mechanicId);
    if (activeRecording == null || activeRecording['taskId'] != taskId) return false;
    
    try {
      // Reset task status back to pending in Firestore
      await updateTaskStatus(taskId, TaskStatus.pending, startedAt: null);
      
      // Cancel recording in GlobalRecordingService (removes from Realtime DB)
      await _globalRecordingService.cancelTaskRecording(taskId, mechanicId);
      
      // Clean up listener
      _globalRecordingSubscription?.cancel();
      
      // Reset UI state
      _isRecording = false;
      _isPaused = false;
      _currentDuration = Duration.zero;
      _currentRecordingTaskId = null;
      
      _safeAddToController(_recordingStateController, _isRecording);
      _safeAddToController(_pauseStateController, _isPaused);
      _safeAddToController(_durationController, _currentDuration);
      
      return true;
    } catch (e) {
      print('Error canceling recording: $e');
      return false;
    }
  }
  
  /// Update task status and related fields in Firestore
  Future<void> updateTaskStatus(
    String taskId, 
    TaskStatus status, {
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    double? actualTime,
    bool clearStartedAt = false,
    bool clearCompletedAt = false,
    bool clearCancelledAt = false,
    bool clearActualTime = false,
  }) async {
    try {
      Map<String, dynamic> updateData = {
        'status': status.toString().split('.').last,
      };
      
      // Handle startedAt - set value or clear field
      if (startedAt != null) {
        updateData['startedAt'] = startedAt.toUtc().toIso8601String();
      } else if (clearStartedAt) {
        updateData['startedAt'] = FieldValue.delete();
      }
      
      // Handle completedAt - set value or clear field
      if (completedAt != null) {
        updateData['completedAt'] = completedAt.toUtc().toIso8601String();
      } else if (clearCompletedAt) {
        updateData['completedAt'] = FieldValue.delete();
      }
      
      // Handle cancelledAt - set value or clear field
      if (cancelledAt != null) {
        updateData['cancelledAt'] = cancelledAt.toUtc().toIso8601String();
      } else if (clearCancelledAt) {
        updateData['cancelledAt'] = FieldValue.delete();
      }
      
      // Handle actualTime - set value or clear field
      if (actualTime != null) {
        updateData['actualTime'] = actualTime;
      } else if (clearActualTime) {
        updateData['actualTime'] = FieldValue.delete();
      }
      
      await _firestore.collection('tasks').doc(taskId).update(updateData);
    } catch (e) {
      print('Error updating task status: $e');
      throw e;
    }
  }
  
  /// Format duration to display string (MM:SS)
  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
  
  /// Format duration to display string with hours (HH:MM:SS)
  String formatDurationWithHours(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitHours = twoDigits(duration.inHours);
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitHours:$twoDigitMinutes:$twoDigitSeconds";
  }
  
  /// Calculate elapsed time for a task based on its startedAt timestamp
  Duration calculateElapsedTime(Task task) {
    if (task.startedAt != null) {
      return DateTime.now().difference(task.startedAt!);
    }
    return Duration.zero;
  }
  
  /// Get the current duration for a task (from GlobalRecordingService or calculated from startedAt)
  Future<Duration> getCurrentDuration(Task task) async {
    final mechanicId = _authService.currentMechanicId;
    
    if (mechanicId != null) {
      // Check if this task is actively being recorded in Realtime Database
      final activeRecording = await _globalRecordingService.getActiveRecordingForMechanic(mechanicId);
      if (activeRecording != null && activeRecording['taskId'] == task.id) {
        final durationFromDB = activeRecording['duration'] as int? ?? 0;
        return Duration(seconds: durationFromDB);
      }
    }
    
    // If not actively recording, check if it's an in-progress task
    if (task.status == TaskStatus.inProgress && task.startedAt != null) {
      // For in-progress tasks, calculate from startedAt
      return calculateElapsedTime(task);
    }
    
    // For pending/completed tasks, return zero
    return Duration.zero;
  }
  
  /// Check if a task is currently being recorded (checks GlobalRecordingService)
  Future<bool> isTaskCurrentlyRecording(Task task) async {
    final mechanicId = _authService.currentMechanicId;
    
    if (mechanicId != null) {
      final activeRecording = await _globalRecordingService.getActiveRecordingForMechanic(mechanicId);
      return activeRecording != null && activeRecording['taskId'] == task.id;
    }
    
    return false;
  }
  
  /// Calculate progress percentage for current task in job
  double calculateProgress(int currentIndex, int totalTasks) {
    if (totalTasks == 0) return 0.0;
    return (currentIndex + 1) / totalTasks;
  }
  
  /// Get progress text (e.g., "1/8")
  String getProgressText(int currentIndex, int totalTasks) {
    return '${currentIndex + 1}/$totalTasks';
  }
  
  /// Initialize UI state for a task (checks GlobalRecordingService for active recording)
  Future<void> initializeTaskState(Task task) async {
    
    final mechanicId = _authService.currentMechanicId;
    
    if (mechanicId != null) {
      // Check if this task is actively being recorded
      final activeRecording = await _globalRecordingService.getActiveRecordingForMechanic(mechanicId);
      
      if (activeRecording != null && activeRecording['taskId'] == task.id) {
        // This task is actively being recorded - set up listener and UI state
        final durationFromDB = activeRecording['duration'] as int? ?? 0;
        final statusFromDB = activeRecording['status'] as String? ?? 'running';
        
        
        _isRecording = true;
        _isPaused = statusFromDB == 'paused';
        _currentDuration = Duration(seconds: durationFromDB);
        _currentRecordingTaskId = task.id;
        
        // Set up listener for real-time updates
        _setupGlobalRecordingListener(task.id);
      } else {
        // Task is not being recorded - reset UI state
        
        _isRecording = false;
        _isPaused = false;
        _currentDuration = await getCurrentDuration(task);
        _currentRecordingTaskId = null;
        
        
        // Cancel any existing listener
        _globalRecordingSubscription?.cancel();
      }
    } else {
      // No mechanic ID - reset state
      _isRecording = false;
      _isPaused = false;
      _currentDuration = Duration.zero;
      _currentRecordingTaskId = null;
    }
    
    
    // Update UI streams
    _safeAddToController(_recordingStateController, _isRecording);
    _safeAddToController(_pauseStateController, _isPaused);
    _safeAddToController(_durationController, _currentDuration);
    
  }
  
  /// Stop any current recording without updating task status
  void stopCurrentRecording() {
    
    _globalRecordingSubscription?.cancel();
    _isRecording = false;
    _isPaused = false;
    _currentRecordingTaskId = null;
    
    _safeAddToController(_recordingStateController, _isRecording);
    _safeAddToController(_pauseStateController, _isPaused);
    
  }
  
  /// Helper method to safely add events to controllers
  void _safeAddToController<T>(StreamController<T> controller, T value) {
    if (!_isDisposed && !controller.isClosed) {
      controller.add(value);
    }
  }
  
  /// Dispose of resources
  void dispose() {
    _isDisposed = true;
    _globalRecordingSubscription?.cancel();
    _durationController.close();
    _recordingStateController.close();
    _pauseStateController.close();
  }
}
