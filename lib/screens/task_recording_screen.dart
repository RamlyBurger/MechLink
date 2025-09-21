import 'package:flutter/material.dart';
import 'dart:async';
import '../models/task.dart';
import '../models/job.dart';
import '../services/task_recording_service.dart';
import '../services/global_recording_service.dart';
import '../services/auth_service.dart';

class TaskRecordingScreen extends StatefulWidget {
  final String taskId;
  final String jobId;

  const TaskRecordingScreen({
    Key? key,
    required this.taskId,
    required this.jobId,
  }) : super(key: key);

  @override
  State<TaskRecordingScreen> createState() => _TaskRecordingScreenState();
}

class _TaskRecordingScreenState extends State<TaskRecordingScreen>
    with TickerProviderStateMixin {
  final TaskRecordingService _recordingService = TaskRecordingService();
  final GlobalRecordingService _globalRecordingService =
      GlobalRecordingService();

  List<Task> _tasks = [];
  Job? _job;
  int _currentTaskIndex = 0;
  Task? _currentTask;

  bool _isLoading = true;
  bool _isRecording = false;
  bool _isPaused = false;
  Duration _currentDuration = Duration.zero;
  bool _isDisposed = false;

  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotationAnimation;

  StreamSubscription? _recordingStateSubscription;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadData();
    _setupStreamListeners();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _rotationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.linear),
    );
  }

  void _setupStreamListeners() {
    // Set up direct listener to GlobalRecordingService for this specific task
    final AuthService authService = AuthService();
    final mechanicId = authService.currentMechanicId;
    if (mechanicId != null) {
      _recordingStateSubscription = _globalRecordingService
          .listenToMechanicRecordings(mechanicId)
          .listen(
            (recordingData) {
              // Double-check mounted state and disposed flag before any UI updates
              if (!mounted || _isDisposed) return;

              try {
                if (_currentTask != null) {
                  final isThisTaskRecording =
                      recordingData != null &&
                      recordingData['taskId'] == _currentTask!.id;

                  if (isThisTaskRecording) {
                    // This task is being recorded - update UI state
                    final durationFromDB =
                        recordingData['duration'] as int? ?? 0;
                    final statusFromDB =
                        recordingData['status'] as String? ?? 'running';

                    if (mounted) {
                      setState(() {
                        _isRecording = true;
                        _isPaused = statusFromDB == 'paused';
                        _currentDuration = Duration(seconds: durationFromDB);
                      });

                      // Start animations if recording and not paused
                      if (_isRecording && !_isPaused) {
                        _pulseController.repeat(reverse: true);
                        _rotationController.repeat();
                      } else {
                        _pulseController.stop();
                        _rotationController.stop();
                      }
                    }
                  } else {
                    // This task is not being recorded - reset UI state
                    if (mounted) {
                      setState(() {
                        _isRecording = false;
                        _isPaused = false;
                      });

                      _pulseController.stop();
                      _rotationController.stop();
                    }
                  }
                }
              } catch (e) {
                // Silently handle any errors to prevent crashes
                print('Error in recording state listener: $e');
              }
            },
            onError: (error) {
              // Handle stream errors gracefully
              print('Recording state stream error: $error');
            },
          );
    }
  }

  Future<void> _loadData() async {
    try {
      final tasks = await _recordingService.getTasksForJob(widget.jobId);
      final job = await _recordingService.getJobById(widget.jobId);
      final taskIndex = _recordingService.findTaskIndex(tasks, widget.taskId);

      final currentTask = tasks.isNotEmpty
          ? tasks[taskIndex >= 0 ? taskIndex : 0]
          : null;

      setState(() {
        _tasks = tasks;
        _job = job;
        _currentTaskIndex = taskIndex >= 0 ? taskIndex : 0;
        _currentTask = currentTask;
        _isLoading = false;
      });

      // Initialize recording state based on current task
      if (currentTask != null) {
        // Check if any task in this job is currently recording
        Task? recordingTask;
        for (final task in tasks) {
          if (await _recordingService.isTaskCurrentlyRecording(task)) {
            recordingTask = task;
            break;
          }
        }

        if (recordingTask != null) {
          // Check if global recording is already set for this task
          if (_globalRecordingService.currentRecordingTask?.id !=
              recordingTask.id) {
            // Set global recording state only if not already set
            await _globalRecordingService.startGlobalRecording(
              recordingTask,
              widget.jobId,
            );
          }
        }

        // Initialize the UI state for the current task from existing database data
        await _initializeCurrentTaskState(currentTask);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Failed to load task data: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _startRecording() async {
    if (_currentTask == null) return;

    // Check if there's already an active recording running
    final authService = AuthService();
    final mechanicId = authService.currentMechanicId;
    if (mechanicId != null) {
      final activeRecording = await _globalRecordingService
          .getActiveRecordingForMechanic(mechanicId);
      if (activeRecording != null &&
          (activeRecording['status'] == 'running' ||
              activeRecording['status'] == 'paused')) {
        _showErrorSnackBar(
          'Another task is currently being recorded. Please stop it first.',
        );
        return;
      }
    }

    // Check if task is already completed
    if (_currentTask!.status == TaskStatus.completed) {
      _showCompletedTaskDialog();
      return;
    }

    // Check if there are any incomplete tasks before the current one
    bool hasIncompleteTasksBefore = false;
    for (int i = 0; i < _currentTaskIndex; i++) {
      if (_tasks[i].status != TaskStatus.completed) {
        hasIncompleteTasksBefore = true;
        break;
      }
    }

    if (hasIncompleteTasksBefore) {
      _showErrorSnackBar('Please complete previous tasks first');
      return;
    }

    final success = await _recordingService.startRecording(
      _currentTask!.id,
      widget.jobId,
    );
    if (success) {
      _updateCurrentTaskData(); // Refresh task data

      // Start global recording for persistent bar
      await _globalRecordingService.startGlobalRecording(
        _currentTask!,
        widget.jobId,
      );
    } else {
      _showErrorSnackBar('Failed to start recording');
    }
  }

  void _pauseResumeRecording() async {
    if (_isPaused) {
      // Check if there's already another active recording running for a DIFFERENT task
      final authService = AuthService();
      final mechanicId = authService.currentMechanicId;
      if (mechanicId != null) {
        final activeRecording = await _globalRecordingService
            .getActiveRecordingForMechanic(mechanicId);
        if (activeRecording != null &&
            (activeRecording['status'] == 'running' ||
                activeRecording['status'] == 'paused')) {
          // Check if the active recording is for a different task
          final activeTaskId = activeRecording['taskId'];
          if (activeTaskId != _currentTask?.id) {
            _showErrorSnackBar(
              'Another task is currently being recorded. Please stop it first.',
            );
            return;
          }
          // If it's the same task, we can proceed to resume it
        }
      }
      _recordingService.resumeRecording();
    } else {
      _recordingService.pauseRecording();
    }
  }

  Future<void> _stopRecording() async {
    if (_currentTask == null) return;

    final success = await _recordingService.finishRecording(_currentTask!.id);
    if (success) {
      // Stop global recording
      await _globalRecordingService.stopGlobalRecording();

      // Update task data to reflect completed status in UI
      await _updateCurrentTaskData();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task completed successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      _showErrorSnackBar('Failed to complete task');
    }
  }

  /// Initialize the current task state from existing database data
  Future<void> _initializeCurrentTaskState(Task task) async {
    final AuthService authService = AuthService();
    final mechanicId = authService.currentMechanicId;

    if (mechanicId != null) {
      // Check if this specific task is currently being recorded
      final activeRecording = await _globalRecordingService
          .getActiveRecordingForMechanic(mechanicId);

      if (activeRecording != null && activeRecording['taskId'] == task.id) {
        // This task is actively being recorded - set UI state
        final durationFromDB = activeRecording['duration'] as int? ?? 0;
        final statusFromDB = activeRecording['status'] as String? ?? 'running';

        // IMPORTANT: Restore GlobalRecordingService state to ensure proper synchronization
        // This fixes the issue where resume/stop buttons don't show after app restart
        await _globalRecordingService.startGlobalRecording(task, widget.jobId);

        // Also restore the recording timer to ensure duration continues to update
        await _globalRecordingService.restoreRecordingTimer(
          mechanicId,
          task.id,
        );

        if (mounted) {
          setState(() {
            _isRecording = true;
            _isPaused = statusFromDB == 'paused';
            _currentDuration = Duration(seconds: durationFromDB);
          });

          // Start animations if recording and not paused
          if (_isRecording && !_isPaused) {
            _pulseController.repeat(reverse: true);
            _rotationController.repeat();
          } else {
            _pulseController.stop();
            _rotationController.stop();
          }
        }
      } else {
        // Task is not being recorded - check if it's completed and show actual time
        if (mounted) {
          Duration displayDuration = Duration.zero;

          // If task is completed, show the actual time spent from database
          if (task.status == TaskStatus.completed && task.actualTime != null) {
            // actualTime is now stored in seconds, so convert directly to Duration
            displayDuration = Duration(seconds: task.actualTime!.round());
          }

          setState(() {
            _isRecording = false;
            _isPaused = false;
            _currentDuration = displayDuration;
          });

          _pulseController.stop();
          _rotationController.stop();
        }
      }
    }
  }

  Future<void> _navigateToNextTask() async {
    final nextTask = _recordingService.getNextTask(_tasks, _currentTaskIndex);
    if (nextTask != null) {
      // Don't stop any recordings - just update UI to reflect new task
      // Stop animations immediately
      _pulseController.stop();
      _rotationController.stop();

      setState(() {
        _currentTaskIndex++;
        _currentTask = nextTask;
        // Don't reset recording state here - let the listener handle it
      });

      _updateCurrentTaskData();
    } else {
      // All tasks completed, show completion dialog
      _showCompletionDialog();
    }
  }

  Future<void> _navigateToPreviousTask() async {
    final previousTask = _recordingService.getPreviousTask(
      _tasks,
      _currentTaskIndex,
    );
    if (previousTask != null) {
      // Don't stop any recordings - just update UI to reflect new task
      // Stop animations immediately
      _pulseController.stop();
      _rotationController.stop();

      setState(() {
        _currentTaskIndex--;
        _currentTask = previousTask;
        // Don't reset recording state here - let the listener handle it
      });

      _updateCurrentTaskData();
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Job Completed!'),
        content: const Text('All tasks have been completed successfully.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back to tasks screen
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showCompletedTaskDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Task Already Completed'),
        content: const Text(
          'This task has already been completed. Would you like to start over or resume timing?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startOverTask();
            },
            child: const Text('Start Over'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resumeTask();
            },
            child: const Text('Resume'),
          ),
        ],
      ),
    );
  }

  Future<void> _startOverTask() async {
    if (_currentTask == null) return;

    // Check if there's already an active recording running
    final authService = AuthService();
    final mechanicId = authService.currentMechanicId;
    if (mechanicId != null) {
      final activeRecording = await _globalRecordingService
          .getActiveRecordingForMechanic(mechanicId);
      if (activeRecording != null &&
          (activeRecording['status'] == 'running' ||
              activeRecording['status'] == 'paused')) {
        _showErrorSnackBar(
          'Another task is currently being recorded. Please stop it first.',
        );
        return;
      }
    }

    // Reset task to pending status - clear all completion fields
    await _recordingService.updateTaskStatus(
      _currentTask!.id,
      TaskStatus.pending,
      clearStartedAt: true,
      clearCompletedAt: true,
      clearCancelledAt: true,
      clearActualTime: true,
    );

    // Refresh task data and start recording
    await _updateCurrentTaskData();
    await _startRecording();
  }

  Future<void> _resumeTask() async {
    if (_currentTask == null) return;

    // Check if there's already an active recording running
    final authService = AuthService();
    final mechanicId = authService.currentMechanicId;
    if (mechanicId != null) {
      final activeRecording = await _globalRecordingService
          .getActiveRecordingForMechanic(mechanicId);
      if (activeRecording != null &&
          (activeRecording['status'] == 'running' ||
              activeRecording['status'] == 'paused')) {
        _showErrorSnackBar(
          'Another task is currently being recorded. Please stop it first.',
        );
        return;
      }
    }

    // Get the existing actualTime to continue from where we left off
    final existingActualTime = _currentTask!.actualTime?.round() ?? 0;

    // Set task back to inProgress and clear only completion fields (preserve actualTime)
    await _recordingService.updateTaskStatus(
      _currentTask!.id,
      TaskStatus.inProgress,
      startedAt: DateTime.now(), // Set new start time
      clearCompletedAt: true, // Clear completion time
      clearCancelledAt: true, // Clear cancellation time
      // NOTE: Do NOT clear actualTime - preserve existing time to continue from where left off
    );

    // Refresh task data
    await _updateCurrentTaskData();

    // Start recording with existing time as initial duration
    final success = await _recordingService.startRecording(
      _currentTask!.id,
      widget.jobId,
      initialDurationSeconds: existingActualTime,
    );

    if (success) {
      // Start global recording for persistent bar
      await _globalRecordingService.startGlobalRecording(
        _currentTask!,
        widget.jobId,
      );
    } else {
      _showErrorSnackBar('Failed to resume recording');
    }
  }

  Future<void> _updateCurrentTaskData() async {
    if (_currentTask == null) return;

    try {
      // Reload the current task from the database to get latest data
      final tasks = await _recordingService.getTasksForJob(widget.jobId);
      final updatedTask = tasks.firstWhere(
        (task) => task.id == _currentTask!.id,
        orElse: () => _currentTask!,
      );

      // Find which task (if any) is actually recording
      Task? actualRecordingTask;
      for (final task in tasks) {
        if (await _recordingService.isTaskCurrentlyRecording(task)) {
          actualRecordingTask = task;
          break;
        }
      }

      setState(() {
        _tasks = tasks;
        _currentTask = updatedTask;
        // Don't set _currentDuration, _isRecording, or _isPaused here
        // Let _initializeCurrentTaskState handle the proper state from database
      });

      // Initialize UI state for the updated task from database
      await _initializeCurrentTaskState(updatedTask);

      // Update global recording state if needed
      if (actualRecordingTask != null) {
        await _globalRecordingService.startGlobalRecording(
          actualRecordingTask,
          widget.jobId,
        );
      }
    } catch (e) {
      print('Error updating task data: $e');
    }
  }

  Future<void> _handleBackNavigation() async {
    // Ensure global recording state is maintained when leaving the screen
    if (_isRecording && _currentTask != null) {
      // Make sure global recording service knows about the active recording
      await _globalRecordingService.startGlobalRecording(
        _currentTask!,
        widget.jobId,
      );
    }

    // Navigate back
    Navigator.pop(context);
  }

  /// Get status color for task status badge
  Color _getStatusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.pending:
        return Colors.orange;
      case TaskStatus.inProgress:
        return const Color(0xFF5B5BF7);
      case TaskStatus.completed:
        return Colors.green;
      case TaskStatus.cancelled:
        return Colors.red;
    }
  }

  /// Get status text for task status badge
  String _getStatusText(TaskStatus status) {
    switch (status) {
      case TaskStatus.pending:
        return 'PENDING';
      case TaskStatus.inProgress:
        return 'IN PROGRESS';
      case TaskStatus.completed:
        return 'COMPLETED';
      case TaskStatus.cancelled:
        return 'CANCELLED';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF5B5BF7)),
        ),
      );
    }

    if (_currentTask == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => _handleBackNavigation(),
          ),
        ),
        body: const Center(
          child: Text(
            'No tasks found',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        await _handleBackNavigation();
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildProgressBar(),
              Expanded(child: _buildMainContent()),
              _buildControls(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
            onPressed: () => _handleBackNavigation(),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  _job?.title ?? 'Job',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  _recordingService.getProgressText(
                    _currentTaskIndex,
                    _tasks.length,
                  ),
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(width: 48), // Balance the back button
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = _recordingService.calculateProgress(
      _currentTaskIndex,
      _tasks.length,
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF5B5BF7)),
            minHeight: 4,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Task ${_currentTaskIndex + 1}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                '${_tasks.length} Total',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Task Title
          Text(
            _currentTask!.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Task Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getStatusColor(_currentTask!.status),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _getStatusText(_currentTask!.status),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Task Description
          if (_currentTask!.description.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _currentTask!.description,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          const SizedBox(height: 20),

          // Recording Visualization
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _isRecording && !_isPaused ? _pulseAnimation.value : 1.0,
                child: AnimatedBuilder(
                  animation: _rotationAnimation,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _isRecording && !_isPaused
                          ? _rotationAnimation.value * 2 * 3.14159
                          : 0,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: _isRecording
                                ? [
                                    const Color(0xFF5B5BF7),
                                    const Color(0xFF7B68EE),
                                  ]
                                : [Colors.white24, Colors.white12],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: _isRecording
                              ? [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF5B5BF7,
                                    ).withValues(alpha: 0.3),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                ]
                              : null,
                        ),
                        child: Icon(
                          _isRecording
                              ? (_isPaused
                                    ? Icons.pause
                                    : Icons.fiber_manual_record)
                              : Icons.play_arrow,
                          size: 50,
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),

          const SizedBox(height: 20),

          // Timer Display
          Text(
            _recordingService.formatDurationWithHours(_currentDuration),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w300,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),

          const SizedBox(height: 10),

          // Remaining Time (only show if recording and has estimated time)
          if (_isRecording && _currentTask!.estimatedTime != null)
            _buildRemainingTimeDisplay(),

          // Estimated Time
          if (_currentTask!.estimatedTime != null)
            Text(
              'Estimated: ${_recordingService.formatDurationWithHours(Duration(seconds: _currentTask!.estimatedTime!.toInt()))}',
              style: const TextStyle(color: Colors.white60, fontSize: 14),
            ),
        ],
      ),
    );
  }

  Widget _buildRemainingTimeDisplay() {
    final estimatedSeconds = _currentTask!.estimatedTime!
        .toInt(); // estimatedTime is now in seconds
    final elapsedSeconds = _currentDuration.inSeconds;
    final remainingSeconds = estimatedSeconds - elapsedSeconds;

    String displayText;
    Color textColor;

    if (remainingSeconds > 0) {
      // Still have time remaining
      final remainingDuration = Duration(seconds: remainingSeconds);
      displayText =
          'Remaining: ${_recordingService.formatDurationWithHours(remainingDuration)}';
      textColor = Colors.green;
    } else if (remainingSeconds == 0) {
      // Exactly at estimated time
      displayText = 'Time Complete!';
      textColor = Colors.orange;
    } else {
      // Over the estimated time
      final overtimeSeconds = -remainingSeconds;
      final overtimeDuration = Duration(seconds: overtimeSeconds);
      displayText =
          'Overtime: +${_recordingService.formatDurationWithHours(overtimeDuration)}';
      textColor = Colors.red;
    }

    return Text(
      displayText,
      style: TextStyle(
        color: textColor,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Navigation and main control row
          Padding(
            padding: const EdgeInsets.only(bottom: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Previous Task
                IconButton(
                  onPressed: _currentTaskIndex > 0
                      ? _navigateToPreviousTask
                      : null,
                  icon: const Icon(Icons.skip_previous, size: 32),
                  color: _currentTaskIndex > 0 ? Colors.white : Colors.white30,
                ),

                // Main Control Button - Show Resume and Stop when paused
                if (_isRecording && _isPaused)
                  // When paused: show Resume and Stop buttons side by side
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: _pauseResumeRecording,
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Colors.blue, Colors.blueAccent],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withValues(alpha: 0.3),
                                blurRadius: 15,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.play_arrow,
                            size: 30,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: _stopRecording,
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Colors.red, Colors.redAccent],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withValues(alpha: 0.3),
                                blurRadius: 15,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.stop,
                            size: 30,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  // Normal single control button (play/pause)
                  GestureDetector(
                    onTap: _isRecording
                        ? _pauseResumeRecording
                        : _startRecording,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF5B5BF7), Color(0xFF7B68EE)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF5B5BF7,
                            ).withValues(alpha: 0.3),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        _isRecording ? Icons.pause : Icons.play_arrow,
                        size: 36,
                        color: Colors.white,
                      ),
                    ),
                  ),

                // Next Task
                IconButton(
                  onPressed: _currentTaskIndex < _tasks.length - 1
                      ? _navigateToNextTask
                      : null,
                  icon: const Icon(Icons.skip_next, size: 32),
                  color: _currentTaskIndex < _tasks.length - 1
                      ? Colors.white
                      : Colors.white30,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Set disposed flag first to prevent any setState calls
    _isDisposed = true;

    // Cancel subscription before disposing controllers
    _recordingStateSubscription?.cancel();
    _recordingStateSubscription = null;

    // Dispose animation controllers
    _pulseController.dispose();
    _rotationController.dispose();

    // Don't dispose the singleton service
    super.dispose();
  }
}
