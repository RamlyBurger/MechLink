import 'package:flutter/material.dart';
import 'package:mechlink/services/note_detail_service.dart';
import 'package:mechlink/screens/note_edit_screen.dart';
import 'package:mechlink/screens/customer_detail_screen.dart';
import 'package:mechlink/screens/service_history_screen.dart';
import 'package:mechlink/screens/job_detail_screen.dart';
import '../utils/date_time_helper.dart';
import 'dart:convert';

class NoteDetailScreen extends StatefulWidget {
  final String noteId;

  const NoteDetailScreen({super.key, required this.noteId});

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  final NoteDetailService _noteDetailService = NoteDetailService();

  Map<String, dynamic>? _noteDetails;
  List<Map<String, dynamic>> _relatedNotes = [];
  bool _isLoading = true;

  late ScrollController _scrollController;
  late PageController _photoPageController;

  int _currentPhotoIndex = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _photoPageController = PageController();
    _loadNoteDetails();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _photoPageController.dispose();
    super.dispose();
  }

  Future<void> _loadNoteDetails() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final noteDetails = await _noteDetailService.getNoteWithDetails(widget.noteId);
      
      if (noteDetails != null) {
        final jobId = noteDetails['jobId'] as String?;
        List<Map<String, dynamic>> relatedNotes = [];
        
        if (jobId != null) {
          relatedNotes = await _noteDetailService.getRelatedNotes(jobId, widget.noteId);
        }

        if (mounted) {
          setState(() {
            _noteDetails = noteDetails;
            _relatedNotes = relatedNotes;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Note not found')),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading note: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Note Details'),
          backgroundColor: Colors.orange.shade600,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_noteDetails == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Note Details'),
          backgroundColor: Colors.orange.shade600,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('Note not found'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_noteDetails!['name'] ?? 'Note Details'),
        backgroundColor: Colors.orange.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _editNote,
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => _buildPopupMenuItems(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo Section
            _buildPhotoSection(),
            // Note Info Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildNoteInfoSection(),
            ),
            // Related Notes Section
            if (_relatedNotes.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildRelatedNotesSection(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<PopupMenuEntry<String>> _buildPopupMenuItems() {
    final noteType = _noteDetails!['noteType'] ?? 'problem';
    final currentStatus = _noteDetails!['status'] ?? 'pending';
    
    List<PopupMenuEntry<String>> items = [];
    
    // Add status change options based on note type
    if (noteType == 'request') {
      if (currentStatus != 'pending') {
        items.add(
          const PopupMenuItem(
            value: 'mark_pending',
            child: Row(
              children: [
                Icon(Icons.pending_outlined, size: 20),
                SizedBox(width: 8),
                Text('Mark as Pending'),
              ],
            ),
          ),
        );
      }
      if (currentStatus != 'accepted') {
        items.add(
          const PopupMenuItem(
            value: 'mark_accepted',
            child: Row(
              children: [
                Icon(Icons.check_circle_outline, size: 20),
                SizedBox(width: 8),
                Text('Mark as Accepted'),
              ],
            ),
          ),
        );
      }
    } else {
      // Problem type
      if (currentStatus != 'pending') {
        items.add(
          const PopupMenuItem(
            value: 'mark_pending',
            child: Row(
              children: [
                Icon(Icons.pending_outlined, size: 20),
                SizedBox(width: 8),
                Text('Mark as Pending'),
              ],
            ),
          ),
        );
      }
      if (currentStatus != 'solved') {
        items.add(
          const PopupMenuItem(
            value: 'mark_solved',
            child: Row(
              children: [
                Icon(Icons.check_circle_outline, size: 20),
                SizedBox(width: 8),
                Text('Mark as Solved'),
              ],
            ),
          ),
        );
      }
    }
    
    // Add delete option
    items.add(
      const PopupMenuItem(
        value: 'delete',
        child: Row(
          children: [
            Icon(Icons.delete_outline, size: 20, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Note', style: TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
    
    return items;
  }

  // Photo Section with enhanced navigation
  Widget _buildPhotoSection() {
    List<String> photos = List<String>.from(_noteDetails!['photos'] ?? []);

    if (photos.isEmpty) {
      // Default background with note icon
      return SizedBox(
        height: 250,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.orange.shade400, Colors.orange.shade600],
            ),
          ),
          child: Center(
            child: Icon(
              Icons.note_outlined,
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
              final photoString = photos[index];
              final isUrl = photoString.startsWith('http://') || photoString.startsWith('https://');
              
              return Container(
                decoration: BoxDecoration(color: Colors.grey.shade200),
                child: isUrl
                    ? Image.network(
                        photoString,
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
                                    'Failed to load image',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      )
                    : Image.memory(
                        base64Decode(photoString),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey.shade200,
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
                                    'Failed to load image',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              );
            },
          ),

          // Photo indicators
          if (photos.length > 1)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: photos.asMap().entries.map((entry) {
                  return Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentPhotoIndex == entry.key
                          ? Colors.white
                          : Colors.white.withOpacity(0.5),
                    ),
                  );
                }).toList(),
              ),
            ),

          // Photo navigation arrows
          if (photos.length > 1) ...[
            Positioned(
              left: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  icon: const Icon(Icons.chevron_left, color: Colors.white, size: 32),
                  onPressed: _currentPhotoIndex > 0
                      ? () {
                          _photoPageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      : null,
                ),
              ),
            ),
            Positioned(
              right: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  icon: const Icon(Icons.chevron_right, color: Colors.white, size: 32),
                  onPressed: _currentPhotoIndex < photos.length - 1
                      ? () {
                          _photoPageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      : null,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoteInfoSection() {
    final job = _noteDetails!['job'] as Map<String, dynamic>?;
    final customer = _noteDetails!['customer'] as Map<String, dynamic>?;
    final vehicle = _noteDetails!['vehicle'] as Map<String, dynamic>?;
    final equipment = _noteDetails!['equipment'] as Map<String, dynamic>?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Note Status and Type
        Row(
          children: [
            _buildStatusChip(_noteDetails!['status'] ?? 'pending'),
            const SizedBox(width: 8),
            _buildTypeChip(_noteDetails!['noteType'] ?? 'problem'),
          ],
        ),
        const SizedBox(height: 16),

        // Note Description
        _buildInfoCard(
          title: 'Description',
          content: _noteDetails!['description'] ?? 'No description',
          icon: Icons.description_outlined,
        ),
        const SizedBox(height: 16),

        // Job Information
        if (job != null) ...
        [
          _buildInfoCard(
            title: 'Job',
            content: job['title'] ?? 'Untitled Job',
            subtitle: job['description'],
            icon: Icons.work_outline,
            onViewMore: () => _navigateToJobDetail(job['documentId'] ?? job['id']),
          ),
          const SizedBox(height: 16),
        ],

        // Customer Information
        if (customer != null) ...
        [
          _buildInfoCard(
            title: 'Customer',
            content: customer['name'] ?? 'Unknown Customer',
            subtitle: customer['email'] ?? customer['phone'],
            icon: Icons.person_outline,
            onViewMore: () => _navigateToCustomerDetail(customer['documentId'] ?? customer['id']),
          ),
          const SizedBox(height: 16),
        ],

        // Vehicle/Equipment Information
        if (vehicle != null) ...
        [
          _buildInfoCard(
            title: 'Vehicle',
            content: '${vehicle['make'] ?? ''} ${vehicle['model'] ?? ''}'.trim(),
            subtitle: 'License: ${vehicle['licensePlate'] ?? 'N/A'}',
            icon: Icons.directions_car_outlined,
            onViewMore: () => _navigateToServiceHistory(vehicle['documentId'] ?? vehicle['id']),
          ),
          const SizedBox(height: 16),
        ] else if (equipment != null) ...
        [
          _buildInfoCard(
            title: 'Equipment',
            content: '${equipment['make'] ?? ''} ${equipment['model'] ?? ''}'.trim(),
            subtitle: 'Serial: ${equipment['serialNumber'] ?? 'N/A'}',
            icon: Icons.build_outlined,
            onViewMore: () => _navigateToServiceHistory(equipment['documentId'] ?? equipment['id']),
          ),
          const SizedBox(height: 16),
        ],

        // Timestamps
        Row(
          children: [
            Expanded(
              child: _buildInfoCard(
                title: 'Created',
                content: DateTimeHelper.formatDateWithTime(_noteDetails!['createdAt']),
                icon: Icons.access_time,
                compact: true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildInfoCard(
                title: 'Updated',
                content: DateTimeHelper.formatDateWithTime(_noteDetails!['updatedAt']),
                icon: Icons.update,
                compact: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRelatedNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Related Notes',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _relatedNotes.length,
          itemBuilder: (context, index) {
            final note = _relatedNotes[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getNoteTypeColor(note['noteType']),
                  child: Icon(
                    note['noteType'] == 'problem' ? Icons.error_outline : Icons.help_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                title: Text(
                  note['name'] ?? 'Untitled Note',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  note['description'] ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  DateTimeHelper.formatDateWithTime(note['createdAt']),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NoteDetailScreen(noteId: note['id']),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String displayText;

    switch (status.toLowerCase()) {
      case 'pending':
        color = Colors.orange;
        displayText = 'Pending';
        break;
      case 'solved':
        color = Colors.grey;
        displayText = 'Solved';
        break;
      case 'accepted':
        color = Colors.green;
        displayText = 'Accepted';
        break;
      default:
        color = Colors.grey;
        displayText = status;
    }

    return Chip(
      label: Text(
        displayText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  Widget _buildTypeChip(String noteType) {
    Color color;
    String displayText;
    IconData icon;

    switch (noteType.toLowerCase()) {
      case 'problem':
        color = Colors.red;
        displayText = 'Problem';
        icon = Icons.error_outline;
        break;
      case 'request':
        color = Colors.blue;
        displayText = 'Request';
        icon = Icons.help_outline;
        break;
      default:
        color = Colors.grey;
        displayText = noteType;
        icon = Icons.note_outlined;
    }

    return Chip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            displayText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String content,
    String? subtitle,
    required IconData icon,
    bool compact = false,
    VoidCallback? onViewMore,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: Colors.orange.shade600,
            size: compact ? 20 : 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: compact ? 12 : 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: compact ? 14 : 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: compact ? 11 : 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
                if (onViewMore != null) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: onViewMore,
                    child: Text(
                      'View more',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade600,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getNoteTypeColor(String? noteType) {
    switch (noteType?.toLowerCase()) {
      case 'problem':
        return Colors.red;
      case 'request':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Future<void> _editNote() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteEditScreen(
          noteId: widget.noteId,
          jobId: _noteDetails!['jobId'],
        ),
      ),
    );

    if (result == true) {
      _loadNoteDetails(); // Refresh note details
    }
  }

  Future<void> _handleMenuAction(String action) async {
    switch (action) {
      case 'mark_solved':
        await _updateNoteStatus('solved');
        break;
      case 'mark_pending':
        await _updateNoteStatus('pending');
        break;
      case 'mark_accepted':
        await _updateNoteStatus('accepted');
        break;
      case 'delete':
        await _deleteNote();
        break;
    }
  }

  Future<void> _updateNoteStatus(String status) async {
    try {
      final success = await _noteDetailService.updateNoteStatus(widget.noteId, status);
      if (success) {
        setState(() {
          _noteDetails!['status'] = status;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Note marked as ${status.toLowerCase()}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update note status'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteNote() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text('Are you sure you want to delete this note? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final success = await _noteDetailService.deleteNote(widget.noteId);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Note deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true); // Return to previous screen
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete note'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _navigateToJobDetail(String jobId) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JobDetailScreen(jobId: jobId),
      ),
    );
  }

  Future<void> _navigateToCustomerDetail(String customerId) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerDetailScreen(customerId: customerId),
      ),
    );
  }

  Future<void> _navigateToServiceHistory(String vehicleId) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ServiceHistoryScreen(vehicleId: vehicleId),
      ),
    );
  }
}
