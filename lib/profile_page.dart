import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  final User? user = FirebaseAuth.instance.currentUser;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildHeader(context),
                Transform.translate(
                  offset: const Offset(0, -30),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
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
                        _buildModernSection(
                          title: '⚙️ Account Settings',
                          child: Column(
                            children: [
                              _buildModernMenuItem(
                                'Edit Profile',
                                'Update your personal information',
                                Icons.edit,
                                const Color(0xFF667EEA),
                                () {},
                              ),
                              _buildModernMenuItem(
                                'Language Preferences',
                                'Customize your learning language',
                                Icons.language,
                                const Color(0xFF764BA2),
                                () {},
                              ),
                              _buildModernMenuItem(
                                'Notification Settings',
                                'Manage app notifications',
                                Icons.notifications_active,
                                const Color(0xFFF093FB),
                                () {},
                              ),
                              _buildModernMenuItem(
                                'Accessibility',
                                'Customize for better accessibility',
                                Icons.accessibility_new,
                                const Color(0xFF4ECDC4),
                                () {},
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        _buildModernSection(
                          title: '🆘 Support & Help',
                          child: Column(
                            children: [
                              _buildModernMenuItem(
                                'Help & Support',
                                'Get help and contact support',
                                Icons.help_center,
                                const Color(0xFFFF6B6B),
                                () {},
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
                        _buildLogoutButton(),
                        const SizedBox(height: 40),
                      ],
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

  Widget _buildHeader(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: 280,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF667EEA), Color(0xFF764BA2), Color(0xFFF093FB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      'Profile',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Icon(Icons.settings, color: Colors.white, size: 28),
                  ],
                ),
                const SizedBox(height: 30),
                CircleAvatar(
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
                      : const Icon(Icons.person, size: 65, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                Text(
                  user?.displayName ?? 'ASL Learner',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  user?.email ?? 'learner@hacklite.com',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStat(String value, String label) => Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w500)),
        ],
      );

  Widget _buildModernSection({required String title, required Widget child}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              spreadRadius: 2,
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2D3748))),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildModernStatCard(
      String title, String value, IconData icon, Color color, String subtitle) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight),
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
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value,
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: color)),
                    Text(title,
                        style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF718096),
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 12,
                            color: color.withOpacity(0.8),
                            fontWeight: FontWeight.w600)),
                  ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernMenuItem(
      String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
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
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2D3748))),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF718096),
                            fontWeight: FontWeight.w400)),
                  ]),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 16, color: color.withOpacity(0.6)),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight),
          borderRadius: BorderRadius.circular(16)),
      child: ElevatedButton.icon(
        onPressed: () async => await FirebaseAuth.instance.signOut(),
        icon: const Icon(Icons.logout, size: 24, color: Colors.white),
        label: const Text('Sign Out',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
        style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      ),
    );
  }

  void _showModernAboutDialog(BuildContext context) {
    showDialog(
        context: context,
        builder: (_) {
          return Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: const [
                Text("About Hacklite 2.0",
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                SizedBox(height: 12),
                Text(
                  "Hacklite 2.0 is an innovative sign language translation app bridging communication gaps.",
                  textAlign: TextAlign.center,
                )
              ]),
            ),
          );
        });
  }
}
