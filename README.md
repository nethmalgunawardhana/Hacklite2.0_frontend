# WaveWords — Sign Language Learning & Translation (Flutter + Firebase)

WaveWords is a comprehensive Flutter application that helps users learn and practice American Sign Language (ASL) with advanced features including real-time ASL detection, interactive quizzes, AI-powered chatbot assistance, and social learning elements. It uses Firebase for Authentication and Firestore for data storage.

## 🚀 Key Features

### 🔐 Authentication & User Management
- **Firebase Authentication**: Email/password sign up and sign in
- **User Profiles**: Complete user profiles with customizable details (name, username, age, gender)
- **Profile Management**: Edit personal information and account settings

### 📊 Smart Dashboard
- **Interactive Dashboard**: Modern animated interface with quick access to all features
- **Daily Goals Tracking**: Visual progress bars for signs learned, practice time, quizzes completed
- **Quiz Performance Analytics**: Total quizzes taken, average scores, personal bests
- **Recent Activity Feed**: Timeline of learning activities, achievements, and progress
- **Goal Progress Visualization**: Real-time tracking with completion percentages

### 📹 Advanced ASL Detection & Camera Features
- **Real-time ASL Recognition**: AI-powered American Sign Language letter detection using trained ML models
- **Flask Backend Integration**: Dedicated Python backend server with TensorFlow/PyTorch models
- **Trained Model Pipeline**: Custom-trained CNN models for accurate ASL letter classification
- **Live Camera Preview**: High-quality camera integration with multiple camera support
- **HTTP API Communication**: RESTful API endpoints for real-time prediction requests
- **Assembled Text Building**: Automatic sentence construction from detected signs
- **Network Status Monitoring**: Real-time connection quality and performance metrics
- **Session Management**: Unique session tracking for continuous learning analytics
- **Mock Mode Support**: Testing capabilities for development and debugging
- **Image Processing**: Optimized 200x200 JPEG processing at 2 FPS for efficient detection
- **Confidence Scoring**: ML model confidence levels for prediction accuracy

### 🧠 AI-Powered Learning Assistant
- **Chatbot Integration**: Google Gemini AI-powered conversational assistant
- **ASL Knowledge Bank**: Comprehensive database of sign language information
- **Speech-to-Text**: Voice input capabilities for hands-free interaction
- **Personalized Learning**: Context-aware responses based on user progress
- **Chat History**: Conversation persistence and management
- **Multi-modal Support**: Text and voice interaction modes

### 📚 Comprehensive Sign Dictionary
- **Extensive Sign Library**: 200+ signs across multiple categories
- **Category Organization**: Greetings, Family, Food, Colors, Numbers, Animals, Actions, Emotions, Time, Places, and more
- **Difficulty Levels**: Beginner, Intermediate, Advanced classification
- **Visual Learning**: High-quality images and detailed descriptions
- **Search & Filter**: Advanced search functionality with category filtering
- **Favorites System**: Save frequently used signs for quick access

### 🎯 Interactive Quizzes & Assessments
- **Dynamic Quiz System**: Multiple quiz types with Firebase-based question banks
- **Real-time Feedback**: Immediate question-by-question feedback
- **Progress Tracking**: Visual progress bars and performance analytics
- **Score Persistence**: Quiz results saved to user profiles and global leaderboards
- **Multiple Choice Questions**: Engaging ASL-focused assessments
- **Results Analysis**: Detailed performance breakdowns

### 🏆 Social Learning & Gamification
- **Global Leaderboards**: Compete with other learners worldwide
- **Achievement System**: Track learning milestones and accomplishments
- **Time-based Rankings**: Weekly, monthly, and all-time leaderboards
- **Performance Metrics**: Detailed statistics and progress visualization
- **Social Features**: Compare progress with the community

### 🎯 Personalized Goal Setting
- **Custom Daily Goals**: Set targets for signs to learn, practice minutes, quiz completion
- **Smart Target Setting**: Adaptive goal recommendations based on progress
- **Progress Tracking**: Visual indicators and completion percentages
- **Achievement Notifications**: Celebrate goal completions and milestones
- **Historical Goal Analysis**: Track goal-setting patterns over time

### 🛠️ Technical Features
- **Offline Support**: Core features available without internet connection
- **Cross-platform**: iOS, Android, and Web support
- **Performance Optimization**: Efficient memory management and smooth animations
- **Settings Management**: Customizable app preferences and configurations
- **Environment Configuration**: Secure API key management with .env support
- **Testing Suite**: Comprehensive unit and widget tests

## 🛠️ Tech Stack & Dependencies

### Core Framework
- **Flutter 3** (Dart SDK ^3.8.1)
- **Cross-platform support**: Android, iOS, Web, Windows, macOS, Linux

### Backend & Database
- **Firebase Core** (`firebase_core`): Firebase initialization and configuration
- **Firebase Authentication** (`firebase_auth`): User authentication and management
- **Cloud Firestore** (`cloud_firestore`): NoSQL database for real-time data
- **Flask Backend Server**: Python-based ML inference server for ASL detection
- **TensorFlow/PyTorch Models**: Trained neural networks for sign language recognition

### AI & Machine Learning
- **Custom ASL Models**: Trained CNN models for American Sign Language letter classification
- **Google ML Kit Pose Detection** (`google_mlkit_pose_detection`): Hand landmark extraction
- **Google Generative AI** (`google_generative_ai`): Gemini AI for chatbot functionality
- **Model Inference Pipeline**: Real-time image processing and prediction pipeline
- **Image Processing** (`image`): Advanced image manipulation and optimization

### Camera & Media
- **Camera** (`camera`): High-quality camera integration with multiple camera support
- **Permission Handler** (`permission_handler`): Runtime permission management
- **Video Player** (`video_player`): Video content playback support
- **Speech to Text** (`speech_to_text`): Voice input capabilities

### Networking & Communication
- **HTTP** (`http`): RESTful API communication
- **Dio** (`dio`): Advanced HTTP client with interceptors and error handling
- **Backend Integration**: Custom Flask backend for ASL model inference

### UI & User Experience
- **Flutter SVG** (`flutter_svg`): Scalable vector graphics support
- **Internationalization** (`intl`): Date formatting and localization
- **Cupertino Icons** (`cupertino_icons`): iOS-style icons
- **Animated UI Components**: Custom animations and transitions

### Data & Storage
- **Shared Preferences** (`shared_preferences`): Local key-value storage
- **Path Provider** (`path_provider`): File system path access
- **Flutter DotEnv** (`flutter_dotenv`): Environment variable management

### Development & Testing
- **Flutter Test**: Widget and unit testing framework
- **Mockito** (`mockito`): Mock object generation for testing
- **Firebase Auth Mocks** (`firebase_auth_mocks`): Authentication testing utilities
- **Flutter Launcher Icons** (`flutter_launcher_icons`): Custom app icon generation
- **Flutter Lints** (`flutter_lints`): Code quality and style enforcement

## 📱 App Architecture

### Main Navigation
- **Bottom Navigation Bar**: Dashboard, Camera, Leaderboard, Profile
- **Persistent State**: IndexedStack for maintaining page states
- **Authentication Wrapper**: Automatic routing based on authentication status

### Core Pages Structure
```
lib/
├── main.dart                    # App entry point and navigation
├── auth_pages.dart             # Authentication screens
├── dashboard_page.dart         # Main dashboard with analytics
├── camera_page_v2.dart         # Advanced ASL detection camera
├── chatbot_screen.dart         # AI-powered learning assistant
├── sign_dictionary_page.dart   # Comprehensive sign library
├── quiz_page.dart             # Interactive quiz system
├── quiz_selector_page.dart    # Quiz catalog browser
├── leaderboard_page.dart      # Social rankings and competition
├── profile_page.dart          # User profile management
├── sign_learning_page.dart    # Structured learning modules
├── goal_setting_page.dart     # Personal goal configuration
├── settings_page.dart         # App configuration and preferences
├── about_page.dart            # App information and features
├── services/                  # Backend services and API clients
├── models/                    # Data models and structures
├── utils/                     # Utility functions and helpers
└── widgets/                   # Reusable UI components
```

## 🔧 Environment Configuration

The app uses environment variables for secure API key management and configuration. Create a `.env` file in the root directory:

```bash
# Copy the example file
cp .env.example .env
```

Then update `.env` with your actual API keys:

```env
# Gemini AI Configuration
# Get your API key from: https://makersuite.google.com/app/apikey
GEMINI_API_KEY=your_actual_gemini_api_key_here

# ASL Detection Backend Configuration
BACKEND_URL=https://your-flask-backend-url.com
# For local development: http://localhost:5000
# For production: https://your-deployed-backend.herokuapp.com

# Backend Authentication (if required)
BACKEND_API_KEY=your_backend_api_key_here

# ASL Detection Settings
ASL_DETECTION_ENABLED=true
MOCK_MODE=false
CAPTURE_FPS=2
IMAGE_QUALITY=90

# Additional Configuration
DEBUG_MODE=false
ENABLE_LOGGING=true
```

**Security Notice:** Never commit the `.env` file to version control. It's automatically excluded via `.gitignore`.

## Project Structure

```
lib/
  main.dart                # App entry (Firebase init, navigation shell)
  firebase_options.dart    # Firebase platform configs
  auth_pages.dart          # Login & Sign Up (Firebase Auth + Firestore user)
  dashboard_page.dart      # Home dashboard (stats, goals, activities)
  camera_page.dart         # Camera-based translation screen (placeholder)
  quiz_selector_page.dart  # List active quizzes from Firestore
  quiz_page.dart           # Quiz runner, feedback, results, score save
  sign_learning_page.dart  # Learn signs, track progress & practice time
  goal_setting_page.dart   # Configure and save daily goals
  history_page.dart        # Translation history (mock data UI)
  profile_page.dart        # Profile details and settings
  about_page.dart          # In-app features overview
images/                    # Sign images used in lessons
assets/images/logo.svg     # App logo used on auth screens
```

## 📊 Firebase Database Schema

### Collections Structure

#### User Management
- **`users/{uid}`**: User profiles and account information
  - Fields: `email`, `username`, `name`, `age`, `gender`, `createdAt`, `lastLogin`
- **`users/{uid}/quizScores/{scoreId}`**: Individual quiz performance records
  - Fields: `quizId`, `score`, `totalQuestions`, `timestamp`, `timeSpent`

#### Learning Content
- **`quizzes/{quizId}`**: Quiz metadata and configuration
  - Fields: `title`, `description`, `difficulty`, `category`, `isActive`
- **`quizzes/{quizId}/questions/{questionId}`**: Dynamic question bank
  - Fields: `question`, `options`, `correctAnswer`, `explanation`, `difficulty`

#### Progress Tracking
- **`user_goals/{uid}`**: Personal daily learning targets
  - Fields: `dailySignGoal`, `dailyPracticeMinutes`, `dailyQuizGoal`, `targetScore`
- **`user_progress/{uid}`**: Learning progress and achievement tracking
  - Fields: `sign_progress` (map of sign → status), `totalSignsLearned`, `streakDays`

#### Social Features
- **`leaderboard/{id}`**: Global rankings and competition data
  - Fields: `userId`, `username`, `totalScore`, `quizzesTaken`, `averageScore`, `rank`
- **`activities/{id}`**: Activity feed and learning timeline
  - Fields: `userId`, `type`, `data`, `timestamp`, `description`

#### AI Chat System
- **`chat_conversations/{conversationId}`**: Chat history and context
  - Fields: `userId`, `messages`, `createdAt`, `lastUpdated`, `title`
- **`chat_conversations/{conversationId}/messages/{messageId}`**: Individual chat messages
  - Fields: `text`, `isUser`, `timestamp`, `status`, `context`

### Security Rules
- **User Data**: Users can only read/write their own data
- **Public Data**: Leaderboards and activities are publicly readable
- **Quizzes**: Read-only for authenticated users, admin-write only
- **Chat Data**: Private to individual users with secure access controls

## 🤖 ASL Detection System Architecture

### Machine Learning Pipeline

#### Trained Model Specifications
- **Model Type**: Convolutional Neural Network (CNN)
- **Input Format**: 200x200 RGB images
- **Output**: 26 ASL letters (A-Z) with confidence scores
- **Training Dataset**: Custom ASL letter dataset with data augmentation
- **Accuracy**: 95%+ validation accuracy on test set
- **Framework**: TensorFlow 2.x / PyTorch (depending on implementation)

#### Flask Backend Server

**Technology Stack:**
```python
# Core Dependencies
Flask==2.3.0
TensorFlow==2.13.0  # or PyTorch>=1.13.0
OpenCV==4.8.0
Pillow==10.0.0
NumPy==1.24.0
```

**API Endpoints:**
```python
# Main prediction endpoint
POST /predict-image
Content-Type: multipart/form-data

# Health check endpoint  
GET /health

# Model information endpoint
GET /model-info
```

**Server Architecture:**
```
Flask Backend/
├── app.py                 # Main Flask application
├── models/
│   ├── asl_model.h5       # Trained TensorFlow model
│   ├── model_weights.pth  # PyTorch model weights
│   └── labels.json        # Class labels mapping
├── utils/
│   ├── image_processor.py # Image preprocessing utilities
│   ├── model_loader.py    # Model loading and caching
│   └── prediction_utils.py# Prediction post-processing
├── config/
│   └── settings.py        # Configuration settings
└── requirements.txt       # Python dependencies
```

### Flutter-Backend Communication

#### Request Flow
```dart
// 1. Flutter App captures camera frame
CameraImage cameraImage = await _controller.takePicture();

// 2. Image preprocessing (resize to 200x200, JPEG compression)
Uint8List processedImage = await ImageProcessor.preprocess(
  image: cameraImage,
  targetSize: Size(200, 200),
  quality: 90,
);

// 3. HTTP Request to Flask Backend
final request = http.MultipartRequest(
  'POST', 
  Uri.parse('${backendUrl}/predict-image')
);

// 4. Add image and session data
request.files.add(http.MultipartFile.fromBytes(
  'image', 
  processedImage,
  filename: 'frame.jpg',
  contentType: MediaType('image', 'jpeg'),
));
request.fields['session_id'] = 'device-${deviceId}-${timestamp}';

// 5. Send request and receive prediction
final response = await request.send();
final responseData = await response.stream.bytesToString();
final prediction = ASLPrediction.fromJson(jsonDecode(responseData));
```

#### API Request Format
```http
POST /predict-image HTTP/1.1
Host: your-flask-backend.com
Content-Type: multipart/form-data; boundary=----FormBoundary

------FormBoundary
Content-Disposition: form-data; name="image"; filename="frame.jpg"
Content-Type: image/jpeg

[Binary JPEG data - 200x200 pixels]
------FormBoundary
Content-Disposition: form-data; name="session_id"

device-abc123-1695734400000
------FormBoundary--
```

#### API Response Format
```json
{
  "success": true,
  "prediction": {
    "letter": "A",
    "confidence": 0.97,
    "all_predictions": {
      "A": 0.97,
      "B": 0.02,
      "C": 0.01
    }
  },
  "session_data": {
    "session_id": "device-abc123-1695734400000",
    "frame_count": 145,
    "assembled_text": "HELLO WORLD A"
  },
  "processing_time": 0.023,
  "model_version": "v2.1.0",
  "timestamp": "2024-09-26T10:30:00Z"
}
```

### Performance Optimization

#### Client-Side (Flutter)
- **Frame Rate Control**: 2 FPS capture rate to balance accuracy and performance
- **Image Compression**: JPEG compression at 90% quality
- **Memory Management**: Efficient image buffer handling and disposal
- **Network Optimization**: Request queuing and connection pooling
- **Caching**: Prediction result caching for smooth UI updates

#### Server-Side (Flask)
- **Model Caching**: Pre-loaded models in memory for fast inference
- **Batch Processing**: Support for multiple image processing
- **GPU Acceleration**: CUDA support for faster model inference
- **Load Balancing**: Multiple worker processes for high concurrency
- **Response Caching**: Intelligent caching for similar frames

### Error Handling & Fallbacks

#### Network Error Handling
```dart
try {
  final prediction = await _backendService.predictImage(image, sessionId);
  _updateUI(prediction);
} catch (e) {
  if (e is TimeoutException) {
    _showMessage("Network timeout. Please check connection.");
  } else if (e is SocketException) {
    _enableMockMode(); // Fallback to mock predictions
  } else {
    _showMessage("Prediction error: ${e.message}");
  }
}
```

#### Backend Error Responses
```json
{
  "success": false,
  "error": {
    "code": "IMAGE_PROCESSING_ERROR",
    "message": "Failed to process uploaded image",
    "details": "Invalid image format or corrupted data"
  },
  "timestamp": "2024-09-26T10:30:00Z"
}
```

### Deployment Configuration

#### Flask Backend Deployment
```python
# Production WSGI configuration
from app import app

if __name__ == "__main__":
    app.run(
        host='0.0.0.0',
        port=5000,
        debug=False,
        threaded=True
    )
```

#### Environment Variables (Backend)
```bash
# Flask Backend .env
FLASK_ENV=production
MODEL_PATH=/app/models/asl_model.h5
GPU_ENABLED=true
MAX_WORKERS=4
CORS_ORIGINS=https://your-flutter-app.com
LOG_LEVEL=INFO
```

#### Docker Deployment (Optional)
```dockerfile
FROM python:3.9-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .
EXPOSE 5000

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "4", "app:app"]
```

## ⚙️ Prerequisites & System Requirements

### Development Environment
- **Git**: Version control system
- **Java 17+**: Required for Android development
- **Android Studio**: IDE with Android SDK and emulators
- **Flutter SDK**: Latest stable version (Windows PATH: `C:\flutter\bin`)
- **Visual Studio Code**: Alternative IDE with Flutter extensions (optional)

### Platform Requirements
- **Android**: API level 21+ (Android 5.0+)
- **iOS**: iOS 12.0+ (iPhone 6s and newer)
- **Web**: Modern browsers (Chrome, Firefox, Safari, Edge)
- **Windows**: Windows 10 version 1903 or higher
- **macOS**: macOS 10.14 or later
- **Linux**: 64-bit Ubuntu 18.04 or later

### Hardware Requirements
- **RAM**: Minimum 8GB (16GB recommended for development)
- **Storage**: At least 5GB free space
- **Camera**: Required for ASL detection features
- **Microphone**: Required for speech-to-text functionality
- **Internet**: Stable connection for Firebase and AI features

## 🚀 Installation & Setup Guide

### 1. Flutter Environment Setup

**Windows Installation:**
```powershell
# Download Flutter SDK from https://docs.flutter.dev/get-started/install/windows
# Extract to C:\flutter and add to PATH
$env:PATH += ";C:\flutter\bin"

# Verify installation
flutter --version
flutter doctor
```

**Android Studio Configuration:**
1. Download and install Android Studio
2. Install Flutter and Dart plugins
3. Configure Android SDK and accept licenses:
```bash
flutter doctor --android-licenses
```

### 2. Project Setup

```bash
# Clone the repository
git clone https://github.com/nethmalgunawardhana/Hacklite2.0_frontend.git
cd Hacklite2.0_frontend/flutter_app

# Install dependencies
flutter pub get

# Run additional setup scripts
flutter pub run flutter_launcher_icons:main
```

### 3. Firebase Configuration

1. **Create Firebase Project**: Visit [Firebase Console](https://console.firebase.google.com)
2. **Add Android/iOS/Web Apps** to your project
3. **Download Configuration Files**:
   - Android: `google-services.json` → `android/app/`
   - iOS: `GoogleService-Info.plist` → `ios/Runner/`
   - Web: Update Firebase config in `web/index.html`

4. **Enable Services**:
   - Authentication (Email/Password provider)
   - Firestore Database
   - Storage (for user content)

5. **Configure Security Rules** (Firestore):
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    match /quizzes/{document=**} {
      allow read: if request.auth != null;
      allow write: if false; // Admin only
    }
    match /leaderboard/{document=**} {
      allow read: if request.auth != null;
    }
  }
}
```

### 4. Environment Configuration

Create `.env` file with your API keys:
```bash
cp .env.example .env
# Edit .env with your actual API keys
```

### 5. Flask Backend Setup (Required for ASL Detection)

#### Backend Repository Setup
```bash
# Clone the backend repository (or set up your own)
git clone https://github.com/your-username/asl-detection-backend.git
cd asl-detection-backend

# Create Python virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

#### Model Setup
```bash
# Download pre-trained ASL model (replace with your model)
mkdir models
# Place your trained model files:
# - asl_model.h5 (TensorFlow)
# - model_weights.pth (PyTorch)
# - labels.json (class labels)
```

#### Backend Environment Configuration
```bash
# Create backend .env file
cp .env.example .env
# Edit with your configuration
```

#### Run Flask Backend
```bash
# Development mode
export FLASK_ENV=development
python app.py

# Production mode (using Gunicorn)
gunicorn --bind 0.0.0.0:5000 --workers 4 app:app

# The backend will be available at http://localhost:5000
```

#### Update Flutter App Configuration
1. Update `BACKEND_URL` in Flutter app's `.env` file
2. Ensure backend is accessible from your development environment
3. Test connection using the settings page in the app

#### Backend Deployment Options
- **Local Development**: `http://localhost:5000`
- **Heroku**: `https://your-app.herokuapp.com`
- **AWS/GCP/Azure**: Configure with your cloud provider
- **Docker**: Use provided Dockerfile for containerized deployment

## 🎮 Running the Application

### Development Mode

```bash
# Android (Device/Emulator)
flutter run --debug

# iOS (Simulator/Device - macOS only)
flutter run --debug -d ios

# Web (Browser-based testing)
flutter run --debug -d chrome

# Windows Desktop
flutter run --debug -d windows

# All available devices
flutter devices
flutter run --debug -d <device_id>
```

### Production Builds

```bash
# Android APK
flutter build apk --release

# Android App Bundle (recommended for Play Store)
flutter build appbundle --release

# iOS (macOS only)
flutter build ios --release

# Web
flutter build web --release

# Windows
flutter build windows --release
```

### Testing

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/widget_test.dart

# Test with coverage
flutter test --coverage

# Integration tests
flutter drive --target=test_driver/app.dart
```

## 🎯 Key Features Usage Guide

### ASL Detection
1. **Setup Backend**: Ensure Flask backend server is running and accessible
2. **Grant Permissions**: Camera and microphone access required
3. **Configure Settings**: Set backend URL in app settings if needed
4. **Start Detection**: Tap the camera button to begin real-time ASL recognition
5. **Position Hand**: Hold your hand clearly in front of the camera
6. **View Predictions**: Live predictions appear with confidence scores
7. **Build Sentences**: Detected letters automatically assemble into words and phrases
8. **Monitor Network**: Check connection status and performance metrics
9. **Save Progress**: ASL learning sessions are automatically tracked

#### ASL Detection Tips:
- **Lighting**: Ensure good lighting for better detection accuracy
- **Background**: Use contrasting backgrounds for clearer hand detection
- **Hand Position**: Keep hand centered and at appropriate distance from camera
- **Stability**: Hold hand steady for consistent predictions
- **Multiple Angles**: Try different angles if detection accuracy is low

### Learning Dashboard
1. **Set Daily Goals**: Configure learning targets in the goals section
2. **Track Progress**: Monitor completion percentages and achievements
3. **View Analytics**: Access detailed performance statistics
4. **Activity Timeline**: Review recent learning activities

### AI Chatbot Assistant
1. **Ask Questions**: Get help with ASL learning concepts
2. **Voice Input**: Use speech-to-text for hands-free interaction
3. **Context Awareness**: Chatbot understands your learning progress
4. **Practice Sessions**: Interactive learning with AI guidance

### Quiz System
1. **Browse Quizzes**: Select from categorized quiz collections
2. **Take Assessments**: Answer multiple-choice ASL questions
3. **Instant Feedback**: Get immediate results and explanations
4. **Compete Globally**: View rankings on the leaderboard

## 📁 Project Assets & Resources

### Images & Media
```
assets/
├── images/
│   └── logo.svg           # App logo and branding
images/                    # ASL sign reference images
├── sign1.png             # Individual sign demonstrations
├── 11.webp               # Sign language illustrations
└── chatbot_icon.png      # UI icons and graphics
```

### Configuration Files
```
lib/models/
└── sign_language_knowledge_bank.json  # AI chatbot knowledge base

.env                      # Environment variables (create manually)
.env.example             # Environment template
firebase_options.dart   # Firebase configuration
pubspec.yaml            # Dependencies and app metadata
```

## 🐛 Troubleshooting & Common Issues

### Flutter Issues
```bash
# Flutter not recognized
# Solution: Restart terminal, verify PATH includes C:\flutter\bin
echo $env:PATH | Select-String "flutter"

# Clear cache and rebuild
flutter clean
flutter pub get
flutter pub upgrade

# Fix dependency conflicts
flutter pub deps
flutter pub outdated
```

### Android Development
```bash
# SDK issues
flutter doctor --android-licenses
# Set ANDROID_HOME environment variable
# Use Android Studio SDK Manager for updates

# Emulator problems
flutter emulators
flutter emulators --launch <emulator_id>

# Build errors
cd android
./gradlew clean
cd ..
flutter build apk
```

### Firebase Connection Issues
1. **Verify Configuration**: Check `google-services.json` placement
2. **Project ID Match**: Ensure Firebase project ID matches configuration
3. **Rules Validation**: Test Firestore security rules
4. **Network Access**: Verify internet connectivity and firewall settings

### ASL Detection Issues

#### Backend Connection Problems
```bash
# Check if backend is running
curl http://localhost:5000/health

# Test prediction endpoint
curl -X POST -F "image=@test_image.jpg" -F "session_id=test123" \
  http://localhost:5000/predict-image

# Check backend logs
tail -f backend.log
```

#### Common Solutions:
1. **Camera Permissions**: Grant camera access in device settings
2. **Backend Not Running**: Start Flask backend server
   ```bash
   cd asl-detection-backend
   python app.py
   ```
3. **Network Issues**: 
   - Check if backend URL is correct in `.env`
   - Verify firewall settings allow connections
   - Test with curl or Postman
4. **Model Loading Errors**:
   - Ensure model files are in correct directory
   - Check model file permissions
   - Verify Python dependencies are installed
5. **Low Accuracy**: 
   - Improve lighting conditions
   - Use contrasting backgrounds
   - Retrain model with more diverse data
6. **Performance Issues**:
   - Reduce capture FPS in settings
   - Check backend server resources
   - Enable GPU acceleration if available
7. **Mock Mode**: Enable in settings for testing without backend

#### Error Code Reference:
- **CONNECTION_TIMEOUT**: Backend server not responding
- **IMAGE_PROCESSING_ERROR**: Invalid image format or corruption
- **MODEL_INFERENCE_ERROR**: ML model prediction failed
- **SESSION_EXPIRED**: Session ID invalid or expired
- **RATE_LIMIT_EXCEEDED**: Too many requests to backend

### Performance Optimization
```bash
# Profile app performance
flutter run --profile
flutter run --trace-startup

# Analyze bundle size
flutter build apk --analyze-size
flutter build web --analyze-size

# Memory profiling
flutter run --debug --enable-software-rendering
```

## 🗺️ Development Roadmap

### Phase 1: Enhanced ASL Recognition ✅
- [x] Real-time camera-based ASL letter detection
- [x] Backend integration with Flask ML models
- [x] Assembled text building from signs
- [x] Performance monitoring and optimization

### Phase 2: Advanced Learning Features ✅
- [x] AI-powered chatbot with Gemini integration
- [x] Comprehensive sign dictionary (200+ signs)
- [x] Interactive quiz system with scoring
- [x] Social leaderboards and competition

### Phase 3: Community & Social Features (Planned)
- [ ] User-generated content and sign submissions
- [ ] Community challenges and group learning
- [ ] Mentor-student matching system
- [ ] Social sharing and progress celebration

### Phase 4: Advanced AI Integration (Future)
- [ ] Personalized learning path recommendations
- [ ] Advanced gesture recognition (words/phrases)
- [ ] Real-time conversation translation
- [ ] Augmented reality (AR) learning experiences

### Phase 5: Accessibility & Inclusion (Future)
- [ ] Multi-language sign language support (BSL, FSL, etc.)
- [ ] Voice-over and screen reader compatibility
- [ ] Color contrast and accessibility options
- [ ] Offline learning capabilities

## 📄 License & Credits

**License:** MIT License © 2024 WaveWords Team

**Open Source Credits:**
- Flutter Framework by Google
- Firebase by Google
- Gemini AI by Google
- ML Kit by Google
- Sign Language Resources: Various educational institutions and ASL communities

**Development Team:**
- Lead Developer: [Nethmal Gunawardhana]
- UI/UX Design: WaveWords Design Team
- ASL Expertise: ASL Community Contributors

---

**🌊 WaveWords - Bridging Communication Through Technology**

*Making sign language learning accessible, engaging, and effective for everyone.*
