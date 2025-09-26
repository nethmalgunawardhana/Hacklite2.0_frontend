import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AppNotification {
  final String id;
  final String title;
  final String message;
  final String type; // 'achievement', 'reminder', 'milestone', 'weekly_summary'
  final DateTime timestamp;
  final bool isRead;
  final Map<String, dynamic>? data;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.data,
  });

  factory AppNotification.fromMap(Map<String, dynamic> map, String id) {
    return AppNotification(
      id: id,
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      type: map['type'] ?? 'general',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: map['isRead'] ?? false,
      data: map['data'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'message': message,
      'type': type,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      'data': data,
    };
  }

  AppNotification copyWith({
    String? id,
    String? title,
    String? message,
    String? type,
    DateTime? timestamp,
    bool? isRead,
    Map<String, dynamic>? data,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      data: data ?? this.data,
    );
  }
}

class AppNotificationService {
  static final AppNotificationService _instance =
      AppNotificationService._internal();
  factory AppNotificationService() => _instance;
  AppNotificationService._internal();

  static AppNotificationService get instance => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get user's notifications stream
  Stream<List<AppNotification>> getNotificationsStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('app_notifications')
        .where('userId', isEqualTo: user.uid)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          final notifications = snapshot.docs.map((doc) {
            return AppNotification.fromMap(doc.data(), doc.id);
          }).toList();
          // Sort in memory instead of requiring index
          notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return notifications;
        })
        .handleError((error) {
          print('Error loading notifications: $error');
          return [];
        });
  }

  // Get unread notifications count stream
  Stream<int> getUnreadCountStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(0);

    return _firestore
        .collection('app_notifications')
        .where('userId', isEqualTo: user.uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length)
        .handleError((error) {
          print('Error loading unread count: $error');
          return 0;
        });
  }

  // Add a new notification
  Future<void> addNotification({
    required String title,
    required String message,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final notification = AppNotification(
      id: '',
      title: title,
      message: message,
      type: type,
      timestamp: DateTime.now(),
      data: data,
    );

    await _firestore.collection('app_notifications').add({
      'userId': user.uid,
      ...notification.toMap(),
    });
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    await _firestore.collection('app_notifications').doc(notificationId).update(
      {'isRead': true},
    );
  }

  // Mark all notifications as read
  Future<void> markAllAsRead() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final unreadNotifications = await _firestore
        .collection('app_notifications')
        .where('userId', isEqualTo: user.uid)
        .where('isRead', isEqualTo: false)
        .get();

    final batch = _firestore.batch();
    for (final doc in unreadNotifications.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  // Delete notification
  Future<void> deleteNotification(String notificationId) async {
    await _firestore
        .collection('app_notifications')
        .doc(notificationId)
        .delete();
  }

  // Delete all notifications
  Future<void> deleteAllNotifications() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final notifications = await _firestore
        .collection('app_notifications')
        .where('userId', isEqualTo: user.uid)
        .get();

    final batch = _firestore.batch();
    for (final doc in notifications.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // Get notification icon and color based on type
  static IconData getNotificationIcon(String type) {
    switch (type) {
      case 'achievement':
        return Icons.emoji_events;
      case 'streak':
        return Icons.local_fire_department;
      case 'milestone':
        return Icons.flag;
      case 'weekly_summary':
        return Icons.analytics;
      case 'smart_recommendation':
        return Icons.lightbulb;
      case 'reminder':
        return Icons.access_time;
      default:
        return Icons.notifications;
    }
  }

  static String getNotificationColor(String type) {
    switch (type) {
      case 'achievement':
        return '#FFD700'; // Gold
      case 'streak':
        return '#FF4500'; // Orange Red
      case 'milestone':
        return '#32CD32'; // Lime Green
      case 'weekly_summary':
        return '#4169E1'; // Royal Blue
      case 'smart_recommendation':
        return '#9932CC'; // Dark Orchid
      case 'reminder':
        return '#FF6347'; // Tomato
      default:
        return '#1976D2'; // Default Blue
    }
  }

  // Demo method to generate sample notifications for testing
  Future<void> generateDemoNotifications() async {
    // Achievement notification
    await addNotification(
      title: '🎉 Goal Achieved!',
      message:
          'Congratulations! You\'ve completed your daily signs goal (5/5)!',
      type: 'achievement',
      data: {'goalType': 'signs', 'achieved': 5, 'target': 5},
    );

    // Streak notification
    await addNotification(
      title: 'Week Warrior!',
      message:
          'One full week of consistent learning! You\'re building great habits!',
      type: 'streak',
      data: {'streakDays': 7},
    );

    // Milestone notification
    await addNotification(
      title: 'New Milestone Unlocked!',
      message:
          '100 Signs Learned: You\'ve reached a major milestone in your ASL journey!',
      type: 'milestone',
      data: {
        'milestone': '100 Signs Learned',
        'description': 'Major milestone achievement',
      },
    );

    // Smart recommendation notification
    await addNotification(
      title: 'Smart Recommendation',
      message:
          'Based on your progress, we suggest increasing your daily practice to 20 minutes for better retention!',
      type: 'smart_recommendation',
      data: {'recommendationType': 'practice_time', 'suggestion': '20 minutes'},
    );

    // Weekly summary notification
    await addNotification(
      title: 'Weekly Summary',
      message:
          'This week: 25 signs learned, 105 minutes practiced, 8 quizzes completed! Great progress!',
      type: 'weekly_summary',
      data: {'totalSigns': 25, 'totalPracticeTime': 105, 'quizzesCompleted': 8},
    );
  }
}
