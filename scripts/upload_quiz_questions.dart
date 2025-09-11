import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class QuizQuestion {
  final String question;
  final List<String> options;
  final int correctAnswer;
  final bool hasImage;
  final String? imageUrl;
  final String category;
  final int difficulty; // 1-5 scale

  QuizQuestion({
    required this.question,
    required this.options,
    required this.correctAnswer,
    this.hasImage = false,
    this.imageUrl,
    required this.category,
    required this.difficulty,
  });

  Map<String, dynamic> toMap() {
    return {
      'question': question,
      'options': options,
      'correctAnswer': correctAnswer,
      'hasImage': hasImage,
      'imageUrl': imageUrl,
      'category': category,
      'difficulty': difficulty,
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': true,
    };
  }
}

class FirebaseConfig {
  static const String apiKey = 'AIzaSyDmlUKgAnMmGe51K18V1FEpX37UY0ZdFrk';
  static const String projectId = 'hacklite-9c06e';
  static const String messagingSenderId = '940330317059';
  static const String appId = '1:940330317059:web:a1b2c3d4e5f6g7h8i9j0';

  static FirebaseOptions get webOptions => const FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: messagingSenderId,
        projectId: projectId,
        authDomain: '$projectId.firebaseapp.com',
        storageBucket: '$projectId.firebasestorage.app',
      );
}

Future<void> main() async {
  try {
    print('🚀 Initializing Firebase...');
    await Firebase.initializeApp(options: FirebaseConfig.webOptions);

    print('📝 Preparing quiz questions...');
    final questions = _getQuizQuestions();

    print('☁️ Uploading questions to Firestore...');
    await uploadQuestionsToFirestore(questions);

    print('✅ Quiz questions uploaded successfully!');
    print('📊 Total questions uploaded: ${questions.length}');
  } catch (e) {
    print('❌ Error: $e');
  }
}

List<QuizQuestion> _getQuizQuestions() {
  return [
    QuizQuestion(
      question:
          'Which communication method is most appropriate for someone who is both deaf and blind?',
      options: [
        'Lipreading',
        'Written notes',
        'Tactile sign language',
        'American Sign Language on video'
      ],
      correctAnswer: 2,
      category: 'Accessibility',
      difficulty: 3,
    ),
    QuizQuestion(
      question:
          'What is a common criticism of automated accessibility overlay tools?',
      options: [
        'They always required extensive manual auditing',
        'They replace the need for any compliance testing',
        'They mask underlying code issues without truly fixing accessibility barriers',
        'They increase page load speed dramatically.'
      ],
      correctAnswer: 2,
      category: 'Accessibility',
      difficulty: 4,
    ),
    QuizQuestion(
      question: 'What does ADA stands for?',
      options: [
        'Accessible Development Act',
        'Association for Disabled Access',
        'American Disability Association',
        'Americans with Disabilities Act'
      ],
      correctAnswer: 3,
      category: 'Legal',
      difficulty: 2,
    ),
    QuizQuestion(
      question:
          'For an employee with a cognitive disability, which accommodation might improve job performance?',
      options: [
        'Limiting access to written instruction',
        'Breaking tasks into smaller, sequential steps',
        'Removing all deadlines',
        'Assigning more complex responsibilities'
      ],
      correctAnswer: 1,
      category: 'Workplace',
      difficulty: 3,
    ),
    QuizQuestion(
      question:
          'Under the ADA, public entities are required to provide sign language interpreters for',
      options: [
        'Crucial communication between public services and individuals with hearing disabilities',
        'All social events held by a public entity',
        'Only emergency announcements',
        'Voluntary public meeting without official business'
      ],
      correctAnswer: 0,
      category: 'Legal',
      difficulty: 4,
    ),
    QuizQuestion(
      question: 'Which of the following is a hidden disability?',
      options: ['Amputation', 'Blindness', 'Spinal injury', 'Dyslexia'],
      correctAnswer: 3,
      category: 'Awareness',
      difficulty: 2,
    ),
    // Additional questions for variety
    QuizQuestion(
      question: 'What is the primary purpose of a screen reader?',
      options: [
        'To display images in higher resolution',
        'To convert text to speech for visually impaired users',
        'To automatically fix website accessibility issues',
        'To compress images for faster loading'
      ],
      correctAnswer: 1,
      category: 'Technology',
      difficulty: 2,
    ),
    QuizQuestion(
      question:
          'Which of these is considered a best practice for web accessibility?',
      options: [
        'Using only images for navigation',
        'Providing alternative text for images',
        'Using very small font sizes',
        'Relying only on color to convey information'
      ],
      correctAnswer: 1,
      category: 'Web Development',
      difficulty: 3,
    ),
    QuizQuestion(
      question: 'What does WCAG stand for?',
      options: [
        'Web Content Accessibility Guidelines',
        'Worldwide Communication Access Group',
        'Web Compliance and Accessibility Guide',
        'Wireless Communication Accessibility Guidelines'
      ],
      correctAnswer: 0,
      category: 'Standards',
      difficulty: 3,
    ),
    QuizQuestion(
      question: 'Which disability type might benefit most from captioning?',
      options: [
        'Mobility impairments',
        'Hearing impairments',
        'Cognitive disabilities',
        'Visual impairments'
      ],
      correctAnswer: 1,
      category: 'Media',
      difficulty: 2,
    ),
  ];
}

Future<void> uploadQuestionsToFirestore(List<QuizQuestion> questions) async {
  final firestore = FirebaseFirestore.instance;

  // Create a quiz document
  final quizRef = await firestore.collection('quizzes').add({
    'title': 'Accessibility and ASL Knowledge Quiz',
    'description':
        'Test your knowledge about accessibility, sign language, and disability awareness',
    'totalQuestions': questions.length,
    'categories': [
      'Accessibility',
      'Legal',
      'Workplace',
      'Awareness',
      'Technology',
      'Web Development',
      'Standards',
      'Media'
    ],
    'difficulty': 'Mixed',
    'estimatedTime': 10, // minutes
    'isActive': true,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  });

  print('📋 Created quiz document: ${quizRef.id}');

  // Upload questions as subcollection
  final batch = firestore.batch();
  int questionCount = 0;

  for (final question in questions) {
    final questionRef = quizRef.collection('questions').doc();
    batch.set(questionRef, question.toMap());
    questionCount++;

    // Commit batch every 10 questions to avoid hitting Firestore limits
    if (questionCount % 10 == 0) {
      await batch.commit();
      print('📤 Uploaded batch of 10 questions...');
      // Start new batch
    }
  }

  // Commit remaining questions
  if (questionCount % 10 != 0) {
    await batch.commit();
    print('📤 Uploaded final batch of questions...');
  }

  print('✅ All questions uploaded successfully!');
}
