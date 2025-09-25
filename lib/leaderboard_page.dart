import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  List<Map<String, dynamic>> leaderboardData = [];
  bool isLoading = true;
  String? errorMessage;
  String selectedTimeframe = 'all'; // 'all', 'week', 'month'

  @override
  void initState() {
    super.initState();
    _fetchLeaderboardData();
  }

  Future<void> _fetchLeaderboardData() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      Query query = FirebaseFirestore.instance.collection('leaderboard');

      // Apply timeframe filter
      if (selectedTimeframe != 'all') {
        DateTime cutoffDate;
        if (selectedTimeframe == 'week') {
          cutoffDate = DateTime.now().subtract(const Duration(days: 7));
        } else {
          cutoffDate = DateTime.now().subtract(const Duration(days: 30));
        }
        query = query.where('timestamp', isGreaterThan: cutoffDate);
      }

      final snapshot = await query.orderBy('timestamp', descending: true).get();

      // Group by user and get their best scores
      Map<String, Map<String, dynamic>> userBestScores = {};

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final userId = data['userId'] as String?;
        final percentage = data['percentage'] as int?;

        if (userId == null || percentage == null) continue;

        if (!userBestScores.containsKey(userId) ||
            (userBestScores[userId]!['percentage'] as int) < percentage) {
          userBestScores[userId] = {
            'id': doc.id,
            'userId': data['userId'],
            'userName': data['userName'] ?? 'Unknown',
            'userEmail': data['userEmail'],
            'quizId': data['quizId'],
            'quizTitle': data['quizTitle'] ?? 'Quiz',
            'score': data['score'] ?? 0,
            'totalQuestions': data['totalQuestions'] ?? 0,
            'percentage': data['percentage'],
            'timestamp': data['timestamp'],
            'date': data['date'],
          };
        }
      }

      // Convert to list and sort by percentage
      final sortedData = userBestScores.values.toList()
        ..sort(
          (a, b) => (b['percentage'] as int).compareTo(a['percentage'] as int),
        );

      setState(() {
        leaderboardData = sortedData.take(50).toList(); // Top 50 players
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load leaderboard: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  void _changeTimeframe(String timeframe) {
    setState(() {
      selectedTimeframe = timeframe;
    });
    _fetchLeaderboardData();
  }

  @override
  Widget build(BuildContext context) {
    final toggleSelection = [
      selectedTimeframe == 'all',
      selectedTimeframe == 'month',
      selectedTimeframe == 'week'
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF6F9FF),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4facfe), Color(0xFF00f2fe)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Back button
                  Material(
                    color: Colors.white.withOpacity(0.12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Title
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '🏆 Leaderboard',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${leaderboardData.length} champions • Best scores',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Timeframe segmented control
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: ToggleButtons(
                      isSelected: toggleSelection,
                      onPressed: (i) {
                        final val = i == 0 ? 'all' : (i == 1 ? 'month' : 'week');
                        _changeTimeframe(val);
                      },
                      borderRadius: BorderRadius.circular(8),
                      selectedColor: Colors.blue.shade900,
                      color: Colors.white,
                      fillColor: Colors.white,
                      renderBorder: false,
                      constraints: const BoxConstraints(minWidth: 64, minHeight: 36),
                      children: const [
                        Text('All'),
                        Text('Month'),
                        Text('Week'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _buildBodyContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBodyContent() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4facfe)),
            ),
            SizedBox(height: 20),
            Text(
              'Loading champions...',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF4facfe),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 72, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                errorMessage!,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _fetchLeaderboardData,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4facfe),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (leaderboardData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.leaderboard,
                size: 56,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No quiz scores yet.\nBe the first champion!',
              style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Learning'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4facfe),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF4facfe),
      onRefresh: _fetchLeaderboardData,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: leaderboardData.length,
        itemBuilder: (context, index) {
          final entry = leaderboardData[index];
          final isCurrentUser = entry['userId'] == FirebaseAuth.instance.currentUser?.uid;

          final primaryColor = _getRankColor(index);
          final titleColor = isCurrentUser ? Colors.white : Colors.black87;
          final subtitleColor = isCurrentUser ? Colors.white70 : Colors.grey[700];

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: Material(
              borderRadius: BorderRadius.circular(14),
              elevation: isCurrentUser ? 6 : 2,
              color: isCurrentUser ? null : Colors.white,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {},
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: isCurrentUser
                        ? const LinearGradient(
                            colors: [Color(0xFF4facfe), Color(0xFF00f2fe)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          )
                        : index < 3
                            ? LinearGradient(
                                colors: [
                                  Colors.white,
                                  Colors.white.withOpacity(0.98),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              )
                            : null,
                    border: isCurrentUser
                        ? Border.all(color: Colors.white.withOpacity(0.16), width: 1)
                        : Border.all(color: Colors.grey.withOpacity(0.06)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Row(
                    children: [
                      // Rank avatar
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [primaryColor.withOpacity(0.95), primaryColor.withOpacity(0.7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.22),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Center(
                          child: index < 3
                              ? Icon(_getRankIcon(index), color: Colors.white, size: 20)
                              : Text(
                                  '${index + 1}',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Name + details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    entry['userName'] as String,
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: titleColor),
                                  ),
                                ),
                                if (isCurrentUser)
                                  Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.16),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'YOU',
                                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.quiz, size: 14, color: subtitleColor),
                                const SizedBox(width: 6),
                                Text(
                                  '${entry['score']}/${entry['totalQuestions']} correct',
                                  style: TextStyle(color: subtitleColor, fontSize: 13),
                                ),
                                const SizedBox(width: 12),
                                Icon(Icons.book, size: 14, color: subtitleColor),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    entry['quizTitle'] as String,
                                    style: TextStyle(color: subtitleColor, fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Percentage badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isCurrentUser ? Colors.white.withOpacity(0.16) : primaryColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: primaryColor.withOpacity(0.14)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${entry['percentage']}%',
                              style: TextStyle(color: isCurrentUser ? Colors.white : primaryColor, fontWeight: FontWeight.w800, fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text('score', style: TextStyle(color: isCurrentUser ? Colors.white70 : primaryColor.withOpacity(0.9), fontSize: 10)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getRankColor(int index) {
    if (index == 0) return Colors.amber; // Gold
    if (index == 1) return Colors.grey; // Silver
    if (index == 2) return Colors.brown; // Bronze
    return const Color(0xFF4facfe); // Blue for others
  }

  IconData _getRankIcon(int index) {
    if (index == 0) return Icons.emoji_events; // Gold trophy
    if (index == 1) return Icons.military_tech; // Silver medal
    if (index == 2) return Icons.workspace_premium; // Bronze medal
    return Icons.person; // Default icon for others
  }
}