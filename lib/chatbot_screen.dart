import 'package:flutter/material.dart';
// import 'package:speech_to_text/speech_to_text.dart' as stt; // Temporarily disabled due to build issues
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:video_player/video_player.dart';
// import 'package:youtube_player_flutter/youtube_player_flutter.dart'; // Temporarily commented
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/gestures.dart';

class Message {
  final bool isUser;
  final String text;
  final DateTime timestamp;
  final MessageStatus status;

  Message({
    required this.isUser,
    required this.text,
    required this.timestamp,
    this.status = MessageStatus.delivered,
  });
}

enum MessageStatus { sending, delivered, error }

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final List<Message> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isProcessing = false;

  // Speech to text - temporarily disabled due to build issues
  // late stt.SpeechToText _speechToText;
  bool _isListening = false;
  String _lastWords = '';

  // Knowledge bank
  Map<String, dynamic>? _knowledgeBank;

  // Gemini AI
  late GenerativeModel _model;

  @override
  void initState() {
    super.initState();
    // _speechToText = stt.SpeechToText(); // Temporarily disabled
    _initializeGemini();
    _loadKnowledgeBank();
    _addWelcomeMessage();
  }

  void _initializeGemini() {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      print('Warning: GEMINI_API_KEY not found in .env file');
      return;
    }
    _model = GenerativeModel(model: 'gemini-2.0-flash-exp', apiKey: apiKey);
  }

  Future<void> _loadKnowledgeBank() async {
    try {
      final jsonString = await rootBundle.loadString(
        'lib/models/sign_language_knowledge_bank.json',
      );
      _knowledgeBank = json.decode(jsonString);
      print(
        'DEBUG: Knowledge bank loaded successfully. Signs count: ${_knowledgeBank!['signs'].length}',
      );
      print('DEBUG: First sign: ${_knowledgeBank!['signs'][0]}');
    } catch (e) {
      print('Error loading knowledge bank: $e');
    }
  }

  @override
  void dispose() {
    // _speechToText.stop(); // Temporarily disabled
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addWelcomeMessage() {
    const welcomeText =
        "Hello! I'm your Sign Language Assistant. How can I help you with ASL today?";
    final welcomeMessage = Message(
      isUser: false,
      text: welcomeText,
      timestamp: DateTime.now(),
    );
    _messages.add(welcomeMessage);
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final userMessage = Message(
      isUser: true,
      text: text,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isProcessing = true;
    });

    _scrollToBottom();
    _textController.clear();

    // Generate AI response
    final aiResponse = await _generateAIResponse(text);
    final aiMessage = Message(
      isUser: false,
      text: aiResponse,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(aiMessage);
      _isProcessing = false;
    });

    _scrollToBottom();
  }

  Future<String> _generateAIResponse(String userMessage) async {
    // Check if the message is about sign language
    final isSignLanguageQuery = await _isSignLanguageQuery(userMessage);

    if (isSignLanguageQuery && _knowledgeBank != null) {
      return await _generateSignLanguageResponse(userMessage);
    } else {
      // Only respond to ASL/sign language queries
      return "I'm here to help with American Sign Language (ASL) questions! Try asking me about signs like 'How do you sign hello?' or 'What's the sign for thank you?'";
    }
  }

  Future<bool> _isSignLanguageQuery(String message) async {
    // First check for obvious sign language keywords
    final signKeywords = [
      'sign',
      'asl',
      'sign language',
      'signing',
      'signed',
      'how to sign',
      'sign for',
      'asl for',
      'show me',
    ];

    final lowerMessage = message.toLowerCase();
    if (signKeywords.any((keyword) => lowerMessage.contains(keyword))) {
      print('DEBUG: Detected sign language query via keywords: $message');
      return true;
    }

    try {
      final prompt =
          '''
Analyze this user message and determine if it's asking about sign language, ASL (American Sign Language), or related topics.
Return only "true" if it's clearly about sign language, or "false" if it's not.

Message: "$message"

Examples of sign language queries:
- "How do you sign hello?"
- "What is the sign for thank you?"
- "Show me ASL for eat"
- "Sign language video for please"

Examples of non-sign language queries:
- "What's the weather like?"
- "How to cook pasta?"
- "Tell me about Flutter development"
''';

      final response = await _model.generateContent([Content.text(prompt)]);
      final result = response.text?.toLowerCase().trim() ?? 'false';
      print('DEBUG: AI sign language detection for "$message": $result');
      return result == 'true';
    } catch (e) {
      print('Error checking sign language query: $e');
      return false;
    }
  }

  Future<String> _generateSignLanguageResponse(String userMessage) async {
    try {
      print('DEBUG: Generating sign language response for: $userMessage');
      final signs = _knowledgeBank!['signs'] as List<dynamic>;
      final categories = _knowledgeBank!['categories'] as Map<String, dynamic>;

      // Use LLM to understand the user query and extract the sign they're asking about
      final signExtractionPrompt =
          '''
Analyze this user message about sign language and determine what specific sign they are asking about.

User message: "$userMessage"

Available signs in our knowledge bank: ${signs.map((s) => s['word']).join(', ')}

If the user is asking about a specific sign that exists in our knowledge bank, return only the exact sign name in lowercase.
If the user is asking about a sign that doesn't exist, or if it's a general question, return "GENERAL".
If the user is asking about multiple signs, return the most relevant one.

Examples:
- "How do you sign hello?" -> "hello"
- "What's the sign for thank you?" -> "thank you"
- "Show me how to sign eat" -> "eat"
- "What is sign language?" -> "GENERAL"
- "Tell me about ASL" -> "GENERAL"

Return only the sign name or "GENERAL" (no quotes, no explanation).
''';

      final extractionResponse = await _model.generateContent([
        Content.text(signExtractionPrompt),
      ]);
      final extractedSign =
          extractionResponse.text?.trim().toLowerCase() ?? 'general';

      print('DEBUG: LLM extracted sign: $extractedSign');

      // If a specific sign was identified, look it up in the knowledge bank
      if (extractedSign != 'general' && extractedSign.isNotEmpty) {
        final signData = signs.firstWhere(
          (sign) => sign['word'].toString().toLowerCase() == extractedSign,
          orElse: () => null,
        );

        if (signData != null) {
          final description = signData['description'] as String;
          final videoUrl = signData['video_url'] as String;
          final difficulty = signData['difficulty'] as String;
          print(
            'DEBUG: Found sign $extractedSign, description: $description, videoUrl: $videoUrl',
          );

          final response =
              'Here\'s how to sign "$extractedSign" (${difficulty}):\n\n$description\n\n📹 Watch the video tutorial: $videoUrl';
          print('DEBUG: Returning knowledge bank response: $response');
          return response;
        }
      }

      // If no specific sign found or general question, use AI to generate a comprehensive response
      print('DEBUG: Using AI fallback for general response or unknown sign');
      final generalPrompt =
          '''
You are a helpful Sign Language Assistant. The user asked: "$userMessage"

Available signs in our knowledge bank: ${signs.map((s) => s['word']).join(', ')}
Categories available: ${categories.keys.join(', ')}

${extractedSign != 'general' ? 'Note: The user asked about "$extractedSign" but this sign is not in our knowledge bank.' : ''}

Provide a helpful, informative response about American Sign Language (ASL). Include:
- Clear explanations of signs when possible
- Learning tips for ASL
- Information about ASL structure and usage
- Video tutorial links when available (format: 📹 Watch: [URL])
- Encouragement for learning ASL

Keep the response engaging and educational. If they ask about a sign not in our database, provide general guidance on how to learn that sign or similar signs.

Response should be comprehensive but not overwhelming.
''';

      final response = await _model.generateContent([
        Content.text(generalPrompt),
      ]);
      return response.text ??
          'Sorry, I couldn\'t generate a response right now.';
    } catch (e) {
      print('Error generating sign language response: $e');
      return 'Sorry, I encountered an error while processing your sign language query.';
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _startListening() async {
    // Speech-to-text temporarily disabled due to build issues
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Speech recognition is temporarily disabled. Please type your message instead.',
          ),
          duration: Duration(seconds: 3),
        ),
      );
    }
    return;
  }

  Future<void> _stopListening() async {
    // await _speechToText.stop(); // Temporarily disabled
    setState(() {
      _isListening = false;
      // Clear the last words when stopping
      _lastWords = '';
    });
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 8, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Thinking...',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  void _showVideoPopup(String videoUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return VideoPlayerDialog(videoUrl: videoUrl);
      },
    );
  }

  Widget _buildMessageItem(Message message) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.only(top: 8, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? Colors.blue.shade700 : Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMessageText(message.text, isUser),
            const SizedBox(height: 4),
            Text(
              '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 10,
                color: isUser ? Colors.white70 : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageText(String text, bool isUser) {
    // Simple URL detection and clickable text
    final urlRegex = RegExp(r'https?://[^\s]+');
    final matches = urlRegex.allMatches(text);

    if (matches.isEmpty) {
      return SelectableText(
        text,
        style: TextStyle(color: isUser ? Colors.white : Colors.black87),
      );
    }

    // Build text spans with clickable URLs
    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      // Add text before the URL
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastEnd, match.start),
            style: TextStyle(color: isUser ? Colors.white : Colors.black87),
          ),
        );
      }

      // Add clickable URL
      spans.add(
        TextSpan(
          text: match.group(0),
          style: TextStyle(
            color: isUser ? Colors.white : Colors.blue,
            decoration: TextDecoration.underline,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => _showVideoPopup(match.group(0)!),
        ),
      );

      lastEnd = match.end;
    }

    // Add remaining text
    if (lastEnd < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastEnd),
          style: TextStyle(color: isUser ? Colors.white : Colors.black87),
        ),
      );
    }

    return SelectableText.rich(TextSpan(children: spans));
  }

  Widget _buildInputArea() {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 16,
        bottom: 16 + bottomPadding,
      ),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Voice input button
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: _isListening
                  ? Colors.red.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              icon: Icon(
                _isListening ? Icons.mic : Icons.mic_none_outlined,
                size: 24,
              ),
              onPressed: _startListening,
              color: _isListening ? Colors.red : Colors.blue[700],
              tooltip: _isListening ? 'Stop listening' : 'Start voice input',
            ),
          ),
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: _isListening
                    ? 'Listening...'
                    : 'Type your message...',
                hintStyle: TextStyle(color: Colors.grey[500]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              minLines: 1,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (text) {
                if (text.trim().isNotEmpty) {
                  _sendMessage(text);
                }
              },
            ),
          ),
          Container(
            margin: const EdgeInsets.only(left: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade800, Colors.blue.shade300],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.send_rounded),
              onPressed: () {
                if (_textController.text.trim().isNotEmpty) {
                  _sendMessage(_textController.text);
                }
              },
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: BoxDecoration(
            color:
                Theme.of(context).appBarTheme.backgroundColor ?? Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.1),
                spreadRadius: 0,
                blurRadius: 15,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.transparent,
            centerTitle: true,
            iconTheme: IconThemeData(color: Colors.blue.shade700),
            title: ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [Colors.blue.shade800, Colors.blue.shade300],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: const Text(
                'Sign Language Assistant',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.blue.shade50],
            stops: const [0.7, 1.0],
          ),
        ),
        child: Column(
          children: [
            // Listening indicator
            if (_isListening)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                color: Colors.red.shade100,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.mic, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(
                      'Listening... Speak now',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: SafeArea(
                bottom: false,
                child: Container(
                  color: Colors.transparent,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: _messages.length + (_isProcessing ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_isProcessing && index == _messages.length) {
                        return _buildTypingIndicator();
                      }

                      final message = _messages[index];
                      return _buildMessageItem(message);
                    },
                  ),
                ),
              ),
            ),
            _buildSampleQuestions(),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildSampleQuestions() {
    final sampleQuestions = [
      'How do you sign hello?',
      'What\'s the sign for thank you?',
      'How to sign please?',
      'Show me ASL for eat',
      'What is sign language?',
    ];

    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: sampleQuestions.length,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: ElevatedButton(
              onPressed: () => _sendMessage(sampleQuestions[index]),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade50,
                foregroundColor: Colors.blue.shade700,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.blue.shade200),
                ),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              child: Text(sampleQuestions[index]),
            ),
          );
        },
      ),
    );
  }
}

class VideoPlayerDialog extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerDialog({super.key, required this.videoUrl});

  @override
  State<VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<VideoPlayerDialog> {
  VideoPlayerController? _videoController;
  // YouTube controller - temporarily disabled due to build issues
  // YoutubePlayerController? _youtubeController;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isYouTubeVideo = false;

  @override
  void initState() {
    super.initState();
    _isYouTubeVideo = _isYouTubeUrl(widget.videoUrl);
    if (_isYouTubeVideo) {
      _initializeYouTubePlayer();
    } else {
      _initializeVideoPlayer();
    }
  }

  bool _isYouTubeUrl(String url) {
    return url.contains('youtube.com') || url.contains('youtu.be');
  }

  String? _extractYouTubeVideoId(String url) {
    // Handle youtube.com URLs
    if (url.contains('youtube.com/watch?v=')) {
      return url.split('v=')[1].split('&')[0];
    }
    // Handle youtu.be URLs
    if (url.contains('youtu.be/')) {
      return url.split('youtu.be/')[1].split('?')[0];
    }
    return null;
  }

  Future<void> _initializeVideoPlayer() async {
    _videoController = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
    );
    try {
      await _videoController!.initialize();
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      print('Error initializing video: $e');
    }
  }

  void _initializeYouTubePlayer() {
    // YouTube player temporarily disabled due to build issues
    setState(() {
      _isInitialized = false; // Keep disabled
    });
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _youtubeController?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_isYouTubeVideo) {
      if (_youtubeController!.value.isPlaying) {
        _youtubeController!.pause();
      } else {
        _youtubeController!.play();
      }
      setState(() {
        _isPlaying = _youtubeController!.value.isPlaying;
      });
    } else {
      setState(() {
        if (_videoController!.value.isPlaying) {
          _videoController!.pause();
          _isPlaying = false;
        } else {
          _videoController!.play();
          _isPlaying = true;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            // Header with close button
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            // Video player
            Expanded(
              child: _isInitialized
                  ? _isYouTubeVideo
                        ? YoutubePlayer(
                            controller: _youtubeController!,
                            showVideoProgressIndicator: true,
                            progressIndicatorColor: Colors.blue,
                            progressColors: const ProgressBarColors(
                              playedColor: Colors.blue,
                              handleColor: Colors.blueAccent,
                            ),
                          )
                        : AspectRatio(
                            aspectRatio: _videoController!.value.aspectRatio,
                            child: VideoPlayer(_videoController!),
                          )
                  : const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
            ),
            // Controls (only for non-YouTube videos)
            if (_isInitialized && !_isYouTubeVideo)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 48,
                    ),
                    onPressed: _togglePlayPause,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
