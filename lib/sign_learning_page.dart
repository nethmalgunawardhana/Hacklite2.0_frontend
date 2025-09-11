import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignLearningPage extends StatefulWidget {
  final Function(int)? onSignLearned;
  final Function(int)? onPracticeTimeUpdated;

  const SignLearningPage({
    super.key,
    this.onSignLearned,
    this.onPracticeTimeUpdated,
  });

  @override
  State<SignLearningPage> createState() => _SignLearningPageState();
}

class _SignLearningPageState extends State<SignLearningPage> {
  final User? user = FirebaseAuth.instance.currentUser;

  // Practice time tracking
  DateTime? _practiceStartTime;
  int _sessionPracticeMinutes = 0;

  // List of signs with their images and descriptions
  final List<Map<String, dynamic>> signs = [
    {
      'name': 'Please',
      'image': 'Sign-Language-Please-.webp',
      'description':
          'Place your dominant hand flat against your chest and move it in a circular motion.',
      'difficulty': 'Beginner',
    },
    {
      'name': 'Eat/Lunch',
      'image': 'Sign-Language-Eat-Lunch-.webp',
      'description':
          'Bring your fingertips to your mouth and move your hand away as if taking food.',
      'difficulty': 'Beginner',
    },
    {
      'name': 'Potty',
      'image': 'Sign-Language-Potty-.webp',
      'description':
          'Make a fist with your dominant hand and tap it against your chin.',
      'difficulty': 'Beginner',
    },
    {
      'name': 'M',
      'image': 'Sign-Language-M-.webp',
      'description':
          'Form an M shape with your fingers and hold it near your forehead.',
      'difficulty': 'Intermediate',
    },
  ];

  int currentSignIndex = 0;
  Map<String, String> progressTracking = {};

  @override
  void initState() {
    super.initState();
    _practiceStartTime = DateTime.now();
    _loadProgress();
  }

  @override
  void dispose() {
    // Calculate practice time when leaving the page
    if (_practiceStartTime != null) {
      final practiceDuration = DateTime.now().difference(_practiceStartTime!);
      _sessionPracticeMinutes = practiceDuration.inMinutes;
      if (_sessionPracticeMinutes > 0) {
        if (widget.onPracticeTimeUpdated != null) {
          widget.onPracticeTimeUpdated!(_sessionPracticeMinutes);
        }

        // Log practice time activity
        if (user != null) {
          FirebaseFirestore.instance
              .collection('activities')
              .add({
                'userId': user!.uid,
                'type': 'practice_session',
                'title': 'Practice session completed',
                'subtitle': 'Spent $_sessionPracticeMinutes minutes learning',
                'timestamp': FieldValue.serverTimestamp(),
                'data': {'minutes': _sessionPracticeMinutes},
              })
              .then((_) {
                // Activity logged successfully
              })
              .catchError((e) {
                print('Error logging practice activity: $e');
                return null; // Return null to satisfy the error handler
              });
        }
      }
    }
    super.dispose();
  }

  Future<void> _loadProgress() async {
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('user_progress')
          .doc(user!.uid)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final progress = data['sign_progress'] as Map<String, dynamic>? ?? {};
        setState(() {
          progressTracking = Map<String, String>.from(progress);
        });
      }
    } catch (e) {
      print('Error loading progress: $e');
    }
  }

  Future<void> _saveProgress(String signName, String status) async {
    if (user == null) return;

    // Check if this is a new completion
    final wasCompleted =
        progressTracking[signName] == 'Mastered' ||
        progressTracking[signName] == 'Practiced';
    final isNowCompleted = status == 'Mastered' || status == 'Practiced';

    setState(() {
      progressTracking[signName] = status;
    });

    try {
      await FirebaseFirestore.instance
          .collection('user_progress')
          .doc(user!.uid)
          .set({
            'sign_progress': progressTracking,
            'last_updated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      // Call callback if sign was newly completed
      if (!wasCompleted && isNowCompleted && widget.onSignLearned != null) {
        widget.onSignLearned!(1);
      }

      // Log activity for recent activities if sign was newly completed
      if (!wasCompleted && isNowCompleted) {
        await FirebaseFirestore.instance.collection('activities').add({
          'userId': user!.uid,
          'type': 'sign_learned',
          'title': 'Learned sign: $signName',
          'subtitle': 'Sign language practice',
          'timestamp': FieldValue.serverTimestamp(),
          'data': {'signName': signName, 'status': status},
        });
      }
    } catch (e) {
      print('Error saving progress: $e');
    }
  }

  void _nextSign() {
    setState(() {
      if (currentSignIndex < signs.length - 1) {
        currentSignIndex++;
      } else {
        currentSignIndex = 0; // Loop back to first sign
      }
    });
  }

  void _previousSign() {
    setState(() {
      if (currentSignIndex > 0) {
        currentSignIndex--;
      } else {
        currentSignIndex = signs.length - 1; // Loop to last sign
      }
    });
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty) {
      case 'Beginner':
        return Colors.green;
      case 'Intermediate':
        return Colors.orange;
      case 'Advanced':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentSign = signs[currentSignIndex];
    final currentProgress =
        progressTracking[currentSign['name']] ?? 'Not Started';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Learn Signs'),
        backgroundColor: const Color(0xFF4facfe),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Chip(
              label: Text(
                '${currentSignIndex + 1}/${signs.length}',
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.white24,
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Sign Image Card
              Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Sign Name
                      Text(
                        currentSign['name'],
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4facfe),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Difficulty Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _getDifficultyColor(
                            currentSign['difficulty'],
                          ).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _getDifficultyColor(
                              currentSign['difficulty'],
                            ),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          currentSign['difficulty'],
                          style: TextStyle(
                            color: _getDifficultyColor(
                              currentSign['difficulty'],
                            ),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Sign Image
                      Container(
                        height: 250,
                        width: 250,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image.asset(
                            'images/${currentSign['image']}',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[200],
                                child: const Icon(
                                  Icons.image_not_supported,
                                  size: 80,
                                  color: Colors.grey,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Description
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4facfe).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          currentSign['description'],
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.5,
                            color: Color(0xFF2C3E50),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Progress Tracking
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
                        'Mark Your Progress',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4facfe),
                        ),
                      ),
                      const SizedBox(height: 15),
                      Column(
                        children: [
                          RadioListTile<String>(
                            title: const Text('Not Started'),
                            value: 'Not Started',
                            groupValue: currentProgress,
                            onChanged: (value) =>
                                _saveProgress(currentSign['name'], value!),
                            activeColor: const Color(0xFF4facfe),
                          ),
                          RadioListTile<String>(
                            title: const Text('Learning'),
                            value: 'Learning',
                            groupValue: currentProgress,
                            onChanged: (value) =>
                                _saveProgress(currentSign['name'], value!),
                            activeColor: const Color(0xFF4facfe),
                          ),
                          RadioListTile<String>(
                            title: const Text('Practiced'),
                            value: 'Practiced',
                            groupValue: currentProgress,
                            onChanged: (value) =>
                                _saveProgress(currentSign['name'], value!),
                            activeColor: const Color(0xFF4facfe),
                          ),
                          RadioListTile<String>(
                            title: const Text('Mastered'),
                            value: 'Mastered',
                            groupValue: currentProgress,
                            onChanged: (value) =>
                                _saveProgress(currentSign['name'], value!),
                            activeColor: const Color(0xFF4facfe),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Navigation Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _previousSign,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Previous'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4facfe),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _nextSign,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Next'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4facfe),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Progress Overview
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
                        'Your Progress Overview',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4facfe),
                        ),
                      ),
                      const SizedBox(height: 15),
                      ...signs.map((sign) {
                        final progress =
                            progressTracking[sign['name']] ?? 'Not Started';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  sign['name'],
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getProgressColor(
                                    progress,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  progress,
                                  style: TextStyle(
                                    color: _getProgressColor(progress),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getProgressColor(String progress) {
    switch (progress) {
      case 'Not Started':
        return Colors.grey;
      case 'Learning':
        return Colors.orange;
      case 'Practiced':
        return Colors.blue;
      case 'Mastered':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
