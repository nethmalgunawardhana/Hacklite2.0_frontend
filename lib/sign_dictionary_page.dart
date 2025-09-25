import 'package:flutter/material.dart';

class SignDictionaryPage extends StatefulWidget {
  const SignDictionaryPage({super.key});

  @override
  State<SignDictionaryPage> createState() => _SignDictionaryPageState();
}

class _SignDictionaryPageState extends State<SignDictionaryPage> {
  String selectedCategory = 'All';
  String searchQuery = '';

  // Comprehensive sign dictionary
  final List<Map<String, dynamic>> allSigns = [
    // Basic Greetings
    {
      'name': 'Hello',
      'image': 'Sign-Language-Hello.webp',
      'description':
          'Raise your dominant hand and wave it side to side near your forehead.',
      'difficulty': 'Beginner',
      'category': 'Greetings',
    },
    {
      'name': 'Goodbye',
      'image': 'Sign-Language-Goodbye.webp',
      'description':
          'Open your dominant hand and move it away from your chin in a waving motion.',
      'difficulty': 'Beginner',
      'category': 'Greetings',
    },
    {
      'name': 'Thank You',
      'image': 'Sign-Language-Thank-You.webp',
      'description':
          'Touch your chin with your fingertips and move your hand forward and down.',
      'difficulty': 'Beginner',
      'category': 'Greetings',
    },
    {
      'name': 'Please',
      'image': 'Sign-Language-Please-.webp',
      'description':
          'Place your dominant hand flat against your chest and move it in a circular motion.',
      'difficulty': 'Beginner',
      'category': 'Greetings',
    },
    {
      'name': 'Sorry',
      'image': 'Sign-Language-Sorry.webp',
      'description':
          'Make a fist with your dominant hand and rub it in a circular motion over your chest.',
      'difficulty': 'Beginner',
      'category': 'Greetings',
    },

    // Common Words
    {
      'name': 'Help',
      'image': 'Sign-Language-Help.webp',
      'description':
          'Make a fist with both hands and raise them to shoulder height, palms facing up.',
      'difficulty': 'Beginner',
      'category': 'Common Words',
    },
    {
      'name': 'Stop',
      'image': 'Sign-Language-Stop.webp',
      'description':
          'Hold your dominant hand up with palm facing forward, like a traffic cop.',
      'difficulty': 'Beginner',
      'category': 'Common Words',
    },
    {
      'name': 'Yes',
      'image': 'Sign-Language-Yes.webp',
      'description': 'Make a fist and nod it up and down at the wrist.',
      'difficulty': 'Beginner',
      'category': 'Common Words',
    },
    {
      'name': 'No',
      'image': 'Sign-Language-No.webp',
      'description':
          'Hold your index and middle fingers together and shake them side to side.',
      'difficulty': 'Beginner',
      'category': 'Common Words',
    },
    {
      'name': 'Love',
      'image': 'Sign-Language-Love.webp',
      'description':
          'Cross your arms over your chest, right hand over left, and hug yourself.',
      'difficulty': 'Beginner',
      'category': 'Common Words',
    },

    // Family Members
    {
      'name': 'Mother/Mom',
      'image': 'Sign-Language-Mother.webp',
      'description': 'Tap your thumb against your chin.',
      'difficulty': 'Beginner',
      'category': 'Family',
    },
    {
      'name': 'Father/Dad',
      'image': 'Sign-Language-Father.webp',
      'description': 'Tap your thumb against your forehead.',
      'difficulty': 'Beginner',
      'category': 'Family',
    },
    {
      'name': 'Brother',
      'image': 'Sign-Language-Brother.webp',
      'description':
          'Tap your thumb against your forehead, then move it in a small arc.',
      'difficulty': 'Beginner',
      'category': 'Family',
    },
    {
      'name': 'Sister',
      'image': 'Sign-Language-Sister.webp',
      'description':
          'Tap your thumb against your chin, then move it in a small arc.',
      'difficulty': 'Beginner',
      'category': 'Family',
    },
    {
      'name': 'Friend',
      'image': 'Sign-Language-Friend.webp',
      'description': 'Link your index fingers together.',
      'difficulty': 'Beginner',
      'category': 'Family',
    },

    // Food and Drink
    {
      'name': 'Eat/Lunch',
      'image': 'Sign-Language-Eat-Lunch-.webp',
      'description':
          'Bring your fingertips to your mouth and move your hand away as if taking food.',
      'difficulty': 'Beginner',
      'category': 'Food',
    },
    {
      'name': 'Drink',
      'image': 'Sign-Language-Drink.webp',
      'description':
          'Make a C-shape with your hand and bring it to your mouth as if drinking.',
      'difficulty': 'Beginner',
      'category': 'Food',
    },
    {
      'name': 'Water',
      'image': 'Sign-Language-Water.webp',
      'description':
          'Make a W-shape with your fingers and tap it against your chin.',
      'difficulty': 'Beginner',
      'category': 'Food',
    },
    {
      'name': 'Food',
      'image': 'Sign-Language-Food.webp',
      'description': 'Make a fist and rub it in a circle over your stomach.',
      'difficulty': 'Beginner',
      'category': 'Food',
    },
    {
      'name': 'Hungry',
      'image': 'Sign-Language-Hungry.webp',
      'description': 'Make a fist and rub it in a circle over your stomach.',
      'difficulty': 'Beginner',
      'category': 'Food',
    },

    // Animals
    {
      'name': 'Dog',
      'image': 'Sign-Language-Dog.webp',
      'description': 'Snap your fingers or pat your leg as if calling a dog.',
      'difficulty': 'Beginner',
      'category': 'Animals',
    },
    {
      'name': 'Cat',
      'image': 'Sign-Language-Cat.webp',
      'description':
          'Make a C-shape with your hand and scratch your cheek like cat whiskers.',
      'difficulty': 'Beginner',
      'category': 'Animals',
    },
    {
      'name': 'Bird',
      'image': 'Sign-Language-Bird.webp',
      'description': 'Flap your arms like wings.',
      'difficulty': 'Beginner',
      'category': 'Animals',
    },
    {
      'name': 'Fish',
      'image': 'Sign-Language-Fish.webp',
      'description':
          'Make a fish shape with both hands and move them side to side.',
      'difficulty': 'Beginner',
      'category': 'Animals',
    },

    // Colors
    {
      'name': 'Red',
      'image': 'Sign-Language-Red.webp',
      'description': 'Make a fist and rub it across your lips.',
      'difficulty': 'Beginner',
      'category': 'Colors',
    },
    {
      'name': 'Blue',
      'image': 'Sign-Language-Blue.webp',
      'description': 'Point to the sky or make a B-shape near your shoulder.',
      'difficulty': 'Beginner',
      'category': 'Colors',
    },
    {
      'name': 'Green',
      'image': 'Sign-Language-Green.webp',
      'description': 'Make a G-shape and touch it to your chin.',
      'difficulty': 'Beginner',
      'category': 'Colors',
    },
    {
      'name': 'Yellow',
      'image': 'Sign-Language-Yellow.webp',
      'description': 'Make a Y-shape and shake it near your shoulder.',
      'difficulty': 'Beginner',
      'category': 'Colors',
    },

    // Numbers
    {
      'name': 'One',
      'image': 'Sign-Language-One.webp',
      'description': 'Hold up your index finger.',
      'difficulty': 'Beginner',
      'category': 'Numbers',
    },
    {
      'name': 'Two',
      'image': 'Sign-Language-Two.webp',
      'description': 'Hold up your index and middle fingers.',
      'difficulty': 'Beginner',
      'category': 'Numbers',
    },
    {
      'name': 'Three',
      'image': 'Sign-Language-Three.webp',
      'description': 'Hold up your index, middle, and ring fingers.',
      'difficulty': 'Beginner',
      'category': 'Numbers',
    },
    {
      'name': 'Four',
      'image': 'Sign-Language-Four.webp',
      'description': 'Hold up all four fingers except your thumb.',
      'difficulty': 'Beginner',
      'category': 'Numbers',
    },
    {
      'name': 'Five',
      'image': 'Sign-Language-Five.webp',
      'description': 'Hold up all five fingers in a flat hand.',
      'difficulty': 'Beginner',
      'category': 'Numbers',
    },

    // Emotions
    {
      'name': 'Happy',
      'image': 'Sign-Language-Happy.webp',
      'description':
          'Smile widely and move your hands in a happy, open gesture.',
      'difficulty': 'Beginner',
      'category': 'Emotions',
    },
    {
      'name': 'Sad',
      'image': 'Sign-Language-Sad.webp',
      'description': 'Make a frown and move your hands downward.',
      'difficulty': 'Beginner',
      'category': 'Emotions',
    },
    {
      'name': 'Angry',
      'image': 'Sign-Language-Angry.webp',
      'description': 'Make fists and shake them or make an angry face.',
      'difficulty': 'Beginner',
      'category': 'Emotions',
    },

    // Bathroom/Personal Care
    {
      'name': 'Bathroom',
      'image': 'Sign-Language-Bathroom.webp',
      'description':
          'Make a B-shape with your hand and tap it against your forehead.',
      'difficulty': 'Beginner',
      'category': 'Personal Care',
    },
    {
      'name': 'Potty',
      'image': 'Sign-Language-Potty-.webp',
      'description':
          'Make a fist with your dominant hand and tap it against your chin.',
      'difficulty': 'Beginner',
      'category': 'Personal Care',
    },

    // Alphabet (Basic Letters)
    {
      'name': 'A',
      'image': 'Sign-Language-A.webp',
      'description': 'Make a fist with your thumb on top.',
      'difficulty': 'Intermediate',
      'category': 'Alphabet',
    },
    {
      'name': 'B',
      'image': 'Sign-Language-B.webp',
      'description': 'Hold your fingers straight up with thumb tucked in.',
      'difficulty': 'Intermediate',
      'category': 'Alphabet',
    },
    {
      'name': 'C',
      'image': 'Sign-Language-C.webp',
      'description': 'Curve your fingers into a C-shape.',
      'difficulty': 'Intermediate',
      'category': 'Alphabet',
    },
    {
      'name': 'M',
      'image': 'Sign-Language-M-.webp',
      'description':
          'Form an M shape with your fingers and hold it near your forehead.',
      'difficulty': 'Intermediate',
      'category': 'Alphabet',
    },
    {
      'name': 'S',
      'image': 'Sign-Language-S.webp',
      'description': 'Make a fist with your thumb wrapped around your fingers.',
      'difficulty': 'Intermediate',
      'category': 'Alphabet',
    },
    {
      'name': 'T',
      'image': 'Sign-Language-T.webp',
      'description':
          'Make a fist with your thumb between your index and middle fingers.',
      'difficulty': 'Intermediate',
      'category': 'Alphabet',
    },

    // Time and Days
    {
      'name': 'Time',
      'image': 'Sign-Language-Time.webp',
      'description': 'Tap your wrist as if wearing a watch.',
      'difficulty': 'Beginner',
      'category': 'Time',
    },
    {
      'name': 'Today',
      'image': 'Sign-Language-Today.webp',
      'description': 'Point downward with both index fingers.',
      'difficulty': 'Beginner',
      'category': 'Time',
    },
    {
      'name': 'Tomorrow',
      'image': 'Sign-Language-Tomorrow.webp',
      'description': 'Point forward with both index fingers.',
      'difficulty': 'Beginner',
      'category': 'Time',
    },
    {
      'name': 'Yesterday',
      'image': 'Sign-Language-Yesterday.webp',
      'description':
          'Point backward over your shoulder with both index fingers.',
      'difficulty': 'Beginner',
      'category': 'Time',
    },

    // School/Work
    {
      'name': 'School',
      'image': 'Sign-Language-School.webp',
      'description': 'Make both hands into A-shapes and tap them together.',
      'difficulty': 'Beginner',
      'category': 'Education',
    },
    {
      'name': 'Work',
      'image': 'Sign-Language-Work.webp',
      'description':
          'Make fists and alternate tapping them against each other.',
      'difficulty': 'Beginner',
      'category': 'Education',
    },
    {
      'name': 'Learn',
      'image': 'Sign-Language-Learn.webp',
      'description': 'Tap your forehead with your index finger.',
      'difficulty': 'Beginner',
      'category': 'Education',
    },
    {
      'name': 'Teacher',
      'image': 'Sign-Language-Teacher.webp',
      'description':
          'Make a Y-shape with your dominant hand and tap it against your shoulder.',
      'difficulty': 'Beginner',
      'category': 'Education',
    },

    // Weather
    {
      'name': 'Hot',
      'image': 'Sign-Language-Hot.webp',
      'description': 'Fan yourself with your hand.',
      'difficulty': 'Beginner',
      'category': 'Weather',
    },
    {
      'name': 'Cold',
      'image': 'Sign-Language-Cold.webp',
      'description': 'Shiver your body and wrap your arms around yourself.',
      'difficulty': 'Beginner',
      'category': 'Weather',
    },
    {
      'name': 'Rain',
      'image': 'Sign-Language-Rain.webp',
      'description': 'Wiggle your fingers downward like rain falling.',
      'difficulty': 'Beginner',
      'category': 'Weather',
    },
    {
      'name': 'Sun',
      'image': 'Sign-Language-Sun.webp',
      'description': 'Make a circle with your arms above your head.',
      'difficulty': 'Beginner',
      'category': 'Weather',
    },
  ];

  List<String> get categories {
    Set<String> categorySet = {'All'};
    for (var sign in allSigns) {
      categorySet.add(sign['category']);
    }
    return categorySet.toList()..sort();
  }

  List<Map<String, dynamic>> get filteredSigns {
    List<Map<String, dynamic>> filtered = allSigns;

    // Filter by category
    if (selectedCategory != 'All') {
      filtered = filtered
          .where((sign) => sign['category'] == selectedCategory)
          .toList();
    }

    // Filter by search query
    if (searchQuery.isNotEmpty) {
      filtered = filtered
          .where(
            (sign) =>
                sign['name'].toLowerCase().contains(
                  searchQuery.toLowerCase(),
                ) ||
                sign['description'].toLowerCase().contains(
                  searchQuery.toLowerCase(),
                ),
          )
          .toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFF4F7FB), Color(0xFFF4F7FB)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              children: [
                // Search and Filter Header
                Container(
                  padding: const EdgeInsets.only(
                    top: 80,
                    left: 20,
                    right: 20,
                    bottom: 20,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📚 Sign Dictionary',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.3),
                              offset: const Offset(0, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${filteredSigns.length} signs available',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Search Bar
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: TextField(
                          onChanged: (value) =>
                              setState(() => searchQuery = value),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search signs...',
                            hintStyle: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 16,
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              color: Colors.white.withOpacity(0.7),
                              size: 24,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Category Filter
                      Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: categories.length,
                          itemBuilder: (context, index) {
                            final category = categories[index];
                            final isSelected = category == selectedCategory;
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              child: FilterChip(
                                label: Text(
                                  category,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.black,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() => selectedCategory = category);
                                },
                                backgroundColor: isSelected
                                    ? const Color(0xFF1976D2).withOpacity(0.8)
                                    : Colors.white.withOpacity(0.2),
                                selectedColor: const Color(0xFF1976D2),
                                checkmarkColor: Colors.white,
                                elevation: isSelected ? 4 : 2,
                                shadowColor: isSelected
                                    ? const Color(0xFF1976D2).withOpacity(0.3)
                                    : Colors.black.withOpacity(0.1),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(
                                    color: isSelected
                                        ? const Color(0xFF1976D2)
                                        : Colors.white.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Signs List
                Expanded(
                  child: filteredSigns.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 80,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No signs found',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredSigns.length,
                          itemBuilder: (context, index) {
                            final sign = filteredSigns[index];
                            return Card(
                              elevation: 6,
                              margin: const EdgeInsets.only(bottom: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  gradient: LinearGradient(
                                    colors: [Colors.white, Color(0xFFF4F7FB)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFF1976D2,
                                              ).withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              border: Border.all(
                                                color: const Color(
                                                  0xFF1976D2,
                                                ).withOpacity(0.2),
                                                width: 1,
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.sign_language,
                                              color: Color(0xFF1976D2),
                                              size: 28,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  sign['name'],
                                                  style: const TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 4,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            _getDifficultyColor(
                                                              sign['difficulty'],
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        sign['difficulty'],
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      sign['category'],
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey[600],
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        sign['description'],
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: Colors.grey[700],
                                          height: 1.5,
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
              ],
            ),
          ),

          // Back Button
          Positioned(
            top: 40,
            left: 20,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
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

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty) {
      case 'Beginner':
        return Colors.green;
      case 'Intermediate':
        return Colors.orange;
      case 'Advanced':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
