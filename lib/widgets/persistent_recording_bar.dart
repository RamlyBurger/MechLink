import 'package:flutter/material.dart';
import 'dart:async';
import '../models/task.dart';
import '../services/task_recording_service.dart';
import '../services/global_recording_service.dart';
import '../services/auth_service.dart';
import '../screens/task_recording_screen.dart';

class PersistentRecordingBar extends StatefulWidget {
  final Task recordingTask;
  final String jobId;
  final VoidCallback? onDismiss;

  const PersistentRecordingBar({
    Key? key,
    required this.recordingTask,
    required this.jobId,
    this.onDismiss,
  }) : super(key: key);

  @override
  State<PersistentRecordingBar> createState() => _PersistentRecordingBarState();
}

class _PersistentRecordingBarState extends State<PersistentRecordingBar>
    with TickerProviderStateMixin {
  final TaskRecordingService _recordingService = TaskRecordingService();
  Duration _currentDuration = Duration.zero;
  bool _isRecording = false;
  bool _isPaused = false;

  StreamSubscription? _durationSubscription;
  StreamSubscription? _recordingStateSubscription;
  StreamSubscription? _pauseStateSubscription;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  Timer? _durationTimer;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeState(); // This is now async but we don't await in initState
    _setupStreamListeners();
    _startDurationTimer();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _setupStreamListeners() {
    _durationSubscription = _recordingService.durationStream.listen((duration) {
      if (mounted) {
        setState(() {
          _currentDuration = duration;
        });
      }
    });

    _recordingStateSubscription = _recordingService.recordingStateStream.listen(
      (isRecording) {
        if (mounted) {
          setState(() {
            _isRecording = isRecording;
          });

          if (isRecording && !_isPaused) {
            _pulseController.repeat(reverse: true);
          } else {
            _pulseController.stop();
          }
        }
      },
    );

    _pauseStateSubscription = _recordingService.pauseStateStream.listen((
      isPaused,
    ) {
      if (mounted) {
        setState(() {
          _isPaused = isPaused;
        });

        if (isPaused) {
          _pulseController.stop();
        } else if (_isRecording) {
          _pulseController.repeat(reverse: true);
        }
      }
    });
  }

  Future<void> _initializeState() async {
    // Initialize the recording state for the persistent bar
    _currentDuration = await _recordingService.getCurrentDuration(
      widget.recordingTask,
    );
    _isRecording = await _recordingService.isTaskCurrentlyRecording(
      widget.recordingTask,
    );

    // Get actual pause state from database instead of relying on potentially uninitialized service state
    // This ensures we get the correct pause state even if TaskRecordingService hasn't been initialized yet
    final globalRecordingService = GlobalRecordingService();
    final authService = AuthService();
    final mechanicId = authService.currentMechanicId;

    if (mechanicId != null) {
      final activeRecording = await globalRecordingService
          .getActiveRecordingForMechanic(mechanicId);
      if (activeRecording != null &&
          activeRecording['taskId'] == widget.recordingTask.id) {
        final statusFromDB = activeRecording['status'] as String? ?? 'running';
        _isPaused = statusFromDB == 'paused';
      } else {
        _isPaused = false;
      }
    } else {
      _isPaused = false;
    }

    // Start animation if recording
    if (_isRecording && !_isPaused) {
      _pulseController.repeat(reverse: true);
    }

    // Update the UI
    if (mounted) {
      setState(() {});
    }
  }

  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_isRecording && !_isPaused) {
        final duration = await _recordingService.getCurrentDuration(
          widget.recordingTask,
        );
        if (mounted) {
          setState(() {
            _currentDuration = duration;
          });
        }
      }
    });
  }

  void _openRecordingScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskRecordingScreen(
          taskId: widget.recordingTask.id,
          jobId: widget.jobId,
        ),
      ),
    );
  }

  void _pauseResumeRecording() {
    if (_isPaused) {
      _recordingService.resumeRecording();
    } else {
      _recordingService.pauseRecording();
    }
  }

  Future<void> _stopRecording() async {
    final success = await _recordingService.finishRecording(
      widget.recordingTask.id,
    );
    if (success && widget.onDismiss != null) {
      widget.onDismiss!();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isRecording) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 60,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5B5BF7), Color(0xFF7B68EE)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _openRecordingScreen,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Recording indicator
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _isPaused ? 1.0 : _pulseAnimation.value,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isPaused ? Colors.orange : Colors.red,
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(width: 12),

                // Task info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Recording: ${widget.recordingTask.title}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _recordingService.formatDurationWithHours(
                          _currentDuration,
                        ),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),

                // Control buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Pause/Resume button
                    IconButton(
                      onPressed: _pauseResumeRecording,
                      icon: Icon(
                        _isPaused ? Icons.play_arrow : Icons.pause,
                        color: Colors.white,
                        size: 20,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      padding: EdgeInsets.zero,
                    ),

                    // Stop button
                    IconButton(
                      onPressed: _stopRecording,
                      icon: const Icon(
                        Icons.stop,
                        color: Colors.white,
                        size: 20,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _durationTimer?.cancel();
    _durationSubscription?.cancel();
    _recordingStateSubscription?.cancel();
    _pauseStateSubscription?.cancel();
    super.dispose();
  }
}
