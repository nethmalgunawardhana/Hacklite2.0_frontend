import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class QuizPage extends StatefulWidget {
  final String? quizId;
  final String? quizTitle;

  const QuizPage({super.key, this.quizId, this.quizTitle});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  List<Map<String, dynamic>> questions = [];
  bool isLoading = true;
  String? errorMessage;
  int currentQuestionIndex = 0;
  int score = 0;
  List<int?> selectedAnswers = [];
  bool showResults = false;
  List<bool> answersChecked =
      []; // Track if answer has been checked for each question
  List<bool> answersCorrect = []; // Track if the selected answer is correct

  @override
  void initState() {
    super.initState();
    _fetchQuestions();
  }

  Future<void> _fetchQuestions() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      QuerySnapshot quizSnapshot;

      if (widget.quizId != null) {
        // Load specific quiz by ID
        quizSnapshot = await FirebaseFirestore.instance
            .collection('quizzes')
            .where(FieldPath.documentId, isEqualTo: widget.quizId)
            .limit(1)
            .get();
      } else {
        // Get ASL quiz specifically (fallback)
        quizSnapshot = await FirebaseFirestore.instance
            .collection('quizzes')
            .where('isActive', isEqualTo: true)
            .where('quizType', isEqualTo: 'asl')
            .limit(1)
            .get();
      }

      if (quizSnapshot.docs.isEmpty) {
        setState(() {
          errorMessage = 'No active quiz found. Please try again later.';
          isLoading = false;
        });
        return;
      }

      final quizDoc = quizSnapshot.docs.first;
      final questionsSnapshot = await quizDoc.reference
          .collection('questions')
          .where('isActive', isEqualTo: true)
          .get();

      final fetchedQuestions = questionsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'question': data['question'] as String,
          'options': List<String>.from(data['options'] as List),
          'correctAnswer': data['correctAnswer'] as int,
          'hasImage': data['hasImage'] as bool? ?? false,
          'imageUrl': data['imageUrl'] as String?,
          'category': data['category'] as String? ?? 'General',
          'difficulty': data['difficulty'] as int? ?? 1,
        };
      }).toList();

      // Shuffle questions for random order
      fetchedQuestions.shuffle();

      setState(() {
        questions = fetchedQuestions;
        selectedAnswers = List.filled(questions.length, null);
        answersChecked = List.filled(questions.length, false);
        answersCorrect = List.filled(questions.length, false);
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load questions: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  void _selectAnswer(int answerIndex) {
    setState(() {
      selectedAnswers[currentQuestionIndex] = answerIndex;
    });
  }

  void _nextQuestion() {
    if (currentQuestionIndex < questions.length - 1) {
      setState(() {
        currentQuestionIndex++;
      });
    } else {
      _showResults();
    }
  }

  void _previousQuestion() {
    if (currentQuestionIndex > 0) {
      setState(() {
        currentQuestionIndex--;
      });
    }
  }

  void _showResults() async {
    // Save score to Firestore before showing results
    await _saveQuizScore();
    setState(() {
      showResults = true;
    });
  }

  Future<void> _saveQuizScore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final quizScore = {
        'userId': user.uid,
        'userName': user.displayName ?? 'Anonymous User',
        'userEmail': user.email ?? '',
        'quizId': widget.quizId ?? 'general_quiz',
        'quizTitle': widget.quizTitle ?? 'Practice Quiz',
        'score': score,
        'totalQuestions': questions.length,
        'percentage': (score / questions.length * 100).round(),
        'timestamp': FieldValue.serverTimestamp(),
        'date': DateTime.now().toIso8601String().split(
          'T',
        )[0], // YYYY-MM-DD format
      };

      // Save to user's quiz scores collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('quizScores')
          .add(quizScore);

      // Also save to global leaderboard collection
      await FirebaseFirestore.instance.collection('leaderboard').add(quizScore);

      // Log activity for recent activities
      await FirebaseFirestore.instance.collection('activities').add({
        'userId': user.uid,
        'type': 'quiz_completed',
        'title': 'Completed quiz: ${widget.quizTitle ?? 'Practice Quiz'}',
        'subtitle': 'Scored ${(score / questions.length * 100).round()}%',
        'timestamp': FieldValue.serverTimestamp(),
        'data': {
          'quizTitle': widget.quizTitle ?? 'Practice Quiz',
          'score': score,
          'percentage': (score / questions.length * 100).round(),
        },
      });

      print('Quiz score saved successfully');
    } catch (e) {
      print('Error saving quiz score: $e');
    }
  }

  void _checkAnswer() {
    if (selectedAnswers[currentQuestionIndex] != null) {
      final isCorrect =
          selectedAnswers[currentQuestionIndex] ==
          questions[currentQuestionIndex]['correctAnswer'];
      setState(() {
        answersChecked[currentQuestionIndex] = true;
        answersCorrect[currentQuestionIndex] = isCorrect;
        if (isCorrect) {
          score++;
        }
      });
    }
  }

  void _resetQuiz() {
    setState(() {
      currentQuestionIndex = 0;
      score = 0;
      selectedAnswers = List.filled(questions.length, null);
      answersChecked = List.filled(questions.length, false);
      answersCorrect = List.filled(questions.length, false);
      showResults = false;
    });
  }

  Color _getOptionColor(int index) {
    if (!answersChecked[currentQuestionIndex]) {
      // Before checking - show selection state
      return selectedAnswers[currentQuestionIndex] == index
          ? const Color(0xFF4facfe)
          : Colors.grey[300]!;
    } else {
      // After checking - show correct/incorrect state
      final correctIndex =
          questions[currentQuestionIndex]['correctAnswer'] as int;
      if (index == correctIndex) {
        return Colors.green[600]!;
      } else if (selectedAnswers[currentQuestionIndex] == index) {
        return Colors.red[600]!;
      } else {
        return Colors.grey[300]!;
      }
    }
  }

  Widget _getOptionIcon(int index) {
    if (!answersChecked[currentQuestionIndex]) {
      // Before checking
      if (selectedAnswers[currentQuestionIndex] == index) {
        return const Icon(Icons.check, color: Colors.white, size: 20);
      } else {
        return Center(
          child: Text(
            String.fromCharCode(65 + index), // A, B, C, D
            style: TextStyle(
              color: selectedAnswers[currentQuestionIndex] == index
                  ? Colors.white
                  : Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }
    } else {
      // After checking
      final correctIndex =
          questions[currentQuestionIndex]['correctAnswer'] as int;
      if (index == correctIndex) {
        return const Icon(Icons.check_circle, color: Colors.white, size: 20);
      } else if (selectedAnswers[currentQuestionIndex] == index) {
        return const Icon(Icons.cancel, color: Colors.white, size: 20);
      } else {
        return Center(
          child: Text(
            String.fromCharCode(65 + index),
            style: const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }
    }
  }

  Color _getOptionTextColor(int index) {
    if (!answersChecked[currentQuestionIndex]) {
      return selectedAnswers[currentQuestionIndex] == index
          ? const Color(0xFF4facfe)
          : Colors.black87;
    } else {
      final correctIndex =
          questions[currentQuestionIndex]['correctAnswer'] as int;
      if (index == correctIndex) {
        return Colors.green[800]!;
      } else if (selectedAnswers[currentQuestionIndex] == index) {
        return Colors.red[800]!;
      } else {
        return Colors.grey[600]!;
      }
    }
  }

  FontWeight _getOptionFontWeight(int index) {
    if (!answersChecked[currentQuestionIndex]) {
      return selectedAnswers[currentQuestionIndex] == index
          ? FontWeight.w600
          : FontWeight.normal;
    } else {
      final correctIndex =
          questions[currentQuestionIndex]['correctAnswer'] as int;
      if (index == correctIndex ||
          selectedAnswers[currentQuestionIndex] == index) {
        return FontWeight.w600;
      } else {
        return FontWeight.normal;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading state
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Practice Quiz'),
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
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4facfe)),
                ),
                SizedBox(height: 20),
                Text(
                  'Loading quiz questions...',
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
      );
    }

    // Show error state
    if (errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Practice Quiz'),
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
                  const Icon(Icons.error_outline, size: 80, color: Colors.red),
                  const SizedBox(height: 20),
                  Text(
                    errorMessage!,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    onPressed: _fetchQuestions,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
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
            ),
          ),
        ),
      );
    }

    // Show empty state if no questions
    if (questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Practice Quiz'),
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
          child: const Center(
            child: Text(
              'No questions available at the moment.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ),
        ),
      );
    }

    if (showResults) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Quiz Results'),
          backgroundColor: const Color(0xFF4facfe),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4facfe), Color(0xFF00f2fe)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Center(
            child: Card(
              margin: const EdgeInsets.all(20),
              elevation: 10,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.celebration,
                      size: 80,
                      color: Color(0xFF4facfe),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Quiz Complete!',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF4facfe),
                          ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Your Score: $score/${questions.length}',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${(score / questions.length * 100).round()}% Correct',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _resetQuiz,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retake Quiz'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4facfe),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.home),
                          label: const Text('Back to Dashboard'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[600],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final currentQuestion = questions[currentQuestionIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.quizTitle ??
              'Practice Quiz (${currentQuestionIndex + 1}/${questions.length})',
        ),
        backgroundColor: const Color(0xFF4facfe),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                'Score: $score',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Question Card
              Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (currentQuestion['hasImage'] &&
                          currentQuestion['imageUrl'] != null) ...[
                        Container(
                          height: 250,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              currentQuestion['imageUrl'],
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[200],
                                  child: const Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.broken_image,
                                          size: 60,
                                          color: Colors.grey,
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'Image not found',
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      Text(
                        currentQuestion['question'],
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF2D3748),
                            ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Options
              ...List.generate(
                currentQuestion['options'].length,
                (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    child: Card(
                      elevation: selectedAnswers[currentQuestionIndex] == index
                          ? 8
                          : 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: selectedAnswers[currentQuestionIndex] == index
                              ? const Color(0xFF4facfe)
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: InkWell(
                        onTap: answersChecked[currentQuestionIndex]
                            ? null // Disable selection after checking
                            : () => _selectAnswer(index),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _getOptionColor(index),
                                ),
                                child: _getOptionIcon(index),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  currentQuestion['options'][index],
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: _getOptionTextColor(index),
                                    fontWeight: _getOptionFontWeight(index),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Answer Feedback (shown after checking)
              if (answersChecked[currentQuestionIndex]) ...[
                Card(
                  elevation: 4,
                  color: answersCorrect[currentQuestionIndex]
                      ? Colors.green[50]
                      : Colors.red[50],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: answersCorrect[currentQuestionIndex]
                          ? Colors.green[300]!
                          : Colors.red[300]!,
                      width: 2,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              answersCorrect[currentQuestionIndex]
                                  ? Icons.check_circle
                                  : Icons.cancel,
                              color: answersCorrect[currentQuestionIndex]
                                  ? Colors.green[700]
                                  : Colors.red[700],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              answersCorrect[currentQuestionIndex]
                                  ? 'Correct!'
                                  : 'Incorrect',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: answersCorrect[currentQuestionIndex]
                                    ? Colors.green[700]
                                    : Colors.red[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Correct Answer: ${questions[currentQuestionIndex]['options'][questions[currentQuestionIndex]['correctAnswer']]}',
                          style: TextStyle(
                            fontSize: 16,
                            color: answersCorrect[currentQuestionIndex]
                                ? Colors.green[800]
                                : Colors.red[800],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Navigation Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (currentQuestionIndex > 0)
                    ElevatedButton.icon(
                      onPressed: _previousQuestion,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Previous'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 100),

                  // Check Answer Button (shown when answer selected but not checked)
                  if (selectedAnswers[currentQuestionIndex] != null &&
                      !answersChecked[currentQuestionIndex])
                    ElevatedButton.icon(
                      onPressed: _checkAnswer,
                      icon: const Icon(Icons.visibility),
                      label: const Text('Check Answer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFA726),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    )
                  else if (answersChecked[currentQuestionIndex])
                    // Next/Finish Button (shown after checking answer)
                    ElevatedButton.icon(
                      onPressed: _nextQuestion,
                      icon: currentQuestionIndex < questions.length - 1
                          ? const Icon(Icons.arrow_forward)
                          : const Icon(Icons.check),
                      label: Text(
                        currentQuestionIndex < questions.length - 1
                            ? 'Next Question'
                            : 'Finish Quiz',
                      ),
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
                    )
                  else
                    // Disabled Next Button (shown when no answer selected)
                    ElevatedButton.icon(
                      onPressed: null,
                      icon: currentQuestionIndex < questions.length - 1
                          ? const Icon(Icons.arrow_forward)
                          : const Icon(Icons.check),
                      label: Text(
                        currentQuestionIndex < questions.length - 1
                            ? 'Next'
                            : 'Finish Quiz',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[400],
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

              // Progress Indicator
              LinearProgressIndicator(
                value: (currentQuestionIndex + 1) / questions.length,
                backgroundColor: Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF4facfe),
                ),
              ),

              const SizedBox(height: 10),

              Center(
                child: Text(
                  '${currentQuestionIndex + 1} of ${questions.length} questions',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
