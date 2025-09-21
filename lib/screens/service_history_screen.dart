import 'package:flutter/material.dart';
import '../services/service_history_service.dart';
import '../utils/date_time_helper.dart';

class ServiceHistoryScreen extends StatefulWidget {
  final String vehicleId;
  final String? vehicleName;

  const ServiceHistoryScreen({
    Key? key,
    required this.vehicleId,
    this.vehicleName,
  }) : super(key: key);

  @override
  State<ServiceHistoryScreen> createState() => _ServiceHistoryScreenState();
}

class _ServiceHistoryScreenState extends State<ServiceHistoryScreen> {
  final ServiceHistoryService _serviceHistoryService = ServiceHistoryService();
  List<Map<String, dynamic>> _serviceHistory = [];
  Map<String, dynamic>? _vehicleDetails;
  Map<String, dynamic>? _equipmentDetails;
  Map<String, dynamic> _statistics = {};
  bool _isLoading = true;
  Set<String> _expandedJobs = {};
  bool _isEquipment = false;

  @override
  void initState() {
    super.initState();
    _loadServiceHistory();
  }

  Future<void> _loadServiceHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final history = await _serviceHistoryService.getVehicleServiceHistory(
        widget.vehicleId,
      );

      // Try to get vehicle details first
      final vehicleDetails = await _serviceHistoryService.getVehicleDetails(
        widget.vehicleId,
      );

      // If no vehicle details, try equipment
      Map<String, dynamic>? equipmentDetails;
      bool isEquipment = false;
      if (vehicleDetails == null) {
        equipmentDetails = await _serviceHistoryService.getEquipmentDetails(
          widget.vehicleId,
        );
        isEquipment = equipmentDetails != null;
      }

      final statistics = _serviceHistoryService.getServiceStatistics(history);

      setState(() {
        _serviceHistory = history;
        _vehicleDetails = vehicleDetails;
        _equipmentDetails = equipmentDetails;
        _isEquipment = isEquipment;
        _statistics = statistics;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading service history: $e')),
      );
    }
  }

  void _toggleJobExpansion(String jobId) {
    setState(() {
      if (_expandedJobs.contains(jobId)) {
        _expandedJobs.remove(jobId);
      } else {
        _expandedJobs.add(jobId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          // App Bar with Vehicle Info
          SliverAppBar(
            expandedHeight:
            320, // Increased from 280 to accommodate asset attributes
            pinned: true,
            backgroundColor: const Color(0xFF5B5BF7),
            foregroundColor: Colors.white,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF5B5BF7), Color(0xFF4338CA)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 60),
                        // Asset Info (Vehicle or Equipment)
                        Flexible(
                          child: Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: _buildAssetImage(),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _buildAssetTitle(),
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    ..._buildAssetAttributes(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Service Statistics
                        if (_statistics.isNotEmpty) _buildServiceStats(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Service History Content
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_serviceHistory.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'No service history found',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This vehicle has no recorded service jobs yet.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final job = _serviceHistory[index];
                  return _buildJobCard(job);
                }, childCount: _serviceHistory.length),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildServiceStats() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Jobs',
            '${_statistics['totalJobs'] ?? 0}',
            Icons.work_outline,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Completed',
            '${_statistics['completedJobs'] ?? 0}',
            Icons.check_circle_outline,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Total Cost',
            'RM ${(_statistics['totalCost'] ?? 0.0).toStringAsFixed(0)}',
            Icons.account_balance,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    final bool isExpanded = _expandedJobs.contains(job['id']);
    final List<dynamic> tasks = job['tasks'] ?? [];
    final Map<String, dynamic>? mechanic = job['mechanic'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Job Header
          InkWell(
            onTap: () => _toggleJobExpansion(job['id']),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Job Title and Status
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          job['title'] ?? 'Untitled Job',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      _buildStatusChip(job['status']),
                      const SizedBox(width: 8),
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.grey.shade600,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Job Info Row
                  Row(
                    children: [
                      // Mechanic Info
                      if (mechanic != null) ...[
                        Icon(
                          Icons.person,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          mechanic['name'] ?? 'Unknown Mechanic',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(width: 16),
                      ],
                      // Date
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateTimeHelper.formatHybridDate(job['assignedAt']),
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const Spacer(),
                      // Task Count
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${tasks.length} tasks',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Cost and Duration
                  if (job['actualCost'] != null ||
                      job['estimatedCost'] != null ||
                      job['actualDuration'] != null ||
                      job['estimatedDuration'] != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (job['actualCost'] != null ||
                            job['estimatedCost'] != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            'RM ${((job['actualCost'] ?? job['estimatedCost']) as num).toStringAsFixed(2)}',
                            style: TextStyle(
                              color: Colors.green.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 16),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Expandable Tasks Section
          if (isExpanded && tasks.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
              ),
              child: Column(
                children: [
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tasks (${tasks.length})',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...tasks.map((task) => _buildTaskItem(task)).toList(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTaskItem(Map<String, dynamic> task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // Task Status Icon
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: _getTaskStatusColor(task['status']),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getTaskStatusIcon(task['status']),
              size: 14,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          // Task Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task['title'] ?? 'Untitled Task',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                if (task['description'] != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    task['description'],
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (task['completedAt'] != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Completed: ${DateTimeHelper.formatHybridDate(task['completedAt'])}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.green.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Task Duration
          if (task['actualTime'] != null || task['estimatedTime'] != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                DateTimeHelper.formatReadableDuration(
                  (task['actualTime'] ?? task['estimatedTime'])?.toDouble(),
                ),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String? status) {
    Color color;
    String displayText;

    switch (status?.toLowerCase()) {
      case 'completed':
        color = Colors.green;
        displayText = 'Completed';
        break;
      case 'inprogress':
      case 'in_progress':
        color = Colors.blue;
        displayText = 'In Progress';
        break;
      case 'assigned':
        color = Colors.orange;
        displayText = 'Assigned';
        break;
      case 'accepted':
        color = Colors.green;
        displayText = 'Accepted';
        break;
      case 'onhold':
      case 'on_hold':
        color = Colors.red;
        displayText = 'On Hold';
        break;
      case 'cancelled':
        color = Colors.grey;
        displayText = 'Cancelled';
        break;
      default:
        color = Colors.grey;
        displayText = status?.toUpperCase() ?? 'Unknown';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Color _getTaskStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'inprogress':
      case 'in_progress':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getTaskStatusIcon(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return Icons.check;
      case 'inprogress':
      case 'in_progress':
        return Icons.play_arrow;
      case 'cancelled':
        return Icons.close;
      default:
        return Icons.radio_button_unchecked;
    }
  }

  /// Build asset image (vehicle or equipment photo)
  Widget _buildAssetImage() {
    List<String>? photos;
    IconData fallbackIcon;

    if (_isEquipment && _equipmentDetails != null) {
      photos = (_equipmentDetails!['photos'] as List<dynamic>?)?.cast<String>();
      fallbackIcon = Icons.build;
    } else if (_vehicleDetails != null) {
      photos = (_vehicleDetails!['photos'] as List<dynamic>?)?.cast<String>();
      fallbackIcon = Icons.directions_car;
    } else {
      fallbackIcon = Icons.help_outline;
    }

    if (photos != null && photos.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          photos.first,
          width: 60,
          height: 60,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              Icon(fallbackIcon, color: Colors.white, size: 32),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Icon(fallbackIcon, color: Colors.white, size: 32);
          },
        ),
      );
    } else {
      return Icon(fallbackIcon, color: Colors.white, size: 32);
    }
  }

  /// Build asset title (vehicle or equipment name)
  String _buildAssetTitle() {
    if (_isEquipment && _equipmentDetails != null) {
      return '${_equipmentDetails!['year']} ${_equipmentDetails!['manufacturer']} ${_equipmentDetails!['model']}';
    } else if (_vehicleDetails != null) {
      return '${_vehicleDetails!['year']} ${_vehicleDetails!['make']} ${_vehicleDetails!['model']}';
    } else {
      return widget.vehicleName ?? 'Service History';
    }
  }

  /// Build asset attributes (vehicle or equipment specific info)
  List<Widget> _buildAssetAttributes() {
    if (_isEquipment && _equipmentDetails != null) {
      return [
        Text(
          'Serial: ${_equipmentDetails!['serialNumber'] ?? 'N/A'}',
          style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.9)),
        ),
        Text(
          'Category: ${_equipmentDetails!['category'] ?? 'N/A'}',
          style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.9)),
        ),
        Text(
          'Condition: ${_equipmentDetails!['condition'] ?? 'N/A'}',
          style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.9)),
        ),
      ];
    } else if (_vehicleDetails != null) {
      return [
        Text(
          'VIN: ${_vehicleDetails!['vin'] ?? 'N/A'}',
          style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.9)),
        ),
        Text(
          'License: ${_vehicleDetails!['licensePlate'] ?? 'N/A'}',
          style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.9)),
        ),
        Text(
          'Mileage: ${_vehicleDetails!['mileage'] ?? 'N/A'}',
          style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.9)),
        ),
      ];
    } else {
      return [
        Text(
          'Asset information not available',
          style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.7)),
        ),
      ];
    }
  }
}
