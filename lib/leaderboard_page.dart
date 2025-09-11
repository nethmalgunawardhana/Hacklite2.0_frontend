import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
            'userName': data['userName'],
            'userEmail': data['userEmail'],
            'quizId': data['quizId'],
            'quizTitle': data['quizTitle'],
            'score': data['score'],
            'totalQuestions': data['totalQuestions'],
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
        backgroundColor: const Color(0xFF4facfe),
        actions: [
          PopupMenuButton<String>(
            onSelected: _changeTimeframe,
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'all',
                child: Text('All Time'),
              ),
              const PopupMenuItem<String>(
                value: 'month',
                child: Text('This Month'),
              ),
              const PopupMenuItem<String>(
                value: 'week',
                child: Text('This Week'),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    selectedTimeframe == 'all'
                        ? 'All Time'
                        : selectedTimeframe == 'month'
                        ? 'This Month'
                        : 'This Week',
                    style: const TextStyle(color: Colors.white),
                  ),
                  const Icon(Icons.arrow_drop_down, color: Colors.white),
                ],
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
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
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
              'Loading leaderboard...',
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
                onPressed: _fetchLeaderboardData,
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
      );
    }

    if (leaderboardData.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.leaderboard, size: 80, color: Colors.grey),
            SizedBox(height: 20),
            Text(
              'No quiz scores yet.\nBe the first to take a quiz!',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: leaderboardData.length,
      itemBuilder: (context, index) {
        final entry = leaderboardData[index];
        final isCurrentUser =
            entry['userId'] == FirebaseAuth.instance.currentUser?.uid;

        return Card(
          elevation: 4,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: isCurrentUser
                  ? const LinearGradient(
                      colors: [Color(0xFF4facfe), Color(0xFF00f2fe)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                  : null,
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: _getRankColor(index),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              title: Text(
                entry['userName'] as String,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isCurrentUser ? Colors.white : Colors.black87,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${entry['score']}/${entry['totalQuestions']} correct',
                    style: TextStyle(
                      color: isCurrentUser ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
                  Text(
                    entry['quizTitle'] as String,
                    style: TextStyle(
                      color: isCurrentUser ? Colors.white70 : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isCurrentUser
                      ? Colors.white24
                      : Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${entry['percentage']}%',
                  style: TextStyle(
                    color: isCurrentUser ? Colors.white : Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getRankColor(int index) {
    if (index == 0) return Colors.amber; // Gold
    if (index == 1) return Colors.grey; // Silver
    if (index == 2) return Colors.brown; // Bronze
    return const Color(0xFF4facfe); // Blue for others
  }
}
