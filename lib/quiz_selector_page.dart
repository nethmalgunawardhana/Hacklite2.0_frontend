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
  List<Map<String, dynamic>> filteredQuizzes = [];
  bool isLoading = true;
  String? errorMessage;

  final TextEditingController _searchController = TextEditingController();
  String selectedType = 'all'; // 'all', 'asl', 'general'
  String selectedDifficulty = 'all'; // 'all', 'easy', 'medium', 'hard'

  @override
  void initState() {
    super.initState();
    _fetchAvailableQuizzes();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.removeListener(_applyFilters);
    _searchController.dispose();
    super.dispose();
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
          'title': (data['title'] ?? '') as String,
          'description': (data['description'] ?? '') as String,
          'totalQuestions': (data['totalQuestions'] ?? 0) as int,
          'quizType': (data['quizType'] ?? 'general') as String,
          'difficulty': (data['difficulty'] ?? 'unknown') as String,
          'estimatedTime': (data['estimatedTime'] ?? 0) as int,
        };
      }).toList();

      setState(() {
        availableQuizzes = quizzes;
        filteredQuizzes = List.from(quizzes);
        isLoading = false;
      });
      _applyFilters();
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load quizzes: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      filteredQuizzes = availableQuizzes.where((q) {
        final matchesSearch = q['title'].toString().toLowerCase().contains(query) ||
            q['description'].toString().toLowerCase().contains(query);
        final matchesType = selectedType == 'all' || q['quizType'] == selectedType;
        final matchesDifficulty = selectedDifficulty == 'all' || q['difficulty'] == selectedDifficulty;
        return matchesSearch && matchesType && matchesDifficulty;
      }).toList();
    });
  }

  void _startQuiz(String quizId, String quizTitle) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizPage(quizId: quizId, quizTitle: quizTitle),
      ),
    );
  }

  Widget _buildTopBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 8),
              const Text(
                'Choose a Quiz',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              CircleAvatar(
                backgroundColor: Colors.white24,
                child: const Icon(Icons.school, color: Colors.white),
              )
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search quizzes...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.9)),
              prefixIcon: const Icon(Icons.search, color: Colors.white70),
              filled: true,
              fillColor: Colors.white.withOpacity(0.12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', 'all', selectedType == 'all', onSelectedType: true),
                const SizedBox(width: 8),
                _buildFilterChip('ASL', 'asl', selectedType == 'asl', onSelectedType: true),
                const SizedBox(width: 8),
                _buildFilterChip('General', 'general', selectedType == 'general', onSelectedType: true),
                const SizedBox(width: 12),
                _buildFilterChip('Any difficulty', 'all', selectedDifficulty == 'all', onSelectedType: false),
                const SizedBox(width: 8),
                _buildFilterChip('Easy', 'easy', selectedDifficulty == 'easy', onSelectedType: false),
                const SizedBox(width: 8),
                _buildFilterChip('Medium', 'medium', selectedDifficulty == 'medium', onSelectedType: false),
                const SizedBox(width: 8),
                _buildFilterChip('Hard', 'hard', selectedDifficulty == 'hard', onSelectedType: false),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, bool selected, {required bool onSelectedType}) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() {
          if (onSelectedType) {
            selectedType = value;
          } else {
            selectedDifficulty = value;
          }
        });
        _applyFilters();
      },
      selectedColor: Colors.white,
      backgroundColor: Colors.white24,
      labelStyle: TextStyle(color: selected ? Colors.blueGrey[900] : Colors.white),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Loading full-screen with gradient
    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
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
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    SizedBox(
                      width: 64,
                      height: 64,
                      child: CircularProgressIndicator(
                        strokeWidth: 6,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1976D2)),
                      ),
                    ),
                    SizedBox(height: 18),
                    Text(
                      'Loading available quizzes...',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF1976D2),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 40,
              left: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
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
          backgroundColor: const Color(0xFF1976D2),
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
                      backgroundColor: const Color(0xFF1976D2),
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
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBanner(context),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchAvailableQuizzes,
                color: const Color(0xFF1976D2),
                child: filteredQuizzes.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 60),
                          Center(
                            child: Column(
                              children: [
                                Container(
                                  width: 140,
                                  height: 140,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFe3f2fd), Color(0xFFd0f0ff)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.search_off, size: 64, color: Color(0xFF1976D2)),
                                ),
                                const SizedBox(height: 18),
                                const Text(
                                  'No quizzes found',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF2D3748)),
                                ),
                                const SizedBox(height: 8),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 36),
                                  child: Text(
                                    'Try a different search term or reset filters to view available quizzes.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      _searchController.clear();
                                      selectedType = 'all';
                                      selectedDifficulty = 'all';
                                    });
                                    _applyFilters();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1976D2),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  ),
                                  child: const Text('Reset Filters'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                        itemCount: filteredQuizzes.length,
                        itemBuilder: (context, index) {
                          final quiz = filteredQuizzes[index];
                          final isASL = quiz['quizType'] == 'asl';
                          final accent = isASL ? const Color(0xFF1976D2) : const Color(0xFF48C78E);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Material(
                              color: Colors.white,
                              elevation: 6,
                              shadowColor: Colors.black.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _startQuiz(quiz['id'], quiz['title']),
                                child: Row(
                                  children: [
                                    // accent stripe
                                    Container(
                                      width: 8,
                                      height: 120,
                                      decoration: BoxDecoration(
                                        color: accent,
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(16),
                                          bottomLeft: Radius.circular(16),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.all(14),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: accent.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  child: Icon(
                                                    isASL ? Icons.pan_tool : Icons.quiz,
                                                    color: accent,
                                                    size: 20,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    quiz['title'],
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w700,
                                                      color: Color(0xFF2D3748),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black.withOpacity(0.06),
                                                    borderRadius: BorderRadius.circular(20),
                                                  ),
                                                  child: Text(
                                                    '${quiz['totalQuestions']} Q',
                                                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              quiz['description'],
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(color: Colors.grey, fontSize: 13),
                                            ),
                                            const SizedBox(height: 12),
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black.withOpacity(0.04),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      const Icon(Icons.access_time, size: 14, color: Colors.grey),
                                                      const SizedBox(width: 6),
                                                      Text('${quiz['estimatedTime']} min', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black.withOpacity(0.04),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Text(
                                                    quiz['difficulty'].toString().toUpperCase(),
                                                    style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600),
                                                  ),
                                                ),
                                                const Spacer(),
                                                ElevatedButton(
                                                  onPressed: () => _startQuiz(quiz['id'], quiz['title']),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: accent,
                                                    elevation: 0,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                  ),
                                                  child: const Padding(
                                                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                    child: Text('Start', style: TextStyle(fontWeight: FontWeight.w700)),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
