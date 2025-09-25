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
  List<bool> answersChecked = [];
  List<bool> answersCorrect = [];

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
        quizSnapshot = await FirebaseFirestore.instance
            .collection('quizzes')
            .where(FieldPath.documentId, isEqualTo: widget.quizId)
            .limit(1)
            .get();
      } else {
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
      final qs = await quizDoc.reference
          .collection('questions')
          .where('isActive', isEqualTo: true)
          .get();

      final fetched = qs.docs.map((d) {
        final data = d.data();
        return {
          'id': d.id,
          'question': data['question'] as String? ?? '',
          'options': List<String>.from(data['options'] as List? ?? []),
          'correctAnswer': data['correctAnswer'] as int? ?? 0,
          'hasImage': data['hasImage'] as bool? ?? false,
          'imageUrl': data['imageUrl'] as String?,
          'category': data['category'] as String? ?? 'General',
          'difficulty': data['difficulty'] as int? ?? 1,
        };
      }).toList();

      fetched.shuffle();

      setState(() {
        questions = fetched;
        selectedAnswers = List.filled(questions.length, null);
        answersChecked = List.filled(questions.length, false);
        answersCorrect = List.filled(questions.length, false);
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load questions: $e';
        isLoading = false;
      });
    }
  }

  void _selectAnswer(int idx) {
    if (answersChecked.isNotEmpty &&
        answersChecked[currentQuestionIndex]) return;
    setState(() {
      selectedAnswers[currentQuestionIndex] = idx;
    });
  }

  void _checkAnswer() {
    final sel = selectedAnswers[currentQuestionIndex];
    if (sel == null) return;
    final correct = questions[currentQuestionIndex]['correctAnswer'] as int;
    final isCorrect = sel == correct;
    setState(() {
      answersChecked[currentQuestionIndex] = true;
      answersCorrect[currentQuestionIndex] = isCorrect;
      if (isCorrect) score++;
    });
  }

  Future<void> _saveQuizScore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final total = questions.length;
      final percentage = total > 0 ? ((score / total) * 100).round() : 0;
      final quizScore = {
        'userId': user.uid,
        'userName': user.displayName ?? 'Anonymous User',
        'userEmail': user.email ?? '',
        'quizId': widget.quizId ?? 'general_quiz',
        'quizTitle': widget.quizTitle ?? 'Practice Quiz',
        'score': score,
        'totalQuestions': total,
        'percentage': percentage,
        'timestamp': FieldValue.serverTimestamp(),
        'date': DateTime.now().toIso8601String().split('T')[0],
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('quizScores')
          .add(quizScore);

      await FirebaseFirestore.instance.collection('leaderboard').add(quizScore);

      await FirebaseFirestore.instance.collection('activities').add({
        'userId': user.uid,
        'type': 'quiz_completed',
        'title': 'Completed quiz: ${widget.quizTitle ?? 'Practice Quiz'}',
        'subtitle': 'Scored $percentage%',
        'timestamp': FieldValue.serverTimestamp(),
        'data': quizScore,
      });
    } catch (e) {
      // minimal logging
      print('Error saving score: $e');
    }
  }

  void _nextQuestion() {
    if (currentQuestionIndex < questions.length - 1) {
      setState(() => currentQuestionIndex++);
    } else {
      _finishQuiz();
    }
  }

  void _previousQuestion() {
    if (currentQuestionIndex > 0) {
      setState(() => currentQuestionIndex--);
    }
  }

  void _finishQuiz() async {
    await _saveQuizScore();
    setState(() {
      showResults = true;
    });
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

  Color _optionBg(int index) {
    if (!answersChecked[currentQuestionIndex]) {
      return selectedAnswers[currentQuestionIndex] == index
          ? const Color(0xFF1976D2)
          : Colors.white;
    }
    final correct = questions[currentQuestionIndex]['correctAnswer'] as int;
    if (index == correct) return Colors.green[50]!;
    if (selectedAnswers[currentQuestionIndex] == index) return Colors.red[50]!;
    return Colors.white;
  }

  Color _optionBorder(int index) {
    if (!answersChecked[currentQuestionIndex]) {
      return selectedAnswers[currentQuestionIndex] == index
          ? const Color(0xFF1976D2)
          : Colors.grey.shade200;
    }
    final correct = questions[currentQuestionIndex]['correctAnswer'] as int;
    if (index == correct) return Colors.green;
    if (selectedAnswers[currentQuestionIndex] == index) return Colors.red;
    return Colors.grey.shade200;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Practice Quiz'), backgroundColor: const Color(0xFF1976D2)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Practice Quiz'), backgroundColor: const Color(0xFF1976D2)),
        body: Center(child: Text(errorMessage!)),
      );
    }

    if (questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Practice Quiz'), backgroundColor: const Color(0xFF1976D2)),
        body: const Center(child: Text('No questions available')),
      );
    }

    if (showResults) {
      final total = questions.length;
      final percent = total > 0 ? ((score / total) * 100).round() : 0;
      return Scaffold(
        appBar: AppBar(title: const Text('Results'), backgroundColor: const Color(0xFF1976D2)),
        body: Center(
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Quiz Complete', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                Text('Score: $score / $total'),
                const SizedBox(height: 8),
                Text('$percent%'),
                const SizedBox(height: 16),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  ElevatedButton(onPressed: _resetQuiz, child: const Text('Retake')),
                  const SizedBox(width: 12),
                  OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
                ])
              ]),
            ),
          ),
        ),
      );
    }

    final current = questions[currentQuestionIndex];
    final options = current['options'] as List<String>;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.quizTitle ?? 'Practice Quiz'),
        backgroundColor: const Color(0xFF1976D2),
        actions: [Padding(padding: const EdgeInsets.all(12), child: Center(child: Text('Score: $score')))],
      ),
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Question ${currentQuestionIndex + 1} of ${questions.length}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(current['question'] as String, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
            const SizedBox(height: 18),
            ...List.generate(options.length, (i) {
              final bg = _optionBg(i);
              final border = _optionBorder(i);
              final selected = selectedAnswers[currentQuestionIndex] == i;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: answersChecked[currentQuestionIndex] ? null : () => _selectAnswer(i),
                  child: Container(
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: border),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    child: Row(children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: selected ? const Color(0xFF4facfe) : Colors.white,
                        child: Text(String.fromCharCode(65 + i), style: TextStyle(color: selected ? Colors.white : Colors.black)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(options[i], style: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w500))),
                    ]),
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
            if (answersChecked[currentQuestionIndex]) ...[
              Card(
                color: answersCorrect[currentQuestionIndex] ? Colors.green[50] : Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    answersCorrect[currentQuestionIndex]
                        ? 'Correct'
                        : 'Incorrect — correct: ${options[current['correctAnswer'] as int]}',
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: currentQuestionIndex > 0 ? _previousQuestion : null,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Previous'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: selectedAnswers[currentQuestionIndex] != null && !answersChecked[currentQuestionIndex]
                    ? ElevatedButton.icon(onPressed: _checkAnswer, icon: const Icon(Icons.visibility), label: const Text('Check Answer'))
                    : answersChecked[currentQuestionIndex]
                        ? ElevatedButton.icon(onPressed: _nextQuestion, icon: const Icon(Icons.arrow_forward), label: Text(currentQuestionIndex < questions.length - 1 ? 'Next' : 'Finish'))
                        : ElevatedButton.icon(onPressed: null, icon: const Icon(Icons.arrow_forward), label: const Text('Next')),
              ),
            ]),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: (currentQuestionIndex + 1) / questions.length),
            const SizedBox(height: 8),
            Center(child: Text('${currentQuestionIndex + 1} of ${questions.length}')),
          ]),
        ),
      ),
    );
  }
}
