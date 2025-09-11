import 'dart:collection';

/// Advanced word recognition for common ASL words and phrases
class WordRecognizer {
  // Common ASL words dictionary
  static const Map<String, List<String>> aslWords = {
    // Greetings
    'HELLO': ['H', 'E', 'L', 'L', 'O'],
    'HI': ['H', 'I'],
    'BYE': ['B', 'Y', 'E'],
    'GOODBYE': ['G', 'O', 'O', 'D', 'B', 'Y', 'E'],

    // Common words
    'YES': ['Y', 'E', 'S'],
    'NO': ['N', 'O'],
    'PLEASE': ['P', 'L', 'E', 'A', 'S', 'E'],
    'THANK': ['T', 'H', 'A', 'N', 'K'],
    'YOU': ['Y', 'O', 'U'],
    'SORRY': ['S', 'O', 'R', 'R', 'Y'],
    'HELP': ['H', 'E', 'L', 'P'],
    'LOVE': ['L', 'O', 'V', 'E'],
    'GOOD': ['G', 'O', 'O', 'D'],
    'BAD': ['B', 'A', 'D'],
    'NICE': ['N', 'I', 'C', 'E'],

    // Questions
    'WHAT': ['W', 'H', 'A', 'T'],
    'WHERE': ['W', 'H', 'E', 'R', 'E'],
    'WHEN': ['W', 'H', 'E', 'N'],
    'WHO': ['W', 'H', 'O'],
    'WHY': ['W', 'H', 'Y'],
    'HOW': ['H', 'O', 'W'],

    // Family
    'MOM': ['M', 'O', 'M'],
    'DAD': ['D', 'A', 'D'],
    'FAMILY': ['F', 'A', 'M', 'I', 'L', 'Y'],
    'FRIEND': ['F', 'R', 'I', 'E', 'N', 'D'],

    // Common phrases
    'I LOVE YOU': ['I', 'L', 'O', 'V', 'E', 'Y', 'O', 'U'],
    'THANK YOU': ['T', 'H', 'A', 'N', 'K', 'Y', 'O', 'U'],
    'HOW ARE YOU': ['H', 'O', 'W', 'A', 'R', 'E', 'Y', 'O', 'U'],
  };

  // Letter sequence tracking
  final Queue<String> _letterSequence = Queue<String>();
  static const int maxSequenceLength = 15;
  static const Duration wordTimeout = Duration(seconds: 8);
  DateTime? _lastLetterTime;

  // Recognition state
  String _currentWord = '';
  double _wordConfidence = 0.0;
  List<String> _recognizedWords = [];

  /// Add a new letter to the sequence
  Map<String, dynamic>? addLetter(String letter) {
    final now = DateTime.now();

    // Check for timeout - start new sequence if too much time passed
    if (_lastLetterTime != null &&
        now.difference(_lastLetterTime!) > wordTimeout) {
      _startNewSequence();
    }

    // Add letter to sequence
    _letterSequence.add(letter);
    _lastLetterTime = now;

    // Limit sequence length
    if (_letterSequence.length > maxSequenceLength) {
      _letterSequence.removeFirst();
    }

    // Try to recognize words
    final recognition = _recognizeWords();

    return recognition;
  }

  /// Recognize words from current letter sequence
  Map<String, dynamic>? _recognizeWords() {
    if (_letterSequence.isEmpty) return null;

    final sequence = _letterSequence.toList();
    String? bestMatch;
    double bestScore = 0.0;
    List<String> possibleWords = [];

    // Check all known words
    aslWords.forEach((word, letters) {
      final score = _calculateMatchScore(sequence, letters);

      if (score > 0.7) {
        // Minimum match threshold
        possibleWords.add(word);

        if (score > bestScore) {
          bestScore = score;
          bestMatch = word;
        }
      }
    });

    // Check for complete word matches
    String? completeWord = _findCompleteWord(sequence);
    if (completeWord != null) {
      _recognizedWords.add(completeWord);
      _currentWord = completeWord;
      _wordConfidence = 1.0;

      return {
        'type': 'complete_word',
        'word': completeWord,
        'confidence': 1.0,
        'sequence': sequence.join(''),
        'possibleWords': possibleWords,
      };
    }

    // Return partial match if found
    if (bestMatch != null) {
      _currentWord = bestMatch!;
      _wordConfidence = bestScore;

      return {
        'type': 'partial_word',
        'word': bestMatch,
        'confidence': bestScore,
        'sequence': sequence.join(''),
        'possibleWords': possibleWords,
        'progress': _calculateProgress(sequence, aslWords[bestMatch]!),
      };
    }

    return null;
  }

  /// Calculate match score between sequence and target word
  double _calculateMatchScore(List<String> sequence, List<String> target) {
    if (sequence.isEmpty || target.isEmpty) return 0.0;

    // Check if sequence is a prefix of target
    if (sequence.length <= target.length) {
      int matches = 0;
      for (int i = 0; i < sequence.length; i++) {
        if (sequence[i] == target[i]) {
          matches++;
        }
      }
      return matches / sequence.length;
    }

    // Check if target is contained in sequence (with some flexibility)
    return _findBestSubsequenceMatch(sequence, target);
  }

  /// Find best subsequence match
  double _findBestSubsequenceMatch(List<String> sequence, List<String> target) {
    double bestScore = 0.0;

    // Try different starting positions in the sequence
    for (int start = 0; start <= sequence.length - target.length; start++) {
      int matches = 0;
      for (int i = 0; i < target.length; i++) {
        if (start + i < sequence.length && sequence[start + i] == target[i]) {
          matches++;
        }
      }
      double score = matches / target.length;
      if (score > bestScore) {
        bestScore = score;
      }
    }

    return bestScore;
  }

  /// Find complete word match
  String? _findCompleteWord(List<String> sequence) {
    final sequenceString = sequence.join('');

    // Check for exact matches
    for (final entry in aslWords.entries) {
      final word = entry.key;
      final letters = entry.value;
      final wordString = letters.join('');

      if (sequenceString.endsWith(wordString)) {
        return word;
      }
    }

    return null;
  }

  /// Calculate progress towards completing a word
  double _calculateProgress(List<String> sequence, List<String> target) {
    if (target.isEmpty) return 0.0;

    int matchedLetters = 0;
    for (int i = 0; i < sequence.length && i < target.length; i++) {
      if (sequence[i] == target[i]) {
        matchedLetters++;
      } else {
        break; // Stop at first mismatch
      }
    }

    return matchedLetters / target.length;
  }

  /// Start a new letter sequence
  void _startNewSequence() {
    _letterSequence.clear();
    _currentWord = '';
    _wordConfidence = 0.0;
  }

  /// Get current letter sequence
  String get currentSequence => _letterSequence.join('');

  /// Get current word being formed
  String get currentWord => _currentWord;

  /// Get current word confidence
  double get wordConfidence => _wordConfidence;

  /// Get recognized words
  List<String> get recognizedWords => List.from(_recognizedWords);

  /// Get possible completions for current sequence
  List<String> getPossibleCompletions() {
    if (_letterSequence.isEmpty) return [];

    final sequence = _letterSequence.toList();
    List<String> completions = [];

    aslWords.forEach((word, letters) {
      if (_calculateMatchScore(sequence, letters) > 0.5) {
        completions.add(word);
      }
    });

    return completions;
  }

  /// Get recognition statistics
  Map<String, dynamic> getStatistics() {
    return {
      'currentSequence': currentSequence,
      'currentWord': _currentWord,
      'wordConfidence': _wordConfidence,
      'recognizedWords': _recognizedWords,
      'sequenceLength': _letterSequence.length,
      'knownWords': aslWords.keys.length,
      'lastLetterTime': _lastLetterTime?.toIso8601String(),
    };
  }

  /// Clear all recognition data
  void reset() {
    _letterSequence.clear();
    _currentWord = '';
    _wordConfidence = 0.0;
    _recognizedWords.clear();
    _lastLetterTime = null;
  }

  /// Force word completion (user confirmation)
  void confirmCurrentWord() {
    if (_currentWord.isNotEmpty) {
      _recognizedWords.add(_currentWord);
      _startNewSequence();
    }
  }
}
