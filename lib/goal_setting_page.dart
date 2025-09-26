import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'dart:math' as math;
import 'services/goal_analytics_service.dart';
import 'services/notification_service.dart';

class GoalSettingPage extends StatefulWidget {
  const GoalSettingPage({super.key});

  @override
  State<GoalSettingPage> createState() => _GoalSettingPageState();
}

class _GoalSettingPageState extends State<GoalSettingPage> {
  final User? user = FirebaseAuth.instance.currentUser;

  // Goal settings
  int dailySignGoal = 5;
  int dailyPracticeMinutes = 15;
  int dailyQuizGoal = 2;
  double targetScore = 80.0;

  bool isLoading = true;
  bool isSaving = false;

  // Enhanced features
  Map<String, dynamic> smartRecommendations = {};
  List<Map<String, dynamic>> goalHistory = [];
  Map<String, int> currentProgress = {};
  bool showAnalytics = false;
  bool notificationsEnabled = true;

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _loadGoals();
    _loadSmartRecommendations();
    _loadGoalHistory();
    _loadCurrentProgress();
    _initializeNotifications();
  }

  Future<void> _loadGoals() async {
    if (user == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('user_goals')
          .doc(user!.uid)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          dailySignGoal = data['dailySignGoal'] ?? 5;
          dailyPracticeMinutes = data['dailyPracticeMinutes'] ?? 15;
          dailyQuizGoal = data['dailyQuizGoal'] ?? 2;
          targetScore = (data['targetScore'] ?? 80.0).toDouble();
        });
      }
    } catch (e) {
      print('Error loading goals: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _saveGoals() async {
    if (user == null) return;

    setState(() {
      isSaving = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('user_goals')
          .doc(user!.uid)
          .set({
            'dailySignGoal': dailySignGoal,
            'dailyPracticeMinutes': dailyPracticeMinutes,
            'dailyQuizGoal': dailyQuizGoal,
            'targetScore': targetScore,
            'lastUpdated': FieldValue.serverTimestamp(),
            'date': DateTime.now().toIso8601String().split(
              'T',
            )[0], // YYYY-MM-DD format
          }, SetOptions(merge: true));

      // Log activity for recent activities
      await FirebaseFirestore.instance.collection('activities').add({
        'userId': user!.uid,
        'type': 'goals_set',
        'title': 'Set daily learning goals',
        'subtitle': 'Personalized learning targets',
        'timestamp': FieldValue.serverTimestamp(),
        'data': {
          'signsGoal': dailySignGoal,
          'practiceMinutes': dailyPracticeMinutes,
          'quizGoal': dailyQuizGoal,
          'targetScore': targetScore,
        },
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Goals saved successfully! 🎯'),
          backgroundColor: Color(0xFF4facfe),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save goals: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isSaving = false;
      });
    }
  }

  // Enhanced Features Methods

  Future<void> _initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);
    await _notifications.initialize(initSettings);

    final prefs = await SharedPreferences.getInstance();
    notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
  }

  Future<void> _loadSmartRecommendations() async {
    if (user == null) return;

    try {
      // Get user's historical performance for recommendations
      final analytics = await _getUserAnalytics();
      setState(() {
        smartRecommendations = _calculateSmartRecommendations(analytics);
      });
    } catch (e) {
      print('Error loading smart recommendations: $e');
    }
  }

  Future<void> _loadGoalHistory() async {
    if (user == null) return;

    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(const Duration(days: 30));

      final query = await FirebaseFirestore.instance
          .collection('user_goals_history')
          .where('userId', isEqualTo: user!.uid)
          .where(
            'date',
            isGreaterThanOrEqualTo: startDate.toIso8601String().split('T')[0],
          )
          .orderBy('date', descending: true)
          .limit(30)
          .get();

      setState(() {
        goalHistory = query.docs.map((doc) => doc.data()).toList();
      });
    } catch (e) {
      print('Error loading goal history: $e');
    }
  }

  Future<void> _loadCurrentProgress() async {
    if (user == null) return;

    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final doc = await FirebaseFirestore.instance
          .collection('user_daily_progress')
          .doc('${user!.uid}_$today')
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          currentProgress = {
            'signs': data['signsProgress'] ?? 0,
            'practice': data['practiceProgress'] ?? 0,
            'quiz': data['quizProgress'] ?? 0,
          };
        });
      }
    } catch (e) {
      print('Error loading current progress: $e');
    }
  }

  Future<Map<String, dynamic>> _getUserAnalytics() async {
    if (user == null) return {};

    final endDate = DateTime.now();
    final startDate = endDate.subtract(const Duration(days: 30));

    final query = await FirebaseFirestore.instance
        .collection('user_daily_progress')
        .where('userId', isEqualTo: user!.uid)
        .where(
          'date',
          isGreaterThanOrEqualTo: startDate.toIso8601String().split('T')[0],
        )
        .get();

    List<int> signProgress = [];
    List<int> practiceProgress = [];
    List<int> quizProgress = [];

    for (var doc in query.docs) {
      final data = doc.data();
      signProgress.add(data['signsProgress'] ?? 0);
      practiceProgress.add(data['practiceProgress'] ?? 0);
      quizProgress.add(data['quizProgress'] ?? 0);
    }

    return {
      'signProgress': signProgress,
      'practiceProgress': practiceProgress,
      'quizProgress': quizProgress,
      'totalDays': query.docs.length,
    };
  }

  Map<String, dynamic> _calculateSmartRecommendations(
    Map<String, dynamic> analytics,
  ) {
    List<int> signProgress = analytics['signProgress'] ?? [];
    List<int> practiceProgress = analytics['practiceProgress'] ?? [];
    List<int> quizProgress = analytics['quizProgress'] ?? [];

    if (signProgress.isEmpty) {
      return {
        'dailySignGoal': 5,
        'dailyPracticeMinutes': 15,
        'dailyQuizGoal': 2,
        'targetScore': 80.0,
        'confidence': 0.5,
        'reasoning': 'Default recommendations for new users',
      };
    }

    double signAvg = signProgress.reduce((a, b) => a + b) / signProgress.length;
    double practiceAvg =
        practiceProgress.reduce((a, b) => a + b) / practiceProgress.length;
    double quizAvg = quizProgress.reduce((a, b) => a + b) / quizProgress.length;

    // Add 10-20% challenge factor
    int recommendedSigns = (signAvg * 1.15).round().clamp(3, 15);
    int recommendedPractice = (practiceAvg * 1.1).round().clamp(10, 60);
    int recommendedQuiz = (quizAvg * 1.2).round().clamp(1, 8);

    return {
      'dailySignGoal': recommendedSigns,
      'dailyPracticeMinutes': recommendedPractice,
      'dailyQuizGoal': recommendedQuiz,
      'targetScore': 85.0,
      'confidence': 0.8,
      'reasoning':
          'Based on your ${analytics['totalDays']} day performance history',
    };
  }

  Future<void> _scheduleNotifications() async {
    if (!notificationsEnabled) return;

    const androidDetails = AndroidNotificationDetails(
      'daily_reminders',
      'Daily Reminders',
      channelDescription: 'Daily goal reminders',
      importance: Importance.defaultImportance,
    );

    const details = NotificationDetails(android: androidDetails);

    // Schedule daily reminder at 9 AM
    await _notifications.zonedSchedule(
      1001,
      '🎯 Daily Goal Reminder',
      'Time to work on your ASL learning goals!',
      _nextInstanceOfTime(9, 0),
      details,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

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

  void _toggleNotifications() async {
    setState(() {
      notificationsEnabled = !notificationsEnabled;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', notificationsEnabled);

    if (notificationsEnabled) {
      await _scheduleNotifications();
    } else {
      await _notifications.cancelAll();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          notificationsEnabled
              ? 'Notifications enabled! 🔔'
              : 'Notifications disabled 🔕',
        ),
        backgroundColor: const Color(0xFF4facfe),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        body: Stack(
          children: [
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4facfe)),
              ),
            ),
            // Back Button
            Positioned(
              top: 40,
              left: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 24,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: const EdgeInsets.all(12),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white, Color(0xFFF8F9FA)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(
                left: 20,
                right: 20,
                top: 80,
                bottom: 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4facfe), Color(0xFF00f2fe)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('🎯', style: TextStyle(fontSize: 32)),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Set Your Daily Goals',
                                    style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Stay motivated and track your progress!',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white70,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Section Title
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 16),
                    child: Text(
                      '📊 Daily Goals',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4facfe),
                      ),
                    ),
                  ),

                  // Goal Settings
                  _buildGoalCard(
                    '📝 Signs to Learn',
                    'Set how many new signs you want to learn today',
                    Icons.sign_language,
                    dailySignGoal,
                    1,
                    20,
                    (value) => setState(() => dailySignGoal = value),
                  ),

                  const SizedBox(height: 24),

                  _buildGoalCard(
                    '⏰ Practice Time',
                    'Minutes of practice time per day',
                    Icons.timer,
                    dailyPracticeMinutes,
                    5,
                    120,
                    (value) => setState(() => dailyPracticeMinutes = value),
                  ),

                  const SizedBox(height: 24),

                  _buildGoalCard(
                    '🧠 Quiz Sessions',
                    'Number of quiz sessions to complete',
                    Icons.quiz,
                    dailyQuizGoal,
                    1,
                    10,
                    (value) => setState(() => dailyQuizGoal = value),
                  ),

                  const SizedBox(height: 32),

                  // Section Title for Target Score
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 16),
                    child: Text(
                      '🎯 Performance Target',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4facfe),
                      ),
                    ),
                  ),

                  _buildScoreGoalCard(),

                  const SizedBox(height: 32),

                  // Smart Recommendations Section
                  if (smartRecommendations.isNotEmpty) ...[
                    _buildSmartRecommendationsCard(),
                    const SizedBox(height: 32),
                  ],

                  // Progress Overview Section
                  if (currentProgress.isNotEmpty) ...[
                    _buildProgressOverviewCard(),
                    const SizedBox(height: 32),
                  ],

                  // Analytics Toggle
                  _buildAnalyticsToggle(),
                  const SizedBox(height: 16),

                  // Analytics Section (if expanded)
                  if (showAnalytics && goalHistory.isNotEmpty) ...[
                    _buildAnalyticsCard(),
                    const SizedBox(height: 32),
                  ],

                  // Notification Settings
                  _buildNotificationSettingsCard(),

                  const SizedBox(height: 32),

                  // Motivation Section
                  Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          colors: [Colors.white, Color(0xFFF8F9FA)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF4facfe,
                                    ).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.lightbulb,
                                    color: Color(0xFF4facfe),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  '💪 Stay Motivated!',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF4facfe),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _buildMotivationItem(
                              'Consistency is key to mastering sign language',
                              Icons.lightbulb_outline,
                            ),
                            const SizedBox(height: 16),
                            _buildMotivationItem(
                              'Small daily progress leads to big results',
                              Icons.trending_up,
                            ),
                            const SizedBox(height: 16),
                            _buildMotivationItem(
                              'Every sign you learn helps someone communicate',
                              Icons.favorite_border,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Save Button
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4facfe).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: isSaving ? null : _saveGoals,
                      icon: isSaving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.save, size: 24),
                      label: Text(
                        isSaving ? 'Saving Goals...' : '💾 Save My Goals',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4facfe),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          // Back Button
          Positioned(
            top: 40,
            left: 20,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 24,
                ),
                onPressed: () => Navigator.of(context).pop(),
                padding: const EdgeInsets.all(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard(
    String title,
    String subtitle,
    IconData icon,
    int currentValue,
    int minValue,
    int maxValue,
    Function(int) onChanged,
  ) {
    return Card(
      elevation: 8,
      shadowColor: const Color(0xFF4facfe).withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [Colors.white, Color(0xFFF8F9FA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4facfe).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF4facfe).withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Icon(icon, color: const Color(0xFF4facfe), size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4facfe).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$currentValue',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4facfe),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      children: [
                        Slider(
                          value: currentValue.toDouble(),
                          min: minValue.toDouble(),
                          max: maxValue.toDouble(),
                          divisions: maxValue - minValue,
                          activeColor: const Color(0xFF4facfe),
                          inactiveColor: Colors.grey[300],
                          onChanged: (value) => onChanged(value.toInt()),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '$minValue',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '$maxValue',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreGoalCard() {
    return Card(
      elevation: 8,
      shadowColor: const Color(0xFF4facfe).withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [Colors.white, Color(0xFFF8F9FA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4facfe).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF4facfe).withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.grade,
                      color: Color(0xFF4facfe),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🎯 Target Score',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Minimum score to achieve in quizzes',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4facfe).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${targetScore.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4facfe),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      children: [
                        Slider(
                          value: targetScore,
                          min: 50.0,
                          max: 100.0,
                          divisions: 10,
                          activeColor: const Color(0xFF4facfe),
                          inactiveColor: Colors.grey[300],
                          onChanged: (value) =>
                              setState(() => targetScore = value),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '50%',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '100%',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMotivationItem(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF4facfe).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF4facfe), size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black87,
                height: 1.4,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Enhanced UI Components

  Widget _buildSmartRecommendationsCard() {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('🤖', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Smart Recommendations',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'AI-powered goal suggestions',
                          style: TextStyle(fontSize: 14, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _applySmartRecommendations(),
                    icon: const Icon(Icons.auto_fix_high, color: Colors.white),
                    tooltip: 'Apply recommendations',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildRecommendationItem(
                '📝 Signs',
                '${smartRecommendations['dailySignGoal']} per day',
                dailySignGoal,
                smartRecommendations['dailySignGoal'],
              ),
              _buildRecommendationItem(
                '⏱️ Practice',
                '${smartRecommendations['dailyPracticeMinutes']} minutes',
                dailyPracticeMinutes,
                smartRecommendations['dailyPracticeMinutes'],
              ),
              _buildRecommendationItem(
                '🧠 Quizzes',
                '${smartRecommendations['dailyQuizGoal']} sessions',
                dailyQuizGoal,
                smartRecommendations['dailyQuizGoal'],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        smartRecommendations['reasoning'] ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecommendationItem(
    String title,
    String recommendation,
    int current,
    int suggested,
  ) {
    bool isHigher = suggested > current;
    bool isSame = suggested == current;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          if (!isSame) ...[
            Text(
              '$current → $suggested',
              style: TextStyle(
                color: isHigher ? Colors.greenAccent : Colors.orangeAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isHigher ? Icons.trending_up : Icons.trending_down,
              color: isHigher ? Colors.greenAccent : Colors.orangeAccent,
              size: 20,
            ),
          ] else ...[
            const Text(
              'Perfect! ✨',
              style: TextStyle(
                color: Colors.greenAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressOverviewCard() {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4facfe).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.trending_up,
                    color: Color(0xFF4facfe),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  '📊 Today\'s Progress',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4facfe),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildProgressItem(
              'Signs Learned',
              currentProgress['signs'] ?? 0,
              dailySignGoal,
              '👋',
            ),
            _buildProgressItem(
              'Practice Time',
              currentProgress['practice'] ?? 0,
              dailyPracticeMinutes,
              '⏱️',
            ),
            _buildProgressItem(
              'Quiz Sessions',
              currentProgress['quiz'] ?? 0,
              dailyQuizGoal,
              '🧠',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressItem(
    String title,
    int current,
    int target,
    String emoji,
  ) {
    double percentage = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Text(
                '$current / $target',
                style: TextStyle(
                  color: percentage >= 1.0 ? Colors.green : Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: percentage,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              percentage >= 1.0 ? Colors.green : const Color(0xFF4facfe),
            ),
            minHeight: 6,
          ),
          const SizedBox(height: 4),
          Text(
            '${(percentage * 100).toInt()}% Complete',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsToggle() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => showAnalytics = !showAnalytics),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4facfe).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.analytics, color: Color(0xFF4facfe)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '📈 Historical Goal Analysis',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              Icon(
                showAnalytics
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                color: const Color(0xFF4facfe),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyticsCard() {
    if (goalHistory.isEmpty) return const SizedBox.shrink();

    // Calculate analytics
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

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFF11998e), Color(0xFF38ef7d)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Text('📊', style: TextStyle(fontSize: 28)),
                  SizedBox(width: 12),
                  Text(
                    'Goal Performance Analytics',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildAnalyticsMetric(
                      'Active Days',
                      '$totalDays',
                      'Last 30 days',
                      Icons.calendar_today,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildAnalyticsMetric(
                      'Completion Rate',
                      '${completionRate.toInt()}%',
                      'Goal achievement',
                      Icons.check_circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🎯 Insights',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _generateInsight(completionRate, totalDays),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyticsMetric(
    String title,
    String value,
    String subtitle,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationSettingsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4facfe).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.notifications,
                    color: Color(0xFF4facfe),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  '🔔 Achievement Notifications',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4facfe),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Reminders',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Get notified about your goals and achievements',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: notificationsEnabled,
                  onChanged: (_) => _toggleNotifications(),
                  activeColor: const Color(0xFF4facfe),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _applySmartRecommendations() {
    setState(() {
      dailySignGoal = smartRecommendations['dailySignGoal'] ?? dailySignGoal;
      dailyPracticeMinutes =
          smartRecommendations['dailyPracticeMinutes'] ?? dailyPracticeMinutes;
      dailyQuizGoal = smartRecommendations['dailyQuizGoal'] ?? dailyQuizGoal;
      targetScore = (smartRecommendations['targetScore'] ?? targetScore)
          .toDouble();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Smart recommendations applied! 🤖✨'),
        backgroundColor: Color(0xFF4facfe),
      ),
    );
  }

  String _generateInsight(double completionRate, int totalDays) {
    if (completionRate >= 80) {
      return 'Excellent! You\'re consistently meeting your goals. Consider increasing your targets for an extra challenge.';
    } else if (completionRate >= 60) {
      return 'Good progress! You\'re on track. Try to maintain consistency to build stronger learning habits.';
    } else if (completionRate >= 40) {
      return 'Room for improvement. Consider setting more realistic goals or breaking them into smaller, achievable tasks.';
    } else {
      return 'Let\'s restart with easier goals. Small consistent steps are better than ambitious goals that are hard to maintain.';
    }
  }
}
