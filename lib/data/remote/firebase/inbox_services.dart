import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'media_services.dart';

// --- MODELS ---

enum MessageType { text, image, video, voice, emoji }

class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final int timestamp;
  final bool isRead;
  final MessageType type;
  final String? mediaUrl;
  final int? mediaDuration;
  final String? thumbnailUrl;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.isRead = false,
    this.type = MessageType.text,
    this.mediaUrl,
    this.mediaDuration,
    this.thumbnailUrl,
  });

  factory ChatMessage.fromMap(String id, Map<dynamic, dynamic> map) {
    return ChatMessage(
      id: id,
      senderId: map['senderId'] ?? '',
      text: map['text'] ?? '',
      timestamp: (map['timestamp'] as num?)?.toInt() ?? 0,
      isRead: map['isRead'] ?? false,
      type: MessageType.values.firstWhere((e) => e.name == map['type'], orElse: () => MessageType.text),
      mediaUrl: map['mediaUrl'],
      mediaDuration: (map['mediaDuration'] as num?)?.toInt(),
      thumbnailUrl: map['thumbnailUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'text': text,
      'timestamp': timestamp,
      'isRead': isRead,
      'type': type.name,
      if (mediaUrl != null) 'mediaUrl': mediaUrl,
      if (mediaDuration != null) 'mediaDuration': mediaDuration,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
    };
  }
}

// ConversationSummary remains mostly the same, just ensuring it handles the enum
class ConversationSummary {
  final String peerId;
  final String lastMessage;
  final int timestamp;
  final int unreadCount;
  final String lastSenderId;
  final MessageType? lastMessageType;

  ConversationSummary({
    required this.peerId,
    required this.lastMessage,
    required this.timestamp,
    required this.unreadCount,
    required this.lastSenderId,
    this.lastMessageType,
  });

  factory ConversationSummary.fromMap(String peerId, Map<dynamic, dynamic> map) {
    return ConversationSummary(
      peerId: peerId,
      lastMessage: map['lastMessage'] ?? '',
      timestamp: (map['timestamp'] as num?)?.toInt() ?? 0,
      unreadCount: (map['unreadCount'] as num?)?.toInt() ?? 0,
      lastSenderId: map['lastSenderId'] ?? '',
      lastMessageType: map['lastMessageType'] != null
          ? MessageType.values.firstWhere((e) => e.name == map['lastMessageType'], orElse: () => MessageType.text)
          : null,
    );
  }
}

// --- SERVICE ---

class InboxService {
  static final _db = FirebaseDatabase.instance;
  static final _auth = FirebaseAuth.instance;

  static String getChatId(String userId1, String userId2) {
    return userId1.compareTo(userId2) < 0 ? '${userId1}_$userId2' : '${userId2}_$userId1';
  }

  // Send text message
  static Future<void> sendMessage(String peerId, String text) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final currentUserId = currentUser.uid;
    final chatId = getChatId(currentUserId, peerId);
    final timestamp = ServerValue.timestamp;

    // Send Message
    final messageRef = _db.ref('messages/$chatId').push();
    await messageRef.set({
      'senderId': currentUserId,
      'text': text,
      'timestamp': timestamp,
      'isRead': false,
      'type': MessageType.text.name,
    });

    // Update inboxes
    await _updateInboxes(currentUserId, peerId, text, MessageType.text);
  }

  static Future<void> sendEmojiMessage(String peerId, String emojiFileName) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final currentUserId = currentUser.uid;
    final chatId = getChatId(currentUserId, peerId);
    final timestamp = ServerValue.timestamp;

    // Send Message
    final messageRef = _db.ref('messages/$chatId').push();
    await messageRef.set({
      'senderId': currentUserId,
      'text': 'Emoji', // Fallback text
      'timestamp': timestamp,
      'isRead': false,
      'type': MessageType.emoji.name,
      'mediaUrl': emojiFileName, // We store the filename (e.g., 'happy.webp') here
    });

    // Update inboxes
    await _updateInboxes(currentUserId, peerId, '😊 Sticker', MessageType.emoji);
  }

  // Send image message
  static Future<bool> sendImageMessage(String peerId, File imageFile) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      // Upload image
      final imageUrl = await MediaService.compressAndUploadImage(imageFile);
      if (imageUrl == null) return false;

      final currentUserId = currentUser.uid;
      final chatId = getChatId(currentUserId, peerId);
      final timestamp = ServerValue.timestamp;

      // Send message
      final messageRef = _db.ref('messages/$chatId').push();
      await messageRef.set({
        'senderId': currentUserId,
        'text': '📷 Photo',
        'timestamp': timestamp,
        'isRead': false,
        'type': MessageType.image.name,
        'mediaUrl': imageUrl,
      });

      // Update inboxes
      await _updateInboxes(currentUserId, peerId, '📷 Photo', MessageType.image);
      return true;
    } catch (e) {
      debugPrint('Error sending image: $e');
      return false;
    }
  }

  // Send video message
  static Future<bool> sendVideoMessage(String peerId, File videoFile) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      // Upload video
      final videoData = await MediaService.compressAndUploadVideo(videoFile);
      if (videoData == null) return false;

      final currentUserId = currentUser.uid;
      final chatId = getChatId(currentUserId, peerId);
      final timestamp = ServerValue.timestamp;

      // Send message
      final messageRef = _db.ref('messages/$chatId').push();
      await messageRef.set({
        'senderId': currentUserId,
        'text': '🎥 Video',
        'timestamp': timestamp,
        'isRead': false,
        'type': MessageType.video.name,
        'mediaUrl': videoData['url'],
        'mediaDuration': videoData['duration'],
        'thumbnailUrl': videoData['thumbnailUrl'],
      });

      // Update inboxes
      await _updateInboxes(currentUserId, peerId, '🎥 Video', MessageType.video);
      return true;
    } catch (e) {
      debugPrint('Error sending video: $e');
      return false;
    }
  }

  // Send voice message
  static Future<bool> sendVoiceMessage(String peerId, File audioFile, int durationSeconds) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      // Upload voice
      final audioUrl = await MediaService.uploadVoiceRecording(audioFile);
      if (audioUrl == null) return false;

      final currentUserId = currentUser.uid;
      final chatId = getChatId(currentUserId, peerId);
      final timestamp = ServerValue.timestamp;

      // Send message
      final messageRef = _db.ref('messages/$chatId').push();
      await messageRef.set({
        'senderId': currentUserId,
        'text': '🎤 Voice message',
        'timestamp': timestamp,
        'isRead': false,
        'type': MessageType.voice.name,
        'mediaUrl': audioUrl,
        'mediaDuration': durationSeconds,
      });

      // Update inboxes
      await _updateInboxes(currentUserId, peerId, '🎤 Voice message', MessageType.voice);
      return true;
    } catch (e) {
      debugPrint('Error sending voice: $e');
      return false;
    }
  }

  // Helper to update inboxes
  static Future<void> _updateInboxes(
    String currentUserId,
    String peerId,
    String lastMessage,
    MessageType messageType,
  ) async {
    final timestamp = ServerValue.timestamp;

    // Update My Inbox
    await _db.ref('user_chats/$currentUserId/$peerId').update({
      'lastMessage': lastMessage,
      'timestamp': timestamp,
      'lastSenderId': currentUserId,
      'lastMessageType': messageType.name,
    });

    // Update Peer Inbox
    final peerInboxRef = _db.ref('user_chats/$peerId/$currentUserId');
    await peerInboxRef.update({
      'lastMessage': lastMessage,
      'timestamp': timestamp,
      'lastSenderId': currentUserId,
      'lastMessageType': messageType.name,
    });

    await peerInboxRef.child('unreadCount').runTransaction((mutableData) {
      if (mutableData == null) return Transaction.success(1);
      final current = (mutableData as int?) ?? 0;
      return Transaction.success(current + 1);
    });
  }

  static Future<void> markMessageAsRead(String peerId, String messageId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final chatId = getChatId(uid, peerId);
    await _db.ref('messages/$chatId/$messageId').update({'isRead': true});
  }

  static Stream<List<ConversationSummary>> getUserChatsStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.empty();

    return _db.ref('user_chats/$uid').orderByChild('timestamp').onValue.map((event) {
      final List<ConversationSummary> chats = [];
      for (final child in event.snapshot.children) {
        if (child.value is Map) {
          chats.add(ConversationSummary.fromMap(child.key.toString(), child.value as Map<dynamic, dynamic>));
        }
      }
      chats.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return chats;
    });
  }

  static Future<List<ChatMessage>> getInitialMessages(String peerId, {int limit = 20}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    final chatId = getChatId(uid, peerId);

    try {
      final snapshot = await _db.ref('messages/$chatId').orderByKey().limitToLast(limit).get();

      if (!snapshot.exists) return [];

      final List<ChatMessage> messages = [];
      for (final child in snapshot.children) {
        if (child.value is Map) {
          messages.add(ChatMessage.fromMap(child.key.toString(), child.value as Map<dynamic, dynamic>));
        }
      }

      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return messages;
    } catch (e) {
      debugPrint('Error fetching initial messages: $e');
      return [];
    }
  }

  static Future<List<ChatMessage>> loadOlderMessages(String peerId, String oldestMessageKey, {int limit = 20}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    final chatId = getChatId(uid, peerId);

    try {
      final snapshot = await _db
          .ref('messages/$chatId')
          .orderByKey()
          .endBefore(oldestMessageKey)
          .limitToLast(limit)
          .get();

      if (!snapshot.exists) return [];

      final List<ChatMessage> messages = [];
      for (final child in snapshot.children) {
        if (child.value is Map) {
          messages.add(ChatMessage.fromMap(child.key.toString(), child.value as Map<dynamic, dynamic>));
        }
      }

      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return messages;
    } catch (e) {
      debugPrint('Error loading older messages: $e');
      return [];
    }
  }

  static Stream<ChatMessage?> listenToNewMessages(String peerId, String? newestMessageKey) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.empty();

    final chatId = getChatId(uid, peerId);

    Query query = _db.ref('messages/$chatId').orderByKey();

    if (newestMessageKey != null && newestMessageKey.isNotEmpty) {
      query = query.startAfter(newestMessageKey);
    }

    return query.onChildAdded
        .map((event) {
          if (event.snapshot.value is Map) {
            return ChatMessage.fromMap(event.snapshot.key.toString(), event.snapshot.value as Map<dynamic, dynamic>);
          }
          return null;
        })
        .where((msg) => msg != null);
  }

  static Stream<ChatMessage?> listenToMessageUpdates(String peerId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.empty();

    final chatId = getChatId(uid, peerId);

    return _db
        .ref('messages/$chatId')
        .onChildChanged
        .map((event) {
          if (event.snapshot.value is Map) {
            return ChatMessage.fromMap(event.snapshot.key.toString(), event.snapshot.value as Map<dynamic, dynamic>);
          }
          return null;
        })
        .where((msg) => msg != null);
  }

  static Future<void> markAsRead(String peerId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _db.ref('user_chats/$uid/$peerId').update({'unreadCount': 0});
  }
}
