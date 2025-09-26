import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';

class GoalAnalyticsService {
  static final GoalAnalyticsService _instance =
      GoalAnalyticsService._internal();
  factory GoalAnalyticsService() => _instance;
  GoalAnalyticsService._internal();

  static GoalAnalyticsService get instance => _instance;

  final NotificationService _notificationService = NotificationService.instance;

  // Smart Goal Recommendations
  Future<Map<String, int>> getSmartGoalRecommendations() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return _getDefaultGoals();

    try {
      // Get user's historical performance
      final analytics = await _getUserAnalytics();

      return {
        'dailySignGoal': _calculateOptimalSignGoal(analytics),
        'dailyPracticeMinutes': _calculateOptimalPracticeTime(analytics),
        'dailyQuizGoal': _calculateOptimalQuizGoal(analytics),
        'targetScore': _calculateOptimalTargetScore(analytics),
      };
    } catch (e) {
      print('Error getting smart recommendations: $e');
      return _getDefaultGoals();
    }
  }

  // Historical Goal Analysis
  Future<Map<String, dynamic>> getGoalHistoryAnalysis() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};

    try {
      // Get last 30 days of goal data
      final endDate = DateTime.now();
      final startDate = endDate.subtract(const Duration(days: 30));

      final goalsQuery = await FirebaseFirestore.instance
          .collection('user_goals_history')
          .where('userId', isEqualTo: user.uid)
          .where(
            'date',
            isGreaterThanOrEqualTo: startDate.toIso8601String().split('T')[0],
          )
          .where(
            'date',
            isLessThanOrEqualTo: endDate.toIso8601String().split('T')[0],
          )
          .orderBy('date', descending: true)
          .get();

      List<Map<String, dynamic>> goalHistory = [];
      for (var doc in goalsQuery.docs) {
        final data = doc.data();
        goalHistory.add(data);
      }

      return _analyzeGoalPatterns(goalHistory);
    } catch (e) {
      print('Error analyzing goal history: $e');
      return {};
    }
  }

  // Achievement Tracking
  Future<void> trackGoalProgress({
    required String goalType,
    required int currentProgress,
    required int target,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final progressDoc = FirebaseFirestore.instance
          .collection('user_daily_progress')
          .doc('${user.uid}_$today');

      // Update progress
      await progressDoc.set({
        'userId': user.uid,
        'date': today,
        '${goalType}Progress': currentProgress,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Calculate percentage
      double percentage = (currentProgress / target) * 100;

      // Check for milestone notifications
      if (percentage >= 50 && percentage < 100) {
        await _notificationService.showProgressUpdateNotification(
          progress: {
            'goalType': goalType,
            'currentProgress': currentProgress,
            'target': target,
            'percentage': percentage,
          },
        );
      }

      // Check for goal completion
      if (currentProgress >= target) {
        await _handleGoalCompletion(goalType, currentProgress, target);
        await _checkStreaks(goalType);
      }
    } catch (e) {
      print('Error tracking goal progress: $e');
    }
  }

  // Streak Management
  Future<void> _checkStreaks(String goalType) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final streakDoc = await FirebaseFirestore.instance
          .collection('user_streaks')
          .doc(user.uid)
          .get();

      Map<String, dynamic> streakData = streakDoc.exists
          ? streakDoc.data() as Map<String, dynamic>
          : {};

      String streakKey = '${goalType}Streak';
      String lastDateKey = '${goalType}LastDate';

      int currentStreak = streakData[streakKey] ?? 0;
      String? lastDate = streakData[lastDateKey];
      String today = DateTime.now().toIso8601String().split('T')[0];

      // Check if this is consecutive day
      if (lastDate != null) {
        DateTime lastDateTime = DateTime.parse(lastDate);
        DateTime todayDateTime = DateTime.parse(today);

        if (todayDateTime.difference(lastDateTime).inDays == 1) {
          // Consecutive day - increment streak
          currentStreak++;
        } else if (todayDateTime.difference(lastDateTime).inDays > 1) {
          // Streak broken - reset
          currentStreak = 1;
        }
        // If same day, don't change streak
      } else {
        // First time
        currentStreak = 1;
      }

      // Update streak data
      streakData[streakKey] = currentStreak;
      streakData[lastDateKey] = today;

      await FirebaseFirestore.instance
          .collection('user_streaks')
          .doc(user.uid)
          .set(streakData, SetOptions(merge: true));

      // Notify for significant streaks
      if (currentStreak >= 3 && currentStreak % 3 == 0) {
        await _notificationService.showStreakNotification(
          streakDays: currentStreak,
        );
      }
    } catch (e) {
      print('Error checking streaks: $e');
    }
  }

  // Weekly Summary Generation
  Future<void> generateWeeklySummary() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(const Duration(days: 7));

      // Get week's progress data
      final progressQuery = await FirebaseFirestore.instance
          .collection('user_daily_progress')
          .where('userId', isEqualTo: user.uid)
          .where(
            'date',
            isGreaterThanOrEqualTo: startDate.toIso8601String().split('T')[0],
          )
          .where(
            'date',
            isLessThanOrEqualTo: endDate.toIso8601String().split('T')[0],
          )
          .get();

      Map<String, dynamic> weeklyStats = _calculateWeeklyStats(
        progressQuery.docs,
      );

      // Send weekly summary notification
      await _notificationService.showWeeklySummaryNotification(
        summary: weeklyStats,
      );

      // Save weekly summary to Firestore
      await FirebaseFirestore.instance.collection('weekly_summaries').add({
        'userId': user.uid,
        'weekStart': startDate.toIso8601String().split('T')[0],
        'weekEnd': endDate.toIso8601String().split('T')[0],
        'stats': weeklyStats,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error generating weekly summary: $e');
    }
  }

  // Smart Recommendations Based on Performance
  Future<void> generateSmartRecommendations() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final analytics = await _getUserAnalytics();
      final recommendations = _analyzePerformanceAndRecommend(analytics);

      for (var recommendation in recommendations) {
        await _notificationService.showSmartRecommendation(
          recommendations: {
            'type': recommendation['type'],
            'message': recommendation['message'],
            'data': recommendation['data'],
          },
        );
      }
    } catch (e) {
      print('Error generating smart recommendations: $e');
    }
  }

  // Private Methods
  Future<Map<String, dynamic>> _getUserAnalytics() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};

    // Get last 30 days of data for analysis
    final endDate = DateTime.now();
    final startDate = endDate.subtract(const Duration(days: 30));

    final progressQuery = await FirebaseFirestore.instance
        .collection('user_daily_progress')
        .where('userId', isEqualTo: user.uid)
        .where(
          'date',
          isGreaterThanOrEqualTo: startDate.toIso8601String().split('T')[0],
        )
        .where(
          'date',
          isLessThanOrEqualTo: endDate.toIso8601String().split('T')[0],
        )
        .get();

    List<int> signProgress = [];
    List<int> practiceProgress = [];
    List<int> quizProgress = [];

    for (var doc in progressQuery.docs) {
      final data = doc.data();
      signProgress.add(data['signsProgress'] ?? 0);
      practiceProgress.add(data['practiceProgress'] ?? 0);
      quizProgress.add(data['quizProgress'] ?? 0);
    }

    return {
      'signProgress': signProgress,
      'practiceProgress': practiceProgress,
      'quizProgress': quizProgress,
      'totalDays': progressQuery.docs.length,
    };
  }

  Map<String, int> _getDefaultGoals() {
    return {
      'dailySignGoal': 5,
      'dailyPracticeMinutes': 15,
      'dailyQuizGoal': 2,
      'targetScore': 80,
    };
  }

  int _calculateOptimalSignGoal(Map<String, dynamic> analytics) {
    List<int> signProgress = analytics['signProgress'] ?? [];
    if (signProgress.isEmpty) return 5;

    // Calculate average and add 20% challenge
    double average = signProgress.reduce((a, b) => a + b) / signProgress.length;
    return (average * 1.2).round().clamp(3, 15);
  }

  int _calculateOptimalPracticeTime(Map<String, dynamic> analytics) {
    List<int> practiceProgress = analytics['practiceProgress'] ?? [];
    if (practiceProgress.isEmpty) return 15;

    double average =
        practiceProgress.reduce((a, b) => a + b) / practiceProgress.length;
    return (average * 1.15).round().clamp(10, 60);
  }

  int _calculateOptimalQuizGoal(Map<String, dynamic> analytics) {
    List<int> quizProgress = analytics['quizProgress'] ?? [];
    if (quizProgress.isEmpty) return 2;

    double average = quizProgress.reduce((a, b) => a + b) / quizProgress.length;
    return (average * 1.1).round().clamp(1, 10);
  }

  int _calculateOptimalTargetScore(Map<String, dynamic> analytics) {
    // This would be based on quiz scores, but for now return adaptive target
    return 85; // Could be calculated from actual quiz performance
  }

  Map<String, dynamic> _analyzeGoalPatterns(
    List<Map<String, dynamic>> goalHistory,
  ) {
    if (goalHistory.isEmpty) return {};

    int totalDays = goalHistory.length;
    int completedDays = goalHistory
        .where(
          (day) =>
              (day['signsCompleted'] ?? false) ||
              (day['practiceCompleted'] ?? false) ||
              (day['quizCompleted'] ?? false),
        )
        .length;

    double completionRate = (completedDays / totalDays) * 100;

    // Calculate trends
    Map<String, List<int>> trends = {'signs': [], 'practice': [], 'quiz': []};

    for (var day in goalHistory) {
      trends['signs']!.add(day['signsProgress'] ?? 0);
      trends['practice']!.add(day['practiceProgress'] ?? 0);
      trends['quiz']!.add(day['quizProgress'] ?? 0);
    }

    return {
      'totalDays': totalDays,
      'completedDays': completedDays,
      'completionRate': completionRate,
      'trends': trends,
      'mostProductiveGoal': _findMostProductiveGoal(trends),
      'improvementAreas': _findImprovementAreas(trends),
    };
  }

  String _findMostProductiveGoal(Map<String, List<int>> trends) {
    double signsAvg = trends['signs']!.isNotEmpty
        ? trends['signs']!.reduce((a, b) => a + b) / trends['signs']!.length
        : 0;
    double practiceAvg = trends['practice']!.isNotEmpty
        ? trends['practice']!.reduce((a, b) => a + b) /
              trends['practice']!.length
        : 0;
    double quizAvg = trends['quiz']!.isNotEmpty
        ? trends['quiz']!.reduce((a, b) => a + b) / trends['quiz']!.length
        : 0;

    if (signsAvg >= practiceAvg && signsAvg >= quizAvg) return 'signs';
    if (practiceAvg >= quizAvg) return 'practice';
    return 'quiz';
  }

  List<String> _findImprovementAreas(Map<String, List<int>> trends) {
    List<String> areas = [];

    trends.forEach((goal, progress) {
      if (progress.isNotEmpty) {
        double average = progress.reduce((a, b) => a + b) / progress.length;
        if (average < 0.5) {
          // Less than 50% completion rate
          areas.add(goal);
        }
      }
    });

    return areas;
  }

  Future<void> _handleGoalCompletion(
    String goalType,
    int progress,
    int target,
  ) async {
    await _notificationService.showGoalCompletionNotification(
      goalType: goalType,
      achieved: progress,
      target: target,
      message: 'Daily $goalType goal completed!',
    );

    // Save goal completion to history
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final today = DateTime.now().toIso8601String().split('T')[0];
      await FirebaseFirestore.instance.collection('goal_completions').add({
        'userId': user.uid,
        'goalType': goalType,
        'progress': progress,
        'target': target,
        'completedAt': FieldValue.serverTimestamp(),
        'date': today,
      });
    }
  }

  Map<String, dynamic> _calculateWeeklyStats(List<QueryDocumentSnapshot> docs) {
    int completedGoals = 0;
    int totalSigns = 0;
    int totalPracticeMinutes = 0;
    int quizzesTaken = 0;

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;

      if ((data['signsCompleted'] ?? false)) completedGoals++;
      if ((data['practiceCompleted'] ?? false)) completedGoals++;
      if ((data['quizCompleted'] ?? false)) completedGoals++;

      totalSigns += (data['signsProgress'] ?? 0) as int;
      totalPracticeMinutes += (data['practiceProgress'] ?? 0) as int;
      quizzesTaken += (data['quizProgress'] ?? 0) as int;
    }

    return {
      'completedGoals': completedGoals,
      'totalSigns': totalSigns,
      'totalPracticeMinutes': totalPracticeMinutes,
      'quizzesTaken': quizzesTaken,
      'activeDays': docs.length,
    };
  }

  List<Map<String, dynamic>> _analyzePerformanceAndRecommend(
    Map<String, dynamic> analytics,
  ) {
    List<Map<String, dynamic>> recommendations = [];

    List<int> signProgress = analytics['signProgress'] ?? [];
    List<int> practiceProgress = analytics['practiceProgress'] ?? [];

    // Check for consistent low performance
    if (signProgress.isNotEmpty &&
        signProgress.reduce((a, b) => a + b) / signProgress.length < 2) {
      recommendations.add({
        'type': 'sign_learning',
        'message': 'Consider starting with easier signs to build confidence!',
        'data': {
          'currentAverage':
              signProgress.reduce((a, b) => a + b) / signProgress.length,
        },
      });
    }

    if (practiceProgress.isNotEmpty &&
        practiceProgress.reduce((a, b) => a + b) / practiceProgress.length <
            5) {
      recommendations.add({
        'type': 'practice_time',
        'message': 'Try shorter, more frequent practice sessions!',
        'data': {
          'currentAverage':
              practiceProgress.reduce((a, b) => a + b) /
              practiceProgress.length,
        },
      });
    }

    return recommendations;
  }
}
