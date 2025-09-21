import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/auth_service.dart';
import '../services/dashboard_service.dart';
import 'job_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with AutomaticKeepAliveClientMixin {
  final AuthService _authService = AuthService();
  final DashboardService _dashboardService = DashboardService();

  bool _isLoading = true;
  bool _isDisposed = false;
  Map<String, dynamic> _dashboardData = {};
  DateTime _focusedDay = DateTime.now();
  String _selectedDateFilter =
      'assignedAt'; // 'assignedAt', 'startedAt', 'completedAt'

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    if (_isDisposed || !mounted) return;

    setState(() => _isLoading = true);

    try {
      // Get current mechanic ID for personalized dashboard data
      final mechanicId = _authService.currentMechanicId;

      final data = await _dashboardService.getComprehensiveDashboardData(
        mechanicId: mechanicId,
      );

      if (_isDisposed || !mounted) return;

      setState(() {
        _dashboardData = data;
        _isLoading = false;
      });
    } catch (e) {
      if (_isDisposed || !mounted) return;

      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading dashboard: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
          ),
        ],
      ),
      body: _buildDashboard(),
    );
  }

  Widget _buildDashboard() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading dashboard data...'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(
          top: 16,
          left: 16,
          right: 16,
          bottom: 125,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildQuickStats(),
            const SizedBox(height: 24),
            _buildJobStatusChart(),
            const SizedBox(height: 24),
            _buildPriorityDistributionChart(),
            const SizedBox(height: 24),
            _buildServiceTypeBreakdown(),
            const SizedBox(height: 24),
            _buildTimePerformanceChart(),
            const SizedBox(height: 24),
            _buildCostAnalysisChart(),
            const SizedBox(height: 24),
            _buildCustomerSatisfactionChart(),
            const SizedBox(height: 24),
            _buildTaskAnalyticsChart(),
            const SizedBox(height: 24),
            _buildTimelineAnalytics(),
            const SizedBox(height: 24),
            _buildNotesAnalysis(),
            const SizedBox(height: 24),
            _buildCalendarView(),
            const SizedBox(height: 24),
            _buildPartsUsageChart(),
            const SizedBox(height: 24),
            _buildVehicleAnalytics(),
            const SizedBox(height: 24),
            _buildEquipmentAnalytics(),
            const SizedBox(height: 24),
            _buildCustomerInsights(),
            const SizedBox(height: 24),
            _buildDigitalSignoffAnalytics(),
            const SizedBox(height: 24),
            _buildFinancialAnalytics(),
            const SizedBox(height: 24),
            _buildMechanicPerformance(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    final jobStats =
        _dashboardData['jobStatistics'] as Map<String, dynamic>? ?? {};
    final customerSatisfaction =
        _dashboardData['customerSatisfactionAnalytics']
            as Map<String, dynamic>? ??
        {};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Overview',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total Jobs',
                    '${jobStats['total'] ?? 0}',
                    Icons.work,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    'Completed',
                    '${jobStats['completed'] ?? 0}',
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    'In Progress',
                    '${jobStats['inProgress'] ?? 0}',
                    Icons.hourglass_empty,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    'Rating',
                    '${(customerSatisfaction['averageRating'] ?? 0.0).toStringAsFixed(1)}⭐',
                    Icons.star,
                    Colors.amber,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildJobStatusChart() {
    final jobStats =
        _dashboardData['jobStatistics'] as Map<String, dynamic>? ?? {};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Job Status Distribution',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 0,
                  centerSpaceRadius: 40,
                  sections: [
                    PieChartSectionData(
                      color: Colors.blue,
                      value: (jobStats['assigned'] ?? 0).toDouble(),
                      title: 'Assigned\n${jobStats['assigned'] ?? 0}',
                      radius: 50,
                      titleStyle: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    PieChartSectionData(
                      color: Colors.orange,
                      value: (jobStats['inProgress'] ?? 0).toDouble(),
                      title: 'In Progress\n${jobStats['inProgress'] ?? 0}',
                      radius: 50,
                      titleStyle: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    PieChartSectionData(
                      color: Colors.green,
                      value: (jobStats['completed'] ?? 0).toDouble(),
                      title: 'Completed\n${jobStats['completed'] ?? 0}',
                      radius: 50,
                      titleStyle: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    PieChartSectionData(
                      color: Colors.red,
                      value: (jobStats['onHold'] ?? 0).toDouble(),
                      title: 'On Hold\n${jobStats['onHold'] ?? 0}',
                      radius: 50,
                      titleStyle: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    PieChartSectionData(
                      color: Colors.grey,
                      value: (jobStats['cancelled'] ?? 0).toDouble(),
                      title: 'Cancelled\n${jobStats['cancelled'] ?? 0}',
                      radius: 50,
                      titleStyle: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityDistributionChart() {
    if (_isDisposed || !mounted) {
      return const SizedBox.shrink();
    }

    final priorityData =
        _dashboardData['priorityDistribution'] as Map<String, dynamic>? ?? {};

    List<ChartData> chartData = [];
    if (priorityData.isNotEmpty) {
      priorityData.forEach((priority, data) {
        if (data is Map<String, dynamic>) {
          chartData.add(
            ChartData(
              priority.toUpperCase(),
              (data['count'] ?? 0).toDouble(),
              _getPriorityColor(priority),
            ),
          );
        }
      });
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Job Priority Distribution',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: SfCartesianChart(
                primaryXAxis: const CategoryAxis(),
                primaryYAxis: const NumericAxis(),
                series: <CartesianSeries>[
                  ColumnSeries<ChartData, String>(
                    dataSource: chartData,
                    xValueMapper: (ChartData data, _) => data.x,
                    yValueMapper: (ChartData data, _) => data.y,
                    pointColorMapper: (ChartData data, _) => data.color,
                    dataLabelSettings: const DataLabelSettings(isVisible: true),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePerformanceChart() {
    if (_isDisposed || !mounted) {
      return const SizedBox.shrink();
    }

    final timeData =
        _dashboardData['timePerformance'] as Map<String, dynamic>? ?? {};

    List<ChartData> chartData = [
      ChartData(
        'Estimated',
        timeData['totalEstimatedHours']?.toDouble() ?? 0,
        Colors.blue,
      ),
      ChartData(
        'Actual',
        timeData['totalActualHours']?.toDouble() ?? 0,
        Colors.orange,
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Time Performance (Hours)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Variance: ${(timeData['timeVariancePercentage'] ?? 0).toStringAsFixed(1)}%',
              style: TextStyle(
                color: (timeData['timeVariancePercentage'] ?? 0) > 0
                    ? Colors.red
                    : Colors.green,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: SfCartesianChart(
                primaryXAxis: const CategoryAxis(),
                primaryYAxis: const NumericAxis(),
                series: <CartesianSeries>[
                  ColumnSeries<ChartData, String>(
                    dataSource: chartData,
                    xValueMapper: (ChartData data, _) => data.x,
                    yValueMapper: (ChartData data, _) => data.y,
                    pointColorMapper: (ChartData data, _) => data.color,
                    dataLabelSettings: const DataLabelSettings(isVisible: true),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCostAnalysisChart() {
    final costData =
        _dashboardData['costAnalysis'] as Map<String, dynamic>? ?? {};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cost Analysis',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildCostCard(
                    'Estimated Cost',
                    '\$${(costData['totalEstimatedCost'] ?? 0).toStringAsFixed(0)}',
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildCostCard(
                    'Actual Cost',
                    '\$${(costData['totalActualCost'] ?? 0).toStringAsFixed(0)}',
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildCostCard(
                    'Variance',
                    '\$${(costData['costVariance'] ?? 0).toStringAsFixed(0)}',
                    (costData['costVariance'] ?? 0) > 0
                        ? Colors.red
                        : Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildCostCard(
                    'Avg Job Cost',
                    '\$${(costData['averageJobCost'] ?? 0).toStringAsFixed(0)}',
                    Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCostCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerSatisfactionChart() {
    if (_isDisposed || !mounted) {
      return const SizedBox.shrink();
    }

    final satisfactionData =
        _dashboardData['customerSatisfactionAnalytics']
            as Map<String, dynamic>? ??
        {};
    final ratingDistribution =
        satisfactionData['ratingDistribution'] as Map<String, dynamic>? ?? {};

    List<ChartData> chartData = [];
    for (int i = 1; i <= 5; i++) {
      chartData.add(
        ChartData(
          '$i⭐',
          (ratingDistribution[i.toString()] ?? 0).toDouble(),
          _getStarColor(i),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Customer Satisfaction (${(satisfactionData['averageRating'] ?? 0.0).toStringAsFixed(1)}⭐ avg)',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: SfCartesianChart(
                primaryXAxis: const CategoryAxis(),
                primaryYAxis: const NumericAxis(),
                series: <CartesianSeries>[
                  BarSeries<ChartData, String>(
                    dataSource: chartData,
                    xValueMapper: (ChartData data, _) => data.x,
                    yValueMapper: (ChartData data, _) => data.y,
                    pointColorMapper: (ChartData data, _) => data.color,
                    dataLabelSettings: const DataLabelSettings(isVisible: true),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskAnalyticsChart() {
    final taskData =
        _dashboardData['taskAnalytics'] as Map<String, dynamic>? ?? {};

    List<ChartData> chartData = [
      ChartData(
        'Completed',
        (taskData['completedTasks'] ?? 0).toDouble(),
        Colors.green,
      ),
      ChartData(
        'In Progress',
        (taskData['inProgressTasks'] ?? 0).toDouble(),
        Colors.orange,
      ),
      ChartData(
        'Pending',
        (taskData['pendingTasks'] ?? 0).toDouble(),
        Colors.red,
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Task Analytics (${taskData['totalTasks'] ?? 0} total)',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 50,
                  sections: chartData.map((data) {
                    return PieChartSectionData(
                      color: data.color,
                      value: data.y,
                      title: '${data.x}\n${data.y.toInt()}',
                      radius: 40,
                      titleStyle: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarView() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Calendar Overview',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    _buildDateFilterButton('assignedAt', 'Assigned'),
                    const SizedBox(width: 4),
                    _buildDateFilterButton('startedAt', 'Started'),
                    const SizedBox(width: 4),
                    _buildDateFilterButton('completedAt', 'Completed'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            FutureBuilder<Map<DateTime, List<Map<String, dynamic>>>>(
              future: _dashboardService.getJobsByDate(
                mechanicId: _authService.currentMechanicId,
                dateField: _selectedDateFilter,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final jobsByDate = snapshot.data ?? {};

                return TableCalendar<Map<String, dynamic>>(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) =>
                      false, // Disable day selection highlighting
                  onDaySelected: (selectedDay, focusedDay) {
                    // Only show job details dialog without updating focused day
                    final dateOnly = DateTime(
                      selectedDay.year,
                      selectedDay.month,
                      selectedDay.day,
                    );
                    final dayJobs = jobsByDate[dateOnly] ?? [];
                    if (dayJobs.isNotEmpty) {
                      _showJobsDialog(selectedDay, dayJobs);
                    }
                  },
                  eventLoader: (day) {
                    final dateOnly = DateTime(day.year, day.month, day.day);
                    return jobsByDate[dateOnly] ?? [];
                  },
                  calendarBuilders: CalendarBuilders<Map<String, dynamic>>(
                    defaultBuilder: (context, day, focusedDay) {
                      final dateOnly = DateTime(day.year, day.month, day.day);
                      final jobs = jobsByDate[dateOnly] ?? [];

                      if (jobs.isEmpty) {
                        return null; // Use default rendering
                      }

                      // Group jobs by status
                      Map<String, int> statusCounts = {};
                      for (var job in jobs) {
                        final status = job['status'] as String;
                        statusCounts[status] = (statusCounts[status] ?? 0) + 1;
                      }

                      // Find the most common status for background color
                      String dominantStatus = 'assigned';
                      int maxCount = 0;
                      statusCounts.forEach((status, count) {
                        if (count > maxCount) {
                          maxCount = count;
                          dominantStatus = status;
                        }
                      });

                      return Container(
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: _getStatusColor(
                            dominantStatus,
                          ).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _getStatusColor(
                              dominantStatus,
                            ).withValues(alpha: 0.7),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${day.day}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              if (jobs.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                _buildStatusCountsWidget(statusCounts),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                    // Remove todayBuilder to eliminate current date highlighting
                  ),
                  calendarFormat: CalendarFormat.month,
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                  ),
                  calendarStyle: CalendarStyle(
                    markersMaxCount: 0,
                    outsideDaysVisible: false,
                    weekendTextStyle: TextStyle(color: Colors.red[400]),
                    holidayTextStyle: TextStyle(color: Colors.red[800]),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            // Legend for status colors
            Wrap(
              spacing: 16,
              children: [
                _buildStatusLegend('Completed', Colors.green),
                _buildStatusLegend('In Progress', Colors.orange),
                _buildStatusLegend('Assigned', Colors.blue),
                _buildStatusLegend('Pending', Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build widget to display multiple status counts
  Widget _buildStatusCountsWidget(Map<String, int> statusCounts) {
    List<Widget> countWidgets = [];

    // Define the order of statuses to display
    final statusOrder = ['completed', 'inProgress', 'assigned', 'pending'];

    for (String status in statusOrder) {
      if (statusCounts.containsKey(status) && statusCounts[status]! > 0) {
        countWidgets.add(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${statusCounts[status]}',
              style: TextStyle(
                color: _getStatusColor(status),
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }
    }

    if (countWidgets.length == 1) {
      // If only one status, make it slightly larger
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '${statusCounts.values.first}',
          style: TextStyle(
            color: _getStatusColor(statusCounts.keys.first),
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return Wrap(spacing: 1, runSpacing: 1, children: countWidgets);
  }

  /// Get color for job status
  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'inProgress':
        return Colors.orange;
      case 'assigned':
        return Colors.blue;
      case 'pending':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  /// Build status legend item
  Widget _buildStatusLegend(String status, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(status, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  /// Build date filter button
  Widget _buildDateFilterButton(String value, String label) {
    final isSelected = _selectedDateFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDateFilter = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  /// Show dialog with jobs for the selected date
  void _showJobsDialog(DateTime selectedDate, List<Map<String, dynamic>> jobs) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Jobs for ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: jobs.isEmpty
                ? const Center(child: Text('No jobs found for this date'))
                : ListView.builder(
                    itemCount: jobs.length,
                    itemBuilder: (context, index) {
                      final job = jobs[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _getStatusColor(
                                job['status'],
                              ).withOpacity(0.8),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                job['status']?.substring(0, 1).toUpperCase() ??
                                    'J',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            job['title'] ?? 'Untitled Job',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Customer: ${job['customerName'] ?? 'Unknown'}',
                              ),
                              Text('Status: ${job['status'] ?? 'Unknown'}'),
                              Text('Priority: ${job['priority'] ?? 'Unknown'}'),
                            ],
                          ),
                          trailing: Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.grey[600],
                            size: 16,
                          ),
                          onTap: () {
                            Navigator.of(context).pop(); // Close dialog
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    JobDetailScreen(jobId: job['id']),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPartsUsageChart() {
    final partsData =
        _dashboardData['partsAnalysis'] as Map<String, dynamic>? ?? {};
    final topParts = partsData['topParts'] as List<dynamic>? ?? [];

    List<ChartData> chartData = [];
    for (int i = 0; i < (topParts.length > 5 ? 5 : topParts.length); i++) {
      final part = topParts[i] as Map<String, dynamic>;
      chartData.add(
        ChartData(
          part['name'] ?? 'Unknown',
          (part['count'] ?? 0).toDouble(),
          _getRandomColor(i),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top Parts Usage (${partsData['totalPartTypes'] ?? 0} types)',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: SfCartesianChart(
                primaryXAxis: const CategoryAxis(labelRotation: -45),
                primaryYAxis: const NumericAxis(),
                series: <CartesianSeries>[
                  ColumnSeries<ChartData, String>(
                    dataSource: chartData,
                    xValueMapper: (ChartData data, _) => data.x,
                    yValueMapper: (ChartData data, _) => data.y,
                    pointColorMapper: (ChartData data, _) => data.color,
                    dataLabelSettings: const DataLabelSettings(isVisible: true),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: const TextStyle(fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildServiceTypeBreakdown() {
    final serviceTypeData =
        _dashboardData['serviceTypeBreakdown'] as Map<String, dynamic>? ?? {};

    List<ChartData> chartData = [];
    serviceTypeData.forEach((type, data) {
      if (data is Map<String, dynamic>) {
        chartData.add(
          ChartData(
            type.toUpperCase(),
            (data['count'] ?? 0).toDouble(),
            type == 'vehicle' ? Colors.blue : Colors.orange,
          ),
        );
      }
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Service Type Breakdown',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: chartData.isNotEmpty
                  ? PieChart(
                      PieChartData(
                        sectionsSpace: 0,
                        centerSpaceRadius: 40,
                        sections: chartData.map((data) {
                          return PieChartSectionData(
                            color: data.color,
                            value: data.y,
                            title: '${data.x}\n${data.y.toInt()}',
                            radius: 50,
                            titleStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          );
                        }).toList(),
                      ),
                    )
                  : const Center(child: Text('No service type data available')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineAnalytics() {
    final timelineData =
        _dashboardData['timelineAnalytics'] as Map<String, dynamic>? ?? {};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Timeline Analytics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildTimelineCard(
                        'Avg. Assigned to Started',
                        '${(timelineData['averageAssignedToStartedDays'] ?? 0).toStringAsFixed(1)} days',
                        Icons.play_arrow,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildTimelineCard(
                        'Avg. Started to Completed',
                        '${(timelineData['averageStartedToCompletedDays'] ?? 0).toStringAsFixed(1)} days',
                        Icons.check_circle,
                        Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildTimelineCard(
                        'Started Today',
                        '${timelineData['jobsStartedToday'] ?? 0}',
                        Icons.today,
                        Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildTimelineCard(
                        'Completed Today',
                        '${timelineData['jobsCompletedToday'] ?? 0}',
                        Icons.done_all,
                        Colors.purple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildTimelineCard(
                        'Assigned This Week',
                        '${timelineData['jobsAssignedThisWeek'] ?? 0}',
                        Icons.assignment,
                        Colors.teal,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildTimelineCard(
                        'Completed This Week',
                        '${timelineData['jobsCompletedThisWeek'] ?? 0}',
                        Icons.check_box,
                        Colors.indigo,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: const TextStyle(fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNotesAnalysis() {
    final notesData =
        _dashboardData['notesAnalysis'] as Map<String, dynamic>? ?? {};

    List<ChartData> typeChartData = [
      ChartData(
        'Problem',
        (notesData['problemNotes'] ?? 0).toDouble(),
        Colors.red,
      ),
      ChartData(
        'Request',
        (notesData['requestNotes'] ?? 0).toDouble(),
        Colors.blue,
      ),
      ChartData(
        'Completion',
        (notesData['completionNotes'] ?? 0).toDouble(),
        Colors.green,
      ),
    ];

    List<ChartData> statusChartData = [
      ChartData(
        'Pending',
        (notesData['pendingNotes'] ?? 0).toDouble(),
        Colors.orange,
      ),
      ChartData(
        'Solved',
        (notesData['solvedNotes'] ?? 0).toDouble(),
        Colors.green,
      ),
      ChartData(
        'Accepted',
        (notesData['acceptedNotes'] ?? 0).toDouble(),
        Colors.blue,
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notes Analysis (${notesData['totalNotes'] ?? 0} total, ${notesData['resolutionRate'] ?? 0}% resolved)',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'By Type',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 150,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 30,
                            sections: typeChartData.map((data) {
                              return PieChartSectionData(
                                color: data.color,
                                value: data.y,
                                title: '${data.x}\n${data.y.toInt()}',
                                radius: 35,
                                titleStyle: const TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'By Status',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 150,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 30,
                            sections: statusChartData.map((data) {
                              return PieChartSectionData(
                                color: data.color,
                                value: data.y,
                                title: '${data.x}\n${data.y.toInt()}',
                                radius: 35,
                                titleStyle: const TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleAnalytics() {
    final vehicleData =
        _dashboardData['vehicleAnalytics'] as Map<String, dynamic>? ?? {};
    final topMakes = vehicleData['topMakes'] as List<dynamic>? ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vehicle Analytics (${vehicleData['totalVehicles'] ?? 0} vehicles)',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildVehicleInfoCard(
                    'Average Year',
                    '${vehicleData['averageYear'] ?? 0}',
                    Icons.calendar_today,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildVehicleInfoCard(
                    'Oldest Vehicle',
                    '${vehicleData['oldestYear'] ?? 0}',
                    Icons.history,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildVehicleInfoCard(
                    'Newest Vehicle',
                    '${vehicleData['newestYear'] ?? 0}',
                    Icons.new_releases,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildVehicleInfoCard(
                    'Avg Mileage',
                    '${(vehicleData['averageMileage'] ?? 0)} mi',
                    Icons.speed,
                    Colors.purple,
                  ),
                ),
              ],
            ),
            if (topMakes.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Top Vehicle Makes',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...topMakes.take(5).map((make) {
                final makeData = make as Map<String, dynamic>;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(makeData['make'] ?? 'Unknown'),
                      Text('${makeData['count'] ?? 0} vehicles'),
                    ],
                  ),
                );
              }).toList(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleInfoCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: const TextStyle(fontSize: 8),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEquipmentAnalytics() {
    final equipmentData =
        _dashboardData['equipmentAnalytics'] as Map<String, dynamic>? ?? {};
    final categories =
        equipmentData['categories'] as Map<String, dynamic>? ?? {};
    final conditions =
        equipmentData['conditions'] as Map<String, dynamic>? ?? {};
    final topManufacturers =
        equipmentData['topManufacturers'] as List<dynamic>? ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Equipment Analytics (${equipmentData['totalEquipment'] ?? 0} items, avg year: ${equipmentData['averageYear'] ?? 0})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Categories',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...categories.entries
                          .map(
                            (entry) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 1),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    entry.key,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  Text(
                                    '${entry.value}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Conditions',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...conditions.entries
                          .map(
                            (entry) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 1),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    entry.key,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  Text(
                                    '${entry.value}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ],
                  ),
                ),
              ],
            ),
            if (topManufacturers.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Top Manufacturers',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...topManufacturers.take(3).map((manufacturer) {
                final mfgData = manufacturer as MapEntry<String, dynamic>;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(mfgData.key),
                      Text('${mfgData.value} items'),
                    ],
                  ),
                );
              }).toList(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerInsights() {
    final customerData =
        _dashboardData['customerInsights'] as Map<String, dynamic>? ?? {};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Customer Insights',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildCustomerInfoCard(
                    'Total Customers',
                    '${customerData['totalCustomers'] ?? 0}',
                    Icons.people,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCustomerInfoCard(
                    'Multi-Job Customers',
                    '${customerData['customersWithMultipleJobs'] ?? 0}',
                    Icons.repeat,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCustomerInfoCard(
                    'New This Month',
                    '${customerData['newCustomersThisMonth'] ?? 0}',
                    Icons.person_add,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildCustomerInfoCard(
                    'Avg Jobs/Customer',
                    '${(customerData['averageJobsPerCustomer'] ?? 0).toStringAsFixed(1)}',
                    Icons.work,
                    Colors.purple,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCustomerInfoCard(
                    'Max Jobs/Customer',
                    '${customerData['maxJobsPerCustomer'] ?? 0}',
                    Icons.star,
                    Colors.amber,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCustomerInfoCard(
                    'Retention Rate',
                    '${customerData['retentionRate'] ?? 0}%',
                    Icons.favorite,
                    Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerInfoCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: const TextStyle(fontSize: 9),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDigitalSignoffAnalytics() {
    final signoffData =
        _dashboardData['digitalSignoffAnalytics'] as Map<String, dynamic>? ??
        {};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Digital Signoff Analytics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSignoffCard(
                    'Jobs with Signoff',
                    '${signoffData['jobsWithSignoff'] ?? 0}',
                    Icons.edit,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSignoffCard(
                    'Pending Signoff',
                    '${signoffData['jobsPendingSignoff'] ?? 0}',
                    Icons.pending,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSignoffCard(
                    'Signoff Rate',
                    '${signoffData['signoffRate'] ?? 0}%',
                    Icons.rate_review,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSignoffCard(
                    'Avg Days to Signoff',
                    '${(signoffData['averageDaysToSignoff'] ?? 0).toStringAsFixed(1)}',
                    Icons.timer,
                    Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignoffCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: const TextStyle(fontSize: 9),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialAnalytics() {
    final financialData =
        _dashboardData['financialAnalytics'] as Map<String, dynamic>? ?? {};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Financial Analytics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildFinancialCard(
                    'Total Monthly Payroll',
                    'RM ${(financialData['totalMonthlySalary'] ?? 0).toStringAsFixed(0)}',
                    Icons.account_balance,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildFinancialCard(
                    'Average Salary',
                    'RM ${(financialData['averageSalary'] ?? 0).toStringAsFixed(0)}',
                    Icons.person,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildFinancialCard(
                    'Labor Cost/Hour',
                    'RM ${(financialData['laborCostPerHour'] ?? 0).toStringAsFixed(2)}',
                    Icons.schedule,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildFinancialCard(
                    'Total Labor Costs',
                    'RM ${(financialData['totalLaborCosts'] ?? 0).toStringAsFixed(0)}',
                    Icons.work,
                    Colors.purple,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildFinancialCard(
                    'Labor Cost/Job',
                    'RM ${(financialData['laborCostPerJob'] ?? 0).toStringAsFixed(0)}',
                    Icons.assignment,
                    Colors.teal,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildFinancialCard(
                    'Total Mechanics',
                    '${financialData['totalMechanics'] ?? 0}',
                    Icons.group,
                    Colors.indigo,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: const TextStyle(fontSize: 8),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMechanicPerformance() {
    final mechanicData =
        _dashboardData['mechanicPerformance'] as Map<String, dynamic>?;

    if (mechanicData == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mechanic Performance',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text('Login to view your personal performance metrics'),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Performance',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildPerformanceCard(
                    'Assigned Jobs',
                    '${mechanicData['assignedJobs'] ?? 0}',
                    Icons.assignment,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildPerformanceCard(
                    'Completed Jobs',
                    '${mechanicData['completedJobs'] ?? 0}',
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildPerformanceCard(
                    'Efficiency',
                    '${mechanicData['efficiency'] ?? 0}%',
                    Icons.trending_up,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildPerformanceCard(
                    'Completion Rate',
                    '${mechanicData['completionRate'] ?? 0}%',
                    Icons.task_alt,
                    Colors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.grey.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Specialization',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          mechanicData['specialization'] ?? 'N/A',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.grey.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Department',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          mechanicData['department'] ?? 'N/A',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: const TextStyle(fontSize: 9),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _getStarColor(int stars) {
    switch (stars) {
      case 5:
        return Colors.green;
      case 4:
        return Colors.lightGreen;
      case 3:
        return Colors.yellow;
      case 2:
        return Colors.orange;
      case 1:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getRandomColor(int index) {
    List<Color> colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
    ];
    return colors[index % colors.length];
  }
}

class ChartData {
  final String x;
  final double y;
  final Color color;

  ChartData(this.x, this.y, this.color);
}
