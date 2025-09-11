import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final User? user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Modern Profile Header with Glassmorphism
            Stack(
              children: [
                // Background Gradient
                Container(
                  height: 280,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF667EEA),
                        Color(0xFF764BA2),
                        Color(0xFFF093FB),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),

                // Glassmorphism Overlay
                Container(
                  height: 280,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.1),
                        Colors.white.withOpacity(0.05),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),

                // Content
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    child: Column(
                      children: [
                        // Header Actions
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Profile',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                // TODO: Settings
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Settings - Coming Soon!'),
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.settings,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 30),

                        // Modern Avatar with Glow Effect
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.3),
                                spreadRadius: 8,
                                blurRadius: 20,
                                offset: const Offset(0, 0),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 65,
                            backgroundColor: Colors.white,
                            child: user?.photoURL != null
                                ? ClipOval(
                                    child: Image.network(
                                      user!.photoURL!,
                                      width: 130,
                                      height: 130,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0xFF667EEA),
                                          Color(0xFF764BA2),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.person,
                                      size: 65,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // User Info with Modern Typography
                        Text(
                          user?.displayName ?? 'ASL Learner',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            user?.email ?? 'learner@hacklite.com',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Quick Stats Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildQuickStat('247', 'Translations'),
                            _buildQuickStat('89', 'Signs Learned'),
                            _buildQuickStat('34', 'Sessions'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Modern Content Section
            Transform.translate(
              offset: const Offset(0, -30),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Statistics Cards
                    _buildModernSection(
                      title: '📊 Learning Progress',
                      child: Column(
                        children: [
                          _buildModernStatCard(
                            'Total Translations',
                            '247',
                            Icons.translate,
                            const Color(0xFF667EEA),
                            '+12% this week',
                          ),
                          const SizedBox(height: 16),
                          _buildModernStatCard(
                            'Words Learned',
                            '89',
                            Icons.school,
                            const Color(0xFF764BA2),
                            '15 new this month',
                          ),
                          const SizedBox(height: 16),
                          _buildModernStatCard(
                            'Practice Sessions',
                            '34',
                            Icons.access_time,
                            const Color(0xFFF093FB),
                            '7 day streak! 🔥',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Settings Section
                    _buildModernSection(
                      title: '⚙️ Account Settings',
                      child: Column(
                        children: [
                          _buildModernMenuItem(
                            'Edit Profile',
                            'Update your personal information',
                            Icons.edit,
                            const Color(0xFF667EEA),
                            () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Edit Profile - Coming Soon!'),
                                ),
                              );
                            },
                          ),
                          _buildModernMenuItem(
                            'Language Preferences',
                            'Customize your learning language',
                            Icons.language,
                            const Color(0xFF764BA2),
                            () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Language Settings - Coming Soon!',
                                  ),
                                ),
                              );
                            },
                          ),
                          _buildModernMenuItem(
                            'Notification Settings',
                            'Manage app notifications',
                            Icons.notifications_active,
                            const Color(0xFFF093FB),
                            () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Notification Settings - Coming Soon!',
                                  ),
                                ),
                              );
                            },
                          ),
                          _buildModernMenuItem(
                            'Accessibility',
                            'Customize for better accessibility',
                            Icons.accessibility_new,
                            const Color(0xFF4ECDC4),
                            () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Accessibility Settings - Coming Soon!',
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Support Section
                    _buildModernSection(
                      title: '🆘 Support & Help',
                      child: Column(
                        children: [
                          _buildModernMenuItem(
                            'Help & Support',
                            'Get help and contact support',
                            Icons.help_center,
                            const Color(0xFFFF6B6B),
                            () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Help & Support - Coming Soon!',
                                  ),
                                ),
                              );
                            },
                          ),
                          _buildModernMenuItem(
                            'About Hacklite 2.0',
                            'Learn more about our mission',
                            Icons.info_outline,
                            const Color(0xFF4ECDC4),
                            () => _showModernAboutDialog(context),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Modern Logout Button
                    Container(
                      width: double.infinity,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF6B6B).withOpacity(0.3),
                            spreadRadius: 2,
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await FirebaseAuth.instance.signOut();
                        },
                        icon: const Icon(
                          Icons.logout,
                          size: 24,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Sign Out',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildModernSection({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            spreadRadius: 2,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2D3748),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildModernStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  spreadRadius: 2,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF718096),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: color.withOpacity(0.8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernMenuItem(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        margin: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF718096),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: color.withOpacity(0.6),
            ),
          ],
        ),
      ),
    );
  }

  void _showModernAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [Colors.white, Color(0xFFF8F9FA)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo/Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.sign_language,
                    color: Colors.white,
                    size: 32,
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  'About Hacklite 2.0',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2D3748),
                  ),
                ),

                const SizedBox(height: 16),

                const Text(
                  'Hacklite 2.0 is an innovative sign language translation app that helps bridge communication gaps between deaf and hearing communities.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF718096),
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 20),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '✨ Key Features',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2D3748),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildFeatureItem('Real-time sign language recognition'),
                      _buildFeatureItem('Text-to-sign conversion'),
                      _buildFeatureItem('Interactive learning modules'),
                      _buildFeatureItem('Community support & resources'),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF667EEA).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Version 2.0.0',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF667EEA),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF667EEA),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Got it!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeatureItem(String feature) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF48BB78), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              feature,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF718096),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
