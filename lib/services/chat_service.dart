import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatMessage {
  final String id;
  final String userId;
  final bool isUser;
  final String text;
  final DateTime timestamp;
  final String? conversationId;

  ChatMessage({
    required this.id,
    required this.userId,
    required this.isUser,
    required this.text,
    required this.timestamp,
    this.conversationId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'isUser': isUser,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'conversationId': conversationId,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'],
      userId: map['userId'],
      isUser: map['isUser'],
      text: map['text'],
      timestamp: DateTime.parse(map['timestamp']),
      conversationId: map['conversationId'],
    );
  }
}

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  // Save a message to Firestore
  Future<void> saveMessage(ChatMessage message) async {
    if (currentUserId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('conversations')
          .doc(message.conversationId ?? 'default')
          .collection('messages')
          .doc(message.id)
          .set(message.toMap());
    } catch (e) {
      print('Error saving message: $e');
    }
  }

  // Get all conversations for the current user
  Future<List<Map<String, dynamic>>> getConversations() async {
    if (currentUserId == null) return [];

    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('conversations')
          .orderBy('lastMessageTime', descending: true)
          .get();

      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Error getting conversations: $e');
      return [];
    }
  }

  // Get messages for a specific conversation
  Future<List<ChatMessage>> getMessages(String conversationId) async {
    if (currentUserId == null) return [];

    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .orderBy('timestamp')
          .get();

      return querySnapshot.docs
          .map((doc) => ChatMessage.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting messages: $e');
      return [];
    }
  }

  // Create a new conversation
  Future<String> createConversation(String title) async {
    if (currentUserId == null) return '';

    try {
      final conversationId = DateTime.now().millisecondsSinceEpoch.toString();
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('conversations')
          .doc(conversationId)
          .set({
            'id': conversationId,
            'title': title,
            'createdAt': DateTime.now().toIso8601String(),
            'lastMessageTime': DateTime.now().toIso8601String(),
          });
      return conversationId;
    } catch (e) {
      print('Error creating conversation: $e');
      return '';
    }
  }

  // Update conversation title and last message time
  Future<void> updateConversation(String conversationId, String title) async {
    if (currentUserId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('conversations')
          .doc(conversationId)
          .update({
            'title': title,
            'lastMessageTime': DateTime.now().toIso8601String(),
          });
    } catch (e) {
      print('Error updating conversation: $e');
    }
  }

  // Delete a conversation
  Future<void> deleteConversation(String conversationId) async {
    if (currentUserId == null) return;

    try {
      // Delete all messages in the conversation
      final messagesSnapshot = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .get();

      for (var doc in messagesSnapshot.docs) {
        await doc.reference.delete();
      }

      // Delete the conversation document
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('conversations')
          .doc(conversationId)
          .delete();
    } catch (e) {
      print('Error deleting conversation: $e');
    }
  }
}
