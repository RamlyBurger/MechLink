import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/customer_detail_service.dart';
import '../utils/date_time_helper.dart';

class CustomerDetailScreen extends StatefulWidget {
  final String customerId;
  final String? customerName;

  const CustomerDetailScreen({
    super.key,
    required this.customerId,
    this.customerName,
  });

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen>
    with TickerProviderStateMixin {
  final CustomerDetailService _customerService = CustomerDetailService();

  Map<String, dynamic>? _customerDetails;
  List<Map<String, dynamic>> _jobHistory = [];
  List<Map<String, dynamic>> _serviceRequests = [];
  List<Map<String, dynamic>> _vehicles = [];
  List<Map<String, dynamic>> _equipment = [];
  Map<String, dynamic> _stats = {};

  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadCustomerData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomerData() async {
    setState(() => _isLoading = true);

    try {
      // Load all customer data in parallel
      final results = await Future.wait([
        _customerService.getCustomerById(widget.customerId),
        _customerService.getCustomerJobHistory(widget.customerId),
        _customerService.getCustomerServiceRequests(widget.customerId),
        _customerService.getCustomerVehicles(widget.customerId),
        _customerService.getCustomerEquipment(widget.customerId),
      ]);

      final customerDetails = results[0] as Map<String, dynamic>?;
      final jobHistory = results[1] as List<Map<String, dynamic>>;
      final serviceRequests = results[2] as List<Map<String, dynamic>>;
      final vehicles = results[3] as List<Map<String, dynamic>>;
      final equipment = results[4] as List<Map<String, dynamic>>;

      setState(() {
        _customerDetails = customerDetails;
        _jobHistory = jobHistory;
        _serviceRequests = serviceRequests;
        _vehicles = vehicles;
        _equipment = equipment;
        _stats = _customerService.getCustomerStats(jobHistory);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading customer data: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: Text(widget.customerName ?? 'Customer Details'),
          backgroundColor: const Color(0xFF5B5BF7),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF5B5BF7)),
              SizedBox(height: 16),
              Text(
                'Loading customer details...',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (_customerDetails == null) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text('Customer Details'),
          backgroundColor: const Color(0xFF5B5BF7),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_off, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('Customer not found', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          // Modern Header with Customer Info
          SliverAppBar(
            expandedHeight: 280,
            floating: false,
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
                        // Customer Name and Avatar
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.2,
                              ),
                              backgroundImage:
                                  _customerDetails!['avatar'] != null
                                  ? NetworkImage(_customerDetails!['avatar'])
                                  : null,
                              child: _customerDetails!['avatar'] == null
                                  ? Text(
                                      (_customerDetails!['name'] ?? 'U')
                                          .substring(0, 1)
                                          .toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _customerDetails!['name'] ?? 'Customer',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Customer since ${DateTimeHelper.formatJoinDate(_customerDetails!['createdAt'])}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Stats Cards
                        _buildCustomerStats(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Tab Bar
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverTabBarDelegate(
              TabBar(
                controller: _tabController,
                isScrollable: true, // Make tab bar scrollable
                labelColor: const Color(0xFF5B5BF7),
                unselectedLabelColor: Colors.grey.shade600,
                indicatorColor: const Color(0xFF5B5BF7),
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                tabs: [
                  const Tab(text: 'Info'),
                  Tab(text: 'Service Requests (${_serviceRequests.length})'),
                  Tab(text: 'Jobs (${_jobHistory.length})'),
                  Tab(text: 'Vehicles (${_vehicles.length})'),
                  Tab(text: 'Equipment (${_equipment.length})'),
                ],
              ),
            ),
          ),
          // Tab Content
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildInfoTab(),
                _buildServiceRequestsTab(),
                _buildJobsTab(),
                _buildVehiclesTab(),
                _buildEquipmentTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerStats() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Jobs',
            '${_stats['totalJobs'] ?? 0}',
            Icons.work_outline,
            Colors.white.withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Total Spent',
            'RM ${(_stats['totalSpent'] ?? 0.0).toStringAsFixed(0)}',
            Icons.account_balance,
            Colors.white.withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Avg Rating',
            _stats['hasRatings']
                ? '${(_stats['averageRating'] ?? 0.0).toStringAsFixed(1)}★'
                : 'N/A',
            Icons.star_outline,
            Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(
        20,
      ), // Restore consistent padding with other tabs
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Contact Information Card
          _buildModernCard(
            title: 'Contact Information',
            icon: Icons.contact_phone,
            child: Column(
              children: [
                if (_customerDetails!['email'] != null)
                  _buildContactRowWithActions(
                    'Email',
                    _customerDetails!['email'],
                    Icons.email_outlined,
                    onCopy: () =>
                        _copyToClipboard(_customerDetails!['email'], 'Email'),
                    onLaunch: () => _launchEmail(_customerDetails!['email']),
                    launchIcon: Icons.email,
                    launchLabel: '',
                  ),
                if (_customerDetails!['phone'] != null)
                  _buildContactRowWithActions(
                    'Phone',
                    _customerDetails!['phone'],
                    Icons.phone_outlined,
                    onCopy: () =>
                        _copyToClipboard(_customerDetails!['phone'], 'Phone'),
                    onLaunch: () => _launchPhone(_customerDetails!['phone']),
                    launchIcon: Icons.phone,
                    launchLabel: '',
                  ),
                if (_customerDetails!['address'] != null)
                  _buildInfoRowModern(
                    'Address',
                    _customerDetails!['address'],
                    Icons.location_on_outlined,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Account Information Card
          _buildModernCard(
            title: 'Account Information',
            icon: Icons.account_circle_outlined,
            child: Column(
              children: [
                _buildInfoRowModern(
                  'Customer ID',
                  widget.customerId,
                  Icons.fingerprint,
                ),
                if (_customerDetails!['createdAt'] != null)
                  _buildInfoRowModern(
                    'Member Since',
                    DateTimeHelper.formatHybridDate(
                      _customerDetails!['createdAt'],
                    ),
                    Icons.calendar_today_outlined,
                  ),
                if (_customerDetails!['updatedAt'] != null)
                  _buildInfoRowModern(
                    'Last Updated',
                    DateTimeHelper.formatHybridDate(
                      _customerDetails!['updatedAt'],
                    ),
                    Icons.update,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceRequestsTab() {
    if (_serviceRequests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.request_page_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No service requests found'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _serviceRequests.length,
      itemBuilder: (context, index) {
        final request = _serviceRequests[index];
        return _buildServiceRequestCard(request);
      },
    );
  }

  Widget _buildServiceRequestCard(Map<String, dynamic> request) {
    return GestureDetector(
      onTap: () {
        // Navigate to jobs screen
        Navigator.pushNamed(context, '/jobs');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    request['title'] ?? 'Untitled Request',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _buildStatusChip(request['status']),
              ],
            ),
            const SizedBox(height: 8),
            if (request['description'] != null) ...[
              Text(
                request['description'],
                style: TextStyle(color: Colors.grey.shade600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
            ],

            // Vehicle/Equipment Information
            if (request['serviceType'] != null) ...[
              Row(
                children: [
                  Icon(
                    request['serviceType'] == 'vehicle'
                        ? Icons.directions_car
                        : Icons.build,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    request['serviceType'] == 'vehicle'
                        ? 'Vehicle Service'
                        : 'Equipment Service',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  if (request['vehicleId'] != null ||
                      request['equipmentId'] != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      'ID: ${request['vehicleId'] ?? request['equipmentId']}',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
            ],

            Row(
              children: [
                Icon(
                  Icons.priority_high,
                  size: 16,
                  color: _getPriorityColor(request['priority']),
                ),
                const SizedBox(width: 4),
                Text(
                  (request['priority'] ?? 'medium').toString().toUpperCase(),
                  style: TextStyle(
                    color: _getPriorityColor(request['priority']),
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  DateTimeHelper.formatHybridDate(request['requestedAt']),
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getPriorityColor(String? priority) {
    switch (priority?.toLowerCase()) {
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

  Widget _buildModernCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF5B5BF7).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: const Color(0xFF5B5BF7), size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildContactRowWithActions(
    String label,
    String value,
    IconData icon, {
    required VoidCallback onCopy,
    required VoidCallback onLaunch,
    required IconData launchIcon,
    required String launchLabel,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade600, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Copy button
          InkWell(
            onTap: onCopy,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
              ),
              child: Icon(
                Icons.content_copy,
                color: Colors.grey.shade600,
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Launch button
          InkWell(
            onTap: onLaunch,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF5B5BF7).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF5B5BF7).withValues(alpha: 0.3),
                ),
              ),
              child: Icon(launchIcon, color: const Color(0xFF5B5BF7), size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRowModern(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade600, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyToClipboard(String text, String type) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$type copied to clipboard'),
          backgroundColor: const Color(0xFF5B5BF7),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  Future<void> _launchEmail(String email) async {
    final success = await _customerService.launchEmail(email);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Opening email app...' : 'Could not open email app',
          ),
          backgroundColor: success ? const Color(0xFF5B5BF7) : Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  Future<void> _launchPhone(String phone) async {
    final success = await _customerService.launchPhone(phone);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Opening phone app...' : 'Could not open phone app',
          ),
          backgroundColor: success ? const Color(0xFF5B5BF7) : Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  Widget _buildJobsTab() {
    if (_jobHistory.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.work_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No job history found'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _jobHistory.length,
      itemBuilder: (context, index) {
        final job = _jobHistory[index];
        return _buildJobCard(job);
      },
    );
  }

  Widget _buildVehiclesTab() {
    if (_vehicles.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_car_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No vehicles found'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _vehicles.length,
      itemBuilder: (context, index) {
        final vehicle = _vehicles[index];
        return _buildVehicleCard(vehicle);
      },
    );
  }

  Widget _buildEquipmentTab() {
    if (_equipment.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.build_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No equipment found'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _equipment.length,
      itemBuilder: (context, index) {
        final equipment = _equipment[index];
        return _buildEquipmentCard(equipment);
      },
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    return GestureDetector(
      onTap: () {
        // Navigate to jobs screen
        Navigator.pushNamed(context, '/jobs');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    job['title'] ?? 'Untitled Job',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _buildStatusChip(job['status']),
              ],
            ),
            const SizedBox(height: 8),
            if (job['description'] != null) ...[
              Text(
                job['description'],
                style: TextStyle(color: Colors.grey.shade600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
            ],

            // Vehicle/Equipment Information
            if (job['serviceType'] != null) ...[
              Row(
                children: [
                  Icon(
                    job['serviceType'] == 'vehicle'
                        ? Icons.directions_car
                        : Icons.build,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    job['serviceType'] == 'vehicle'
                        ? 'Vehicle Service'
                        : 'Equipment Service',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  if (job['vehicleId'] != null ||
                      job['equipmentId'] != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      'ID: ${job['vehicleId'] ?? job['equipmentId']}',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
            ],

            // Mechanic Information
            if (job['mechanicId'] != null) ...[
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    'Mechanic: ${job['mechanicId']}',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // Timestamps Row
            Row(
              children: [
                if (job['estimatedCost'] != null ||
                    job['actualCost'] != null) ...[
                  const SizedBox(width: 4),
                  Text(
                    'RM ${((job['actualCost'] ?? job['estimatedCost']) as num).toStringAsFixed(2)}',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(width: 16),
                ],
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  DateTimeHelper.formatHybridDate(
                    job['assignedAt'] ?? job['createdAt'],
                  ),
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),

            // Additional timestamps if available
            if (job['completedAt'] != null || job['cancelledAt'] != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  if (job['completedAt'] != null) ...[
                    Icon(Icons.check_circle, size: 14, color: Colors.green),
                    const SizedBox(width: 4),
                    Text(
                      'Completed: ${DateTimeHelper.formatHybridDate(job['completedAt'])}',
                      style: TextStyle(color: Colors.green, fontSize: 12),
                    ),
                  ],
                  if (job['cancelledAt'] != null) ...[
                    Icon(Icons.cancel, size: 14, color: Colors.red),
                    const SizedBox(width: 4),
                    Text(
                      'Cancelled: ${DateTimeHelper.formatHybridDate(job['cancelledAt'])}',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleCard(Map<String, dynamic> vehicle) {
    final photos = vehicle['photos'] as List<dynamic>? ?? [];
    final hasPhotos = photos.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo section
          if (hasPhotos)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: SizedBox(
                height: 150,
                width: double.infinity,
                child: Image.network(
                  photos.first,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey.shade200,
                      child: Icon(
                        Icons.directions_car,
                        size: 50,
                        color: Colors.grey.shade400,
                      ),
                    );
                  },
                ),
              ),
            ),
          // Content section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.directions_car,
                        color: Colors.green.shade600,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${vehicle['year'] ?? ''} ${vehicle['make'] ?? ''} ${vehicle['model'] ?? ''}'
                            .trim(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (vehicle['licensePlate'] != null)
                  _buildVehicleInfoRow(
                    'License Plate',
                    vehicle['licensePlate'],
                    Icons.confirmation_number,
                  ),
                if (vehicle['vin'] != null)
                  _buildVehicleInfoRow(
                    'VIN',
                    vehicle['vin'],
                    Icons.fingerprint,
                  ),
                if (vehicle['color'] != null)
                  _buildVehicleInfoRow(
                    'Color',
                    vehicle['color'],
                    Icons.palette,
                  ),
                if (vehicle['mileage'] != null)
                  _buildVehicleInfoRow(
                    'Mileage',
                    '${vehicle['mileage']} miles',
                    Icons.speed,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEquipmentCard(Map<String, dynamic> equipment) {
    final photos = equipment['photos'] as List<dynamic>? ?? [];
    final hasPhotos = photos.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo section
          if (hasPhotos)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: SizedBox(
                height: 150,
                width: double.infinity,
                child: Image.network(
                  photos.first,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey.shade200,
                      child: Icon(
                        Icons.build,
                        size: 50,
                        color: Colors.grey.shade400,
                      ),
                    );
                  },
                ),
              ),
            ),
          // Content section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.build,
                        color: Colors.orange.shade600,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        equipment['name'] ??
                            '${equipment['manufacturer'] ?? ''} ${equipment['model'] ?? ''}'
                                .trim(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (equipment['serialNumber'] != null)
                  _buildVehicleInfoRow(
                    'Serial Number',
                    equipment['serialNumber'],
                    Icons.qr_code,
                  ),
                if (equipment['category'] != null)
                  _buildVehicleInfoRow(
                    'Category',
                    equipment['category'],
                    Icons.category,
                  ),
                if (equipment['condition'] != null)
                  _buildVehicleInfoRow(
                    'Condition',
                    equipment['condition'],
                    Icons.health_and_safety,
                  ),
                if (equipment['year'] != null)
                  _buildVehicleInfoRow(
                    'Year',
                    equipment['year'].toString(),
                    Icons.calendar_today,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String? status) {
    Color color;
    String displayStatus = status ?? 'unknown';

    switch (status?.toLowerCase()) {
      case 'completed':
        color = Colors.green;
        break;
      case 'inprogress':
      case 'in_progress':
        color = Colors.blue;
        displayStatus = 'In Progress';
        break;
      case 'pending':
        color = Colors.orange;
        break;
      case 'cancelled':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        displayStatus.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverTabBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: Colors.white, child: _tabBar);
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}
