import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timezone/timezone.dart' as tz;
import 'dart:io' show Platform;
import 'app_notification_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static NotificationService get instance => _instance;

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _isInitialized = true;
  }

  void _onNotificationTapped(NotificationResponse response) {
    print('Notification tapped: ${response.payload}');
  }

  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final plugin = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await plugin?.requestNotificationsPermission() ?? false;
    } else if (Platform.isIOS) {
      final plugin = _notifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      return await plugin?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return true;
  }

  // Goal Achievement Notifications
  Future<void> showGoalCompletionNotification({
    required String goalType,
    required int achieved,
    required int target,
    String? message,
  }) async {
    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'goal_completion',
        'Goal Achievement',
        channelDescription: 'Notifications for completed learning goals',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: false,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    String title = 'Goal Achieved!';
    String body =
        message ??
        'Congratulations! You\'ve completed your $goalType goal ($achieved/$target)!';

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      notificationDetails,
    );

    // Also add to app notifications
    await AppNotificationService.instance.addNotification(
      title: title,
      message: body,
      type: 'achievement',
      data: {'goalType': goalType, 'achieved': achieved, 'target': target},
    );

    // Track achievement in Firebase
    await _trackAchievement(goalType, achieved, target);
  }

  // Milestone Notifications
  Future<void> showMilestoneNotification({
    required String milestone,
    required String description,
    String? customTitle,
  }) async {
    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'milestones',
        'Learning Milestones',
        channelDescription: 'Notifications for learning milestones',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      customTitle ?? 'New Milestone Unlocked!',
      '$milestone: $description',
      notificationDetails,
    );

    // Also add to app notifications
    await AppNotificationService.instance.addNotification(
      title: customTitle ?? 'New Milestone Unlocked!',
      message: '$milestone: $description',
      type: 'milestone',
      data: {'milestone': milestone, 'description': description},
    );
  }

  // Streak Notifications
  Future<void> showStreakNotification({
    required int streakDays,
    String? message,
  }) async {
    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'streaks',
        'Learning Streaks',
        channelDescription: 'Notifications for learning streaks',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    String title = 'Streak Master!';
    String body =
        message ??
        'Amazing! You\'re on a $streakDays-day learning streak! Keep it up!';

    // Special messages for milestone streaks
    if (streakDays == 7) {
      title = 'Week Warrior!';
      body =
          'One full week of consistent learning! You\'re building great habits!';
    } else if (streakDays == 30) {
      title = 'Monthly Master!';
      body = '30 days of dedication! You\'re becoming an ASL pro!';
    } else if (streakDays == 100) {
      title = 'Centurion Champion!';
      body = '100 days! You\'ve shown incredible commitment to learning ASL!';
    } else if (streakDays % 50 == 0) {
      title = 'Streak Legend!';
      body = '$streakDays days of consistent learning! You\'re an inspiration!';
    }

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      notificationDetails,
    );

    // Also add to app notifications
    await AppNotificationService.instance.addNotification(
      title: title,
      message: body,
      type: 'streak',
      data: {'streakDays': streakDays},
    );

    // Update streak in Firebase
    await _updateStreak(streakDays);
  }

  // Daily Reminder Notifications
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    String? customMessage,
  }) async {
    await _notifications.zonedSchedule(
      0, // Notification ID
      'Time to Practice ASL!',
      customMessage ??
          'Don\'t forget to practice your ASL signs today! Every minute counts!',
      _nextInstanceOfTime(hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminders',
          'Daily Learning Reminders',
          channelDescription: 'Daily reminders to practice ASL',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // Progress Update Notifications
  Future<void> showProgressUpdateNotification({
    required Map<String, dynamic> progress,
    String? message,
  }) async {
    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'progress_updates',
        'Progress Updates',
        channelDescription: 'Updates on learning progress',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    String title = 'Progress Update';
    String body = message ?? _formatProgressMessage(progress);

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      notificationDetails,
    );
  }

  // Smart Recommendation Notifications
  Future<void> showSmartRecommendation({
    required Map<String, dynamic> recommendations,
    String? customMessage,
  }) async {
    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'smart_recommendations',
        'Smart Recommendations',
        channelDescription: 'AI-powered learning recommendations',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      'Smart Recommendation',
      customMessage ??
          'We have new personalized recommendations for your ASL learning journey!',
      notificationDetails,
    );
  }

  // Weekly Summary Notifications
  Future<void> showWeeklySummaryNotification({
    required Map<String, dynamic> summary,
    String? customMessage,
  }) async {
    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'weekly_summary',
        'Weekly Summary',
        channelDescription: 'Weekly learning progress summary',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      'Weekly Progress Summary',
      customMessage ?? _formatWeeklySummary(summary),
      notificationDetails,
    );
  }

  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  // Cancel specific notification
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  // Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notifications_enabled') ?? true;
  }

  // Enable/disable notifications
  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', enabled);

    if (!enabled) {
      await cancelAllNotifications();
    }
  }

  // Helper methods
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  String _formatProgressMessage(Map<String, dynamic> progress) {
    List<String> achievements = [];

    if (progress['signsLearned'] != null) {
      achievements.add('${progress['signsLearned']} signs learned');
    }
    if (progress['practiceTime'] != null) {
      achievements.add('${progress['practiceTime']} minutes practiced');
    }
    if (progress['quizzesTaken'] != null) {
      achievements.add('${progress['quizzesTaken']} quizzes completed');
    }

    return achievements.isEmpty
        ? 'Keep up the great work with your ASL learning!'
        : 'Today: ${achievements.join(', ')}. Great progress!';
  }

  String _formatWeeklySummary(Map<String, dynamic> summary) {
    return 'This week: ${summary['totalSigns'] ?? 0} signs, '
        '${summary['totalPracticeTime'] ?? 0} minutes practiced, '
        '${summary['quizzesCompleted'] ?? 0} quizzes completed!';
  }

  Future<void> _trackAchievement(
    String goalType,
    int achieved,
    int target,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance.collection('achievements').add({
        'userId': user.uid,
        'goalType': goalType,
        'achieved': achieved,
        'target': target,
        'timestamp': FieldValue.serverTimestamp(),
        'notificationSent': true,
      });
    } catch (e) {
      print('Error tracking achievement: $e');
    }
  }

  Future<void> _updateStreak(int streakDays) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('user_streaks')
          .doc(user.uid)
          .set({
            'currentStreak': streakDays,
            'lastUpdated': FieldValue.serverTimestamp(),
            'bestStreak': FieldValue.increment(
              0,
            ), // Will not overwrite if higher
          }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating streak: $e');
    }
  }
}
