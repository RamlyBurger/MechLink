import 'package:flutter/material.dart';
import 'package:mechlink/services/job_detail_service.dart';
import 'package:mechlink/services/auth_service.dart';
import 'package:mechlink/screens/tasks_screen.dart';
import 'package:mechlink/screens/notes_screen.dart';
import 'package:mechlink/screens/customer_detail_screen.dart';
import 'package:mechlink/screens/service_history_screen.dart';
import 'package:mechlink/screens/digital_sign_off_screen.dart';
import '../utils/date_time_helper.dart';
import 'dart:convert';

class JobDetailScreen extends StatefulWidget {
  final String jobId;

  const JobDetailScreen({super.key, required this.jobId});

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  final JobDetailService _jobDetailService = JobDetailService();
  final AuthService _authService = AuthService();

  Map<String, dynamic>? _jobDetails;
  bool _isLoading = true;

  late ScrollController _scrollController;
  late PageController _photoPageController;

  int _currentPhotoIndex = 0;
  bool _showPhotoCarousel = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _photoPageController = PageController();

    _loadJobDetails();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _photoPageController.dispose();
    super.dispose();
  }

  Future<void> _loadJobDetails() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      Map<String, dynamic>? jobDetails = await _jobDetailService
          .getJobWithCompleteDetails(widget.jobId);

      if (mounted) {
        setState(() {
          _jobDetails = jobDetails;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading job details: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Job Details')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading job details...'),
            ],
          ),
        ),
      );
    }

    if (_jobDetails == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Job Details')),
        body: const Center(child: Text('Job not found')),
      );
    }

    final customer = _jobDetails!['customer'] as Map<String, dynamic>?;
    final vehicle = _jobDetails!['vehicle'] as Map<String, dynamic>?;
    final equipment = _jobDetails!['equipment'] as Map<String, dynamic>?;
    final tasks = _jobDetails!['tasks'] as List<Map<String, dynamic>>? ?? [];
    final allTasksCompleted =
        _jobDetails!['allTasksCompleted'] as bool? ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(_jobDetails!['title'] ?? 'Job Details'),
        backgroundColor: const Color(0xFF5B5BF7),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo Section as normal content
            _buildPhotoSection(),
            // Job Info Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildJobInfoSection(customer, vehicle, equipment, tasks),
            ),
            // Digital Signature Section
            if (_jobDetails!['digitalSignOff'] != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: _buildDigitalSignOffSection(),
              ),
          ],
        ),
      ),
      // Floating Action Button for Job Actions
      floatingActionButton: _buildJobActionButton(allTasksCompleted),
    );
  }

  // Photo Section with enhanced navigation
  Widget _buildPhotoSection() {
    final vehicle = _jobDetails!['vehicle'] as Map<String, dynamic>?;
    final equipment = _jobDetails!['equipment'] as Map<String, dynamic>?;

    // Get photos from vehicle or equipment
    List<String> photos = [];
    if (vehicle != null && vehicle['photos'] != null) {
      photos = List<String>.from(vehicle['photos']);
    } else if (equipment != null && equipment['photos'] != null) {
      photos = List<String>.from(equipment['photos']);
    }

    if (photos.isEmpty) {
      // Default background with asset icon
      return SizedBox(
        height: 250,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade400, Colors.blue.shade600],
            ),
          ),
          child: Center(
            child: Icon(
              vehicle != null ? Icons.directions_car : Icons.build,
              size: 80,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ),
      );
    }

    // Photo gallery with enhanced controls
    return SizedBox(
      height: 250,
      child: Stack(
        children: [
          // Main photo view
          PageView.builder(
            controller: _photoPageController,
            itemCount: photos.length,
            onPageChanged: (index) {
              setState(() {
                _currentPhotoIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return Container(
                decoration: BoxDecoration(color: Colors.grey.shade200),
                child: Image.network(
                  photos[index],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey.shade200,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Image not available',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),

          // Left navigation button
          if (photos.length > 1 && _currentPhotoIndex > 0)
            Positioned(
              left: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.chevron_left, color: Colors.white),
                    onPressed: () {
                      _photoPageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                  ),
                ),
              ),
            ),

          // Right navigation button
          if (photos.length > 1 && _currentPhotoIndex < photos.length - 1)
            Positioned(
              right: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.chevron_right, color: Colors.white),
                    onPressed: () {
                      _photoPageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                  ),
                ),
              ),
            ),

          // Photo counter and carousel toggle
          if (photos.length > 1)
            Positioned(
              right: 16,
              top: 16,
              child: Column(
                children: [
                  // Photo counter
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${_currentPhotoIndex + 1}/${photos.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Carousel toggle button
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        _showPhotoCarousel ? Icons.close : Icons.view_carousel,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _showPhotoCarousel = !_showPhotoCarousel;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),

          // Photo carousel
          if (_showPhotoCarousel && photos.length > 1)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(8),
                  itemCount: photos.length,
                  itemBuilder: (context, index) {
                    final isSelected = index == _currentPhotoIndex;
                    return GestureDetector(
                      onTap: () {
                        _photoPageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: Container(
                        width: 64,
                        height: 64,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 2)
                              : null,
                          color: Colors.grey.shade200,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            photos[index],
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    value:
                                        loadingProgress.expectedTotalBytes !=
                                            null
                                        ? loadingProgress
                                                  .cumulativeBytesLoaded /
                                              loadingProgress
                                                  .expectedTotalBytes!
                                        : null,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey.shade200,
                                child: Icon(
                                  Icons.broken_image,
                                  size: 24,
                                  color: Colors.grey.shade400,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Job Information Section
  Widget _buildJobInfoSection(
    Map<String, dynamic>? customer,
    Map<String, dynamic>? vehicle,
    Map<String, dynamic>? equipment,
    List<Map<String, dynamic>> tasks,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Job Title
          Text(
            _jobDetails!['title'] ?? 'Untitled Job',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Status and Priority in same row
          Row(
            children: [
              // Status section
              const Icon(Icons.info, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              const Text('Status: ', style: TextStyle(color: Colors.grey)),
              _buildStatusChip(_jobDetails!['status']),
              const SizedBox(width: 16),
              // Priority section
              const Icon(Icons.flag, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              const Text('Priority: ', style: TextStyle(color: Colors.grey)),
              _buildPriorityChip(_jobDetails!['priority']),
            ],
          ),
          const SizedBox(height: 20),

          // Job Description Box with Details and Status Button
          Container(
            padding: const EdgeInsets.all(16),
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
                    const Expanded(
                      child: Text(
                        'Job Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    // Dynamic Status Management Buttons
                    ..._buildStatusActionButtons(),
                  ],
                ),
                const SizedBox(height: 12),

                // Description
                if (_jobDetails!['description'] != null) ...[
                  Text(
                    _jobDetails!['description'],
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Cost and Duration Information
                Row(
                  children: [
                    if (_jobDetails!['estimatedCost'] != null) ...[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Estimated Cost',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '\$${_jobDetails!['estimatedCost'].toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_jobDetails!['estimatedDuration'] != null) ...[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Estimated Duration',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${_jobDetails!['estimatedDuration']}h',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),

                // Actual Cost and Duration (if exists)
                if (_jobDetails!['actualCost'] != null ||
                    _jobDetails!['actualDuration'] != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (_jobDetails!['actualCost'] != null) ...[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Actual Cost',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '\$${_jobDetails!['actualCost'].toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (_jobDetails!['actualDuration'] != null) ...[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Actual Duration',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '${_jobDetails!['actualDuration']}h',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],

                // Dates Information
                if (_jobDetails!['startedAt'] != null ||
                    _jobDetails!['completedAt'] != null) ...[
                  const SizedBox(height: 12),
                  if (_jobDetails!['startedAt'] != null) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.play_arrow,
                          color: Colors.grey.shade600,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Started: ${DateTimeHelper.formatRelativeDate(_jobDetails!['startedAt'])}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (_jobDetails!['completedAt'] != null) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.grey.shade600,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Completed: ${DateTimeHelper.formatRelativeDate(_jobDetails!['completedAt'])}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],

                // Customer Rating (if exists)
                if (_jobDetails!['customerRating'] != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber.shade600, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Customer Rating: ${_jobDetails!['customerRating']}/5',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Customer Information Box
          if (customer != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person, color: Colors.blue.shade600, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Customer Information',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _navigateToCustomerDetails(),
                        child: const Text('View More'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    customer['name'] ?? 'Unknown Customer',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (customer['phone'] != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.phone,
                          color: Colors.grey.shade600,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          customer['phone'],
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                  if (customer['email'] != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.email,
                          color: Colors.grey.shade600,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          customer['email'],
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Vehicle/Equipment Information Box
          if (vehicle != null || equipment != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        vehicle != null ? Icons.directions_car : Icons.build,
                        color: Colors.green.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          vehicle != null
                              ? 'Vehicle Information'
                              : 'Equipment Information',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _navigateToServiceHistory(),
                        child: const Text('Service History'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    vehicle != null
                        ? '${vehicle['year'] ?? ''} ${vehicle['make'] ?? ''} ${vehicle['model'] ?? ''}'
                        : '${equipment!['manufacturer'] ?? ''} ${equipment['model'] ?? ''}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  // Vehicle-specific details
                  if (vehicle != null) ...[
                    if (vehicle['licensePlate'] != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.confirmation_number,
                            color: Colors.grey.shade600,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'License: ${vehicle['licensePlate']}',
                              style: TextStyle(color: Colors.grey.shade600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (vehicle['vin'] != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.fingerprint,
                            color: Colors.grey.shade600,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'VIN: ${vehicle['vin']}',
                              style: TextStyle(color: Colors.grey.shade600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (vehicle['color'] != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.palette,
                            color: Colors.grey.shade600,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Color: ${vehicle['color']}',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ],
                    if (vehicle['mileage'] != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.speed,
                            color: Colors.grey.shade600,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Mileage: ${vehicle['mileage']} miles',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ],
                  ],

                  // Equipment-specific details
                  if (equipment != null) ...[
                    if (equipment['serialNumber'] != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.qr_code,
                            color: Colors.grey.shade600,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Serial: ${equipment['serialNumber']}',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ],
                    if (equipment['category'] != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.category,
                            color: Colors.grey.shade600,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Category: ${equipment['category']}',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Assigned Parts Section
          if (_jobDetails!['parts'] != null &&
              (_jobDetails!['parts'] as List).isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 6,
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
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.build_circle,
                          color: Colors.blue.shade600,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Assigned Parts',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...(_jobDetails!['parts'] as List).asMap().entries.map((
                    entry,
                  ) {
                    int index = entry.key;
                    String part = entry.value.toString();
                    bool isLast =
                        index == (_jobDetails!['parts'] as List).length - 1;

                    return Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.blue.shade400,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                part,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (!isLast) const SizedBox(height: 8),
                      ],
                    );
                  }).toList(),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Navigation Buttons
          Column(
            children: [
              // Tasks Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TasksScreen(jobId: widget.jobId),
                      ),
                    );

                    // Reload job details when returning from tasks screen
                    // This ensures task status changes are reflected
                    _loadJobDetails();
                  },
                  icon: const Icon(Icons.task),
                  label: Text('Tasks (${tasks.length})'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Notes Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _navigateToNotes(),
                  icon: const Icon(Icons.note),
                  label: const Text('Job Notes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  void _showStatusUpdateDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Job Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('In Progress'),
              leading: const Icon(Icons.play_arrow, color: Colors.blue),
              onTap: () {
                Navigator.pop(context);
                _updateJobStatus('inProgress');
              },
            ),
            ListTile(
              title: const Text('On Hold'),
              leading: const Icon(Icons.pause, color: Colors.orange),
              onTap: () {
                Navigator.pop(context);
                _updateJobStatus('onHold');
              },
            ),
            ListTile(
              title: const Text('Completed'),
              leading: const Icon(Icons.check_circle, color: Colors.green),
              onTap: () {
                Navigator.pop(context);
                _updateJobStatus('completed');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateJobStatus(String newStatus) async {
    try {
      bool success = await _jobDetailService.updateJobStatus(
        widget.jobId,
        newStatus,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Job status updated to $newStatus')),
        );
        _loadJobDetails(); // Reload to update status
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update job status')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating status: $e')));
    }
  }

  // Floating Action Button
  Widget? _buildJobActionButton(bool allTasksCompleted) {
    if (_jobDetails!['status'] == 'pending') {
      return FloatingActionButton.extended(
        onPressed: () => _acceptJob(),
        icon: const Icon(Icons.check),
        label: const Text('Accept Job'),
        backgroundColor: Colors.green,
      );
    }

    if (allTasksCompleted &&
        (_jobDetails!['status'] == 'accepted' ||
            _jobDetails!['status'] == 'inProgress')) {
      final hasDigitalSignOff = _jobDetails!['digitalSignOff'] != null;

      if (!hasDigitalSignOff) {
        // Show Digital Sign Off button when tasks completed but not signed off
        return FloatingActionButton.extended(
          onPressed: () => _navigateToDigitalSignOff(),
          icon: const Icon(
            Icons.draw,
            color: Colors.white, // 👈 make the icon white
          ),
          label: const Text(
            'Digital Sign Off',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.orange,
        );
      } else {
        // Show Complete Job button when signed off
        return FloatingActionButton.extended(
          onPressed: () => _navigateToSignOff(),
          icon: const Icon(Icons.done_all, color: Colors.white),
          label: const Text(
            'Complete Job',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.blue,
        );
      }
    }

    return null;
  }

  /// Build dynamic status action buttons based on current job status
  List<Widget> _buildStatusActionButtons() {
    if (_jobDetails == null) return [];

    String currentStatus = _jobDetails!['status'] ?? 'assigned';
    List<Widget> buttons = [];

    switch (currentStatus) {
      case 'assigned':
        // Show Accept and Reject buttons
        buttons.addAll([
          ElevatedButton.icon(
            onPressed: () => _showAcceptConfirmation(),
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Accept'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _showRejectConfirmation(),
            icon: const Icon(Icons.close, size: 16),
            label: const Text('Reject'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ]);
        break;

      case 'accepted':
        // Show Start Work button
        buttons.add(
          ElevatedButton.icon(
            onPressed: () => _changeJobStatus('inProgress'),
            icon: const Icon(Icons.play_arrow, size: 16),
            label: const Text('Start Work'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        );
        break;

      case 'inProgress':
        // Show Complete (if all tasks done) and Put on Hold buttons
        buttons.addAll([
          if (_areAllTasksCompleted())
            ElevatedButton.icon(
              onPressed: () => _changeJobStatus('completed'),
              icon: const Icon(Icons.done_all, size: 16),
              label: const Text('Complete'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          if (_areAllTasksCompleted()) const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _changeJobStatus('onHold'),
            icon: const Icon(Icons.pause, size: 16),
            label: const Text('Put on Hold'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ]);
        break;

      case 'onHold':
        // Show Resume Work button
        buttons.add(
          ElevatedButton.icon(
            onPressed: () => _changeJobStatus('inProgress'),
            icon: const Icon(Icons.play_arrow, size: 16),
            label: const Text('Resume Work'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        );
        break;

      case 'completed':
      case 'cancelled':
        // No action buttons for final states
        break;

      default:
        // Fallback: show generic status change button
        buttons.add(
          ElevatedButton.icon(
            onPressed: () => _showStatusUpdateDialog(),
            icon: const Icon(Icons.update, size: 16),
            label: const Text('Change Status'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        );
    }

    return buttons;
  }

  /// Check if all tasks are completed
  bool _areAllTasksCompleted() {
    if (_jobDetails == null || _jobDetails!['tasks'] == null) return false;
    List<dynamic> tasks = _jobDetails!['tasks'] as List<dynamic>;
    if (tasks.isEmpty) return false;
    return tasks.every((task) => task['status'] == 'completed');
  }

  /// Show accept confirmation dialog
  void _showAcceptConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept Job'),
        content: const Text('Are you sure you want to accept this job?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _acceptJob();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text(
              'Accept',
              style: TextStyle(color: Colors.white), // 👈 text color
            ),
          ),
        ],
      ),
    );
  }

  /// Show reject confirmation dialog
  void _showRejectConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Job'),
        content: const Text(
          'Are you sure you want to reject this job? This will cancel the job and all its tasks.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _rejectJob();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Reject',
              style: TextStyle(color: Colors.white), // 👈 text color
            ),
          ),
        ],
      ),
    );
  }

  /// Reject/Cancel the job
  Future<void> _rejectJob() async {
    try {
      bool success = await _jobDetailService.rejectJob(widget.jobId);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Job rejected and cancelled successfully'),
          ),
        );
        _loadJobDetails(); // Reload to update status
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to reject job')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error rejecting job: $e')));
    }
  }

  /// Change job status with validation
  Future<void> _changeJobStatus(String newStatus) async {
    try {
      // Validate status change
      Map<String, dynamic> validation = await _jobDetailService
          .validateStatusChange(widget.jobId, newStatus);

      if (!validation['allowed']) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(validation['reason'])));
        return;
      }

      // Proceed with status change
      bool success = await _jobDetailService.updateJobStatus(
        widget.jobId,
        newStatus,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Job status updated to $newStatus')),
        );
        _loadJobDetails(); // Reload to update status
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update job status')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating status: $e')));
    }
  }

  Future<void> _acceptJob() async {
    try {
      bool success = await _jobDetailService.acceptJob(
        widget.jobId,
        _authService.currentMechanicId!,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job accepted successfully')),
        );
        _loadJobDetails(); // Reload to update status
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to accept job: $e')));
    }
  }

  void _navigateToCustomerDetails() {
    if (_jobDetails != null && _jobDetails!['customerId'] != null) {
      final customer = _jobDetails!['customer'] as Map<String, dynamic>?;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CustomerDetailScreen(
            customerId: _jobDetails!['customerId'],
            customerName: customer?['name'],
          ),
        ),
      );
    }
  }

  void _navigateToServiceHistory() {
    if (_jobDetails != null) {
      // Check for vehicle first
      if (_jobDetails!['vehicleId'] != null) {
        final vehicle = _jobDetails!['vehicle'] as Map<String, dynamic>?;
        final vehicleName = vehicle != null
            ? '${vehicle['year']} ${vehicle['make']} ${vehicle['model']}'
            : null;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ServiceHistoryScreen(
              vehicleId: _jobDetails!['vehicleId'],
              vehicleName: vehicleName,
            ),
          ),
        );
      }
      // Check for equipment
      else if (_jobDetails!['equipmentId'] != null) {
        final equipment = _jobDetails!['equipment'] as Map<String, dynamic>?;
        final equipmentName = equipment != null
            ? '${equipment['manufacturer']} ${equipment['model']} (${equipment['category']})'
            : null;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ServiceHistoryScreen(
              vehicleId:
                  _jobDetails!['equipmentId'], // Using same parameter name for simplicity
              vehicleName: equipmentName,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Asset information not available for this job'),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Job details not available')),
      );
    }
  }

  Future<void> _navigateToNotes() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => NotesScreen(jobId: widget.jobId)),
    );

    // Reload job details when returning from notes screen
    // This ensures any note changes are reflected
    _loadJobDetails();
  }

  void _navigateToSignOff() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text("Sign Off")),
          body: const Center(child: Text("Sign off feature coming soon...")),
        ),
      ),
    );
  }

  Widget _buildDigitalSignOffSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Digital Sign Off',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.verified, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Job Signed Off',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    base64Decode(
                      _getBase64String(_jobDetails!['digitalSignOff']),
                    ),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey.shade100,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.broken_image,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Failed to load signature',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_jobDetails!['digitalSignOffAt'] != null)
                Text(
                  'Signed off on: ${DateTimeHelper.formatDateWithTime(_jobDetails!['digitalSignOffAt'])}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _navigateToDigitalSignOff() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DigitalSignOffScreen(
          jobId: widget.jobId,
          jobTitle: _jobDetails!['title'] ?? 'Job',
        ),
      ),
    );

    // If signature was completed, reload job details
    if (result == true) {
      _loadJobDetails();
    }
  }

  /// Extract base64 string from data URL or return as-is if already base64
  String _getBase64String(String input) {
    if (input.startsWith('data:')) {
      // Remove data URL prefix (e.g., "data:image/png;base64,")
      final commaIndex = input.indexOf(',');
      if (commaIndex != -1) {
        return input.substring(commaIndex + 1);
      }
    }
    return input;
  }
}
