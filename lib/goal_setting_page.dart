import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  @override
  void initState() {
    super.initState();
    _loadGoals();
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

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Daily Goals'),
          backgroundColor: const Color(0xFF4facfe),
        ),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4facfe)),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Goals'),
        backgroundColor: const Color(0xFF4facfe),
        actions: [
          TextButton(
            onPressed: isSaving ? null : _saveGoals,
            child: isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Color(0xFFF8F9FA)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4facfe), Color(0xFF00f2fe)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🎯 Set Your Daily Goals',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Stay motivated and track your progress!',
                      style: TextStyle(fontSize: 16, color: Colors.white70),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

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

              const SizedBox(height: 20),

              _buildGoalCard(
                '⏰ Practice Time',
                'Minutes of practice time per day',
                Icons.timer,
                dailyPracticeMinutes,
                5,
                120,
                (value) => setState(() => dailyPracticeMinutes = value),
              ),

              const SizedBox(height: 20),

              _buildGoalCard(
                '🧠 Quiz Sessions',
                'Number of quiz sessions to complete',
                Icons.quiz,
                dailyQuizGoal,
                1,
                10,
                (value) => setState(() => dailyQuizGoal = value),
              ),

              const SizedBox(height: 20),

              _buildScoreGoalCard(),

              const SizedBox(height: 30),

              // Motivation Section
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '💪 Stay Motivated!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4facfe),
                        ),
                      ),
                      const SizedBox(height: 15),
                      _buildMotivationItem(
                        'Consistency is key to mastering sign language',
                        Icons.lightbulb,
                      ),
                      const SizedBox(height: 10),
                      _buildMotivationItem(
                        'Small daily progress leads to big results',
                        Icons.trending_up,
                      ),
                      const SizedBox(height: 10),
                      _buildMotivationItem(
                        'Every sign you learn helps someone communicate',
                        Icons.favorite,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isSaving ? null : _saveGoals,
                  icon: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(isSaving ? 'Saving...' : 'Save Goals'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4facfe),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
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
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: const Color(0xFF4facfe), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text(
                  '$currentValue',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4facfe),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Slider(
                    value: currentValue.toDouble(),
                    min: minValue.toDouble(),
                    max: maxValue.toDouble(),
                    divisions: maxValue - minValue,
                    activeColor: const Color(0xFF4facfe),
                    inactiveColor: Colors.grey[300],
                    onChanged: (value) => onChanged(value.toInt()),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$minValue',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                Text(
                  '$maxValue',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreGoalCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
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
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.grade,
                    color: Color(0xFF4facfe),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🎯 Target Score',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Minimum score to achieve in quizzes',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text(
                  '${targetScore.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4facfe),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Slider(
                    value: targetScore,
                    min: 50.0,
                    max: 100.0,
                    divisions: 10,
                    activeColor: const Color(0xFF4facfe),
                    inactiveColor: Colors.grey[300],
                    onChanged: (value) => setState(() => targetScore = value),
                  ),
                ),
              ],
            ),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('50%', style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text(
                  '100%',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMotivationItem(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF4facfe), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ),
      ],
    );
  }
}
