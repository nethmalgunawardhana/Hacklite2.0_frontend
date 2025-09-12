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
}
