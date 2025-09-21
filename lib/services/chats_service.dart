import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mechlink/models/chat_history.dart';
import 'package:mechlink/models/chat_message.dart';

class ChatsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _geminiApiKey = 'AIzaSyD_F7BNMxWTirHhStzBMmCrVauvRbqY3yI';
  static const String _geminiApiUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

  static const String _systemPrompt = '''
You are MechLink Assistant, an AI chatbot designed to help mechanics with vehicle and equipment repair issues and inquiries.

Your role:
- Assist mechanics with troubleshooting vehicle and equipment problems
- Provide technical guidance on repair procedures
- Help with diagnostic processes
- Offer maintenance recommendations
- Answer questions about parts, tools, and specifications
- Share best practices for automotive and equipment repair

Guidelines:
- Be professional, helpful, and concise
- Focus on practical, actionable advice
- Ask clarifying questions when needed
- Prioritize safety in all recommendations
- If unsure about something, acknowledge limitations
- Use technical terminology appropriately for a mechanic audience

Remember: The user is a professional mechanic seeking technical assistance.
''';

  // ============================================================================
  // CHAT HISTORY MANAGEMENT
  // ============================================================================

  /// Get all chat histories for a specific mechanic
  Future<List<ChatHistory>> getChatHistories(String mechanicId) async {
    try {
      // Using Firestore composite index for optimal performance
      QuerySnapshot snapshot = await _firestore
          .collection('chat_history')
          .where('mechanicId', isEqualTo: mechanicId)
          .orderBy('updatedAt', descending: true)
          .get();

      List<ChatHistory> chatHistories = snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return ChatHistory.fromMap(data);
      }).toList();

      return chatHistories;
    } catch (e) {
      print('Error getting chat histories: $e');
      return [];
    }
  }

  /// Create a new chat history for a mechanic
  Future<String?> createChatHistory(String mechanicId) async {
    try {
      print('Creating chat history for mechanic: $mechanicId');

      // Validate mechanic ID
      if (mechanicId.isEmpty) {
        print('Error: Empty mechanic ID provided');
        return null;
      }

      // Create the document without title initially
      DocumentReference docRef = await _firestore
          .collection('chat_history')
          .add({
            'mechanicId': mechanicId,
            'title': null, // Will be generated after first message
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      print('Chat history created successfully with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('Error creating chat history: $e');
      print('Error type: ${e.runtimeType}');
      print('Stack trace: ${StackTrace.current}');
      return null;
    }
  }

  /// Update chat history timestamp
  Future<void> updateChatHistoryTimestamp(String chatHistoryId) async {
    try {
      await _firestore.collection('chat_history').doc(chatHistoryId).update({
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating chat history timestamp: $e');
    }
  }

  /// Delete a chat history and all its messages
  Future<bool> deleteChatHistory(String chatHistoryId) async {
    try {
      // Delete all messages in this chat history first
      QuerySnapshot messagesSnapshot = await _firestore
          .collection('chat_messages')
          .where('chatHistoryId', isEqualTo: chatHistoryId)
          .get();

      WriteBatch batch = _firestore.batch();

      for (QueryDocumentSnapshot doc in messagesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete the chat history
      batch.delete(_firestore.collection('chat_history').doc(chatHistoryId));

      await batch.commit();
      return true;
    } catch (e) {
      print('Error deleting chat history: $e');
      return false;
    }
  }

  // ============================================================================
  // CHAT MESSAGES MANAGEMENT
  // ============================================================================

  /// Get all messages for a specific chat history
  Future<List<ChatMessage>> getChatMessages(String chatHistoryId) async {
    try {
      // Using Firestore composite index for optimal performance
      QuerySnapshot snapshot = await _firestore
          .collection('chat_messages')
          .where('chatHistoryId', isEqualTo: chatHistoryId)
          .orderBy('createdAt', descending: false)
          .get();

      List<ChatMessage> messages = snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return ChatMessage.fromMap(data);
      }).toList();

      return messages;
    } catch (e) {
      print('Error getting chat messages: $e');
      return [];
    }
  }

  /// Send a text message (optionally with image)
  Future<String?> sendTextMessage({
    required String chatHistoryId,
    required MessageSender sender,
    required String content,
    String? base64Image,
  }) async {
    try {
      DocumentReference docRef = await _firestore
          .collection('chat_messages')
          .add({
            'chatHistoryId': chatHistoryId,
            'sender': sender.toString().split('.').last,
            'content': content,
            'type': base64Image != null
                ? MessageType.image.toString().split('.').last
                : MessageType.text.toString().split('.').last,
            'createdAt': FieldValue.serverTimestamp(),
            'base64Image': base64Image,
          });

      // Update chat history timestamp
      await updateChatHistoryTimestamp(chatHistoryId);

      // Generate title if this is the first user message
      if (sender == MessageSender.mechanic) {
        await _generateTitleIfNeeded(chatHistoryId, content);
      }

      return docRef.id;
    } catch (e) {
      print('Error sending text message: $e');
      return null;
    }
  }

  /// Send an image message
  Future<String?> sendImageMessage({
    required String chatHistoryId,
    required MessageSender sender,
    required String content,
    required String base64Image,
  }) async {
    try {
      DocumentReference docRef = await _firestore
          .collection('chat_messages')
          .add({
            'chatHistoryId': chatHistoryId,
            'sender': sender.toString().split('.').last,
            'content': content,
            'type': MessageType.image.toString().split('.').last,
            'createdAt': FieldValue.serverTimestamp(),
            'base64Image': base64Image,
          });

      // Update chat history timestamp
      await updateChatHistoryTimestamp(chatHistoryId);

      return docRef.id;
    } catch (e) {
      print('Error sending image message: $e');
      return null;
    }
  }

  /// Delete a specific message
  Future<bool> deleteMessage(String messageId) async {
    try {
      await _firestore.collection('chat_messages').doc(messageId).delete();
      print('Message deleted successfully: $messageId');
      return true;
    } catch (e) {
      print('Error deleting message: $e');
      return false;
    }
  }

  /// Get real-time messages stream for a chat history
  Stream<List<ChatMessage>> getChatMessagesStream(String chatHistoryId) {
    return _firestore
        .collection('chat_messages')
        .where('chatHistoryId', isEqualTo: chatHistoryId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return ChatMessage.fromMap(data);
          }).toList();
        });
  }

  /// Get real-time chat histories stream for a mechanic
  Stream<List<ChatHistory>> getChatHistoriesStream(String mechanicId) {
    return _firestore
        .collection('chat_history')
        .where('mechanicId', isEqualTo: mechanicId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return ChatHistory.fromMap(data);
          }).toList();
        });
  }

  // ============================================================================
  // BOT RESPONSE SIMULATION
  // ============================================================================

  /// Generate AI response using Gemini API with context memory and image recognition
  Future<void> generateAIResponse({
    required String chatHistoryId,
    required String userMessage,
    String? base64Image,
  }) async {
    try {
      // Get conversation context (last 15 messages)
      List<ChatMessage> contextMessages = await _getConversationContext(chatHistoryId);
      
      // Get AI response from Gemini with context and optional image
      String aiResponse = await _getGeminiResponseWithContext(
        userMessage: userMessage,
        contextMessages: contextMessages,
        base64Image: base64Image,
      );

      // Send AI response as a message
      await sendTextMessage(
        chatHistoryId: chatHistoryId,
        sender: MessageSender.bot,
        content: aiResponse,
      );

      // Generate title if this is the first message
      await _generateTitleIfNeeded(chatHistoryId, userMessage);
    } catch (e) {
      print('Error generating AI response: $e');
      // Send fallback response
      await sendTextMessage(
        chatHistoryId: chatHistoryId,
        sender: MessageSender.bot,
        content: _generateFallbackResponse(userMessage),
      );
    }
  }

  /// Get conversation context (last 15 messages) for AI response
  Future<List<ChatMessage>> _getConversationContext(String chatHistoryId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('chat_messages')
          .where('chatHistoryId', isEqualTo: chatHistoryId)
          .orderBy('createdAt', descending: true)
          .limit(15)
          .get();

      List<ChatMessage> messages = snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return ChatMessage.fromMap(data);
      }).toList();

      // Reverse to get chronological order (oldest first)
      return messages.reversed.toList();
    } catch (e) {
      print('Error getting conversation context: $e');
      return [];
    }
  }

  /// Generate title for chat history using Gemini API
  Future<void> _generateTitleIfNeeded(
    String chatHistoryId,
    String firstMessage,
  ) async {
    try {
      // Check if title already exists
      DocumentSnapshot chatDoc = await _firestore
          .collection('chat_history')
          .doc(chatHistoryId)
          .get();

      if (chatDoc.exists) {
        Map<String, dynamic> data = chatDoc.data() as Map<String, dynamic>;
        if (data['title'] != null && data['title'].toString().isNotEmpty) {
          return; // Title already exists
        }

        // Generate title using Gemini API
        String title = await _generateChatTitle(firstMessage);

        // Update chat history with generated title
        await _firestore.collection('chat_history').doc(chatHistoryId).update({
          'title': title,
        });
      }
    } catch (e) {
      print('Error generating title: $e');
    }
  }

  /// Generate chat title using Gemini API
  Future<String> _generateChatTitle(String firstMessage) async {
    // Handle simple greetings and short messages
    final trimmedMessage = firstMessage.trim().toLowerCase();
    final greetings = ['hi', 'hello', 'hey', 'good morning', 'good afternoon', 'good evening'];
    
    if (greetings.any((greeting) => trimmedMessage == greeting || trimmedMessage.startsWith('$greeting ')) ||
        firstMessage.trim().length < 10) {
      return 'New Conversation';
    }
    
    try {
      const titlePrompt = '''
Generate a concise, descriptive title (3-6 words) for a mechanic chat conversation based on the first message. The title should capture the main automotive topic or issue discussed. If the message is just a greeting or too vague, return "New Conversation". Return only the title, no additional text.

Examples:
- "Engine Won't Start" 
- "Brake System Issue"
- "Transmission Problems"
- "Oil Change Question"
- "New Conversation" (for greetings or vague messages)

First message: ''';

      final response = await http.post(
        Uri.parse('$_geminiApiUrl?key=$_geminiApiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': '$titlePrompt$firstMessage'},
              ],
            },
          ],
          'generationConfig': {
            'temperature': 0.3,
            'topK': 20,
            'topP': 0.8,
            'maxOutputTokens': 20,
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['candidates'] != null && data['candidates'].isNotEmpty) {
          final content = data['candidates'][0]['content'];
          if (content != null &&
              content['parts'] != null &&
              content['parts'].isNotEmpty) {
            String title = content['parts'][0]['text'] ?? 'New Chat';
            // Clean up the title (remove quotes, trim)
            title = title.replaceAll('"', '').replaceAll("'", '').trim();
            return title.length > 50 ? title.substring(0, 50) : title;
          }
        }
      }
    } catch (e) {
      print('Error generating title with Gemini: $e');
    }

    // Fallback title based on first few words
    List<String> words = firstMessage.split(' ');
    if (words.length > 3) {
      return '${words.take(3).join(' ')}...';
    }
    return firstMessage.length > 20
        ? '${firstMessage.substring(0, 20)}...'
        : firstMessage;
  }

  /// Get response from Gemini API with context memory and image recognition
  Future<String> _getGeminiResponseWithContext({
    required String userMessage,
    required List<ChatMessage> contextMessages,
    String? base64Image,
  }) async {
    try {
      // Build conversation context
      String contextString = '';
      if (contextMessages.isNotEmpty) {
        contextString = '\n\nConversation History:\n';
        for (ChatMessage msg in contextMessages) {
          String sender = msg.sender == MessageSender.bot ? 'Assistant' : 'User';
          if (msg.type == MessageType.image && msg.base64Image != null) {
            contextString += '$sender: [Sent an image] ${msg.content}\n';
          } else {
            contextString += '$sender: ${msg.content}\n';
          }
        }
        contextString += '\nCurrent message:';
      }

      // Prepare request parts
      List<Map<String, dynamic>> parts = [];
      
      // Add text content
      parts.add({
        'text': '$_systemPrompt$contextString\n\nUser: $userMessage'
      });
      
      // Add image if provided (for image recognition)
      if (base64Image != null) {
        parts.add({
          'inline_data': {
            'mime_type': 'image/jpeg',
            'data': base64Image
          }
        });
      }

      final response = await http.post(
        Uri.parse('$_geminiApiUrl?key=$_geminiApiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': parts
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'topK': 40,
            'topP': 0.95,
            'maxOutputTokens': 1024,
          },
          'safetySettings': [
            {
              'category': 'HARM_CATEGORY_HARASSMENT',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
            },
            {
              'category': 'HARM_CATEGORY_HATE_SPEECH',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
            },
            {
              'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
            },
            {
              'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
            },
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['candidates'] != null && data['candidates'].isNotEmpty) {
          final content = data['candidates'][0]['content'];
          if (content != null &&
              content['parts'] != null &&
              content['parts'].isNotEmpty) {
            return content['parts'][0]['text'] ??
                _generateFallbackResponse(userMessage);
          }
        }
      } else {
        print('Gemini API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error calling Gemini API: $e');
    }

    return _generateFallbackResponse(userMessage);
  }

  /// Generate fallback responses when Gemini API is unavailable
  String _generateFallbackResponse(String userMessage) {
    final message = userMessage.toLowerCase();

    if (message.contains('hello') || message.contains('hi')) {
      return 'Hello! I\'m your MechLink assistant. How can I help you today?';
    } else if (message.contains('help')) {
      return 'I can help you with:\n• Job information\n• Equipment details\n• Maintenance schedules\n• Technical support\n\nWhat would you like to know?';
    } else if (message.contains('job') || message.contains('work')) {
      return 'I can help you with job-related queries. Would you like to know about current assignments, job status, or something specific?';
    } else if (message.contains('equipment') || message.contains('machine')) {
      return 'I can provide information about equipment maintenance, specifications, and troubleshooting. What equipment are you working with?';
    } else if (message.contains('thank')) {
      return 'You\'re welcome! I\'m here whenever you need assistance.';
    } else {
      return 'I understand you\'re asking about: "$userMessage"\n\nI\'m here to help with technical support, job information, and equipment guidance. Could you provide more details about what you need?';
    }
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /// Get last message preview for a chat history (optimized with Firestore index)
  Future<String> getLastMessagePreview(String chatHistoryId) async {
    try {
      // Using Firestore composite index for optimal performance - get only the latest message
      QuerySnapshot snapshot = await _firestore
          .collection('chat_messages')
          .where('chatHistoryId', isEqualTo: chatHistoryId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        Map<String, dynamic> data =
            snapshot.docs.first.data() as Map<String, dynamic>;
        data['id'] = snapshot.docs.first.id;
        ChatMessage lastMessage = ChatMessage.fromMap(data);

        if (lastMessage.type == MessageType.image) {
          return lastMessage.content.isNotEmpty
              ? '📷 ${lastMessage.content}'
              : '📷 Image';
        } else if (lastMessage.type == MessageType.file) {
          return '📎 File';
        } else {
          String content = lastMessage.content;
          return content.length > 50
              ? '${content.substring(0, 50)}...'
              : content;
        }
      }
    } catch (e) {
      print('Error getting last message preview: $e');
    }
    return 'No messages yet';
  }

  /// Get unread message count (for future implementation)
  Future<int> getUnreadMessageCount(String chatHistoryId) async {
    // This would require additional fields in the message model
    // For now, return 0
    return 0;
  }
}
