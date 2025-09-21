import 'package:flutter/material.dart';
import 'package:mechlink/services/chats_service.dart';
import 'package:mechlink/services/auth_service.dart';
import 'package:mechlink/models/chat_history.dart';

class ChatsHistoryScreen extends StatefulWidget {
  final Function(ChatHistory) onChatSelected;
  final ChatHistory? selectedChatHistory;
  final VoidCallback? onNewChat;
  final VoidCallback? onDeleteAll;
  final Function(ChatHistory)? onChatDeleted;

  const ChatsHistoryScreen({
    super.key,
    required this.onChatSelected,
    this.selectedChatHistory,
    this.onNewChat,
    this.onDeleteAll,
    this.onChatDeleted,
  });

  @override
  State<ChatsHistoryScreen> createState() => _ChatsHistoryScreenState();
}

class _ChatsHistoryScreenState extends State<ChatsHistoryScreen> {
  final ChatsService _chatsService = ChatsService();
  final AuthService _authService = AuthService();

  List<ChatHistory> _chatHistories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChatHistories();
  }

  Future<void> _loadChatHistories() async {
    setState(() => _isLoading = true);
    try {
      final mechanicId = _authService.currentMechanicId;
      if (mechanicId == null) {
        setState(() => _isLoading = false);
        return;
      }

      final histories = await _chatsService.getChatHistories(mechanicId);
      setState(() {
        _chatHistories = histories;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading chat histories: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteChat(ChatHistory chatHistory) async {
    final confirmed = await _showDeleteConfirmation();
    if (!confirmed) return;

    try {
      final success = await _chatsService.deleteChatHistory(chatHistory.id);
      if (success) {
        await _loadChatHistories();
        // Notify parent that this chat was deleted
        if (widget.onChatDeleted != null) {
          widget.onChatDeleted!(chatHistory);
        }
      } else {
        _showErrorSnackBar('Error deleting chat');
      }
    } catch (e) {
      print('Error deleting chat: $e');
      _showErrorSnackBar('Error deleting chat');
    }
  }

  Future<void> _deleteAllChats() async {
    if (_chatHistories.isEmpty) return;

    final confirmed = await _showDeleteAllConfirmation();
    if (!confirmed) return;

    try {
      // Delete all chat histories
      for (final chat in _chatHistories) {
        await _chatsService.deleteChatHistory(chat.id);
      }

      // Reload chat histories
      await _loadChatHistories();

      // Notify parent about delete all
      if (widget.onDeleteAll != null) {
        widget.onDeleteAll!();
      }
    } catch (e) {
      print('Error deleting all chats: $e');
      _showErrorSnackBar('Error deleting all chats');
    }
  }

  Future<bool> _showDeleteConfirmation() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Chat'),
            content: const Text(
              'Are you sure you want to delete this chat? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _showDeleteAllConfirmation() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete All Chats'),
            content: Text(
              'Are you sure you want to delete all ${_chatHistories.length} chats? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete All'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Minimal header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.history,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Chat History',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          // Chat histories list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _chatHistories.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.chat_bubble_outline,
                            size: 32,
                            color: Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No conversations yet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Start chatting to see history',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _chatHistories.length,
                    itemBuilder: (context, index) {
                      final chat = _chatHistories[index];
                      final isSelected =
                          widget.selectedChatHistory?.id == chat.id;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.blue.shade50
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected
                              ? Border.all(
                                  color: Colors.blue.shade200,
                                  width: 1.5,
                                )
                              : Border.all(color: Colors.grey.shade200),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: Colors.blue.withValues(alpha: 0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => widget.onChatSelected(chat),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  // Chat icon
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.blue.shade100
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.smart_toy_outlined,
                                      color: isSelected
                                          ? Colors.blue.shade600
                                          : Colors.grey.shade600,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Chat details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Title
                                        Text(
                                          chat.title ?? 'Untitled Chat',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: isSelected
                                                ? FontWeight.w600
                                                : FontWeight.w500,
                                            color: Colors.black87,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),

                                        // Created date
                                        Text(
                                          'Created ${_formatDate(chat.createdAt)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),

                                        // Updated date (if different from created)
                                        if (chat.updatedAt
                                                .difference(chat.createdAt)
                                                .inMinutes >
                                            1)
                                          Text(
                                            'Updated ${_formatDate(chat.updatedAt)}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),

                                  IconButton(
                                    onPressed: () => _deleteChat(chat),
                                    icon: Icon(
                                      Icons.close, // proper "X" icon
                                      color: const Color.fromARGB(
                                        255,
                                        255,
                                        171,
                                        165,
                                      ),
                                      size: 15,
                                    ),
                                    tooltip: 'Delete Chat',
                                    padding: EdgeInsets.zero,
                                    constraints: BoxConstraints(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Delete All button at bottom (minimal design)
          if (_chatHistories.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: _deleteAllChats,
                  icon: Icon(
                    Icons.delete_sweep_outlined,
                    color: Colors.red.shade600,
                    size: 18,
                  ),
                  label: Text(
                    'Delete All',
                    style: TextStyle(
                      color: Colors.red.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.red.shade200),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Method to refresh chat histories from parent
  Future<void> refreshChatHistories() async {
    await _loadChatHistories();
  }
}
