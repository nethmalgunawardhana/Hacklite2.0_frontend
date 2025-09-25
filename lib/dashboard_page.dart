import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'quiz_selector_page.dart';
import 'leaderboard_page.dart';
import 'sign_learning_page.dart';
import 'goal_setting_page.dart';
import 'sign_dictionary_page.dart';
import 'chatbot_screen.dart';

class DashboardPage extends StatefulWidget {
  final VoidCallback? onNavigateToCamera;

  const DashboardPage({super.key, this.onNavigateToCamera});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

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

  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.0, end: 10.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);

    _fetchUserStats();
    _fetchUserGoals();
    _fetchTodayProgress();
    _fetchRecentActivities();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _animationController.dispose();
    super.dispose();
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
      backgroundColor: const Color(0xFFF4F7FB),
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 16, right: 16),
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, -_animation.value),
              child: FloatingActionButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ChatbotScreen(),
                    ),
                  );
                },
                backgroundColor: Colors.transparent,
                elevation: 0,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                    border: Border.all(color: Color(0xFF1976D2), width: 5),
                  ),
                  child: Center(
                    child: Image.asset(
                      'images/chatbot_icon.png',
                      width: 70,
                      height: 70,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Enhanced Welcome Header with decorative shapes and avatar
            Container(
              padding: const EdgeInsets.only(
                top: 60,
                left: 20,
                right: 20,
                bottom: 28,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // decorative circles
                  Positioned(
                    right: -40,
                    top: -20,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    left: -30,
                    bottom: -20,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Column(
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
                              const SizedBox(height: 4),
                              Text(
                                user?.displayName?.split(' ').first ??
                                    'Learner',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          // avatar with subtle glow pulse
                          ScaleTransition(
                            scale: Tween(
                              begin: 0.98,
                              end: 1.02,
                            ).animate(_pulseController),
                            child: CircleAvatar(
                              radius: 32,
                              backgroundColor: Colors.white24,
                              backgroundImage: user?.photoURL != null
                                  ? NetworkImage(user!.photoURL!)
                                  : null,
                              child: user?.photoURL == null
                                  ? const Icon(
                                      Icons.waving_hand,
                                      color: Colors.white,
                                      size: 32,
                                    )
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '"Every sign you learn opens a new world of communication"',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: () {
                              if (widget.onNavigateToCamera != null) {
                                widget.onNavigateToCamera!();
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Switch to Camera tab to start translating!',
                                    ),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.camera_alt_outlined),
                            label: const Text('Live Translate'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white24,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ],
                      ),
                    ],
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
                  const SizedBox(height: 14),

                  // nicer quick action grid using Wrap
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildGradientQuickAction(
                        'Start Camera',
                        'Translate signs in real-time',
                        Icons.camera_alt,
                        [Colors.green.shade400, Colors.green.shade200],
                        () {
                          if (widget.onNavigateToCamera != null) {
                            widget.onNavigateToCamera!();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Switch to Camera tab to start translating!',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      _buildGradientQuickAction(
                        'Quizzes',
                        'Learn & test skills',
                        Icons.school,
                        [Colors.orange.shade400, Colors.orange.shade200],
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const QuizSelectorPage(),
                            ),
                          );
                        },
                      ),
                      _buildGradientQuickAction(
                        'Dictionary',
                        'Browse ASL signs',
                        Icons.book,
                        [Colors.purple.shade400, Colors.deepPurple.shade200],
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SignDictionaryPage(),
                            ),
                          );
                        },
                      ),
                      _buildGradientQuickAction(
                        'Practice',
                        'Learn new signs',
                        Icons.sign_language,
                        [Colors.teal.shade400, Colors.teal.shade200],
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SignLearningPage(
                                onSignLearned: updateSignLearningProgress,
                                onPracticeTimeUpdated: updatePracticeTime,
                              ),
                            ),
                          ).then((_) => _fetchTodayProgress());
                        },
                      ),
                      _buildGradientQuickAction(
                        'Set Goals',
                        'Plan your learning',
                        Icons.flag,
                        [Colors.indigo.shade400, Colors.indigo.shade200],
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const GoalSettingPage(),
                            ),
                          );
                        },
                      ),
                      _buildGradientQuickAction(
                        'Leaderboard',
                        'See your ranking',
                        Icons.leaderboard,
                        [Colors.amber.shade600, Colors.amber.shade300],
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LeaderboardPage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 26),
                  _buildSectionTitle('Today\'s Goals'),
                  const SizedBox(height: 12),
                  _buildTodaysGoalsCard(),

                  const SizedBox(height: 26),
                  _buildSectionTitle('Your Quiz Stats'),
                  const SizedBox(height: 12),
                  _buildUserStatsCard(),

                  const SizedBox(height: 26),
                  _buildSectionTitle('Recent Activities'),
                  const SizedBox(height: 12),
                  _buildRecentActivity(),

                  const SizedBox(height: 26),
                  _buildSectionTitle('Featured Lesson'),
                  const SizedBox(height: 12),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color.fromARGB(255, 25, 121, 204),
          ),
        ),
        // small hint button
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.info_outline, color: Colors.grey),
          tooltip: 'Tips',
        ),
      ],
    );
  }

  Widget _buildGradientQuickAction(
    String title,
    String subtitle,
    IconData icon,
    List<Color> colors,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: MediaQuery.of(context).size.width / 2 - 30,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: colors.first.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.white.withOpacity(0.18),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    if (isLoadingActivities) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(28),
          child: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1976D2)),
            ),
          ),
        ),
      );
    }

    if (recentActivities.isEmpty) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: const [
              Icon(Icons.timeline, size: 48, color: Colors.grey),
              SizedBox(height: 12),
              Text(
                'No recent activities yet',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              SizedBox(height: 6),
              Text(
                'Start learning to see your progress!',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: recentActivities.map((activity) {
          return ListTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    activity['color'].withOpacity(0.9),
                    activity['color'].withOpacity(0.6),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                activity['icon'] as IconData,
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Text(
              activity['title'] as String,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(activity['subtitle'] as String),
            trailing: Text(
              activity['time'] as String,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            onTap: () {},
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFeaturedLesson() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Featured Lesson - Coming Soon!')),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade300, Colors.purple.shade100],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.sign_language,
                  color: Colors.white,
                  size: 34,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Advanced Fingerspelling',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Master the art of spelling words with your hands',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
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
    final animatedAverage = averageScore.clamp(0, 100).toDouble();
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
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
                    color: _getPerformanceColor().withOpacity(0.12),
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
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAnimatedStatItem(
                  'Quizzes\nTaken',
                  isLoadingStats ? 0 : quizzesTaken,
                  Colors.blue,
                ),
                _buildAnimatedStatItem(
                  'Average\nScore',
                  isLoadingStats ? 0 : (animatedAverage.toInt()),
                  Colors.green,
                  suffix: '%',
                ),
                _buildAnimatedStatItem(
                  'Best\nScore',
                  isLoadingStats ? 0 : bestScore,
                  Colors.orange,
                  suffix: '%',
                ),
              ],
            ),
            const SizedBox(height: 12),
            // mini sparkline style indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Row(
                children: [
                  Expanded(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(
                        begin: 0,
                        end: _getOverallProgressValue(),
                      ),
                      duration: const Duration(milliseconds: 900),
                      builder: (context, value, child) {
                        return LinearProgressIndicator(
                          value: value,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _getOverallProgressColor(),
                          ),
                          minHeight: 6,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${(_getOverallProgressValue() * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedStatItem(
    String label,
    int value,
    Color color, {
    String suffix = '',
  }) {
    return Column(
      children: [
        TweenAnimationBuilder<int>(
          tween: IntTween(begin: 0, end: value),
          duration: const Duration(milliseconds: 900),
          builder: (context, val, child) {
            return Text(
              '$val$suffix',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildTodaysGoalsCard() {
    if (isLoadingGoals || isLoadingProgress) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(28),
          child: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1976D2)),
            ),
          ),
        ),
      );
    }

    final overallValue = _getOverallProgressValue();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
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
            const SizedBox(height: 14),
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
            const SizedBox(height: 14),
            // animated overall progress bar
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: overallValue),
              duration: const Duration(milliseconds: 900),
              builder: (context, value, _) {
                return Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: value,
                        minHeight: 10,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getOverallProgressColor(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(value * 100).toStringAsFixed(0)}% of today\'s goals completed',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                );
              },
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
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
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
        const SizedBox(height: 6),
        SizedBox(
          width: 52,
          height: 6,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
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

  // Added: helper methods for quiz performance badge (fixes missing method errors)
  Color _getPerformanceColor() {
    final avg = averageScore;
    if (avg >= 90) return Colors.green;
    if (avg >= 75) return Colors.blue;
    if (avg >= 50) return Colors.orange;
    return Colors.red;
  }

  String _getPerformanceText() {
    final avg = averageScore;
    if (avg >= 90) return 'Excellent';
    if (avg >= 75) return 'Good';
    if (avg >= 50) return 'Fair';
    return 'Needs work';
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
