import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About & Features'),
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
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: const [
            _Section(
              title: 'WaveWords',
              subtitle:
                  'An assistive sign-language learning and translation app powered by Firebase.',
              icon: Icons.handshake,
              color: Color(0xFF4facfe),
            ),
            SizedBox(height: 12),
            _FeatureCard(
              title: 'Authentication',
              details: [
                'Email/password sign-in and sign-up',
                'Secure session management via Firebase Auth',
                'User profile stored in Firestore',
              ],
              icon: Icons.lock_outline,
              color: Colors.blue,
            ),
            _FeatureCard(
              title: 'Dashboard',
              details: [
                'Quick actions: Camera, Quizzes, Practice, Goals, Leaderboard',
                'Daily goals progress with overall completion bar',
                'Quiz performance: total taken, average, best score',
                'Recent activity feed (quizzes, practice, goals, signs learned)',
              ],
              icon: Icons.dashboard,
              color: Colors.indigo,
            ),
            _FeatureCard(
              title: 'Camera (Translate)',
              details: [
                'Camera permission handling',
                'Live preview with start/stop controls',
                'Placeholder pipeline for future sign recognition',
              ],
              icon: Icons.camera_alt,
              color: Colors.purple,
            ),
            _FeatureCard(
              title: 'Quizzes',
              details: [
                'Dynamic quiz catalog from Firestore',
                'Per-question feedback and navigation',
                'Results screen and score persistence',
                'Scores stored under users/…/quizScores and global leaderboard',
              ],
              icon: Icons.quiz,
              color: Colors.orange,
            ),
            _FeatureCard(
              title: 'Sign Learning',
              details: [
                'Curated set of common signs with images',
                'Track status per sign: Not Started, Learning, Practiced, Mastered',
                'Practice session time logging',
                'Progress saved to Firestore and activities timeline',
              ],
              icon: Icons.sign_language,
              color: Colors.teal,
            ),
            _FeatureCard(
              title: 'Daily Goals',
              details: [
                'Set targets for signs, practice minutes, quiz count, target score',
                'Goals persisted to Firestore',
                'Activity logged when goals updated',
              ],
              icon: Icons.flag,
              color: Colors.green,
            ),
            _FeatureCard(
              title: 'History',
              details: [
                'Searchable list with filters (Today, Favorites)',
                'Mock data layer ready for wiring actual translations',
                'Favorite, share, delete interactions',
              ],
              icon: Icons.history,
              color: Colors.brown,
            ),
            _FeatureCard(
              title: 'Profile',
              details: [
                'Displays user details from Firestore',
                'Edit profile (name, username, age, gender)',
                'Support, About & Accessibility entry-points',
              ],
              icon: Icons.person_outline,
              color: Colors.blueGrey,
            ),
            SizedBox(height: 16),
            _Section(
              title: 'Data Model (Firestore)',
              subtitle:
                  'collections: users, user_goals, user_progress, leaderboard, activities, quizzes/(id)/questions',
              icon: Icons.storage,
              color: Color(0xFF00c6ff),
            ),
            SizedBox(height: 24),
            _Section(
              title: 'Roadmap',
              subtitle:
                  'Integrate on-device sign recognition, real translation history, ASL dictionary, notifications.',
              icon: Icons.rocket_launch,
              color: Color(0xFF7F00FF),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _Section({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
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
                      color: Color(0xFF2D3748),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final String title;
  final List<String> details;
  final IconData icon;
  final Color color;

  const _FeatureCard({
    required this.title,
    required this.details,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1976D2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...details.map((d) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(color: Colors.grey)),
                      Expanded(
                        child: Text(
                          d,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}


