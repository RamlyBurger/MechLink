import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/auth_service.dart';
import '../services/dashboard_service.dart';
import '../widgets/stat_card.dart';
import 'job_detail_screen.dart';
import 'dart:ui';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final DashboardService _dashboardService = DashboardService();

  bool _isLoading = true;
  bool _isDisposed = false;
  Map<String, dynamic> _dashboardData = {};
  DateTime _focusedDay = DateTime.now();
  String _selectedDateFilter =
      'assignedAt'; // 'assignedAt', 'startedAt', 'completedAt'

  late AnimationController _fadeAnimationController;
  late AnimationController _slideAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late ScrollController _scrollController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _slideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _slideAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _scrollController = ScrollController();

    _loadDashboardData();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _fadeAnimationController.dispose();
    _slideAnimationController.dispose();
    _scrollController.dispose();
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

      // Start animations after data is loaded
      _fadeAnimationController.forward();
      _slideAnimationController.forward();
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: _buildDashboard(),
    );
  }

  Widget _buildDashboard() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade600.withOpacity(0.1),
              colorScheme.surface,
              colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.shade200.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade400,
                              Colors.blue.shade600,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                            strokeWidth: 3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Loading Dashboard',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Preparing your personalized insights...',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.7),
                        ),
                        textAlign: TextAlign.center,
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

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.blue.shade600.withOpacity(0.05), colorScheme.surface],
        ),
      ),
      child: RefreshIndicator(
        onRefresh: _loadDashboardData,
        color: Colors.blue.shade600,
        displacement: 60,
        strokeWidth: 3,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.only(
                top: 60, // Account for status bar
                left: 20,
                right: 20,
                bottom: 125,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildModernQuickStats(),
                  _buildModernJobStatusChart(),
                  const SizedBox(height: 32),
                  _buildModernPriorityDistributionChart(),
                  const SizedBox(height: 32),
                  _buildServiceTypeBreakdown(),
                  const SizedBox(height: 32),
                  _buildTimePerformanceChart(),
                  const SizedBox(height: 32),
                  _buildModernCostAnalysisChart(),
                  const SizedBox(height: 32),
                  _buildCustomerSatisfactionChart(),
                  const SizedBox(height: 32),
                  _buildTaskAnalyticsChart(),
                  const SizedBox(height: 32),
                  _buildTimelineAnalytics(),
                  const SizedBox(height: 32),
                  _buildNotesAnalysis(),
                  const SizedBox(height: 32),
                  _buildModernCalendarView(),
                  const SizedBox(height: 32),
                  _buildPartsUsageChart(),
                  const SizedBox(height: 32),
                  _buildVehicleAnalytics(),
                  const SizedBox(height: 32),
                  _buildEquipmentAnalytics(),
                  const SizedBox(height: 32),
                  _buildCustomerInsights(),
                  const SizedBox(height: 32),
                  _buildDigitalSignoffAnalytics(),
                  const SizedBox(height: 32),
                  _buildFinancialAnalytics(),
                  const SizedBox(height: 32),
                  _buildAssignedJobsOverview(),
                  const SizedBox(height: 32),
                  _buildMechanicPerformance(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Modern Quick Stats using horizontal scrollable StatCard widget
  Widget _buildModernQuickStats() {
    final jobStats =
        _dashboardData['jobStatistics'] as Map<String, dynamic>? ?? {};
    final customerSatisfaction =
        _dashboardData['customerSatisfactionAnalytics']
            as Map<String, dynamic>? ??
        {};
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Quick Overview',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              children: [
                SizedBox(
                  width: 160,
                  child: StatCard(
                    title: 'Total Jobs',
                    value: '${jobStats['total'] ?? 0}',
                    subtitle: 'All assigned jobs',
                    backgroundColor: Colors.blue.shade600,
                    textColor: Colors.white,
                    icon: Icons.work_outline,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 160,
                  child: StatCard(
                    title: 'Completed',
                    value: '${jobStats['completed'] ?? 0}',
                    subtitle: 'Successfully finished',
                    backgroundColor: Colors.green.shade600,
                    textColor: Colors.white,
                    icon: Icons.check_circle_outline,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 160,
                  child: StatCard(
                    title: 'In Progress',
                    value: '${jobStats['inProgress'] ?? 0}',
                    subtitle: 'Currently working on',
                    backgroundColor: Colors.orange.shade600,
                    textColor: Colors.white,
                    icon: Icons.hourglass_empty,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 160,
                  child: StatCard(
                    title: 'Rating',
                    value:
                        '${(customerSatisfaction['averageRating'] ?? 0.0).toStringAsFixed(1)}⭐',
                    subtitle: 'Customer satisfaction',
                    backgroundColor: Colors.amber.shade600,
                    textColor: Colors.white,
                    icon: Icons.star_outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Modern Job Status Chart with enhanced design
  Widget _buildModernJobStatusChart() {
    final jobStats =
        _dashboardData['jobStatistics'] as Map<String, dynamic>? ?? {};
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.green.shade50.withOpacity(0.3)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade100.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade400, Colors.green.shade600],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.pie_chart_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Job Status Distribution',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Current workload breakdown',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 250,
            child: PieChart(
              PieChartData(
                sectionsSpace: 4,
                centerSpaceRadius: 60,
                sections: [
                  PieChartSectionData(
                    color: Colors.blue.shade600,
                    value: (jobStats['assigned'] ?? 0).toDouble(),
                    title: '${jobStats['assigned'] ?? 0}',
                    radius: 45,
                    titleStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  PieChartSectionData(
                    color: Colors.orange.shade600,
                    value: (jobStats['inProgress'] ?? 0).toDouble(),
                    title: '${jobStats['inProgress'] ?? 0}',
                    radius: 45,
                    titleStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  PieChartSectionData(
                    color: Colors.green.shade600,
                    value: (jobStats['completed'] ?? 0).toDouble(),
                    title: '${jobStats['completed'] ?? 0}',
                    radius: 45,
                    titleStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  PieChartSectionData(
                    color: Colors.red.shade600,
                    value: (jobStats['onHold'] ?? 0).toDouble(),
                    title: '${jobStats['onHold'] ?? 0}',
                    radius: 45,
                    titleStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  PieChartSectionData(
                    color: Colors.grey.shade600,
                    value: (jobStats['cancelled'] ?? 0).toDouble(),
                    title: '${jobStats['cancelled'] ?? 0}',
                    radius: 45,
                    titleStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Legend
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              _buildLegendItem(
                'Assigned',
                Colors.blue.shade600,
                jobStats['assigned'] ?? 0,
              ),
              _buildLegendItem(
                'In Progress',
                Colors.orange.shade600,
                jobStats['inProgress'] ?? 0,
              ),
              _buildLegendItem(
                'Completed',
                Colors.green.shade600,
                jobStats['completed'] ?? 0,
              ),
              _buildLegendItem(
                'On Hold',
                Colors.red.shade600,
                jobStats['onHold'] ?? 0,
              ),
              _buildLegendItem(
                'Cancelled',
                Colors.grey.shade600,
                jobStats['cancelled'] ?? 0,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, int count) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$label ($count)',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // Modern Priority Distribution Chart
  Widget _buildModernPriorityDistributionChart() {
    if (_isDisposed || !mounted) {
      return const SizedBox.shrink();
    }

    final priorityData =
        _dashboardData['priorityDistribution'] as Map<String, dynamic>? ?? {};
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.purple.shade50.withOpacity(0.3)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.shade100.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade400, Colors.purple.shade600],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.priority_high_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Job Priority Distribution',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Priority levels breakdown',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 280,
            child: SfCartesianChart(
              primaryXAxis: const CategoryAxis(
                labelStyle: TextStyle(fontWeight: FontWeight.w600),
              ),
              primaryYAxis: const NumericAxis(
                labelStyle: TextStyle(fontWeight: FontWeight.w600),
              ),
              plotAreaBorderWidth: 0,
              series: <CartesianSeries>[
                ColumnSeries<ChartData, String>(
                  dataSource: chartData,
                  xValueMapper: (ChartData data, _) => data.x,
                  yValueMapper: (ChartData data, _) => data.y,
                  pointColorMapper: (ChartData data, _) => data.color,
                  dataLabelSettings: const DataLabelSettings(
                    isVisible: true,
                    textStyle: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimePerformanceChart() {
    if (_isDisposed || !mounted) {
      return const SizedBox.shrink();
    }

    final timeData =
        _dashboardData['timePerformance'] as Map<String, dynamic>? ?? {};
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    List<ChartData> chartData = [
      ChartData(
        'Estimated',
        timeData['totalEstimatedHours']?.toDouble() ?? 0,
        Colors.blue.shade600,
      ),
      ChartData(
        'Actual',
        timeData['totalActualHours']?.toDouble() ?? 0,
        Colors.orange.shade600,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.deepPurple.shade50.withOpacity(0.3)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.shade100.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.deepPurple.shade400,
                      Colors.deepPurple.shade600,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.schedule_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Time Performance',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Variance: ${(timeData['timeVariancePercentage'] ?? 0).toStringAsFixed(1)}%',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: (timeData['timeVariancePercentage'] ?? 0) > 0
                            ? Colors.red.shade600
                            : Colors.green.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 220,
            child: SfCartesianChart(
              primaryXAxis: const CategoryAxis(
                labelStyle: TextStyle(fontWeight: FontWeight.w600),
              ),
              primaryYAxis: const NumericAxis(
                labelStyle: TextStyle(fontWeight: FontWeight.w600),
              ),
              plotAreaBorderWidth: 0,
              series: <CartesianSeries>[
                ColumnSeries<ChartData, String>(
                  dataSource: chartData,
                  xValueMapper: (ChartData data, _) => data.x,
                  yValueMapper: (ChartData data, _) => data.y,
                  pointColorMapper: (ChartData data, _) => data.color,
                  dataLabelSettings: const DataLabelSettings(
                    isVisible: true,
                    textStyle: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Modern Cost Analysis Chart
  Widget _buildModernCostAnalysisChart() {
    final costData =
        _dashboardData['costAnalysis'] as Map<String, dynamic>? ?? {};
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.teal.shade50.withOpacity(0.3)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.shade100.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.teal.shade400, Colors.teal.shade600],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.attach_money_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cost Analysis',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Financial performance overview',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.3,
            children: [
              _buildModernCostCard(
                'Estimated Cost',
                'RM ${(costData['totalEstimatedCost'] ?? 0).toStringAsFixed(0)}',
                Icons.calculate_outlined,
                Colors.blue.shade600,
                Colors.blue.shade50,
              ),
              _buildModernCostCard(
                'Actual Cost',
                'RM ${(costData['totalActualCost'] ?? 0).toStringAsFixed(0)}',
                Icons.receipt_long_outlined,
                Colors.orange.shade600,
                Colors.orange.shade50,
              ),
              _buildModernCostCard(
                'Variance',
                'RM ${(costData['costVariance'] ?? 0).toStringAsFixed(0)}',
                Icons.trending_up_outlined,
                (costData['costVariance'] ?? 0) > 0
                    ? Colors.red.shade600
                    : Colors.green.shade600,
                (costData['costVariance'] ?? 0) > 0
                    ? Colors.red.shade50
                    : Colors.green.shade50,
              ),
              _buildModernCostCard(
                'Avg Job Cost',
                'RM ${(costData['averageJobCost'] ?? 0).toStringAsFixed(0)}',
                Icons.analytics_outlined,
                Colors.purple.shade600,
                Colors.purple.shade50,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModernCostCard(
    String title,
    String value,
    IconData icon,
    Color primaryColor,
    Color backgroundColor,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withOpacity(0.2), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: primaryColor, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: primaryColor.withOpacity(0.8),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Modern Calendar View with actual TableCalendar
  Widget _buildModernCalendarView() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.indigo.shade50.withOpacity(0.3)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.shade100.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.indigo.shade400, Colors.indigo.shade600],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Calendar Overview',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Schedule and timeline view',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Filter buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildModernDateFilterButton('assignedAt', 'Assigned'),
              _buildModernDateFilterButton('startedAt', 'Started'),
              _buildModernDateFilterButton('completedAt', 'Completed'),
            ],
          ),
          const SizedBox(height: 24),
          // Actual TableCalendar
          FutureBuilder<Map<DateTime, List<Map<String, dynamic>>>>(
            future: _dashboardService.getJobsByDate(
              mechanicId: _authService.currentMechanicId,
              dateField: _selectedDateFilter,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Container(
                  height: 300,
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return Container(
                  height: 300,
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(child: Text('Error: ${snapshot.error}')),
                );
              }

              final jobsByDate = snapshot.data ?? {};

              return Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                child: TableCalendar<Map<String, dynamic>>(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => false,
                  onDaySelected: (selectedDay, focusedDay) {
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
                        return null;
                      }

                      return Container(
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.indigo.shade300,
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${day.day}',
                                style: TextStyle(
                                  color: Colors.indigo.shade800,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              if (jobs.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.indigo.shade600,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${jobs.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  calendarFormat: CalendarFormat.month,
                  headerStyle: HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle:
                        theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ) ??
                        const TextStyle(),
                  ),
                  calendarStyle: CalendarStyle(
                    markersMaxCount: 0,
                    outsideDaysVisible: false,
                    weekendTextStyle: TextStyle(color: Colors.red.shade400),
                    holidayTextStyle: TextStyle(color: Colors.red.shade800),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          // Legend
          Wrap(
            spacing: 16,
            children: [
              _buildStatusLegend('Has Jobs', Colors.indigo.shade600),
              _buildStatusLegend('No Jobs', Colors.grey.shade400),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModernDateFilterButton(String value, String label) {
    final isSelected = _selectedDateFilter == value;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDateFilter = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [Colors.indigo.shade400, Colors.indigo.shade600],
                )
              : null,
          color: isSelected ? null : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.indigo.shade600 : Colors.grey.shade300,
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.indigo.shade200.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

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
        Text(
          status,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  void _showJobsDialog(DateTime selectedDay, List<Map<String, dynamic>> jobs) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Jobs for ${selectedDay.day}/${selectedDay.month}/${selectedDay.year}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: jobs.length,
            itemBuilder: (context, index) {
              final job = jobs[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(job['title'] ?? 'Untitled Job'),
                  subtitle: Text(job['status'] ?? 'Unknown Status'),
                  leading: CircleAvatar(
                    backgroundColor: _getStatusColor(
                      job['status'] ?? 'pending',
                    ),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => JobDetailScreen(jobId: job['id']),
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
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.amber.shade50.withOpacity(0.3)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.shade100.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.amber.shade400, Colors.amber.shade600],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.star_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customer Satisfaction',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      '${(satisfactionData['averageRating'] ?? 0.0).toStringAsFixed(1)}⭐ average rating',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 220,
            child: SfCartesianChart(
              primaryXAxis: const CategoryAxis(
                labelStyle: TextStyle(fontWeight: FontWeight.w600),
              ),
              primaryYAxis: const NumericAxis(
                labelStyle: TextStyle(fontWeight: FontWeight.w600),
              ),
              plotAreaBorderWidth: 0,
              series: <CartesianSeries>[
                BarSeries<ChartData, String>(
                  dataSource: chartData,
                  xValueMapper: (ChartData data, _) => data.x,
                  yValueMapper: (ChartData data, _) => data.y,
                  pointColorMapper: (ChartData data, _) => data.color,
                  dataLabelSettings: const DataLabelSettings(
                    isVisible: true,
                    textStyle: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskAnalyticsChart() {
    final taskData =
        _dashboardData['taskAnalytics'] as Map<String, dynamic>? ?? {};
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    List<ChartData> chartData = [
      ChartData(
        'Completed',
        (taskData['completedTasks'] ?? 0).toDouble(),
        Colors.green.shade600,
      ),
      ChartData(
        'In Progress',
        (taskData['inProgressTasks'] ?? 0).toDouble(),
        Colors.orange.shade600,
      ),
      ChartData(
        'Pending',
        (taskData['pendingTasks'] ?? 0).toDouble(),
        Colors.red.shade600,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.cyan.shade50.withOpacity(0.3)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.cyan.shade100.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.cyan.shade400, Colors.cyan.shade600],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.task_alt_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Task Analytics',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      '${taskData['totalTasks'] ?? 0} total tasks',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 220,
            child: PieChart(
              PieChartData(
                sectionsSpace: 4,
                centerSpaceRadius: 60,
                sections: chartData.map((data) {
                  return PieChartSectionData(
                    color: data.color,
                    value: data.y,
                    title: '${data.y.toInt()}',
                    radius: 45,
                    titleStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Legend
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: chartData.map((data) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: data.color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${data.x} (${data.y.toInt()})',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
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

  Widget _buildPartsUsageChart() {
    final partsData =
        _dashboardData['partsAnalysis'] as Map<String, dynamic>? ?? {};
    final topParts = partsData['topParts'] as List<dynamic>? ?? [];
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    List<ChartData> chartData = [];
    for (int i = 0; i < (topParts.length > 3 ? 3 : topParts.length); i++) {
      final part = topParts[i] as Map<String, dynamic>;
      chartData.add(
        ChartData(
          part['name'] ?? 'Unknown',
          (part['count'] ?? 0).toDouble(),
          _getRandomColor(i),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.lime.shade50.withOpacity(0.3)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.lime.shade100.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.lime.shade600, Colors.lime.shade700],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.precision_manufacturing_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Top 3 Parts Usage',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Most frequently used parts',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 280,
            child: SfCartesianChart(
              primaryXAxis: const CategoryAxis(
                labelRotation: -45,
                labelStyle: TextStyle(fontWeight: FontWeight.w600),
              ),
              primaryYAxis: const NumericAxis(
                labelStyle: TextStyle(fontWeight: FontWeight.w600),
              ),
              plotAreaBorderWidth: 0,
              series: <CartesianSeries>[
                ColumnSeries<ChartData, String>(
                  dataSource: chartData,
                  xValueMapper: (ChartData data, _) => data.x,
                  yValueMapper: (ChartData data, _) => data.y,
                  pointColorMapper: (ChartData data, _) => data.color,
                  dataLabelSettings: const DataLabelSettings(
                    isVisible: true,
                    textStyle: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: chartData.map((data) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: data.color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${data.x} (${data.y.toInt()})',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildModernTimelineCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.brown.shade50.withOpacity(0.3)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.brown.shade100.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.brown.shade400, Colors.brown.shade600],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.timeline_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Timeline Analytics',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Job progression insights',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildModernTimelineCard(
                      'Avg. Assigned to Started',
                      '${(timelineData['averageAssignedToStartedDays'] ?? 0).toStringAsFixed(1)} days',
                      Icons.play_arrow_rounded,
                      Colors.blue.shade600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildModernTimelineCard(
                      'Avg. Started to Completed',
                      '${(timelineData['averageStartedToCompletedDays'] ?? 0).toStringAsFixed(1)} days',
                      Icons.check_circle_rounded,
                      Colors.green.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildModernTimelineCard(
                      'Started Today',
                      '${timelineData['jobsStartedToday'] ?? 0}',
                      Icons.today_rounded,
                      Colors.orange.shade600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildModernTimelineCard(
                      'Completed Today',
                      '${timelineData['jobsCompletedToday'] ?? 0}',
                      Icons.done_all_rounded,
                      Colors.purple.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildModernTimelineCard(
                      'Assigned This Week',
                      '${timelineData['jobsAssignedThisWeek'] ?? 0}',
                      Icons.assignment_rounded,
                      Colors.teal.shade600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildModernTimelineCard(
                      'Completed This Week',
                      '${timelineData['jobsCompletedThisWeek'] ?? 0}',
                      Icons.check_box_rounded,
                      Colors.indigo.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    List<ChartData> typeChartData = [
      ChartData(
        'Problem',
        (notesData['problemNotes'] ?? 0).toDouble(),
        Colors.red.shade600,
      ),
      ChartData(
        'Request',
        (notesData['requestNotes'] ?? 0).toDouble(),
        Colors.blue.shade600,
      ),
      ChartData(
        'Complete',
        (notesData['completionNotes'] ?? 0).toDouble(),
        Colors.green.shade600,
      ),
    ];

    List<ChartData> statusChartData = [
      ChartData(
        'Pending',
        (notesData['pendingNotes'] ?? 0).toDouble(),
        Colors.orange.shade600,
      ),
      ChartData(
        'Solved',
        (notesData['solvedNotes'] ?? 0).toDouble(),
        Colors.green.shade600,
      ),
      ChartData(
        'Accepted',
        (notesData['acceptedNotes'] ?? 0).toDouble(),
        Colors.blue.shade600,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.grey.shade50.withOpacity(0.3)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.grey.shade600, Colors.grey.shade700],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.note_alt_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notes Analysis',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      '${notesData['totalNotes'] ?? 0} total, ${notesData['resolutionRate'] ?? 0}% resolved',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'By Type',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 180,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 3,
                            centerSpaceRadius: 40,
                            sections: typeChartData.map((data) {
                              return PieChartSectionData(
                                color: data.color,
                                value: data.y,
                                title: '${data.y.toInt()}',
                                radius: 35,
                                titleStyle: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...typeChartData.map(
                        (data) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: data.color,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${data.x} (${data.y.toInt()})',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'By Status',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 180,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 3,
                            centerSpaceRadius: 40,
                            sections: statusChartData.map((data) {
                              return PieChartSectionData(
                                color: data.color,
                                value: data.y,
                                title: '${data.y.toInt()}',
                                radius: 35,
                                titleStyle: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...statusChartData.map(
                        (data) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: data.color,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${data.x} (${data.y.toInt()})',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleAnalytics() {
    final vehicleData =
        _dashboardData['vehicleAnalytics'] as Map<String, dynamic>? ?? {};
    final topMakes = vehicleData['topMakes'] as List<dynamic>? ?? [];
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.red.shade50.withOpacity(0.3)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.red.shade100.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red.shade400, Colors.red.shade600],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.directions_car_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vehicle Analytics',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontSize: 22, // bigger title
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      '${vehicleData['totalVehicles'] ?? 0} vehicles tracked',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 16, // bump up body text
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.3,
            children: [
              _buildModernVehicleInfoCard(
                'Average Year',
                '${vehicleData['averageYear'] ?? 0}',
                Icons.calendar_today_rounded,
                Colors.blue.shade600,
              ),
              _buildModernVehicleInfoCard(
                'Oldest Vehicle',
                '${vehicleData['oldestYear'] ?? 0}',
                Icons.history_rounded,
                Colors.orange.shade600,
              ),
              _buildModernVehicleInfoCard(
                'Newest Vehicle',
                '${vehicleData['newestYear'] ?? 0}',
                Icons.new_releases_rounded,
                Colors.green.shade600,
              ),
              _buildModernVehicleInfoCard(
                'Avg Mileage',
                '${(vehicleData['averageMileage'] ?? 0)} mi',
                Icons.speed_rounded,
                Colors.purple.shade600,
              ),
            ],
          ),
          if (topMakes.isNotEmpty) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Top Vehicle Makes',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 18, // section title bigger
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...topMakes.take(5).map((make) {
                    final makeData = make as Map<String, dynamic>;
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            makeData['make'] ?? 'Unknown',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade600,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${makeData['count'] ?? 0}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14, // count text larger
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModernVehicleInfoCard(
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

  // Modern Assigned Jobs Overview Section
  Widget _buildAssignedJobsOverview() {
    final assignedJobsData =
        _dashboardData['assignedJobsOverview'] as Map<String, dynamic>? ?? {};
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final todayJobs = assignedJobsData['todayJobs'] as List<dynamic>? ?? [];
    final thisWeekJobs =
        assignedJobsData['thisWeekJobs'] as List<dynamic>? ?? [];
    final totalAssigned = assignedJobsData['totalAssigned'] ?? 0;
    final highPriorityJobs = assignedJobsData['highPriorityJobs'] ?? 0;
    final overdueJobs = assignedJobsData['overdueJobs'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.blue.shade50.withOpacity(0.3)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade100.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade400, Colors.blue.shade600],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.assignment_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assigned Jobs Overview',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Your current workload and upcoming tasks',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Summary Cards
          Row(
            children: [
              Expanded(
                child: _buildJobSummaryCard(
                  'Total Assigned',
                  totalAssigned.toString(),
                  Icons.work_rounded,
                  Colors.blue.shade600,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildJobSummaryCard(
                  'High Priority',
                  highPriorityJobs.toString(),
                  Icons.priority_high_rounded,
                  Colors.red.shade600,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildJobSummaryCard(
                  'Overdue',
                  overdueJobs.toString(),
                  Icons.warning_rounded,
                  Colors.orange.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Today's Jobs Section
          if (todayJobs.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.today_rounded,
                        color: Colors.blue.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Today\'s Jobs (${todayJobs.length})',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...todayJobs.take(5).map((job) => _buildJobCard(job, theme)),
                  if (todayJobs.length > 5)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '... and ${todayJobs.length - 5} more jobs',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.blue.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          // This Week's Jobs Section
          if (thisWeekJobs.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.date_range_rounded,
                        color: Colors.blue.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'This Week\'s Jobs (${thisWeekJobs.length})',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...thisWeekJobs
                      .take(3)
                      .map((job) => _buildJobCard(job, theme)),
                  if (thisWeekJobs.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '... and ${thisWeekJobs.length - 3} more jobs',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.blue.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          // Empty state
          if (todayJobs.isEmpty && thisWeekJobs.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.assignment_turned_in_rounded,
                      size: 48,
                      color: Colors.blue.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No assigned jobs for today or this week',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Great job staying on top of your workload!',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.blue.shade600,
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

  Widget _buildJobSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildJobCard(dynamic job, ThemeData theme) {
    final priority = job['priority'] as String? ?? 'medium';
    final status = job['status'] as String? ?? 'assigned';
    final dueDate = job['dueDate'] as String?;

    Color priorityColor = Colors.blue;
    switch (priority) {
      case 'high':
        priorityColor = Colors.red.shade600;
        break;
      case 'medium':
        priorityColor = Colors.orange.shade600;
        break;
      case 'low':
        priorityColor = Colors.green.shade600;
        break;
    }

    Color statusColor = Colors.blue;
    switch (status) {
      case 'assigned':
        statusColor = Colors.blue.shade600;
        break;
      case 'accepted':
        statusColor = Colors.purple.shade600;
        break;
      case 'inProgress':
        statusColor = Colors.orange.shade600;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  job['title'] ?? 'Untitled Job',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: priorityColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: priorityColor.withOpacity(0.3)),
                ),
                child: Text(
                  priority.toUpperCase(),
                  style: TextStyle(
                    color: priorityColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.person_outline, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  job['customerName'] ?? 'Customer',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (dueDate != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.schedule_outlined,
                  size: 14,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  'Due: ${_formatDate(DateTime.parse(dueDate))}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly.isAtSameMomentAs(today)) {
      return 'Today';
    } else if (dateOnly.isAtSameMomentAs(tomorrow)) {
      return 'Tomorrow';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

class ChartData {
  final String x;
  final double y;
  final Color color;

  ChartData(this.x, this.y, this.color);
}
