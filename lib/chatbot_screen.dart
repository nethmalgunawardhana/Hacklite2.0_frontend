import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
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

  // Speech to text
  late stt.SpeechToText _speechToText;
  bool _isListening = false;
  String _lastWords = '';

  // Knowledge bank
  Map<String, dynamic>? _knowledgeBank;

  // Gemini AI
  late GenerativeModel _model;

  @override
  void initState() {
    super.initState();
    _speechToText = stt.SpeechToText();
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
    _speechToText.stop();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addWelcomeMessage() {
    const welcomeText =
        "Hello! I'm your AI assistant. How can I help you today?";
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
      // Fallback to simple responses for non-sign language queries
      final responses = [
        "I understand you're asking about: $userMessage. Let me help you with that.",
        "That's an interesting question! Based on what you've shared, here's what I think...",
        "Thanks for your message. I'd be happy to assist you with that.",
        "I see you mentioned: $userMessage. Here's some information that might help...",
      ];
      return responses[DateTime.now().millisecondsSinceEpoch %
          responses.length];
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

      // First, try to find the specific sign the user is asking about
      final signWord = _extractSignFromQuery(userMessage.toLowerCase());
      print('DEBUG: Extracted sign word: $signWord');

      if (signWord != null) {
        // Look up the sign in the knowledge bank
        final signData = signs.firstWhere(
          (sign) =>
              sign['word'].toString().toLowerCase() == signWord.toLowerCase(),
          orElse: () => null,
        );

        if (signData != null) {
          final description = signData['description'] as String;
          final videoUrl = signData['video_url'] as String;
          print(
            'DEBUG: Found sign $signWord, description: $description, videoUrl: $videoUrl',
          );
          final response =
              'Here\'s how to sign "$signWord":\n\n$description\n\n📹 Watch the video tutorial: $videoUrl';
          print('DEBUG: Returning response: $response');
          return response;
        } else {
          print('DEBUG: Sign word "$signWord" not found in knowledge bank');
        }
      } else {
        print('DEBUG: No sign word extracted from query');
      }

      // If no specific sign found, use AI to generate a general response
      final prompt =
          '''
You are a sign language assistant. The user asked: "$userMessage"

Available signs in our knowledge bank: ${signs.map((s) => s['word']).join(', ')}

Categories: ${categories.keys.join(', ')}

Please analyze the user's query and provide helpful information about sign language learning.
If they ask generally about sign language, provide helpful information.
If they ask for a category, list the signs in that category.

Keep responses concise and helpful.
''';

      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text ??
          'Sorry, I couldn\'t generate a response right now.';
    } catch (e) {
      print('Error generating sign language response: $e');
      return 'Sorry, I encountered an error while processing your sign language query.';
    }
  }

  String? _extractSignFromQuery(String query) {
    final signs = _knowledgeBank!['signs'] as List<dynamic>;

    // Common patterns for asking about signs
    final patterns = [
      RegExp(r'how (?:do you|to) sign (.+?)(?:\?|$|\s)', caseSensitive: false),
      RegExp(r'what is the sign for (.+?)(?:\?|$|\s)', caseSensitive: false),
      RegExp(r'show me (.+?) sign', caseSensitive: false),
      RegExp(r'sign for (.+?)(?:\?|$|\s)', caseSensitive: false),
      RegExp(r'(.+?) sign language', caseSensitive: false),
      RegExp(r'asl for (.+?)(?:\?|$|\s)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(query);
      if (match != null && match.groupCount >= 1) {
        final extractedWord = match.group(1)?.trim().toLowerCase();
        if (extractedWord != null) {
          // Check if the extracted word matches any sign in our knowledge bank
          final signExists = signs.any(
            (sign) => sign['word'].toString().toLowerCase() == extractedWord,
          );
          if (signExists) {
            print('DEBUG: Extracted sign word: $extractedWord');
            return extractedWord;
          }
        }
      }
    }

    return null;
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
    if (!_isListening) {
      bool available = await _speechToText.initialize(
        onError: (error) =>
            print('Speech recognition error: $error'), // ignore: avoid_print
        onStatus: (status) =>
            print('Speech recognition status: $status'), // ignore: avoid_print
      );

      if (available) {
        setState(() => _isListening = true);

        _speechToText.listen(
          onResult: (result) {
            setState(() {
              _lastWords = result.recognizedWords;
              _textController.text = _lastWords;
            });

            if (result.finalResult) {
              _stopListening();
            }
          },
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
          partialResults: true, // ignore: deprecated_member_use
          cancelOnError: true, // ignore: deprecated_member_use
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Speech recognition not available on this device'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } else {
      _stopListening();
    }
  }

  Future<void> _stopListening() async {
    await _speechToText.stop();
    setState(() => _isListening = false);
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
                'AI Assistant',
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
            _buildInputArea(),
          ],
        ),
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
  YoutubePlayerController? _youtubeController;
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
    final videoId = _extractYouTubeVideoId(widget.videoUrl);
    if (videoId != null) {
      _youtubeController = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: false,
          mute: false,
          enableCaption: true,
        ),
      );
      setState(() {
        _isInitialized = true;
      });
    }
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
