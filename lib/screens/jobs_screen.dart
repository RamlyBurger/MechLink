import 'package:flutter/material.dart';
import 'package:mechlink/services/jobs_service.dart';
import 'package:mechlink/services/auth_service.dart';
import 'package:mechlink/screens/job_detail_screen.dart';
import 'package:mechlink/screens/tasks_screen.dart';
import '../utils/date_time_helper.dart';

class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  final JobsService _jobsService = JobsService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _jobs = [];
  bool _isLoading = true;
  bool _showDetailedInfo = false;
  bool _isListView = false;

  // Filter options
  String _selectedStatus = 'all';
  String _selectedPriority = 'all';
  String _selectedServiceType = 'all';
  String _sortBy = 'assignedAt';
  bool _sortDescending = true;

  Map<String, List<String>> _filterOptions = {};
  Map<String, String> _sortOptions = {};

  // Quick filter options
  final List<Map<String, dynamic>> _quickFilters = [
    {
      'label': 'All Jobs',
      'status': 'all',
      'priority': 'all',
      'serviceType': 'all',
    },
    {
      'label': 'In Progress',
      'status': 'inProgress',
      'priority': 'all',
      'serviceType': 'all',
    },
    {
      'label': 'High Priority',
      'status': 'all',
      'priority': 'high',
      'serviceType': 'all',
    },
    {
      'label': 'Vehicles',
      'status': 'all',
      'priority': 'all',
      'serviceType': 'vehicle',
    },
    {
      'label': 'Equipment',
      'status': 'all',
      'priority': 'all',
      'serviceType': 'equipment',
    },
  ];
  int _selectedQuickFilter = 0;

  @override
  void initState() {
    super.initState();
    _initializeOptions();
    _loadJobs();
  }

  void _initializeOptions() {
    _filterOptions = _jobsService.getFilterOptions();
    _sortOptions = _jobsService.getSortOptions();
  }

  Future<void> _loadJobs() async {
    setState(() => _isLoading = true);
    try {
      // Get current mechanic ID - handle null case
      final mechanicId = _authService.currentMechanicId;

      if (mechanicId == null) {
        print('Warning: No current mechanic ID found');
        setState(() {
          _jobs = [];
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to view jobs')),
        );
        return;
      }

      List<Map<String, dynamic>> jobs = await _jobsService.getJobsWithDetails(
        mechanicId: mechanicId, // Filter by current mechanic
        status: _selectedStatus,
        priority: _selectedPriority,
        serviceType: _selectedServiceType,
        searchQuery: _searchController.text,
        sortBy: _sortBy,
        descending: _sortDescending,
      );
      setState(() {
        _jobs = jobs;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading jobs: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading jobs: $e')));
    }
  }

  void _applyFilters() {
    _loadJobs();
  }

  void _toggleView() {
    setState(() {
      _isListView = !_isListView;
    });
  }

  void _toggleDetailedInfo() {
    setState(() {
      _showDetailedInfo = !_showDetailedInfo;
    });
  }

  Widget _buildQuickFilters() {
    // Define colors for each filter
    final List<List<Color>> filterColors = [
      [
        Colors.blueGrey.shade400,
        Colors.blueGrey.shade600,
      ], // All Jobs - Blue Grey
      [Colors.cyan.shade400, Colors.cyan.shade600], // In Progress - Cyan
      [Colors.amber.shade400, Colors.amber.shade600], // High Priority - Amber
      [Colors.green.shade400, Colors.green.shade600], // Vehicles - Green
      [
        Colors.deepPurple.shade400,
        Colors.deepPurple.shade600,
      ], // Equipment - Deep Purple
    ];

    return Container(
      height: 32,
      margin: const EdgeInsets.fromLTRB(16, 2, 16, 6),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _quickFilters.length,
        itemBuilder: (context, index) {
          final filter = _quickFilters[index];
          final isSelected = _selectedQuickFilter == index;
          final colors = filterColors[index % filterColors.length];

          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedQuickFilter = index;
                  _selectedStatus = filter['status'];
                  _selectedPriority = filter['priority'];
                  _selectedServiceType = filter['serviceType'];
                });
                _applyFilters();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? colors[0] : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? colors[0] : Colors.grey.shade300,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected) ...[
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      filter['label'],
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey.shade700,
                        fontSize: 11,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _getReadableLabel(String item, String category) {
    if (item == 'all') {
      return 'All ${category}s';
    }

    // Convert technical field names to readable labels
    switch (item) {
      case 'assignedAt':
        return 'Assigned Date';
      case 'startedAt':
        return 'Started Date';
      case 'completedAt':
        return 'Completed Date';
      case 'customerName':
        return 'Customer Name';
      case 'taskCount':
        return 'Task Count';
      case 'estimatedDuration':
        return 'Estimated Duration';
      case 'inProgress':
        return 'In Progress';
      case 'pending':
        return 'Pending';
      case 'assigned':
        return 'Assigned';
      case 'completed':
        return 'Completed';
      case 'vehicle':
        return 'Vehicle';
      case 'equipment':
        return 'Equipment';
      case 'high':
        return 'High';
      case 'medium':
        return 'Medium';
      case 'low':
        return 'Low';
      default:
        // Capitalize first letter for other items
        return item.isNotEmpty
            ? '${item[0].toUpperCase()}${item.substring(1)}'
            : item;
    }
  }

  Widget _buildModernDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: Icon(
                Icons.keyboard_arrow_down,
                color: Colors.grey.shade600,
              ),
              style: TextStyle(color: Colors.grey.shade800, fontSize: 14),
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(
                    _getReadableLabel(item, label),
                    style: const TextStyle(fontSize: 14),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        String tempStatus = _selectedStatus;
        String tempPriority = _selectedPriority;
        String tempServiceType = _selectedServiceType;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.filter_list,
                            color: Colors.blue.shade600,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Filter Jobs',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(Icons.close, color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Status Filter
                    _buildModernDropdown(
                      label: 'Status',
                      value: tempStatus,
                      items: _filterOptions['status']!,
                      onChanged: (value) =>
                          setDialogState(() => tempStatus = value!),
                      icon: Icons.radio_button_checked,
                    ),
                    const SizedBox(height: 16),

                    // Priority Filter
                    _buildModernDropdown(
                      label: 'Priority',
                      value: tempPriority,
                      items: _filterOptions['priority']!,
                      onChanged: (value) =>
                          setDialogState(() => tempPriority = value!),
                      icon: Icons.priority_high,
                    ),
                    const SizedBox(height: 16),

                    // Service Type Filter
                    _buildModernDropdown(
                      label: 'Service Type',
                      value: tempServiceType,
                      items: _filterOptions['serviceType']!,
                      onChanged: (value) =>
                          setDialogState(() => tempServiceType = value!),
                      icon: Icons.build,
                    ),

                    const SizedBox(height: 32),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setDialogState(() {
                                tempStatus = 'all';
                                tempPriority = 'all';
                                tempServiceType = 'all';
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                            child: Text(
                              'Clear All',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue.shade400,
                                  Colors.blue.shade600,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _selectedStatus = tempStatus;
                                  _selectedPriority = tempPriority;
                                  _selectedServiceType = tempServiceType;
                                  _selectedQuickFilter = -1;
                                });
                                _applyFilters();
                                Navigator.of(context).pop();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Apply Filters',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSortDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        String tempSortBy = _sortBy;
        bool tempSortDescending = _sortDescending;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.sort,
                            color: Colors.purple.shade600,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Sort Jobs',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(Icons.close, color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Sort By Dropdown
                    _buildModernDropdown(
                      label: 'Sort By',
                      value: tempSortBy,
                      items: _sortOptions.keys.toList(),
                      onChanged: (value) =>
                          setDialogState(() => tempSortBy = value!),
                      icon: Icons.sort_by_alpha,
                    ),

                    const SizedBox(height: 20),

                    // Sort Order
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.swap_vert,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Order',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setDialogState(
                                  () => tempSortDescending = false,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: !tempSortDescending
                                        ? Colors.purple.shade50
                                        : Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: !tempSortDescending
                                          ? Colors.purple.shade300
                                          : Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.arrow_upward,
                                        size: 16,
                                        color: !tempSortDescending
                                            ? Colors.purple.shade600
                                            : Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Ascending',
                                        style: TextStyle(
                                          color: !tempSortDescending
                                              ? Colors.purple.shade600
                                              : Colors.grey.shade600,
                                          fontWeight: !tempSortDescending
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setDialogState(
                                  () => tempSortDescending = true,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: tempSortDescending
                                        ? Colors.purple.shade50
                                        : Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: tempSortDescending
                                          ? Colors.purple.shade300
                                          : Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.arrow_downward,
                                        size: 16,
                                        color: tempSortDescending
                                            ? Colors.purple.shade600
                                            : Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Descending',
                                        style: TextStyle(
                                          color: tempSortDescending
                                              ? Colors.purple.shade600
                                              : Colors.grey.shade600,
                                          fontWeight: tempSortDescending
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Action Button
                    SizedBox(
                      width: double.infinity,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.purple.shade400,
                              Colors.purple.shade600,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _sortBy = tempSortBy;
                              _sortDescending = tempSortDescending;
                            });
                            _applyFilters();
                            Navigator.of(context).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Apply Sorting',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8.0, 2.0, 16.0, 8.0),
      child: Row(
        children: [
          Transform.scale(
            scale: 0.8,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade400, Colors.blue.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: _showFilterDialog,
                icon: const Icon(
                  Icons.filter_list,
                  color: Colors.white,
                  size: 16,
                ),
                tooltip: 'Filter',
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ),
          ),

          // Sort button
          Transform.scale(
            scale: 0.8,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple.shade400, Colors.purple.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: _showSortDialog,
                icon: const Icon(Icons.sort, color: Colors.white, size: 16),
                tooltip: 'Sort',
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ),
          ),

          // Spacer to push right buttons to the right
          const Spacer(),

          // Details toggle button
          Transform.scale(
            scale: 0.8,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _showDetailedInfo
                      ? [Colors.orange.shade400, Colors.orange.shade600]
                      : [Colors.grey.shade400, Colors.grey.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: (_showDetailedInfo ? Colors.orange : Colors.grey)
                        .withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: _toggleDetailedInfo,
                icon: Icon(
                  _showDetailedInfo ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white,
                  size: 16,
                ),
                tooltip: _showDetailedInfo ? 'Hide Details' : 'Show Details',
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ),
          ),
          // View toggle button
          Transform.scale(
            scale: 0.8,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.deepPurple.shade400,
                    Colors.deepPurple.shade600,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepPurple.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: _toggleView,
                icon: Icon(
                  _isListView ? Icons.grid_view : Icons.list,
                  color: Colors.white,
                  size: 16, // shrink icon itself
                ),
                tooltip: _isListView ? 'Grid View' : 'List View',
                padding: EdgeInsets.all(8), // reduce touch padding
                constraints: BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ), // shrink button size
              ),
            ),
          ),
          // Refresh button
          Transform.scale(
            scale: 0.8,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.teal.shade400, Colors.teal.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.teal.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: _loadJobs,
                icon: const Icon(
                  Icons.refresh,
                  color: Colors.white,
                  size: 16,
                ), // smaller icon
                tooltip: 'Refresh',
                padding: const EdgeInsets.all(8), // shrink padding
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ), // shrink button size
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToJobDetail(job['documentId']),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Asset photo
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: job['assetPhoto'] != null
                      ? Colors.white
                      : Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: job['assetPhoto'] != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          job['assetPhoto'],
                          fit: BoxFit
                              .contain, // Changed to contain for consistent scaling
                          errorBuilder: (context, error, stackTrace) => Icon(
                            job['serviceType'] == 'vehicle'
                                ? Icons.directions_car
                                : Icons.build,
                            size: 32,
                            color: Colors.grey,
                          ),
                        ),
                      )
                    : Icon(
                        job['serviceType'] == 'vehicle'
                            ? Icons.directions_car
                            : Icons.build,
                        size: 32,
                        color: Colors.grey,
                      ),
              ),

              const SizedBox(width: 16),

              // Job details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row with title and chips
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            job['title'] ?? 'No Title',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Priority and Status chips in a row
                    Row(
                      children: [
                        _buildPriorityChip(job['priority']),
                        const SizedBox(width: 8),
                        _buildStatusChip(job['status']),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Customer and asset info
                    Row(
                      children: [
                        const Icon(Icons.person, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            job['customerName'] ?? 'Unknown Customer',
                            style: Theme.of(context).textTheme.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    Row(
                      children: [
                        Icon(
                          job['serviceType'] == 'vehicle'
                              ? Icons.directions_car
                              : Icons.build,
                          size: 16,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            job['assetName'] ?? 'No Asset',
                            style: Theme.of(context).textTheme.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    if (_showDetailedInfo) ...[
                      const SizedBox(height: 8),
                      const Divider(),

                      // Detailed information
                      if (job['assignedAt'] != null)
                        _buildDetailRow(
                          'Assigned',
                          DateTimeHelper.formatDate(job['assignedAt']),
                        ),

                      if (job['startedAt'] != null)
                        _buildDetailRow(
                          'Started',
                          DateTimeHelper.formatDate(job['startedAt']),
                        ),

                      if (job['completedAt'] != null)
                        _buildDetailRow(
                          'Completed',
                          DateTimeHelper.formatDate(job['completedAt']),
                        ),

                      if (job['customerRating'] != null)
                        _buildDetailRow('Rating', '${job['customerRating']} ⭐'),

                      _buildDetailRow(
                        'Tasks',
                        '${job['completedTaskCount'] ?? 0}/${job['taskCount']} tasks completed',
                      ),

                      if (job['estimatedDuration'] != null)
                        _buildDetailRow(
                          'Est. Duration',
                          '${job['estimatedDuration']}h',
                        ),
                    ],

                    const SizedBox(height: 12),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.teal.shade400,
                                  Colors.teal.shade600,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  _navigateToJobDetail(job['documentId']),
                              icon: const Icon(
                                Icons.info,
                                size: 16,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'Details',
                                style: TextStyle(color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.indigo.shade400,
                                  Colors.indigo.shade600,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  _navigateToTasks(job['documentId']),
                              icon: const Icon(
                                Icons.task,
                                size: 16,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'Tasks',
                                style: TextStyle(color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssetPhotosSection(Map<String, dynamic> job) {
    // Get photos from job data (already processed by JobsService)
    List<String> photos = [];

    // Use the assetPhotos array if available, otherwise fall back to single photo
    if (job['assetPhotos'] != null && job['assetPhotos'] is List) {
      photos = List<String>.from(job['assetPhotos']);
    } else if (job['assetPhoto'] != null) {
      photos.add(job['assetPhoto']);
    }

    if (photos.isEmpty) {
      // Show icon when no photos
      return Container(
        height: 80,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          job['serviceType'] == 'vehicle' ? Icons.directions_car : Icons.build,
          size: 40,
          color: Colors.white,
        ),
      );
    }

    if (photos.length == 1) {
      // Single photo - covers entire upper half of the box
      return Container(
        height: 100,
        width: double.infinity,
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
          child: Image.network(
            photos[0],
            fit: BoxFit.cover, // Cover entire area
            width: double.infinity,
            height: 100,
            errorBuilder: (context, error, stackTrace) => Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Icon(
                job['serviceType'] == 'vehicle'
                    ? Icons.directions_car
                    : Icons.build,
                size: 40,
                color: Colors.white,
              ),
            ),
          ),
        ),
      );
    }

    // Multiple photos - stacked beautifully
    return Container(
      height: 100,
      width: double.infinity,
      child: Stack(
        children: [
          // Background photos stacked
          for (int i = 0; i < photos.length && i < 3; i++)
            Positioned(
              left: i * 6.0,
              top: i * 3.0,
              right: (photos.length - 1 - i) * 6.0,
              bottom: (photos.length - 1 - i) * 3.0,
              child: ClipRRect(
                borderRadius: i == 0
                    ? const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      )
                    : BorderRadius.circular(12),
                child: Image.network(
                  photos[i],
                  fit: BoxFit.cover, // Cover entire area
                  errorBuilder: (context, error, stackTrace) => Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: i == 0
                          ? const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                            )
                          : BorderRadius.circular(12),
                    ),
                    child: Icon(
                      job['serviceType'] == 'vehicle'
                          ? Icons.directions_car
                          : Icons.build,
                      size: 30,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          // Photo count indicator if more than 3
          if (photos.length > 3)
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+${photos.length - 3}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildJobGridItem(Map<String, dynamic> job) {
    // Get priority color for background
    Color getPriorityColor(String? priority) {
      switch (priority?.toLowerCase()) {
        case 'high':
          return const Color(0xFFEF4444); // Red
        case 'medium':
          return const Color(0xFFF59E0B); // Orange
        case 'low':
          return const Color(0xFF10B981); // Green
        default:
          return const Color(0xFF6B7280); // Gray
      }
    }

    final priorityColor = getPriorityColor(job['priority']);

    return GestureDetector(
      onTap: () => _navigateToJobDetail(job['documentId']),
      child: Column(
        children: [
          // Photo section - above the card
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Photo background
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  child: _buildPhotoBackground(job),
                ),
                // Priority chip overlay
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: priorityColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      (job['priority'] ?? 'unknown').toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Card content - below the photo
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Job title
                  Text(
                    job['title'] ?? 'No Title',
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 4),

                  // Asset info
                  Text(
                    job['assetName'] ?? 'No Asset',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  if (_showDetailedInfo) ...[
                    const SizedBox(height: 6),

                    // Customer name
                    Row(
                      children: [
                        Icon(
                          Icons.person,
                          size: 12,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            job['customerName'] ?? 'Unknown Customer',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 3),

                    // Task count with completed
                    Row(
                      children: [
                        Icon(Icons.task, size: 12, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          '${job['completedTaskCount'] ?? 0}/${job['taskCount']} tasks',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),

                    if (job['assignedAt'] != null) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 12,
                            color: Colors.orange.shade600,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Assigned at ${DateTimeHelper.formatDate(job['assignedAt'])}',
                              style: TextStyle(
                                color: Colors.orange.shade600,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],

                    if (job['startedAt'] != null) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            Icons.play_arrow,
                            size: 12,
                            color: Colors.blue.shade600,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Started at ${DateTimeHelper.formatDate(job['startedAt'])}',
                              style: TextStyle(
                                color: Colors.blue.shade600,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],

                    if (job['completedAt'] != null) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 12,
                            color: Colors.green.shade600,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Completed at ${DateTimeHelper.formatDate(job['completedAt'])}',
                              style: TextStyle(
                                color: Colors.green.shade600,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],

                  const Spacer(),

                  // Status and action area
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(
                            job['status'],
                          ).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _getStatusColor(job['status']),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          (job['status'] ?? 'unknown').toUpperCase(),
                          style: TextStyle(
                            color: _getStatusColor(job['status']),
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Task button
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                TasksScreen(jobId: job['documentId']),
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.indigo.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.task,
                            size: 12,
                            color: Colors.indigo,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Detail navigation button
                      GestureDetector(
                        onTap: () => _navigateToJobDetail(job['documentId']),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: priorityColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.arrow_forward_ios,
                            size: 12,
                            color: priorityColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoBackground(Map<String, dynamic> job) {
    // Get photos from job data
    List<String> photos = [];
    if (job['assetPhotos'] != null && job['assetPhotos'] is List) {
      photos = List<String>.from(job['assetPhotos']);
    } else if (job['assetPhoto'] != null) {
      photos.add(job['assetPhoto']);
    }

    if (photos.isNotEmpty) {
      return Image.network(
        photos[0],
        fit: BoxFit.cover,
        width: double.infinity,
        height: 120,
        errorBuilder: (context, error, stackTrace) =>
            _buildDefaultBackground(job),
      );
    }

    return _buildDefaultBackground(job);
  }

  Widget _buildDefaultBackground(Map<String, dynamic> job) {
    Color getPriorityColor(String? priority) {
      switch (priority?.toLowerCase()) {
        case 'high':
          return const Color(0xFFEF4444);
        case 'medium':
          return const Color(0xFFF59E0B);
        case 'low':
          return const Color(0xFF10B981);
        default:
          return const Color(0xFF6B7280);
      }
    }

    final priorityColor = getPriorityColor(job['priority']);

    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [priorityColor, priorityColor.withValues(alpha: 0.8)],
        ),
      ),
      child: Center(
        child: Icon(
          job['serviceType'] == 'vehicle' ? Icons.directions_car : Icons.build,
          size: 40,
          color: Colors.white,
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'inprogress':
        return Colors.blue;
      case 'assigned':
        return Colors.orange;
      case 'accepted':
        return Colors.green;
      case 'onhold':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityChip(String? priority) {
    Color color;
    String displayText;
    switch (priority?.toLowerCase()) {
      case 'high':
        color = Colors.red;
        displayText = 'High';
        break;
      case 'medium':
        color = Colors.orange;
        displayText = 'Medium';
        break;
      case 'low':
        color = Colors.green;
        displayText = 'Low';
        break;
      default:
        color = Colors.grey;
        displayText = priority ?? 'Normal';
    }

    return Chip(
      label: Text(displayText, style: const TextStyle(fontSize: 12)),
      backgroundColor: color.withValues(alpha: 0.2),
      side: BorderSide(color: color),
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
        color = Colors.blue;
        displayText = 'In Progress';
        break;
      case 'assigned':
        color = Colors.orange;
        displayText = 'Assigned';
        break;
      case 'onhold':
        color = Colors.red;
        displayText = 'On Hold';
        break;
      case 'cancelled':
        color = Colors.grey;
        displayText = 'Cancelled';
        break;
      default:
        color = Colors.grey;
        displayText = status ?? 'Unknown';
    }

    return Chip(
      label: Text(displayText, style: const TextStyle(fontSize: 12)),
      backgroundColor: color.withValues(alpha: 0.2),
      side: BorderSide(color: color),
    );
  }

  Future<void> _navigateToJobDetail(String jobId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => JobDetailScreen(jobId: jobId)),
    );

    // Refresh the jobs list when returning from job detail screen
    // This ensures the status changes are reflected immediately
    _loadJobs();
  }

  void _navigateToTasks(String jobId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TasksScreen(jobId: jobId)),
    );

    _loadJobs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
          const SizedBox(height: 6),

          // Search bar
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            height: 45,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.grey.shade50, Colors.grey.shade100],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.grey.shade300, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Focus(
              onFocusChange: (hasFocus) {
                setState(() {
                  // Trigger rebuild to update decoration
                });
              },
              child: Builder(
                builder: (context) {
                  final hasFocus = Focus.of(context).hasFocus;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.grey.shade50, Colors.grey.shade100],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: hasFocus
                            ? Colors.blue.shade400
                            : Colors.grey.shade300,
                        width: hasFocus ? 2.0 : 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                        if (hasFocus)
                          BoxShadow(
                            color: Colors.blue.withValues(alpha: 0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 0),
                          ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search jobs, customers, vehicles...',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: hasFocus
                              ? Colors.blue.shade600
                              : Colors.grey.shade600,
                          size: 20,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                  _applyFilters();
                                },
                                icon: Icon(
                                  Icons.clear,
                                  color: Colors.grey.shade600,
                                  size: 18,
                                ),
                              )
                            : null,
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                      ),
                      style: const TextStyle(fontSize: 14),
                      onChanged: (value) => _applyFilters(),
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 6),

          // Quick filters
          _buildQuickFilters(),

          const SizedBox(height: 3),

          // Action buttons
          _buildActionButtons(),

          // Jobs list/grid
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading jobs...'),
                      ],
                    ),
                  )
                : _jobs.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.work_off, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No jobs found'),
                        SizedBox(height: 8),
                        Text(
                          'Try adjusting your filters or search terms',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : _isListView
                ? ListView.builder(
                    padding: const EdgeInsets.only(bottom: 125),
                    itemCount: _jobs.length,
                    itemBuilder: (context, index) =>
                        _buildJobCard(_jobs[index]),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: 125,
                    ),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: _showDetailedInfo ? 0.55 : 0.75,
                      crossAxisSpacing: 12.0,
                      mainAxisSpacing: 12.0,
                    ),
                    itemCount: _jobs.length,
                    itemBuilder: (context, index) =>
                        _buildJobGridItem(_jobs[index]),
                  ),
          ),
        ],
      ),
    );
  }
}
