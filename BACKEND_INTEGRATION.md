# Backend ASL Detection Integration

This document explains the implementation of backend ASL prediction integration that replaces local on-device prediction with server-side API calls.

## 🚀 Features Implemented

### ✅ Backend Integration

- Real-time camera frame upload to ASL prediction API
- Multipart/form-data image uploads (JPEG, 200x200px)
- Session-based tracking with persistent device IDs
- Configurable upload frequency (1-5 FPS)
- Automatic retry logic with exponential backoff
- Network health monitoring and statistics

### ✅ Image Processing Pipeline

- Camera frame capture and conversion
- On-device image resizing to 200x200 pixels
- YUV to RGB color space conversion
- JPEG compression with quality optimization
- Frame difference detection for stability

### ✅ UX Enhancements

- Smoothing buffer to reduce prediction flicker
- Real-time assembled text display from backend
- Network latency and server health indicators
- Configurable FPS controls (1-5 FPS)
- Mock mode for development and testing

### ✅ Error Handling

- Network failure resilience with retry attempts
- Graceful degradation on server errors
- Automatic frequency adjustment on failures
- Comprehensive error logging and user feedback

## 📁 Architecture

```
lib/
├── services/
│   ├── backend_prediction_service.dart      # Main API client
│   ├── asl_detection_service_v2.dart       # Enhanced detection service
│   ├── device_session_manager.dart         # Session ID management
│   └── environment_config.dart             # Configuration management
├── models/
│   ├── backend_response.dart               # API response models
│   └── asl_prediction.dart                 # Enhanced prediction model
├── camera_page_v2.dart                     # New backend-integrated UI
└── test/
    └── backend_prediction_test.dart        # Unit tests
```

## ⚙️ Configuration

### Environment Variables (.env)

```env
# Backend server endpoint
ASL_BACKEND_URL=http://192.168.8.102:5000

# Development mode (uses mock responses)
USE_LOCAL_MOCK=false
```

### Runtime Configuration

- **Upload Frequency**: 1-5 FPS (default: 3 FPS / 333ms intervals)
- **Image Size**: 200x200 pixels JPEG
- **Retry Policy**: 3 attempts with 2s exponential backoff
- **Smoothing Buffer**: 3-frame majority voting
- **Frame Difference Threshold**: 10% change detection

## 🔌 API Integration

### Request Format

```http
POST /predict-image
Content-Type: multipart/form-data

form-data:
  image: (file) frame.jpg
  session_id: "device-abc123-1234567890"
```

### Response Format

```json
{
  "predictions": [
    { "label": "hello", "score": 0.89 },
    { "label": "hi", "score": 0.08 }
  ],
  "top_prediction": { "label": "hello", "score": 0.89 },
  "predicted_label": "hello",
  "assembled_text": "HELLO WORLD"
}
```

### Health Check

```http
GET /health
```

## 🎮 Usage Instructions

### 1. Configuration Setup

1. **Update .env file** with your backend server URL
2. **Set mock mode** (`USE_LOCAL_MOCK=true`) for testing without server
3. **Ensure network connectivity** to backend server

### 2. Using the App

1. **Launch app** and navigate to Camera tab (now uses backend)
2. **Grant camera permissions** when prompted
3. **Select detection frequency** (1-5 FPS) using UI controls
4. **Tap "Start Detection"** to begin backend ASL recognition
5. **Monitor network status** in real-time (latency, success rate)
6. **View assembled text** from backend response
7. **Tap "Stop"** to end detection session

### 3. Network Status Indicators

- 🟢 **Green**: Server healthy, low latency
- 🔴 **Red**: Server issues or high latency
- **Metrics**: `{latency}ms • {success_rate}% • {fps}FPS`

## 🧪 Testing

### Unit Tests

```bash
flutter test test/backend_prediction_test.dart
```

### Mock Mode Testing

```env
USE_LOCAL_MOCK=true
```

### Integration Testing

1. Set up backend server at configured URL
2. Run app with `USE_LOCAL_MOCK=false`
3. Test various network conditions
4. Verify error handling and retry logic

## 🔧 Development Features

### Mock Mode

- Simulates backend responses without server
- Provides realistic test data for UI development
- Configurable via `USE_LOCAL_MOCK` environment variable

### Debug Features

- Comprehensive console logging
- Network performance metrics
- Frame processing statistics
- Error tracking and reporting

### Performance Optimizations

- Efficient YUV to RGB conversion
- Smart frame difference detection
- Adaptive upload frequency
- Memory-conscious image processing

## 📊 Performance Metrics

### Typical Performance

- **Image Processing**: ~10-50ms per frame
- **Network Request**: ~100-500ms (varies by connection)
- **Total Latency**: ~150-600ms end-to-end
- **Memory Usage**: Low (streams without buffering)
- **Battery Impact**: Moderate (camera + network usage)

### Optimization Guidelines

- Use lower FPS (1-2) for battery conservation
- Monitor network stats for optimal frequency
- Enable mock mode for UI development
- Consider frame difference threshold adjustment

## 🚧 Migration from Local Prediction

The new backend integration (`CameraPageV2`) replaces the previous local ML Kit implementation while maintaining similar UI patterns:

### Breaking Changes

- Prediction results now include `assembledText` from backend
- Detection frequency is configurable at runtime
- Network connectivity required (unless in mock mode)
- Session-based tracking replaces stateless detection

### Backward Compatibility

- Original `CameraPage` remains available
- Same `ASLPrediction` model structure
- Consistent UI interaction patterns
- Gradual migration path available

## 🔐 Security Considerations

- **Session IDs**: Unique per device, persistent across sessions
- **Image Data**: Transmitted as multipart uploads, not stored
- **Network Security**: Uses standard HTTPS in production
- **Privacy**: No personal data transmitted beyond hand images

---

**Status**: ✅ Production Ready | 🚀 Backend Integration Complete

This implementation provides a robust foundation for server-side ASL prediction with excellent error handling, performance monitoring, and development features.
