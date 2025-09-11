import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'All';
  bool _showFavoritesOnly = false;

  // Mock data for demonstration
  final List<TranslationHistoryItem> _mockHistory = [
    TranslationHistoryItem(
      id: '1',
      originalText: 'Hello',
      translatedText: '👋 (Hello sign)',
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      isFavorite: true,
      confidence: 0.95,
    ),
    TranslationHistoryItem(
      id: '2',
      originalText: 'Thank you',
      translatedText: '🙏 (Thank you sign)',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      isFavorite: false,
      confidence: 0.89,
    ),
    TranslationHistoryItem(
      id: '3',
      originalText: 'How are you?',
      translatedText: '🤔 + 👋 (How are you signs)',
      timestamp: DateTime.now().subtract(const Duration(hours: 4)),
      isFavorite: true,
      confidence: 0.92,
    ),
    TranslationHistoryItem(
      id: '4',
      originalText: 'Good morning',
      translatedText: '☀️ + 👋 (Good morning signs)',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      isFavorite: false,
      confidence: 0.87,
    ),
    TranslationHistoryItem(
      id: '5',
      originalText: 'I love you',
      translatedText: '❤️ + 🤟 (I love you signs)',
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
      isFavorite: true,
      confidence: 0.94,
    ),
    TranslationHistoryItem(
      id: '6',
      originalText: 'Please help me',
      translatedText: '🙏 + 🆘 (Please help signs)',
      timestamp: DateTime.now().subtract(const Duration(days: 3)),
      isFavorite: false,
      confidence: 0.85,
    ),
  ];

  List<TranslationHistoryItem> get _filteredHistory {
    return _mockHistory.where((item) {
      final matchesSearch =
          _searchQuery.isEmpty ||
          item.originalText.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          item.translatedText.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );

      final matchesFilter =
          _selectedFilter == 'All' ||
          (_selectedFilter == 'Today' &&
              item.timestamp.day == DateTime.now().day) ||
          (_selectedFilter == 'Favorites' && item.isFavorite);

      final matchesFavorites = !_showFavoritesOnly || item.isFavorite;

      return matchesSearch && matchesFilter && matchesFavorites;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Header with Search and Filters
          Container(
            padding: const EdgeInsets.only(
              top: 60,
              left: 20,
              right: 20,
              bottom: 20,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue, Colors.blueAccent],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              children: [
                const Text(
                  'Translation History',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),

                // Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search translations...',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 15,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // Filter Buttons
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Today'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Favorites'),
                      const SizedBox(width: 8),
                      _buildActionChip(
                        'Clear All',
                        Icons.delete_sweep,
                        Colors.red,
                        () => _showClearHistoryDialog(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // History List
          Expanded(
            child: _filteredHistory.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _filteredHistory.length,
                    itemBuilder: (context, index) {
                      return _buildHistoryItem(_filteredHistory[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = selected ? label : 'All';
        });
      },
      backgroundColor: Colors.white,
      selectedColor: Colors.blue.withOpacity(0.2),
      checkmarkColor: Colors.blue,
      labelStyle: TextStyle(
        color: isSelected ? Colors.blue : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildActionChip(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return ActionChip(
      label: Text(label),
      avatar: Icon(icon, color: color, size: 18),
      onPressed: onTap,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildHistoryItem(TranslationHistoryItem item) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showTranslationDetails(item),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.originalText,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.translatedText,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      IconButton(
                        icon: Icon(
                          item.isFavorite
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: item.isFavorite ? Colors.red : Colors.grey,
                        ),
                        onPressed: () => _toggleFavorite(item),
                      ),
                      Text(
                        '${(item.confidence * 100).round()}%',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatTimestamp(item.timestamp),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.share, size: 20),
                        onPressed: () => _shareTranslation(item),
                        color: Colors.grey,
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_vert, size: 20),
                        onPressed: () => _showItemMenu(item),
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'No results found'
                : 'No translation history yet',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try adjusting your search terms'
                : 'Start translating to see your history here',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (_searchQuery.isEmpty)
            ElevatedButton.icon(
              onPressed: () {
                // Navigate to camera
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Switch to Camera tab to start translating!'),
                  ),
                );
              },
              icon: const Icon(Icons.camera_alt),
              label: const Text('Start Translating'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(timestamp);
    }
  }

  void _toggleFavorite(TranslationHistoryItem item) {
    setState(() {
      item.isFavorite = !item.isFavorite;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          item.isFavorite ? 'Added to favorites' : 'Removed from favorites',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _shareTranslation(TranslationHistoryItem item) {
    // TODO: Implement share functionality
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Sharing: ${item.originalText}')));
  }

  void _showItemMenu(TranslationHistoryItem item) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.copy),
            title: const Text('Copy Translation'),
            onTap: () {
              Navigator.pop(context);
              // TODO: Implement copy functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Translation copied to clipboard'),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Delete', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              _deleteTranslation(item);
            },
          ),
        ],
      ),
    );
  }

  void _showTranslationDetails(TranslationHistoryItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Translation Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Original: ${item.originalText}'),
            const SizedBox(height: 8),
            Text('Translation: ${item.translatedText}'),
            const SizedBox(height: 8),
            Text('Confidence: ${(item.confidence * 100).round()}%'),
            const SizedBox(height: 8),
            Text('Time: ${_formatTimestamp(item.timestamp)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _shareTranslation(item);
            },
            child: const Text('Share'),
          ),
        ],
      ),
    );
  }

  void _deleteTranslation(TranslationHistoryItem item) {
    setState(() {
      _mockHistory.remove(item);
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Translation deleted')));
  }

  void _showClearHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text(
          'Are you sure you want to clear all translation history? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _mockHistory.clear();
              });
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('History cleared')));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class TranslationHistoryItem {
  final String id;
  final String originalText;
  final String translatedText;
  final DateTime timestamp;
  bool isFavorite;
  final double confidence;

  TranslationHistoryItem({
    required this.id,
    required this.originalText,
    required this.translatedText,
    required this.timestamp,
    required this.isFavorite,
    required this.confidence,
  });
}
