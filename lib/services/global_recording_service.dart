import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/task.dart';
import '../models/service_request.dart';
import '../services/auth_service.dart';

class GlobalRecordingService {
  static final GlobalRecordingService _instance =
      GlobalRecordingService._internal();
  factory GlobalRecordingService() => _instance;
  GlobalRecordingService._internal();

  final AuthService _authService = AuthService();

  // Firebase Realtime Database instance
  late FirebaseDatabase _database;

  // Timer for recording duration updates
  Timer? _recordingTimer;
  String? _currentRecordingMechanicId;
  String? _currentRecordingTaskId;
  int _lastUpdatedDuration = 0;

  // Initialize Firebase Realtime Database instance
  void _initDatabase() {
    _database = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL:
          'https://mechlink-34628-default-rtdb.asia-southeast1.firebasedatabase.app/',
    );
  }

  // Stream controllers for global recording state
  final StreamController<Task?> _recordingTaskController =
      StreamController<Task?>.broadcast();
  final StreamController<String?> _recordingJobIdController =
      StreamController<String?>.broadcast();

  // Current recording state
  Task? _currentRecordingTask;
  String? _currentRecordingJobId;

  // Getters for streams
  Stream<Task?> get recordingTaskStream => _recordingTaskController.stream;
  Stream<String?> get recordingJobIdStream => _recordingJobIdController.stream;

  // Getters for current state
  Task? get currentRecordingTask => _currentRecordingTask;
  String? get currentRecordingJobId => _currentRecordingJobId;
  bool get hasActiveRecording => _currentRecordingTask != null;

  /// Start recording a task globally
  Future<void> startGlobalRecording(Task task, String jobId) async {
    _currentRecordingTask = task;
    _currentRecordingJobId = jobId;

    _recordingTaskController.add(_currentRecordingTask);
    _recordingJobIdController.add(_currentRecordingJobId);
  }

  /// Restore timer state for existing recording (used after app restart)
  Future<void> restoreRecordingTimer(String mechanicId, String taskId) async {
    try {
      // Check if there's actually an active recording in the database
      final activeRecording = await getActiveRecordingForMechanic(mechanicId);

      if (activeRecording != null && activeRecording['taskId'] == taskId) {
        // Restore timer state variables
        _currentRecordingMechanicId = mechanicId;
        _currentRecordingTaskId = taskId;
        _lastUpdatedDuration = activeRecording['duration'] as int? ?? 0;

        // Start the timer if not already running
        if (_recordingTimer == null) {
          _startRecordingTimer();
        }
      }
    } catch (e) {
      print('Error restoring recording timer: $e');
    }
  }

  /// Stop global recording
  Future<void> stopGlobalRecording() async {
    _currentRecordingTask = null;
    _currentRecordingJobId = null;

    _recordingTaskController.add(null);
    _recordingJobIdController.add(null);
  }

  /// Update the recording task (when task data changes)
  void updateRecordingTask(Task updatedTask) {
    if (_currentRecordingTask?.id == updatedTask.id) {
      _currentRecordingTask = updatedTask;
      _recordingTaskController.add(_currentRecordingTask);
    }
  }

  /// Check if a specific task is currently being recorded globally
  bool isTaskRecording(String taskId) {
    return _currentRecordingTask?.id == taskId &&
        _currentRecordingTask?.status == TaskStatus.inProgress;
  }

  /// Get device ID for FCM notifications
  Future<String> _getDeviceId() async {
    try {
      // Get device ID from AuthService (generated during login)
      String? deviceId = await _authService.getCurrentDeviceId();

      if (deviceId != null) {
        return deviceId;
      }

      // Fallback: generate temporary device ID if not found
      final currentMechanicId = _authService.currentMechanicId;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fallbackId =
          'device_temp_${currentMechanicId ?? 'unknown'}_$timestamp';

      print('Using fallback device ID: $fallbackId');
      return fallbackId;
    } catch (e) {
      print('Error getting device ID: $e');
      // Final fallback device ID
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      return 'device_error_$timestamp';
    }
  }

  /// Start recording a task in Realtime Database
  Future<bool> startTaskRecording(
    String taskId,
    String mechanicId,
    String jobId, {
    int initialDuration = 0,
  }) async {
    try {
      // Initialize database if not already done
      _initDatabase();

      // Get device ID for notifications (placeholder for now)
      String deviceId = await _getDeviceId();

      final recordingData = {
        'taskId': taskId,
        'jobId': jobId,
        'duration':
            initialDuration, // Start with provided initial duration (0 for new, existing time for resume)
        'status': 'running', // running or paused
        'deviceId': deviceId, // Device ID for FCM notifications
        'isNotified':
            false, // Whether estimated time notification has been sent
      };

      await _database.ref(mechanicId).set(recordingData);

      // Start the timer for this recording
      _currentRecordingMechanicId = mechanicId;
      _currentRecordingTaskId = taskId;
      _lastUpdatedDuration =
          initialDuration; // Set duration tracker to initial value

      _startRecordingTimer();

      return true;
    } catch (e) {
      print('Error starting task recording: $e');
      return false;
    }
  }

  /// Stop recording a task
  Future<bool> stopTaskRecording(
    String taskId,
    String mechanicId, {
    double? actualTime,
  }) async {
    try {
      _initDatabase();

      // Stop the timer
      if (_currentRecordingMechanicId == mechanicId) {
        _stopRecordingTimer();
      } else {}

      // Simply remove the mechanic's recording entry
      await _database.ref(mechanicId).remove();
      return true;
    } catch (e) {
      print('Error stopping task recording: $e');
      return false;
    }
  }

  /// Cancel recording a task
  Future<bool> cancelTaskRecording(String taskId, String mechanicId) async {
    try {
      _initDatabase();

      // Stop the timer
      if (_currentRecordingMechanicId == mechanicId) {
        _stopRecordingTimer();
      }

      // Simply remove the mechanic's recording entry
      await _database.ref(mechanicId).remove();
      return true;
    } catch (e) {
      print('Error cancelling task recording: $e');
      return false;
    }
  }

  /// Check if a mechanic has any active recordings
  Future<Map<String, dynamic>?> getActiveRecordingForMechanic(
    String mechanicId,
  ) async {
    try {
      _initDatabase();
      final snapshot = await _database.ref(mechanicId).get();

      if (snapshot.exists && snapshot.value != null) {
        final result = Map<String, dynamic>.from(snapshot.value as Map);
        return result;
      }

      return null;
    } catch (e) {
      print('Error getting active recording for mechanic: $e');
      return null;
    }
  }

  /// Update recording duration
  Future<bool> updateRecordingDuration(
    String mechanicId,
    int durationInSeconds,
  ) async {
    try {
      await _database.ref('$mechanicId/duration').set(durationInSeconds);
      return true;
    } catch (e) {
      print('Error updating recording duration: $e');
      return false;
    }
  }

  /// Update recording status (running/paused)
  Future<bool> updateRecordingStatus(String mechanicId, String status) async {
    try {
      await _database.ref('$mechanicId/status').set(status);
      return true;
    } catch (e) {
      print('Error updating recording status: $e');
      return false;
    }
  }

  /// Pause recording
  Future<bool> pauseRecording(String mechanicId) async {
    return await updateRecordingStatus(mechanicId, 'paused');
  }

  /// Resume recording
  Future<bool> resumeRecording(String mechanicId) async {
    return await updateRecordingStatus(mechanicId, 'running');
  }

  /// Start the recording timer
  void _startRecordingTimer() {
    _recordingTimer?.cancel(); // Cancel any existing timer

    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_currentRecordingMechanicId != null) {
        try {
          // Get current recording data
          final snapshot = await _database
              .ref(_currentRecordingMechanicId!)
              .get();
          if (snapshot.exists && snapshot.value != null) {
            final recordingData = Map<String, dynamic>.from(
              snapshot.value as Map,
            );
            final status = recordingData['status'] as String? ?? 'running';
            final currentDuration = recordingData['duration'] as int? ?? 0;

            // Only increment duration if status is 'running'
            if (status == 'running') {
              final newDuration = currentDuration + 1;

              // Only update database if duration actually changed
              if (newDuration != _lastUpdatedDuration) {
                await updateRecordingDuration(
                  _currentRecordingMechanicId!,
                  newDuration,
                );
                _lastUpdatedDuration = newDuration;
              }
            }
          } else {
            // Recording was deleted, stop timer
            _stopRecordingTimer();
          }
        } catch (e) {
          print('Error updating recording duration: $e');
        }
      } else {
        // No active recording, stop timer
        _stopRecordingTimer();
      }
    });
  }

  /// Stop the recording timer
  void _stopRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _currentRecordingMechanicId = null;
    _currentRecordingTaskId = null;
    _lastUpdatedDuration = 0; // Reset duration tracker
  }

  /// Listen to changes in mechanic's active recordings
  Stream<Map<String, dynamic>?> listenToMechanicRecordings(String mechanicId) {
    _initDatabase(); // Ensure database is initialized
    return _database.ref(mechanicId).onValue.map((event) {
      if (event.snapshot.exists && event.snapshot.value != null) {
        return Map<String, dynamic>.from(event.snapshot.value as Map);
      }
      return null;
    });
  }

  /// Initialize global recording state from existing tasks across all jobs
  Future<void> initializeFromExistingTasks(String? specificJobId) async {
    try {
      // Check if current user has any active recordings in Realtime Database
      final mechanicId = _authService.currentMechanicId;
      if (mechanicId != null) {
        final activeRecording = await getActiveRecordingForMechanic(mechanicId);

        if (activeRecording != null) {
          final taskId = activeRecording['taskId'] as String;
          final jobId = activeRecording['jobId'] as String? ?? 'unknown';

          // Create a placeholder task with the real job ID from the recording data
          final recordingTask = Task(
            id: taskId,
            jobId: jobId,
            title: 'Recording Task',
            description: 'Task currently being recorded',
            priority: Priority.medium,
            status: TaskStatus.inProgress,
            estimatedTime: 1.0,
            order: 1,
            difficultyLevel: DifficultyLevel.medium,
          );

          // Set the global recording state
          _currentRecordingTask = recordingTask;
          _currentRecordingJobId = recordingTask.jobId;

          _recordingTaskController.add(_currentRecordingTask);
          _recordingJobIdController.add(_currentRecordingJobId);

          print(
            'Found active recording: ${recordingTask.title} for job: $jobId',
          );
          return;
        }
      }

      print('No active recordings found for current user');
    } catch (e) {
      print('Error initializing global recording state: $e');
    }
  }

  /// Dispose of resources
  void dispose() {
    _recordingTaskController.close();
    _recordingJobIdController.close();
  }
}
