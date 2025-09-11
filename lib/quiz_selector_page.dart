import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'quiz_page.dart';

class QuizSelectorPage extends StatefulWidget {
  const QuizSelectorPage({super.key});

  @override
  State<QuizSelectorPage> createState() => _QuizSelectorPageState();
}

class _QuizSelectorPageState extends State<QuizSelectorPage> {
  List<Map<String, dynamic>> availableQuizzes = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchAvailableQuizzes();
  }

  Future<void> _fetchAvailableQuizzes() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final quizSnapshot = await FirebaseFirestore.instance
          .collection('quizzes')
          .where('isActive', isEqualTo: true)
          .get();

      final quizzes = quizSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'title': data['title'] as String,
          'description': data['description'] as String,
          'totalQuestions': data['totalQuestions'] as int,
          'quizType': data['quizType'] as String? ?? 'general',
          'difficulty': data['difficulty'] as String,
          'estimatedTime': data['estimatedTime'] as int,
        };
      }).toList();

      setState(() {
        availableQuizzes = quizzes;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load quizzes: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  void _startQuiz(String quizId, String quizTitle) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizPage(quizId: quizId, quizTitle: quizTitle),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
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
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF4facfe),
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Loading available quizzes...',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF4facfe),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
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

    if (errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Select Quiz'),
          backgroundColor: const Color(0xFF4facfe),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, Color(0xFFF8F9FA)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.red),
                  const SizedBox(height: 20),
                  Text(
                    errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: Colors.red),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _fetchAvailableQuizzes,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4facfe),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 15,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: const Text(
                      'Retry',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Quiz'),
        backgroundColor: const Color(0xFF4facfe),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Color(0xFFF8F9FA)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: availableQuizzes.length,
          itemBuilder: (context, index) {
            final quiz = availableQuizzes[index];
            return Card(
              elevation: 8,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: InkWell(
                onTap: () => _startQuiz(quiz['id'], quiz['title']),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: quiz['quizType'] == 'asl'
                                  ? Colors.blue[100]
                                  : Colors.green[100],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              quiz['quizType'] == 'asl' ? 'ASL' : 'General',
                              style: TextStyle(
                                color: quiz['quizType'] == 'asl'
                                    ? Colors.blue[800]
                                    : Colors.green[800],
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${quiz['totalQuestions']} questions',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        quiz['title'],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2D3748),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        quiz['description'],
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 16,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${quiz['estimatedTime']} min',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Icon(
                            Icons.bar_chart,
                            size: 16,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            quiz['difficulty'],
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
