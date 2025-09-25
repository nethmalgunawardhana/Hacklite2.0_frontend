# ASL Letter Recognition Flutter App

This Flutter app captures images from the camera and sends them to a Flask backend for American Sign Language (ASL) letter recognition.

## ✅ Implementation Status

All requested features have been implemented:

### Core Features

- **Camera Integration**: ✅ Using camera plugin with preview
- **Image Processing**: ✅ JPEG format, 200x200 resizing, 90% quality
- **HTTP Communication**: ✅ Multipart/form-data with `image` and `session_id` fields
- **Backend Integration**: ✅ POST to `/predict-image` endpoint
- **UI Features**: ✅ Camera preview, capture controls, prediction display
- **Error Handling**: ✅ Network, permissions, backend errors
- **Performance**: ✅ 2 FPS capture rate, efficient memory management

### Technical Implementation

#### Backend Communication

- **Endpoint**: `POST /predict-image`
- **Format**: `multipart/form-data`
- **Fields**:
  - `image`: JPEG image file (200x200, 90% quality)
  - `session_id`: Unique identifier (`device-{uniqueId}-{timestamp}`)
- **Response**: JSON with predictions, confidence scores, assembled text

#### Key Components

1. **BackendPredictionService** (`lib/services/backend_prediction_service.dart`)

   - Handles image capture and HTTP requests
   - Manages session IDs and network performance
   - Implements retry logic and error handling
   - Supports mock mode for testing

2. **ASLDetectionServiceV2** (`lib/services/asl_detection_service_v2.dart`)

   - Orchestrates camera stream and backend service
   - Provides reactive streams for UI updates
   - Manages detection lifecycle

3. **CameraPageV2** (`lib/camera_page_v2.dart`)

   - Main UI with camera preview
   - Real-time prediction display
   - Network status monitoring
   - Settings access

4. **SettingsPage** (`lib/settings_page.dart`)
   - Configure backend URL at runtime
   - Connection testing
   - Validation and persistence

#### Configuration

The app supports multiple configuration methods:

1. **Environment Variables** (highest priority):

   ```bash
   flutter run --dart-define=ASL_BACKEND_URL=http://your-server:5000
   ```

2. **Runtime Settings** (via Settings page):

   - Users can change backend URL in the app
   - Saved using SharedPreferences

3. **Environment File** (`.env`):
   ```properties
   ASL_BACKEND_URL=http://localhost:5000
   USE_LOCAL_MOCK=false
   ```

## 🚀 Usage

### Running the App

1. **Install Dependencies**:

   ```bash
   flutter pub get
   ```

2. **Start Backend Server**:
   Make sure your Flask backend is running on the configured URL

3. **Run Flutter App**:
   ```bash
   flutter run
   ```

### Using the Camera Page

1. **Grant Permissions**: Allow camera access when prompted
2. **Start Detection**: Tap "Start Detection" button
3. **Show Hand Signs**: Position your hand in front of the camera
4. **View Results**: See live predictions and assembled text
5. **Configure Backend**: Tap settings icon to change backend URL

### Backend Requirements

Your Flask backend should implement:

```python
@app.route('/predict-image', methods=['POST'])
def predict_image():
    # Get multipart data
    image_file = request.files.get('image')
    session_id = request.form.get('session_id')

    # Process image and return JSON
    return {
        "predictions": [
            {"label": "a", "score": 0.94},
            {"label": "space", "score": 0.03}
        ],
        "top_prediction": {"label": "a", "score": 0.94},
        "predicted_label": "a",
        "assembled_text": "HELLO A"
    }

@app.route('/health', methods=['GET'])
def health_check():
    return {"status": "healthy"}
```

## 📱 UI Features

- **Modern Design**: Gradient backgrounds, rounded corners, shadows
- **Real-time Status**: Live prediction display with confidence scores
- **Network Monitoring**: Connection health, latency, success rates
- **Settings Management**: Easy backend configuration
- **Error Handling**: User-friendly error messages
- **Mock Mode**: Testing without backend server

## ⚙️ Performance Optimizations

- **Adaptive Frame Rate**: 2 FPS default (configurable 0.5-5 FPS)
- **Frame Difference Detection**: Only upload significant changes
- **Prediction Smoothing**: Buffer to reduce flicker
- **Memory Management**: Efficient image processing
- **Network Retry**: Automatic retry with backoff
- **Health Monitoring**: Periodic backend connectivity checks

## 🔧 Development Features

- **Mock Mode**: Test without backend (`USE_LOCAL_MOCK=true`)
- **Network Stats**: Performance monitoring and debugging
- **Comprehensive Logging**: Detailed debug information
- **Error Recovery**: Graceful handling of failures
- **Session Persistence**: Unique device/session tracking

## 📚 Dependencies

Key packages used:

- `camera`: Camera functionality
- `dio`: HTTP client with multipart support
- `image`: Image processing and resizing
- `permission_handler`: Camera permissions
- `path_provider`: File system access
- `shared_preferences`: Settings persistence

## 🧪 Testing

The app includes mock mode for testing without a backend:

1. Set `USE_LOCAL_MOCK=true` in `.env`
2. App will simulate backend responses
3. Useful for UI development and testing

## 📋 Requirements Checklist

- ✅ Camera integration with preview
- ✅ JPEG image capture and processing
- ✅ Square aspect ratio resizing (200x200)
- ✅ High quality compression (90%)
- ✅ HTTP multipart/form-data requests
- ✅ Proper field names (`image`, `session_id`)
- ✅ Configurable backend URL
- ✅ JSON response handling
- ✅ Real-time prediction display
- ✅ Assembled text from session
- ✅ Settings UI for configuration
- ✅ Network error handling
- ✅ Camera permission management
- ✅ Backend error handling
- ✅ Efficient performance (2 FPS)
- ✅ Continuous prediction mode
- ✅ Memory management
- ✅ Proper async/await patterns
- ✅ Loading states and feedback
- ✅ Session ID format compliance
- ✅ Error response handling

All requirements have been fully implemented! 🎉
