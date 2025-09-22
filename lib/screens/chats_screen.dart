import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:async';

import 'package:mechlink/services/chats_service.dart';
import 'package:mechlink/services/auth_service.dart';
import 'package:mechlink/models/chat_history.dart';
import 'package:mechlink/models/chat_message.dart';
import 'package:mechlink/screens/chats_history_screen.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen>
    with SingleTickerProviderStateMixin {
  final ChatsService _chatsService = ChatsService();
  final AuthService _authService = AuthService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();

  List<ChatHistory> _chatHistories = [];
  List<ChatMessage> _currentMessages = [];
  ChatHistory? _selectedChatHistory;
  bool _isLoading = true;
  bool _isLoadingMessages = false;
  bool _isSending = false;
  bool _showSidebar = false;

  // Image preview state
  String? _previewImageBase64;

  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  // Note: ChatsHistoryScreen will automatically reload when rebuilt

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Initialize slide animation (from left)
    _slideAnimation =
        Tween<Offset>(begin: const Offset(-1.0, 0.0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInOut,
          ),
        );

    // Initialize fade animation for background
    _fadeAnimation = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Precache the background image to prevent flickering
    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(const AssetImage('assets/chat/chat_bg.webp'), context);
    });

    _loadChatHistories();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadChatHistories() async {
    setState(() => _isLoading = true);
    try {
      final mechanicId = _authService.currentMechanicId;
      if (mechanicId == null) {
        _showErrorSnackBar('Please log in to view chats');
        setState(() => _isLoading = false);
        return;
      }

      final histories = await _chatsService.getChatHistories(mechanicId);

      // Auto-create chat if none exist
      if (histories.isEmpty) {
        print('No chat histories found, creating new chat automatically');
        final chatHistoryId = await _chatsService.createChatHistory(mechanicId);
        if (chatHistoryId != null) {
          // Reload histories after creating new chat
          final updatedHistories = await _chatsService.getChatHistories(
            mechanicId,
          );
          setState(() {
            _chatHistories = updatedHistories;
            _isLoading = false;
          });

          // Auto-select the newly created chat
          if (_chatHistories.isNotEmpty) {
            _selectChatHistory(_chatHistories.first);
          }
        } else {
          setState(() {
            _chatHistories = [];
            _isLoading = false;
          });
          _showErrorSnackBar('Failed to create initial chat');
        }
      } else {
        setState(() {
          _chatHistories = histories;
          _isLoading = false;
        });

        // Auto-select first chat if available and none is selected
        if (_chatHistories.isNotEmpty && _selectedChatHistory == null) {
          _selectChatHistory(_chatHistories.first);
        }
      }
    } catch (e) {
      print('Error loading chat histories: $e');
      _showErrorSnackBar('Error loading chat histories');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectChatHistory(ChatHistory chatHistory) async {
    setState(() {
      _selectedChatHistory = chatHistory;
      _isLoadingMessages = true;
    });

    try {
      final messages = await _chatsService.getChatMessages(chatHistory.id);
      setState(() {
        _currentMessages = messages;
        _isLoadingMessages = false;
      });
      _scrollToBottom();
    } catch (e) {
      print('Error loading messages: $e');
      _showErrorSnackBar('Error loading messages');
      setState(() => _isLoadingMessages = false);
    }
  }

  Future<void> _createNewChat() async {
    // Check if current chat is empty (has no messages)
    if (_selectedChatHistory != null && _currentMessages.isEmpty) {
      _showErrorSnackBar('Current chat is empty. Send a message first.');
      return;
    }

    final mechanicId = _authService.currentMechanicId;
    if (mechanicId == null) {
      _showErrorSnackBar('Please log in to create a new chat');
      return;
    }

    try {
      final chatHistoryId = await _chatsService.createChatHistory(mechanicId);
      if (chatHistoryId != null) {
        await _loadChatHistories();

        // Find and select the newly created chat
        if (_chatHistories.isNotEmpty) {
          final newChat = _chatHistories.firstWhere(
            (chat) => chat.id == chatHistoryId,
            orElse: () => _chatHistories.first,
          );
          _selectChatHistory(newChat);
        }

        // ChatsHistoryScreen will automatically refresh when rebuilt
      } else {
        _showErrorSnackBar('Failed to create new chat - please try again');
      }
    } catch (e) {
      print('Exception in _createNewChat: $e');
      _showErrorSnackBar('Error creating new chat: ${e.toString()}');
    }
  }

  void _toggleSidebar() {
    setState(() {
      _showSidebar = true;
    });
    _animationController.forward();
  }

  void _hideSidebar() {
    _animationController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _showSidebar = false;
        });
      }
    });
  }

  Future<void> _sendTextMessage({String? base64Image}) async {
    final message = _messageController.text.trim();
    final imageToSend = base64Image ?? _previewImageBase64;

    if (message.isEmpty && imageToSend == null) return;
    if (_selectedChatHistory == null) return;

    // Validate message length (2000 character limit)
    if (message.length > 2000) {
      _showErrorSnackBar('Message too long. Maximum 2000 characters allowed.');
      return;
    }

    // Clear input and preview immediately
    _messageController.clear();
    _clearImagePreview();

    // Create user message object immediately
    final userMessage = ChatMessage(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}', // Temporary ID
      sender: MessageSender.mechanic,
      chatHistoryId: _selectedChatHistory!.id,
      createdAt: DateTime.now(),
      content: message.isEmpty ? 'Image' : message,
      type: imageToSend != null ? MessageType.image : MessageType.text,
      base64Image: imageToSend,
    );

    // Add user message to UI immediately
    setState(() {
      _currentMessages.add(userMessage);
    });
    _scrollToBottom();

    try {
      // Send user message to Firestore in background
      final messageId = await _chatsService.sendTextMessage(
        chatHistoryId: _selectedChatHistory!.id,
        sender: MessageSender.mechanic,
        content: message.isEmpty ? 'Image' : message,
        base64Image: imageToSend,
      );

      // Update the temporary message with real ID
      if (messageId != null) {
        setState(() {
          final index = _currentMessages.indexWhere(
            (msg) => msg.id == userMessage.id,
          );
          if (index != -1) {
            _currentMessages[index] = userMessage.copyWith(id: messageId);
          }
        });
      }

      // Add loading message for AI response
      final loadingMessage = ChatMessage(
        id: 'loading_${DateTime.now().millisecondsSinceEpoch}',
        sender: MessageSender.bot,
        chatHistoryId: _selectedChatHistory!.id,
        createdAt: DateTime.now(),
        content: '_LOADING_SPINNER_',
        type: MessageType.text,
      );

      setState(() {
        _currentMessages.add(loadingMessage);
        _isSending = true; // Only show loading for AI response
      });
      _scrollToBottom();

      // Generate AI response
      String promptMessage = message.isEmpty ? 'User sent an image' : message;
      await _chatsService.generateAIResponse(
        chatHistoryId: _selectedChatHistory!.id,
        userMessage: promptMessage,
        base64Image: imageToSend, // Pass image for recognition
      );

      // Remove loading message and get the actual AI response
      setState(() {
        _currentMessages.removeWhere((msg) => msg.id == loadingMessage.id);
        _isSending = false;
      });

      // Fetch only the latest AI message instead of reloading all
      await _appendLatestAIMessage();
    } catch (e) {
      print('Error sending message: $e');
      _showErrorSnackBar('Error sending message');

      // Remove user message if sending failed
      setState(() {
        _currentMessages.removeWhere((msg) => msg.id == userMessage.id);
        _currentMessages.removeWhere(
          (msg) => msg.sender == MessageSender.bot && msg.content == '...',
        );
        _isSending = false;
      });
    }
  }

  Future<void> _showImageOptions() async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.blue),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.green),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_selectedChatHistory == null) return;

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image != null) {
        // Convert image to base64 for preview
        final bytes = await image.readAsBytes();
        final base64Image = base64Encode(bytes);

        // Set preview state instead of sending immediately
        setState(() {
          _previewImageBase64 = base64Image;
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      _showErrorSnackBar('Error selecting image');
    }
  }

  void _onChatSelected(ChatHistory chatHistory) {
    // Only select if it's a different chat to prevent unnecessary reloads
    if (_selectedChatHistory?.id != chatHistory.id) {
      _selectChatHistory(chatHistory);
    }
    // Don't automatically hide sidebar - let user click outside to close
  }

  void _onDeleteAll() {
    // Clear current state when all chats are deleted
    setState(() {
      _selectedChatHistory = null;
      _currentMessages = [];
      _chatHistories = [];
    });
    // Auto-create a new chat
    _createNewChat();
  }

  void _onChatDeleted(ChatHistory deletedChat) {
    // If the deleted chat was the currently selected one, handle fallback
    if (_selectedChatHistory?.id == deletedChat.id) {
      setState(() {
        _selectedChatHistory = null;
        _currentMessages = [];
      });

      // Reload chat histories to get updated list
      _loadChatHistories().then((_) {
        // Try to select the most recent chat history
        if (_chatHistories.isNotEmpty) {
          // Select the first (most recent) chat history
          _selectChatHistory(_chatHistories.first);
        } else {
          // No chat histories left, show welcome state
          setState(() {
            _selectedChatHistory = null;
            _currentMessages = [];
          });
        }
      });
    }
  }

  Future<void> _appendLatestAIMessage() async {
    if (_selectedChatHistory == null) return;

    try {
      // Get all messages and find the latest AI message
      final allMessages = await _chatsService.getChatMessages(
        _selectedChatHistory!.id,
      );

      // Find the latest AI message that's not already in our current messages
      final latestAIMessage = allMessages
          .where((msg) => msg.sender == MessageSender.bot)
          .where(
            (msg) => !_currentMessages.any((current) => current.id == msg.id),
          )
          .lastOrNull;

      if (latestAIMessage != null) {
        setState(() {
          _currentMessages.add(latestAIMessage);
        });
        _scrollToBottom();
      }
    } catch (e) {
      print('Error appending latest AI message: $e');
      // Fallback: reload all messages if append fails
      await _selectChatHistory(_selectedChatHistory!);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        // First scroll immediately
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );

        // Then scroll again after a short delay to account for images loading
        Future.delayed(const Duration(milliseconds: 500), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });
  }

  void _clearImagePreview() {
    setState(() {
      _previewImageBase64 = null;
    });
  }

  void _showFullScreenImage(String base64Image, {String? title}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            _FullScreenImageViewer(base64Image: base64Image, title: title),
      ),
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Message copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _regenerateMessage(ChatMessage message) async {
    if (_selectedChatHistory == null) return;

    // Find the user message that triggered this bot response
    final messageIndex = _currentMessages.indexOf(message);
    if (messageIndex > 0) {
      final previousMessage = _currentMessages[messageIndex - 1];
      if (previousMessage.sender == MessageSender.mechanic) {
        try {
          // Delete the current bot message from database
          await _chatsService.deleteMessage(message.id);

          // Remove the current bot message from UI
          setState(() {
            _currentMessages.removeAt(messageIndex);
          });

          // Add loading message
          final loadingMessage = ChatMessage(
            id: 'loading_${DateTime.now().millisecondsSinceEpoch}',
            sender: MessageSender.bot,
            chatHistoryId: _selectedChatHistory!.id,
            createdAt: DateTime.now(),
            content: '_LOADING_SPINNER_',
            type: MessageType.text,
          );

          setState(() {
            _currentMessages.add(loadingMessage);
          });
          _scrollToBottom();

          // Generate new AI response
          try {
            await _chatsService.generateAIResponse(
              chatHistoryId: _selectedChatHistory!.id,
              userMessage: previousMessage.content,
              base64Image: previousMessage
                  .base64Image, // Pass original image if it was an image message
            );

            // Remove loading message
            setState(() {
              _currentMessages.removeWhere(
                (msg) => msg.content == '_LOADING_SPINNER_',
              );
            });

            // Fetch the new AI response
            await _appendLatestAIMessage();
          } catch (e) {
            // Remove loading message if it exists
            setState(() {
              _currentMessages.removeWhere(
                (msg) => msg.content == '_LOADING_SPINNER_',
              );
            });
            _showErrorSnackBar('Failed to regenerate message');
          }
        } catch (e) {
          // Handle any errors in the regenerate process
          setState(() {
            _currentMessages.removeWhere(
              (msg) => msg.content == '_LOADING_SPINNER_',
            );
          });
          _showErrorSnackBar('Failed to regenerate message');
        }
      }
    }
  }

  // Note: Methods like _clearImagePreview, _showImageOptions, etc. are already defined elsewhere in this file

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: Stack(
          children: [
            // Main chat area
            Column(
              children: [
                // Top navigation bar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade200,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Left side - Back button
                      Positioned(
                        left: 0,
                        top: -2,
                        bottom: 0,
                        child: IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back),
                          tooltip: 'Back',
                        ),
                      ),

                      // Center - Chat title (absolutely centered)
                      Center(
                        child: _selectedChatHistory != null
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _selectedChatHistory!.title ??
                                        'MechLink Assistant',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Online • Ready to help',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green.shade600,
                                    ),
                                  ),
                                ],
                              )
                            : const Text(
                                'MechLink Assistant',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),

                      // Right side - Action buttons
                      Positioned(
                        right: 0,
                        top: -2,
                        bottom: 0,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // New Chat button
                            IconButton(
                              onPressed: _createNewChat,
                              icon: const Icon(Icons.add),
                              tooltip: 'New Chat',
                            ),
                            const SizedBox(width: 8),
                            // Sidebar button
                            IconButton(
                              onPressed: _toggleSidebar,
                              icon: const Icon(Icons.menu),
                              tooltip: 'Chat History',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Chat content
                Expanded(
                  child: Column(
                    children: [
                      // Messages list with background
                      Expanded(
                        child: RepaintBoundary(
                          child: Container(
                            decoration: const BoxDecoration(
                              image: DecorationImage(
                                image: AssetImage('assets/chat/chat_bg.webp'),
                                fit: BoxFit.cover,
                                opacity: 0.1, // Make it subtle
                              ),
                            ),
                            child: _isLoadingMessages
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : _currentMessages.isEmpty
                                ? _buildEmptyMessagesState()
                                : ListView.builder(
                                    controller: _scrollController,
                                    padding: const EdgeInsets.all(16),
                                    itemCount: _currentMessages.length,
                                    itemBuilder: (context, index) {
                                      return _buildMessageBubble(
                                        _currentMessages[index],
                                      );
                                    },
                                  ),
                          ),
                        ),
                      ),

                      // Message input
                      _buildMessageInput(),
                    ],
                  ),
                ),
              ],
            ),

            // Floating sidebar overlay
            if (_showSidebar) _buildSidebarOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyMessagesState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.smart_toy, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Start a conversation',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ask me anything about vehicle repairs!',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isBot = message.sender == MessageSender.bot;
    final isImage = message.type == MessageType.image;
    final isLoading = message.content == '_LOADING_SPINNER_';

    // Check if this is the latest bot message
    final isLatestBotMessage =
        isBot &&
        _currentMessages.isNotEmpty &&
        _currentMessages.last.id == message.id &&
        _currentMessages.last.sender == MessageSender.bot;

    // For loading messages, show spinner outside bubble
    if (isLoading) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue.shade100,
              child: Icon(
                Icons.smart_toy,
                size: 16,
                color: Colors.blue.shade600,
              ),
            ),
            const SizedBox(width: 12),
            const Spinner(),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isBot
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isBot) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue.shade100,
              child: Icon(
                Icons.smart_toy,
                size: 16,
                color: Colors.blue.shade600,
              ),
            ),
            const SizedBox(width: 8),
          ],
          IntrinsicWidth(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isBot ? Colors.grey.shade100 : Colors.blue.shade600,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isImage && message.base64Image != null) ...[
                    RepaintBoundary(
                      child: GestureDetector(
                        onTap: () => _showFullScreenImage(
                          message.base64Image!,
                          title: isBot ? 'Bot Image' : 'Your Image',
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            base64Decode(message.base64Image!),
                            width: 200,
                            fit: BoxFit.cover,
                            cacheWidth: 200, // Cache at display size
                            gaplessPlayback:
                                true, // Prevent flickering during rebuilds
                          ),
                        ),
                      ),
                    ),
                    if (message.content.isNotEmpty) const SizedBox(height: 8),
                  ],
                  if (message.content.isNotEmpty)
                    isBot
                        ? MarkdownBody(
                            data: message.content,
                            styleSheet: MarkdownStyleSheet(
                              p: TextStyle(
                                color: Colors.black87,
                                fontSize: 14,
                                height: 1.4,
                              ),
                              h1: TextStyle(
                                color: Colors.black87,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                height: 1.3,
                              ),
                              h2: TextStyle(
                                color: Colors.black87,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                height: 1.3,
                              ),
                              h3: TextStyle(
                                color: Colors.black87,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                              ),
                              strong: TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.bold,
                              ),
                              em: TextStyle(
                                color: Colors.black87,
                                fontStyle: FontStyle.italic,
                              ),
                              listBullet: TextStyle(
                                color: Colors.blue.shade600,
                                fontSize: 14,
                              ),
                              code: TextStyle(
                                backgroundColor: Colors.grey.shade200,
                                color: Colors.red.shade700,
                                fontSize: 13,
                                fontFamily: 'monospace',
                              ),
                              codeblockDecoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              blockquote: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                              ),
                              blockquoteDecoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                border: Border(
                                  left: BorderSide(
                                    color: Colors.grey.shade400,
                                    width: 4,
                                  ),
                                ),
                              ),
                            ),
                            selectable: true,
                          )
                        : Text(
                            message.content,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Time and model info for bot messages
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatMessageTime(message.createdAt),
                            style: TextStyle(
                              color: isBot
                                  ? Colors.grey.shade600
                                  : Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                          if (isBot)
                            Text(
                              'Gemini 2.0 Flash',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                      // Action buttons for bot messages
                      if (isBot && message.content != '_LOADING_SPINNER_')
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Copy button
                            IconButton(
                              onPressed: () =>
                                  _copyToClipboard(message.content),
                              icon: Icon(
                                Icons.copy,
                                size: 16,
                                color: Colors.grey.shade600,
                              ),
                              tooltip: 'Copy message',
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                              padding: const EdgeInsets.all(4),
                            ),
                            // Reload button - only show for latest bot message
                            if (isLatestBotMessage)
                              IconButton(
                                onPressed: () => _regenerateMessage(message),
                                icon: Icon(
                                  Icons.refresh,
                                  size: 16,
                                  color: Colors.grey.shade600,
                                ),
                                tooltip: 'Regenerate response',
                                constraints: const BoxConstraints(
                                  minWidth: 28,
                                  minHeight: 28,
                                ),
                                padding: const EdgeInsets.all(4),
                              ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (!isBot) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.green.shade100,
              child: Icon(Icons.person, size: 16, color: Colors.green.shade600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          // Image preview section
          if (_previewImageBase64 != null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Image preview (tappable)
                  GestureDetector(
                    onTap: () => _showFullScreenImage(
                      _previewImageBase64!,
                      title: 'Image Preview',
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        base64Decode(_previewImageBase64!),
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Image info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Image attached',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Add a message or send as is',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Remove button
                  IconButton(
                    onPressed: _clearImagePreview,
                    icon: Icon(
                      Icons.close,
                      color: Colors.grey.shade600,
                      size: 20,
                    ),
                    tooltip: 'Remove image',
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
            ),

          // Input section
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(
                                controller: _messageController,
                                decoration: InputDecoration(
                                  hintText: _previewImageBase64 != null
                                      ? 'Add a message (optional)...'
                                      : 'Ask about vehicle repairs...',
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 14,
                                  ),
                                  hintStyle: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 15,
                                  ),
                                ),
                                maxLines: null,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                onSubmitted: (_) => _sendTextMessage(),
                                onChanged: (_) => setState(
                                  () {},
                                ), // Trigger rebuild for counter
                                style: const TextStyle(
                                  fontSize: 15,
                                  height: 1.4,
                                ),
                              ),
                              // Character counter
                              if (_messageController.text.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 20,
                                    right: 20,
                                    bottom: 8,
                                  ),
                                  child: Text(
                                    '${_messageController.text.length}/2000',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color:
                                          _messageController.text.length > 2000
                                          ? Colors.red
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (_previewImageBase64 == null)
                          Padding(
                            padding: const EdgeInsets.only(
                              right: 5,
                              bottom: 5,
                            ), // 👈 move it up
                            child: IconButton(
                              onPressed: _showImageOptions,
                              icon: Icon(
                                Icons.add_photo_alternate_outlined,
                                color: Colors.grey.shade600,
                                size: 22,
                              ),
                              tooltip: 'Add Photo',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Send button
                Padding(
                  padding: const EdgeInsets.only(bottom: 5), // 👈 move it up
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade600, Colors.blue.shade700],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: _isSending ? null : () => _sendTextMessage(),
                      icon: _isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                      tooltip: 'Send',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatMessageTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${dateTime.day}/${dateTime.month} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  Widget _buildSidebarOverlay() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return GestureDetector(
          onTap: _hideSidebar,
          child: Container(
            color: Colors.black.withValues(alpha: _fadeAnimation.value),
            child: Row(
              children: [
                // Animated sidebar panel
                SlideTransition(
                  position: _slideAnimation,
                  child: ChatsHistoryScreen(
                    onChatSelected: _onChatSelected,
                    selectedChatHistory: _selectedChatHistory,
                    onNewChat: _createNewChat,
                    onDeleteAll: _onDeleteAll,
                    onChatDeleted: _onChatDeleted,
                  ),
                ),
                // Transparent area that closes sidebar when tapped
                Expanded(
                  child: GestureDetector(
                    onTap: _hideSidebar,
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Animated spinner widget for Gemini AI loading
class Spinner extends StatefulWidget {
  const Spinner({super.key});

  @override
  State<Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<Spinner> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) {
          return Stack(
            children: List.generate(12, (i) {
              final angle = i * 30 * pi / 180;
              final fade = ((i - _controller.value * 12) % 12) / 12;
              return Transform.rotate(
                angle: angle,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Opacity(
                    opacity: 1.0 - fade,
                    child: Container(
                      width: 1.5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[600],
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

// Full-screen image viewer widget
class _FullScreenImageViewer extends StatelessWidget {
  final String base64Image;
  final String? title;

  const _FullScreenImageViewer({required this.base64Image, this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          title ?? 'Image',
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          boundaryMargin: const EdgeInsets.all(20),
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.memory(
            base64Decode(base64Image),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: Colors.white, size: 64),
                    SizedBox(height: 16),
                    Text(
                      'Failed to load image',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
