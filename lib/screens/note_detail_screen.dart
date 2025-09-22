import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mechlink/services/note_detail_service.dart';
import 'package:mechlink/screens/note_edit_screen.dart';
import 'package:mechlink/screens/customer_detail_screen.dart';
import 'package:mechlink/screens/service_history_screen.dart';
import 'package:mechlink/screens/job_detail_screen.dart';
import '../utils/date_time_helper.dart';
import 'dart:convert';
import 'dart:ui';

class NoteDetailScreen extends StatefulWidget {
  final String noteId;

  const NoteDetailScreen({super.key, required this.noteId});

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen>
    with TickerProviderStateMixin {
  final NoteDetailService _noteDetailService = NoteDetailService();

  Map<String, dynamic>? _noteDetails;
  List<Map<String, dynamic>> _relatedNotes = [];
  bool _isLoading = true;

  late ScrollController _scrollController;
  late PageController _photoPageController;
  late AnimationController _fadeAnimationController;
  late AnimationController _slideAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  int _currentPhotoIndex = 0;
  bool _isAppBarExpanded = true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _photoPageController = PageController();

    // Initialize animations
    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
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

    // Add scroll listener for app bar effects
    _scrollController.addListener(_onScroll);

    _loadNoteDetails();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _photoPageController.dispose();
    _fadeAnimationController.dispose();
    _slideAnimationController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    final isExpanded = offset < 100;
    if (isExpanded != _isAppBarExpanded) {
      setState(() {
        _isAppBarExpanded = isExpanded;
      });
    }
  }

  Future<void> _loadNoteDetails() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final noteDetails = await _noteDetailService.getNoteWithDetails(
        widget.noteId,
      );

      if (noteDetails != null) {
        final jobId = noteDetails['jobId'] as String?;
        List<Map<String, dynamic>> relatedNotes = [];

        if (jobId != null) {
          relatedNotes = await _noteDetailService.getRelatedNotes(
            jobId,
            widget.noteId,
          );
        }

        if (mounted) {
          setState(() {
            _noteDetails = noteDetails;
            _relatedNotes = relatedNotes;
            _isLoading = false;
          });
          // Start animations after data is loaded
          _fadeAnimationController.forward();
          _slideAnimationController.forward();
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Note not found')));
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading note: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.orange.shade400,
                Colors.orange.shade600,
                Colors.deepOrange.shade700,
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Modern App Bar
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'Note Details',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Loading Content
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                            strokeWidth: 3,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Loading note details...',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 16,
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
      );
    }

    if (_noteDetails == null) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.grey.shade400, Colors.grey.shade600],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Modern App Bar
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'Note Details',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Error Content
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Note not found',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'The requested note could not be loaded',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 14,
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
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(0),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
      ),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Modern Hero Section with Photo
          _buildHeroSection(),
          // Content Section
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      // Drag Handle
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: colorScheme.onSurface.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Note Info Section
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: _buildNoteInfoSection(),
                      ),
                      // Related Notes Section
                      if (_relatedNotes.isNotEmpty) ...[
                        const SizedBox(height: 32),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: _buildRelatedNotesSection(),
                        ),
                      ],
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButtons(),
    );
  }

  // Modern Hero Section with enhanced photo display
  Widget _buildHeroSection() {
    List<String> photos = List<String>.from(_noteDetails!['photos'] ?? []);
    final colorScheme = Theme.of(context).colorScheme;

    return SliverAppBar(
      expandedHeight: 320,
      pinned: true,
      stretch: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: IconButton(
            icon: const Icon(Icons.edit, color: Colors.white, size: 20),
            onPressed: _editNote,
          ),
        ),
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white, size: 20),
            onSelected: _handleMenuAction,
            itemBuilder: (context) => _buildPopupMenuItems(),
            color: colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground,
        ],
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Background Image or Gradient
            if (photos.isNotEmpty)
              NotificationListener<OverscrollIndicatorNotification>(
                onNotification: (overscroll) {
                  overscroll.disallowIndicator();
                  return true;
                },
                child: _buildPhotoGallery(photos), // <-- contains arrows
              )
            else
              _buildDefaultHeroBackground(),

            // 👇 MOVE THESE BELOW PHOTO GALLERY
            // Gradient Overlay
            IgnorePointer(
              ignoring: true, // so touches pass through
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.3),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),

            // Note Title and Status
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildModernStatusChip(
                        _noteDetails!['status'] ?? 'pending',
                      ),
                      const SizedBox(width: 8),
                      _buildModernTypeChip(
                        _noteDetails!['noteType'] ?? 'problem',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _noteDetails!['name'] ?? 'Untitled Note',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          offset: Offset(0, 2),
                          blurRadius: 4,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Created ${DateTimeHelper.formatDateWithTime(_noteDetails!['createdAt'])}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      shadows: const [
                        Shadow(
                          offset: Offset(0, 1),
                          blurRadius: 2,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoGallery(List<String> photos) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // PageView
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
            final isUrl =
                photoString.startsWith('http://') ||
                photoString.startsWith('https://');

            return isUrl
                ? Image.network(
                    photoString,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: Colors.grey.shade200,
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                : null,
                            color: Colors.orange.shade600,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) =>
                        _buildDefaultHeroBackground(),
                  )
                : Image.memory(
                    base64Decode(photoString),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildDefaultHeroBackground(),
                  );
          },
        ),

        // Left button
        Positioned(
          left: 8,
          top: 0,
          bottom: 0,
          child: Center(
            child: IconButton(
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: 0.3),
                shape: const CircleBorder(),
              ),
              icon: const Icon(
                Icons.chevron_left,
                color: Colors.white,
                size: 32,
              ),
              onPressed: () {
                if (_currentPhotoIndex > 0) {
                  _photoPageController.previousPage(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                  );
                }
              },
            ),
          ),
        ),

        // Right button
        Positioned(
          right: 8,
          top: 0,
          bottom: 0,
          child: Center(
            child: IconButton(
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: 0.3),
                shape: const CircleBorder(),
              ),
              icon: const Icon(
                Icons.chevron_right,
                color: Colors.white,
                size: 32,
              ),
              onPressed: () {
                if (_currentPhotoIndex < photos.length - 1) {
                  _photoPageController.nextPage(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                  );
                }
              },
            ),
          ),
        ),

        // Photo Indicators
        if (photos.length > 1)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: photos.asMap().entries.map((entry) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: _currentPhotoIndex == entry.key ? 24 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: _currentPhotoIndex == entry.key
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildDefaultHeroBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.orange.shade400,
            Colors.orange.shade600,
            Colors.deepOrange.shade700,
          ],
        ),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Icon(
            Icons.note_outlined,
            size: 80,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingActionButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Edit Button
        FloatingActionButton(
          heroTag: "edit",
          onPressed: _editNote,
          backgroundColor: Colors.orange.shade600,
          child: const Icon(Icons.edit, color: Colors.white),
        ),
      ],
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

  // Modern Status Chip with enhanced styling
  Widget _buildModernStatusChip(String status) {
    Color backgroundColor;
    Color foregroundColor;
    String displayText;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'pending':
        backgroundColor = Colors.orange.shade600;
        foregroundColor = Colors.white;
        displayText = 'Pending';
        icon = Icons.pending_outlined;
        break;
      case 'solved':
        backgroundColor = Colors.green.shade600;
        foregroundColor = Colors.white;
        displayText = 'Solved';
        icon = Icons.check_circle_outline;
        break;
      case 'accepted':
        backgroundColor = Colors.blue.shade600;
        foregroundColor = Colors.white;
        displayText = 'Accepted';
        icon = Icons.verified_outlined;
        break;
      default:
        backgroundColor = Colors.grey.shade600;
        foregroundColor = Colors.white;
        displayText = status;
        icon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: backgroundColor.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foregroundColor),
          const SizedBox(width: 6),
          Text(
            displayText,
            style: TextStyle(
              color: foregroundColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernTypeChip(String noteType) {
    Color backgroundColor;
    Color foregroundColor;
    String displayText;
    IconData icon;

    switch (noteType.toLowerCase()) {
      case 'problem':
        backgroundColor = Colors.red.shade600;
        foregroundColor = Colors.white;
        displayText = 'Problem';
        icon = Icons.error_outline;
        break;
      case 'request':
        backgroundColor = Colors.purple.shade600;
        foregroundColor = Colors.white;
        displayText = 'Request';
        icon = Icons.help_outline;
        break;
      default:
        backgroundColor = Colors.grey.shade600;
        foregroundColor = Colors.white;
        displayText = noteType;
        icon = Icons.note_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: backgroundColor.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foregroundColor),
          const SizedBox(width: 6),
          Text(
            displayText,
            style: TextStyle(
              color: foregroundColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteInfoSection() {
    final job = _noteDetails!['job'] as Map<String, dynamic>?;
    final customer = _noteDetails!['customer'] as Map<String, dynamic>?;
    final vehicle = _noteDetails!['vehicle'] as Map<String, dynamic>?;
    final equipment = _noteDetails!['equipment'] as Map<String, dynamic>?;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title
        Text(
          'Note Details',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 20),

        // Note Description
        _buildModernInfoCard(
          title: 'Description',
          content: _noteDetails!['description'] ?? 'No description',
          icon: Icons.description_outlined,
          iconColor: Colors.blue.shade600,
        ),
        const SizedBox(height: 16),

        // Job Information
        if (job != null) ...[
          _buildModernInfoCard(
            title: 'Related Job',
            content: job['title'] ?? 'Untitled Job',
            subtitle: job['description'],
            icon: Icons.work_outline,
            iconColor: Colors.purple.shade600,
            onViewMore: () =>
                _navigateToJobDetail(job['documentId'] ?? job['id']),
          ),
          const SizedBox(height: 16),
        ],

        // Customer Information
        if (customer != null) ...[
          _buildModernInfoCard(
            title: 'Customer',
            content: customer['name'] ?? 'Customer',
            subtitle: customer['email'] ?? customer['phone'],
            icon: Icons.person_outline,
            iconColor: Colors.green.shade600,
            onViewMore: () => _navigateToCustomerDetail(
              customer['documentId'] ?? customer['id'],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Vehicle/Equipment Information
        if (vehicle != null) ...[
          _buildModernInfoCard(
            title: 'Vehicle',
            content: '${vehicle['make'] ?? ''} ${vehicle['model'] ?? ''}'
                .trim(),
            subtitle: 'License: ${vehicle['licensePlate'] ?? 'N/A'}',
            icon: Icons.directions_car_outlined,
            iconColor: Colors.orange.shade600,
            onViewMore: () => _navigateToServiceHistory(
              vehicle['documentId'] ?? vehicle['id'],
            ),
          ),
          const SizedBox(height: 16),
        ] else if (equipment != null) ...[
          _buildModernInfoCard(
            title: 'Equipment',
            content: '${equipment['make'] ?? ''} ${equipment['model'] ?? ''}'
                .trim(),
            subtitle: 'Serial: ${equipment['serialNumber'] ?? 'N/A'}',
            icon: Icons.build_outlined,
            iconColor: Colors.teal.shade600,
            onViewMore: () => _navigateToServiceHistory(
              equipment['documentId'] ?? equipment['id'],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Timestamps in modern grid layout
        Row(
          children: [
            Expanded(
              child: _buildModernInfoCard(
                title: 'Last Updated',
                content: DateTimeHelper.formatDateWithTime(
                  _noteDetails!['updatedAt'],
                ),
                icon: Icons.update,
                iconColor: Colors.indigo.shade600,
                compact: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Modern Info Card with enhanced Material 3 styling
  Widget _buildModernInfoCard({
    required String title,
    required String content,
    String? subtitle,
    required IconData icon,
    required Color iconColor,
    bool compact = false,
    VoidCallback? onViewMore,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 16 : 20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: compact ? 20 : 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w600,
                        fontSize: compact ? 12 : 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      content,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: compact ? 14 : 16,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                          fontSize: compact ? 11 : 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (onViewMore != null) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onViewMore,
                icon: Icon(Icons.arrow_forward_ios, size: 14, color: iconColor),
                label: Text(
                  'View Details',
                  style: TextStyle(
                    color: iconColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  backgroundColor: iconColor.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRelatedNotesSection() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade600.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.link, color: Colors.blue.shade600, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'Related Notes',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _relatedNotes.length,
          itemBuilder: (context, index) {
            final note = _relatedNotes[index];
            final noteTypeColor = _getNoteTypeColor(note['noteType']);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: noteTypeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    note['noteType'] == 'problem'
                        ? Icons.error_outline
                        : Icons.help_outline,
                    color: noteTypeColor,
                    size: 20,
                  ),
                ),
                title: Text(
                  note['name'] ?? 'Untitled Note',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      note['description'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateTimeHelper.formatDateWithTime(note['createdAt']),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          NoteDetailScreen(noteId: note['id']),
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

  Color _getNoteTypeColor(String? noteType) {
    switch (noteType?.toLowerCase()) {
      case 'problem':
        return Colors.red.shade600;
      case 'request':
        return Colors.purple.shade600;
      default:
        return Colors.grey.shade600;
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
      final success = await _noteDetailService.updateNoteStatus(
        widget.noteId,
        status,
      );
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
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteNote() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text(
          'Are you sure you want to delete this note? This action cannot be undone.',
        ),
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
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _navigateToJobDetail(String jobId) async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => JobDetailScreen(jobId: jobId)),
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
