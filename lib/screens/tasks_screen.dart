import 'package:flutter/material.dart';
import 'package:mechlink/services/tasks_service.dart';
import 'task_recording_screen.dart';
import '../utils/date_time_helper.dart';

class TasksScreen extends StatefulWidget {
  final String jobId;

  const TasksScreen({super.key, required this.jobId});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final TasksService _tasksService = TasksService();

  List<Map<String, dynamic>> _tasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    try {
      List<Map<String, dynamic>> tasks = await _tasksService.getTasksByJobId(
        widget.jobId,
      );
      setState(() {
        _tasks = tasks;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading tasks: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tasks (${_tasks.length})'),
        backgroundColor: Colors.orange.shade600,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading tasks...'),
                ],
              ),
            )
          : _tasks.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.task_alt, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No tasks available for this job',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Tasks will appear here once they are created',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadTasks,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _tasks.length,
                itemBuilder: (context, index) {
                  final task = _tasks[index];
                  return _buildTaskCard(
                    task,
                    index + 1,
                  ); // Pass task number (1-based)
                },
              ),
            ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task, int taskNumber) {
    final status = task['status'] ?? 'pending';
    final priority = task['priority'] ?? 'medium';

    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'inProgress':
        statusColor = Colors.blue;
        statusIcon = Icons.play_circle;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.radio_button_unchecked;
    }

    Color priorityColor;
    switch (priority) {
      case 'high':
        priorityColor = Colors.red;
        break;
      case 'medium':
        priorityColor = Colors.orange;
        break;
      case 'low':
        priorityColor = Colors.green;
        break;
      default:
        priorityColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () => _showTaskDetails(task),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with task number, title, and priority
              Row(
                children: [
                  // Task number
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: statusColor, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        taskNumber.toString(),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(statusIcon, color: statusColor, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      task['title'] ?? 'Untitled Task',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: priorityColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: priorityColor),
                    ),
                    child: Text(
                      priority.toUpperCase(),
                      style: TextStyle(
                        color: priorityColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),

              // Description
              if (task['description'] != null &&
                  task['description'].isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  task['description'],
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                ),
              ],

              const SizedBox(height: 12),

              // Time information row
              Row(
                children: [
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),

                  // Estimated time
                  if (task['estimatedTime'] != null) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.schedule, color: Colors.grey.shade600, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Est: ${DateTimeHelper.formatDuration(task['estimatedTime']?.toDouble())}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],

                  // Actual time (if completed)
                  if (task['actualTime'] != null) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.timer, color: Colors.green.shade600, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Act: ${DateTimeHelper.formatDuration(task['actualTime']?.toDouble())}',
                      style: TextStyle(
                        color: Colors.green.shade600,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],

                  const Spacer(),
                  if (status != 'completed')
                    Icon(
                      Icons.chevron_right,
                      color: Colors.grey.shade400,
                      size: 20,
                    ),
                ],
              ),

              // Timestamps row
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  if (task['startedAt'] != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.play_arrow,
                          color: Colors.blue.shade600,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Started: ${DateTimeHelper.formatTimestamp(task['startedAt'])}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  if (task['completedAt'] != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check,
                          color: Colors.green.shade600,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Completed: ${DateTimeHelper.formatTimestamp(task['completedAt'])}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  if (task['cancelledAt'] != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.cancel,
                          color: Colors.red.shade600,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Cancelled: ${DateTimeHelper.formatTimestamp(task['cancelledAt'])}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTaskDetails(Map<String, dynamic> task) async {
    // Check job status before allowing navigation
    String? jobStatus = await _tasksService.getJobStatus(widget.jobId);

    // Prevent navigation if job status is assigned, cancelled, or accepted
    if (jobStatus == 'assigned' ||
        jobStatus == 'cancelled' ||
        jobStatus == 'accepted') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot access task recording when job status is ${jobStatus?.toUpperCase()}',
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    // Navigate to task recording screen and wait for return
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskRecordingScreen(
          taskId: task['id'] ?? '',
          jobId: task['jobId'] ?? '',
        ),
      ),
    );

    // Refresh tasks when returning from task recording screen
    await _loadTasks();
  }
}
