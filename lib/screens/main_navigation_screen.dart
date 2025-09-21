import 'package:flutter/material.dart';
import 'package:mechlink/screens/dashboard_screen.dart';
import 'package:mechlink/screens/jobs_screen.dart';
import 'package:mechlink/screens/notes_screen.dart';
import 'package:mechlink/screens/profile_screen.dart';
import 'package:mechlink/screens/chats_screen.dart';
import '../services/global_recording_service.dart';
import '../services/auth_service.dart';
import '../services/task_recording_service.dart';
import '../widgets/persistent_recording_bar.dart';
import '../models/task.dart';
import '../models/service_request.dart';
import 'dart:async';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  final GlobalRecordingService _globalRecordingService =
      GlobalRecordingService();
  final AuthService _authService = AuthService();

  Task? _recordingTask;
  String? _recordingJobId;
  StreamSubscription? _recordingTaskSubscription;
  StreamSubscription? _recordingJobIdSubscription;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const JobsScreen(),
    const NotesScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _setupRecordingListeners();
    _initializeGlobalRecording();
    _setupRealtimeRecordingListener();
  }

  Future<void> _initializeGlobalRecording() async {
    // Check if there are any ongoing recordings for the current user
    try {
      final mechanicId = _authService.currentMechanicId;
      if (mechanicId != null) {
        // Check for active recordings in Realtime Database
        final activeRecording = await _globalRecordingService
            .getActiveRecordingForMechanic(mechanicId);

        if (activeRecording != null) {
          print('Found active recording for mechanic: $mechanicId');
          final taskId = activeRecording['taskId'] as String;
          final jobId = activeRecording['jobId'] as String? ?? 'unknown';

          // Create a task object for the persistent bar
          // We'll use a simple task since we just need it for display
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

          // Set the global recording state directly
          await _globalRecordingService.startGlobalRecording(
            recordingTask,
            jobId,
          );
          // IMPORTANT: Also restore the recording timer to ensure duration continues to update
          await _globalRecordingService.restoreRecordingTimer(
            mechanicId,
            taskId,
          );

          // IMPORTANT: Initialize TaskRecordingService for the existing recording
          // This ensures PersistentRecordingBar can pause/resume/stop properly
          // UI layer properly initializes UI service - maintains separation of concerns
          final TaskRecordingService taskRecordingService =
              TaskRecordingService();
          await taskRecordingService.initializeForExistingRecording(taskId);
        } else {
          print('No active recordings found for current user');
        }
      } else {
        print('No authenticated user found');
      }
    } catch (e) {
      print('Error initializing global recording: $e');
    }
  }

  void _setupRecordingListeners() {
    _recordingTaskSubscription = _globalRecordingService.recordingTaskStream
        .listen((task) {
          setState(() {
            _recordingTask = task;
          });
        });

    _recordingJobIdSubscription = _globalRecordingService.recordingJobIdStream
        .listen((jobId) {
          setState(() {
            _recordingJobId = jobId;
          });
        });
  }

  void _setupRealtimeRecordingListener() {
    // Listen to real-time changes in recording status
    final mechanicId = _authService.currentMechanicId;
    if (mechanicId != null) {
      _globalRecordingService.listenToMechanicRecordings(mechanicId).listen((
        recordingData,
      ) {
        if (recordingData != null) {
          // A recording was started or updated
          // print('Real-time recording update detected: ${recordingData['taskId']}',);

          // Check if we need to initialize the global recording state
          if (_globalRecordingService.currentRecordingTask == null) {
            final taskId = recordingData['taskId'] as String;

            // Create a task object for the persistent bar
            final recordingTask = Task(
              id: taskId,
              jobId: 'active_job',
              title: 'Recording Task',
              description: 'Task currently being recorded',
              priority: Priority.medium,
              status: TaskStatus.inProgress,
              estimatedTime: 1.0,
              order: 1,
              difficultyLevel: DifficultyLevel.medium,
            );

            // Set the global recording state
            _globalRecordingService.startGlobalRecording(
              recordingTask,
              'active_job',
            );
          }
        } else {
          // No active recordings
          print('No active recordings detected in real-time');
          _globalRecordingService.stopGlobalRecording();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        extendBody: true, // 👈 important: lets background show behind nav bar
        body: Column(
          children: [
            // Persistent recording bar
            if (_recordingTask != null && _recordingJobId != null)
              PersistentRecordingBar(
                recordingTask: _recordingTask!,
                jobId: _recordingJobId!,
                onDismiss: () {
                  _globalRecordingService.stopGlobalRecording();
                },
              ),
            // Main content
            Expanded(
              child: IndexedStack(index: _selectedIndex, children: _screens),
            ),
          ],
        ),
        bottomNavigationBar: CustomBottomNavigationBar(
          selectedIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
        ),
        floatingActionButton: Container(
          width: 60,
          height: 60,
          margin: const EdgeInsets.only(top: 50), // Lower the button further
          decoration: BoxDecoration(
            color: const Color(0xFF613EEA),
            borderRadius: BorderRadius.circular(50),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF613EEA).withValues(alpha: 0.5),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IconButton(
            onPressed: () {
              // Navigate to AI Chat Assistant
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ChatsScreen()),
              );
            },
            icon: const Icon(Icons.build_circle, color: Colors.white, size: 35),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      ),
    );
  }

  @override
  void dispose() {
    _recordingTaskSubscription?.cancel();
    _recordingJobIdSubscription?.cancel();
    super.dispose();
  }
}

class CustomBottomNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTap;

  const CustomBottomNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: CustomPaint(
              size: Size(MediaQuery.of(context).size.width, 90),
              painter: BottomNavPainter(),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 75,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left side buttons
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildNavItem(0, Icons.dashboard, 'Dashboard'),
                        _buildNavItem(1, Icons.work, 'Jobs'),
                      ],
                    ),
                  ),
                  // Space for FAB in the middle
                  const SizedBox(width: 80),
                  // Right side buttons
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildNavItem(2, Icons.note_alt, 'Notes'),
                        _buildNavItem(3, Icons.person_2_rounded, 'Profile'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final bool isSelected = selectedIndex == index;
    final Color color = isSelected
        ? const Color.fromARGB(255, 142, 47, 231)
        : const Color(0xFF9DB2CE);

    return GestureDetector(
      onTap: () => onTap(index),
      child: Container(
        width: 70,
        height: 60,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 23, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w400,
                fontFamily: 'SF Pro Text',
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // Active indicator - thin horizontal line
            Container(
              width: 30,
              height: 2,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color.fromARGB(255, 142, 47, 231)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BottomNavPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Gradient fill paint
    final Paint fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color.fromARGB(255, 187, 193, 255),
          const Color.fromARGB(255, 241, 229, 255),
          const Color.fromARGB(255, 253, 252, 255),
          const Color.fromARGB(255, 253, 252, 255),
        ],
        stops: [0.0, 0.32, 0.66, 1.0],
      ).createShader(rect)
      ..style = PaintingStyle.fill;

    // Border paint
    final Paint borderPaint = Paint()
      ..color =
          const Color.fromARGB(
            47,
            112,
            73,
            228,
          ) // purple border (change as needed)
      ..strokeWidth =
          2.0 // border thickness
      ..style = PaintingStyle.stroke;

    final Path path = Path();

    final double width = size.width;
    final double height = size.height;

    final double scaleX = width / 428.0;
    final double scaleY = height / 81.0;

    double sx(double x) => x * scaleX;
    double sy(double y) => y * scaleY;

    path.moveTo(0, sy(28));

    path.cubicTo(0, sy(21.9), sx(4.7), sy(16.8), sx(10.8), sy(16.2));
    path.lineTo(sx(164.1), sy(0.95));
    path.cubicTo(sx(171.9), sy(0.18), sx(178), sy(9.16), sx(178), sy(17));
    path.cubicTo(sx(178), sy(36.88), sx(194.1), sy(53), sx(214), sy(53));
    path.cubicTo(sx(233.9), sy(53), sx(250), sy(36.88), sx(250), sy(17));
    path.cubicTo(sx(250), sy(9.16), sx(256.1), sy(0.18), sx(263.9), sy(0.95));
    path.lineTo(sx(417.2), sy(16.2));
    path.cubicTo(sx(423.3), sy(16.8), width, sy(21.9), width, sy(28.1));

    path.lineTo(width, sy(67));
    path.cubicTo(width, sy(74.7), sx(421.7), height, sx(414), height);
    path.lineTo(sx(14), height);
    path.cubicTo(sx(6.3), height, 0, sy(74.7), 0, sy(67));
    path.close();

    // Draw fill first
    canvas.drawPath(path, fillPaint);

    // Draw border on top
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
