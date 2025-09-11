import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'quiz_selector_page.dart';
import 'leaderboard_page.dart';
import 'sign_learning_page.dart';
import 'goal_setting_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final User? user = FirebaseAuth.instance.currentUser;

  // User stats
  int quizzesTaken = 0;
  double averageScore = 0.0;
  int bestScore = 0;
  bool isLoadingStats = true;

  // User goals
  int dailySignGoal = 5;
  int dailyPracticeMinutes = 15;
  int dailyQuizGoal = 2;
  double targetScore = 80.0;
  bool isLoadingGoals = true;

  // Goal progress tracking
  int signsLearnedToday = 0;
  int practiceMinutesToday = 0;
  int quizzesCompletedToday = 0;
  bool isLoadingProgress = true;

  // Recent activities
  List<Map<String, dynamic>> recentActivities = [];
  bool isLoadingActivities = true;

  @override
  void initState() {
    super.initState();
    _fetchUserStats();
    _fetchUserGoals();
    _fetchTodayProgress();
    _fetchRecentActivities();
  }

  Future<void> _fetchUserStats() async {
    if (user == null) {
      setState(() {
        isLoadingStats = false;
      });
      return;
    }

    try {
      // Fetch user's quiz scores from leaderboard collection
      final snapshot = await FirebaseFirestore.instance
          .collection('leaderboard')
          .where('userId', isEqualTo: user!.uid)
          .orderBy('timestamp', descending: true)
          .get();

      if (snapshot.docs.isEmpty) {
        setState(() {
          isLoadingStats = false;
        });
        return;
      }

      int totalScore = 0;
      int maxScore = 0;
      int totalQuizzes = snapshot.docs.length;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final percentage = data['percentage'] as int? ?? 0;
        totalScore += percentage;
        if (percentage > maxScore) {
          maxScore = percentage;
        }
      }

      setState(() {
        quizzesTaken = totalQuizzes;
        averageScore = totalQuizzes > 0 ? totalScore / totalQuizzes : 0.0;
        bestScore = maxScore;
        isLoadingStats = false;
      });
    } catch (e) {
      print('Error fetching user stats: $e');
      setState(() {
        isLoadingStats = false;
      });
    }
  }

  Future<void> _fetchUserGoals() async {
    if (user == null) {
      setState(() {
        isLoadingGoals = false;
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
      print('Error fetching user goals: $e');
    } finally {
      setState(() {
        isLoadingGoals = false;
      });
    }
  }

  Future<void> _fetchTodayProgress() async {
    if (user == null) {
      setState(() {
        isLoadingProgress = false;
      });
      return;
    }

    try {
      final today = DateTime.now().toIso8601String().split('T')[0];

      // Fetch today's quiz progress
      final quizSnapshot = await FirebaseFirestore.instance
          .collection('leaderboard')
          .where('userId', isEqualTo: user!.uid)
          .where('date', isEqualTo: today)
          .get();

      // Fetch today's sign learning progress
      final signProgressDoc = await FirebaseFirestore.instance
          .collection('daily_progress')
          .doc('${user!.uid}_$today')
          .get();

      setState(() {
        quizzesCompletedToday = quizSnapshot.docs.length;

        if (signProgressDoc.exists) {
          final data = signProgressDoc.data() as Map<String, dynamic>;
          signsLearnedToday = data['signsLearned'] ?? 0;
          practiceMinutesToday = data['practiceMinutes'] ?? 0;
        }
      });
    } catch (e) {
      print('Error fetching today progress: $e');
    } finally {
      setState(() {
        isLoadingProgress = false;
      });
    }
  }

  Future<void> _fetchRecentActivities() async {
    if (user == null) {
      setState(() {
        isLoadingActivities = false;
      });
      return;
    }

    try {
      // Fetch recent activities from activities collection
      final activitiesSnapshot = await FirebaseFirestore.instance
          .collection('activities')
          .where('userId', isEqualTo: user!.uid)
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      List<Map<String, dynamic>> activities = [];

      for (var doc in activitiesSnapshot.docs) {
        final data = doc.data();
        final timestamp = data['timestamp'] as Timestamp?;
        final timeAgo = timestamp != null
            ? _getTimeAgo(timestamp.toDate())
            : 'Recently';

        // Determine icon and color based on activity type
        IconData icon = Icons.info;
        Color color = Colors.grey;

        switch (data['type']) {
          case 'quiz_completed':
            icon = Icons.quiz;
            color = Colors.blue;
            break;
          case 'sign_learned':
          case 'signs_learned':
            icon = Icons.sign_language;
            color = Colors.green;
            break;
          case 'goals_set':
            icon = Icons.flag;
            color = Colors.purple;
            break;
          case 'practice_session':
            icon = Icons.timer;
            color = Colors.orange;
            break;
        }

        activities.add({
          'title': data['title'] as String? ?? 'Activity',
          'subtitle': data['subtitle'] as String? ?? '',
          'time': timeAgo,
          'icon': icon,
          'color': color,
          'timestamp': timestamp?.toDate() ?? DateTime.now(),
        });
      }

      // If no activities found, add a welcome message
      if (activities.isEmpty) {
        activities.add({
          'title': 'Welcome!',
          'subtitle': 'Start your sign language journey',
          'time': 'Just now',
          'icon': Icons.waving_hand,
          'color': Colors.purple,
          'timestamp': DateTime.now(),
        });
      }

      setState(() {
        recentActivities = activities.take(5).toList();
      });
    } catch (e) {
      print('Error fetching recent activities: $e');
      // Fallback to some default activities
      setState(() {
        recentActivities = [
          {
            'title': 'Welcome!',
            'subtitle': 'Start your sign language journey',
            'time': 'Just now',
            'icon': Icons.waving_hand,
            'color': Colors.purple,
            'timestamp': DateTime.now(),
          },
        ];
      });
    } finally {
      setState(() {
        isLoadingActivities = false;
      });
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Header
            Container(
              padding: const EdgeInsets.only(
                top: 60,
                left: 20,
                right: 20,
                bottom: 30,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4facfe), Color(0xFF00f2fe)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Welcome back,',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                            ),
                          ),
                          Text(
                            user?.displayName?.split(' ').first ?? 'Learner',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white24,
                        child: Icon(
                          Icons.waving_hand,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '"Every sign you learn opens a new world of communication"',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),

            // Content Sections
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Quick Actions'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickActionCard(
                          'Start Camera',
                          'Translate signs in real-time',
                          Icons.camera_alt,
                          Colors.green,
                          () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Switch to Camera tab to start translating!',
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildQuickActionCard(
                          'Quizzes',
                          'Learn and test your skills',
                          Icons.school,
                          Colors.orange,
                          () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const QuizSelectorPage(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickActionCard(
                          'Dictionary',
                          'Browse ASL signs',
                          Icons.book,
                          Colors.purple,
                          () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('ASL Dictionary - Coming Soon!'),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildQuickActionCard(
                          'Practice New Sign',
                          'Learn sign language basics',
                          Icons.sign_language,
                          Colors.teal,
                          () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SignLearningPage(
                                  onSignLearned: updateSignLearningProgress,
                                  onPracticeTimeUpdated: updatePracticeTime,
                                ),
                              ),
                            ).then((_) {
                              // Refresh progress when returning from sign learning page
                              _fetchTodayProgress();
                            });
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickActionCard(
                          'Set Goals',
                          'Plan your daily learning',
                          Icons.flag,
                          Colors.indigo,
                          () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const GoalSettingPage(),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildQuickActionCard(
                          'Leaderboard',
                          'See your ranking',
                          Icons.leaderboard,
                          Colors.amber,
                          () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LeaderboardPage(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),
                  _buildSectionTitle('Today\'s Goals'),
                  const SizedBox(height: 16),
                  _buildTodaysGoalsCard(),

                  const SizedBox(height: 30),
                  _buildSectionTitle('Your Quiz Stats'),
                  const SizedBox(height: 16),
                  _buildUserStatsCard(),

                  const SizedBox(height: 30),
                  _buildSectionTitle('Recent Activities'),
                  const SizedBox(height: 16),
                  _buildRecentActivity(),

                  const SizedBox(height: 30),
                  _buildSectionTitle('Featured Lesson'),
                  const SizedBox(height: 16),
                  _buildFeaturedLesson(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Color(0xFF4facfe),
      ),
    );
  }

  Widget _buildQuickActionCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: color.withOpacity(0.12),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    if (isLoadingActivities) {
      return Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: const Padding(
          padding: EdgeInsets.all(40),
          child: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4facfe)),
            ),
          ),
        ),
      );
    }

    if (recentActivities.isEmpty) {
      return Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: const Padding(
          padding: EdgeInsets.all(40),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.history, size: 48, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No recent activities yet',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Start learning to see your progress!',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: recentActivities.asMap().entries.map((entry) {
            final index = entry.key;
            final activity = entry.value;
            final widget = _buildActivityItem(
              activity['title'] as String,
              activity['time'] as String,
              activity['icon'] as IconData,
              activity['color'] as Color,
            );

            // Add divider between items (except for the last one)
            if (index < recentActivities.length - 1) {
              return Column(children: [widget, const Divider()]);
            }
            return widget;
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildActivityItem(
    String title,
    String time,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                time,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturedLesson() {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Featured Lesson - Coming Soon!')),
          );
        },
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.sign_language,
                  color: Colors.purple,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Advanced Fingerspelling',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Master the art of spelling words with your hands',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        const Icon(
                          Icons.star_half,
                          color: Colors.amber,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '4.5',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserStatsCard() {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Quiz Performance',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getPerformanceColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _getPerformanceText(),
                    style: TextStyle(
                      color: _getPerformanceColor(),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  'Quizzes\nTaken',
                  isLoadingStats ? '...' : '$quizzesTaken',
                  Colors.blue,
                ),
                _buildStatItem(
                  'Average\nScore',
                  isLoadingStats
                      ? '...'
                      : '${averageScore.toStringAsFixed(1)}%',
                  Colors.green,
                ),
                _buildStatItem(
                  'Best\nScore',
                  isLoadingStats ? '...' : '$bestScore%',
                  Colors.orange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLeaderboardButton() {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LeaderboardPage()),
          );
        },
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.amber, Colors.orange],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.leaderboard,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'View Leaderboard',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'See how you rank against other learners',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  String _getPerformanceText() {
    if (isLoadingStats) return 'Loading...';
    if (quizzesTaken == 0) return 'Start Learning!';
    if (averageScore >= 90) return 'Excellent!';
    if (averageScore >= 80) return 'Great!';
    if (averageScore >= 70) return 'Good!';
    if (averageScore >= 60) return 'Keep Going!';
    return 'Practice More!';
  }

  Color _getPerformanceColor() {
    if (isLoadingStats || quizzesTaken == 0) return Colors.grey;
    if (averageScore >= 90) return Colors.purple;
    if (averageScore >= 80) return Colors.green;
    if (averageScore >= 70) return Colors.blue;
    if (averageScore >= 60) return Colors.orange;
    return Colors.red;
  }

  Widget _buildTodaysGoalsCard() {
    if (isLoadingGoals || isLoadingProgress) {
      return Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: const Padding(
          padding: EdgeInsets.all(40),
          child: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4facfe)),
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Today\'s Progress',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getOverallProgressColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _getOverallProgressText(),
                    style: TextStyle(
                      color: _getOverallProgressColor(),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildGoalProgressItem(
                  'Signs Learned',
                  signsLearnedToday,
                  dailySignGoal,
                  Icons.sign_language,
                  Colors.teal,
                ),
                _buildGoalProgressItem(
                  'Practice Time',
                  practiceMinutesToday,
                  dailyPracticeMinutes,
                  Icons.timer,
                  Colors.orange,
                ),
                _buildGoalProgressItem(
                  'Quizzes Done',
                  quizzesCompletedToday,
                  dailyQuizGoal,
                  Icons.quiz,
                  Colors.purple,
                ),
              ],
            ),
            const SizedBox(height: 20),
            LinearProgressIndicator(
              value: _getOverallProgressValue(),
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                _getOverallProgressColor(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(_getOverallProgressValue() * 100).toStringAsFixed(0)}% of today\'s goals completed',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalProgressItem(
    String label,
    int current,
    int target,
    IconData icon,
    Color color,
  ) {
    final progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    final isCompleted = current >= target;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          '$current/$target',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isCompleted ? color : Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 40,
          height: 4,
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  double _getOverallProgressValue() {
    if (dailySignGoal == 0 && dailyPracticeMinutes == 0 && dailyQuizGoal == 0) {
      return 0.0;
    }

    final signProgress = dailySignGoal > 0
        ? (signsLearnedToday / dailySignGoal).clamp(0.0, 1.0)
        : 0.0;
    final practiceProgress = dailyPracticeMinutes > 0
        ? (practiceMinutesToday / dailyPracticeMinutes).clamp(0.0, 1.0)
        : 0.0;
    final quizProgress = dailyQuizGoal > 0
        ? (quizzesCompletedToday / dailyQuizGoal).clamp(0.0, 1.0)
        : 0.0;

    final totalProgress = (signProgress + practiceProgress + quizProgress) / 3;
    return totalProgress.clamp(0.0, 1.0);
  }

  String _getOverallProgressText() {
    final progress = _getOverallProgressValue();
    if (progress >= 1.0) return 'Completed! 🎉';
    if (progress >= 0.8) return 'Almost there!';
    if (progress >= 0.5) return 'Good progress';
    if (progress >= 0.2) return 'Keep going!';
    return 'Just started';
  }

  Color _getOverallProgressColor() {
    final progress = _getOverallProgressValue();
    if (progress >= 1.0) return Colors.green;
    if (progress >= 0.8) return Colors.blue;
    if (progress >= 0.5) return Colors.orange;
    if (progress >= 0.2) return Colors.amber;
    return Colors.grey;
  }

  // Progress update methods
  void updateSignLearningProgress(int signsLearned) {
    _updateSignLearningProgress(signsLearned);
  }

  void updatePracticeTime(int minutes) {
    _updatePracticeTime(minutes);
  }

  Future<void> _updateSignLearningProgress(int signsLearned) async {
    if (user == null) return;

    final today = DateTime.now().toIso8601String().split('T')[0];
    final docRef = FirebaseFirestore.instance
        .collection('daily_progress')
        .doc('${user!.uid}_$today');

    try {
      final doc = await docRef.get();
      int currentSigns = 0;

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        currentSigns = data['signsLearned'] ?? 0;
      }

      await docRef.set({
        'signsLearned': currentSigns + signsLearned,
        'lastUpdated': FieldValue.serverTimestamp(),
        'date': today,
      }, SetOptions(merge: true));

      // Refresh progress
      await _fetchTodayProgress();
    } catch (e) {
      print('Error updating sign learning progress: $e');
    }
  }

  Future<void> _updatePracticeTime(int minutes) async {
    if (user == null) return;

    final today = DateTime.now().toIso8601String().split('T')[0];
    final docRef = FirebaseFirestore.instance
        .collection('daily_progress')
        .doc('${user!.uid}_$today');

    try {
      final doc = await docRef.get();
      int currentMinutes = 0;

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        currentMinutes = data['practiceMinutes'] ?? 0;
      }

      await docRef.set({
        'practiceMinutes': currentMinutes + minutes,
        'lastUpdated': FieldValue.serverTimestamp(),
        'date': today,
      }, SetOptions(merge: true));

      // Refresh progress
      await _fetchTodayProgress();
    } catch (e) {
      print('Error updating practice time: $e');
    }
  }

  // Activity logging methods
  void logQuizActivity(String quizTitle, int score, int percentage) {
    _logQuizActivity(quizTitle, score, percentage);
  }

  void logSignLearningActivity(int signsLearned) {
    _logSignLearningActivity(signsLearned);
  }

  void logGoalSettingActivity() {
    _logGoalSettingActivity();
  }

  Future<void> _logQuizActivity(
    String quizTitle,
    int score,
    int percentage,
  ) async {
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('activities').add({
        'userId': user!.uid,
        'type': 'quiz_completed',
        'title': 'Completed quiz: $quizTitle',
        'subtitle': 'Scored $percentage%',
        'timestamp': FieldValue.serverTimestamp(),
        'data': {
          'quizTitle': quizTitle,
          'score': score,
          'percentage': percentage,
        },
      });

      // Refresh activities
      await _fetchRecentActivities();
    } catch (e) {
      print('Error logging quiz activity: $e');
    }
  }

  Future<void> _logSignLearningActivity(int signsLearned) async {
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('activities').add({
        'userId': user!.uid,
        'type': 'signs_learned',
        'title': 'Learned $signsLearned new signs',
        'subtitle': 'Sign language practice',
        'timestamp': FieldValue.serverTimestamp(),
        'data': {'signsLearned': signsLearned},
      });

      // Refresh activities
      await _fetchRecentActivities();
    } catch (e) {
      print('Error logging sign learning activity: $e');
    }
  }

  Future<void> _logGoalSettingActivity() async {
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('activities').add({
        'userId': user!.uid,
        'type': 'goals_set',
        'title': 'Set daily learning goals',
        'subtitle': 'Personalized learning targets',
        'timestamp': FieldValue.serverTimestamp(),
        'data': {},
      });

      // Refresh activities
      await _fetchRecentActivities();
    } catch (e) {
      print('Error logging goal setting activity: $e');
    }
  }
}
