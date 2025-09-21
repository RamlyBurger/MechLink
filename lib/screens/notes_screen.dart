import 'package:flutter/material.dart';
import 'package:mechlink/services/notes_service.dart';
import 'package:mechlink/services/auth_service.dart';
import '../utils/date_time_helper.dart';
import 'note_edit_screen.dart';
import 'note_detail_screen.dart';
import 'dart:convert';

class NotesScreen extends StatefulWidget {
  final String? jobId;

  const NotesScreen({super.key, this.jobId});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final NotesService _noteService = NotesService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _notes = [];
  List<Map<String, dynamic>> _filteredNotes = [];
  bool _isLoading = true;
  bool _sortNewestFirst = true; // true for newest first, false for oldest first

  // Quick filter options
  final List<Map<String, dynamic>> _quickFilters = [
    {
      'label': 'All Notes',
      'noteType': 'all',
      'status': 'all',
    },
    {
      'label': 'Problems',
      'noteType': 'problem',
      'status': 'all',
    },
    {
      'label': 'Requests',
      'noteType': 'request',
      'status': 'all',
    },
    {
      'label': 'Solved',
      'noteType': 'all',
      'status': 'solved',
    },
    {
      'label': 'Pending',
      'noteType': 'all',
      'status': 'pending',
    },
    {
      'label': 'Accepted',
      'noteType': 'all',
      'status': 'accepted',
    },
  ];
  int _selectedQuickFilter = 0;

  @override
  void initState() {
    super.initState();
    _loadNotes();
    _searchController.addListener(_filterNotes);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    setState(() => _isLoading = true);
    try {
      List<Map<String, dynamic>> notes;
      
      if (widget.jobId != null) {
        // Get notes for specific job
        notes = await _noteService.getNotesByJobId(widget.jobId!);
      } else {
        // Get all notes and filter by current mechanic
        final currentMechanicId = _authService.currentMechanicId;
        if (currentMechanicId == null) {
          setState(() {
            _notes = [];
            _filteredNotes = [];
            _isLoading = false;
          });
          return;
        }
        
        // Get all notes first
        final allNotes = await _noteService.getAllNotes();
        
        // Filter notes by checking if their job's mechanicId matches current mechanic
        notes = [];
        for (final note in allNotes) {
          final jobId = note['jobId'] as String?;
          if (jobId != null) {
            // Get the job for this note
            final jobStatus = await _noteService.getJobByIdForNote(jobId);
            if (jobStatus != null && jobStatus['mechanicId'] == currentMechanicId) {
              notes.add(note);
            }
          }
        }
      }
      setState(() {
        _notes = notes;
        _filteredNotes = notes;
        _isLoading = false;
      });
      _sortNotes();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading notes: $e')));
      }
    }
  }

  void _filterNotes() {
    final query = _searchController.text.toLowerCase();
    final selectedFilter = _quickFilters[_selectedQuickFilter];
    
    setState(() {
      _filteredNotes = _notes.where((note) {
        // Apply search query filter
        final title = (note['name'] ?? '').toString().toLowerCase();
        final content = (note['description'] ?? '').toString().toLowerCase();
        final noteType = (note['noteType'] ?? '').toString().toLowerCase();
        final matchesSearch = query.isEmpty || 
            title.contains(query) ||
            content.contains(query) ||
            noteType.contains(query);
        
        // Apply quick filter
        final noteTypeFilter = selectedFilter['noteType'] as String;
        final statusFilter = selectedFilter['status'] as String;
        
        final matchesNoteType = noteTypeFilter == 'all' || 
            (note['noteType'] ?? '').toString().toLowerCase() == noteTypeFilter;
        final matchesStatus = statusFilter == 'all' || 
            (note['status'] ?? '').toString().toLowerCase() == statusFilter;
        
        return matchesSearch && matchesNoteType && matchesStatus;
      }).toList();
    });
    _sortNotes();
  }

  void _applyQuickFilter(int index) {
    setState(() {
      _selectedQuickFilter = index;
    });
    _filterNotes();
  }

  void _sortNotes() {
    setState(() {
      _filteredNotes.sort((a, b) {
        if (_sortNewestFirst) {
          return _compareTimestamps(b['createdAt'], a['createdAt']); // Newest first
        } else {
          return _compareTimestamps(a['createdAt'], b['createdAt']); // Oldest first
        }
      });
    });
  }

  void _toggleSort() {
    setState(() {
      _sortNewestFirst = !_sortNewestFirst;
    });
    _sortNotes();
  }

  int _compareTimestamps(dynamic a, dynamic b) {
    try {
      DateTime dateA = DateTime.parse(a.toString());
      DateTime dateB = DateTime.parse(b.toString());
      return dateB.compareTo(dateA);
    } catch (e) {
      return 0;
    }
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

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'solved':
        return Colors.grey;
      case 'accepted':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(widget.jobId != null ? 'Job Notes' : 'All Notes'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          // Modern Sort Toggle Button
          Container(
            margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade300, width: 1),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _toggleSort,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _sortNewestFirst ? Icons.arrow_downward : Icons.arrow_upward,
                        size: 16,
                        color: Colors.grey.shade700,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _sortNewestFirst ? 'Newest' : 'Oldest',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar and Quick Filters
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                // Compact Search Bar
                SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search notes...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                const SizedBox(height: 12),
                // Quick Filter Chips
                SizedBox(
                  height: 32,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _quickFilters.length,
                    itemBuilder: (context, index) {
                      final filter = _quickFilters[index];
                      final isSelected = _selectedQuickFilter == index;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(
                            filter['label'],
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected ? Colors.white : Colors.grey.shade700,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (_) => _applyQuickFilter(index),
                          backgroundColor: Colors.grey.shade200,
                          selectedColor: Colors.orange.shade600,
                          checkmarkColor: Colors.white,
                          elevation: 0,
                          pressElevation: 2,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Notes Grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredNotes.isEmpty
                ? _buildEmptyState()
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.8,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                      itemCount: _filteredNotes.length,
                      itemBuilder: (context, index) =>
                          _buildNoteCard(_filteredNotes[index]),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewNote,
        backgroundColor: Colors.orange.shade600,
        child: const Icon(
          Icons.add,
          color: Colors.white,
        ),
      ),
    );
  }

  Future<void> _createNewNote() async {
    // Only allow creating notes when viewing a specific job
    if (widget.jobId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a specific job to create notes'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteEditScreen(
          jobId: widget.jobId!,
        ),
      ),
    );

    // If note was created successfully, refresh the notes list
    if (result == true) {
      await _loadNotes();
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.note_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isNotEmpty
                ? 'No notes found matching your search'
                : 'No notes found for this job',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          if (_searchController.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                _searchController.clear();
                _filterNotes();
              },
              child: const Text('Clear search'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoteCard(Map<String, dynamic> note) {
    final noteType = note['noteType'] ?? 'general';
    final status = note['status'] ?? 'pending';
    final photos = note['photos'] as List<dynamic>? ?? [];

    return GestureDetector(
      onTap: () => _navigateToNoteDetail(note),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo section
          Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: photos.isNotEmpty
                ? ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    child: _buildPhotoWidget(photos.first.toString()),
                  )
                : _buildPhotoPlaceholder(),
          ),

          // Content section
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    note['name'] ?? 'Untitled Note',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Content preview
                  Text(
                    note['description'] ?? 'No description',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const Spacer(),

                  // Note type and status chips
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getNoteTypeColor(noteType).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _getNoteTypeColor(noteType),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          noteType.toUpperCase(),
                          style: TextStyle(
                            color: _getNoteTypeColor(noteType),
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _getStatusColor(status),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            color: _getStatusColor(status),
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Date
                  Text(
                    DateTimeHelper.formatDateWithTime(note['createdAt']),
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
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

  Future<void> _navigateToNoteDetail(Map<String, dynamic> note) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteDetailScreen(
          noteId: note['id'] ?? note['documentId'] ?? '',
        ),
      ),
    );

    // If note was updated or deleted, refresh the notes list
    if (result == true) {
      await _loadNotes();
    }
  }

  Widget _buildPhotoWidget(String photoString) {
    final isUrl = photoString.startsWith('http://') || photoString.startsWith('https://');
    
    if (isUrl) {
      return Image.network(
        photoString,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => _buildPhotoPlaceholder(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(child: CircularProgressIndicator());
        },
      );
    } else {
      try {
        return Image.memory(
          base64Decode(photoString),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) => _buildPhotoPlaceholder(),
        );
      } catch (e) {
        return _buildPhotoPlaceholder();
      }
    }
  }

  Widget _buildPhotoPlaceholder() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.grey.shade200,
      child: Icon(Icons.note_outlined, size: 32, color: Colors.grey.shade400),
    );
  }
}
