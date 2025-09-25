# Backend Integration Setup Guide

This guide will help you set up the backend integration for the WaveWords ASL recognition app.

## Prerequisites

1. **ASL Recognition Backend Server**: You need a running Python backend server with the following endpoints:

   - `GET /health` - Health check endpoint
   - `POST /predict-image` - ASL prediction endpoint

2. **Flutter Development Environment**: Ensure you have Flutter 3.8.1+ installed.

## Setup Instructions

### Step 1: Environment Configuration

1. Create a `.env` file in the `assets/` directory:

   ```
   ASL_BACKEND_URL=http://your-backend-server:port
   ```

2. Replace `http://your-backend-server:port` with your actual backend server URL.

### Step 2: Update Assets

Make sure your `pubspec.yaml` includes the .env file in assets:

```yaml
flutter:
  assets:
    - assets/.env
    - assets/images/
    - assets/models/
```

### Step 3: Test Backend Connection

1. Run the Flutter app
2. Navigate to **Enhanced Dashboard** (you can modify main.dart to use EnhancedDashboard instead of DashboardPage)
3. Tap on "Backend Connection Test"
4. Test your backend connectivity

### Step 4: Configure Detection Mode

1. Go to "ASL Detection Settings" from the Enhanced Dashboard
2. Configure your preferred detection mode:
   - **Backend API Only**: Uses only your backend server
   - **Local ML Kit Only**: Uses only local Google ML Kit
   - **Hybrid**: Uses both (recommended) - falls back to ML Kit if backend fails

### Step 5: Use Enhanced ASL Detection

1. From Enhanced Dashboard, tap "Enhanced ASL Detection"
2. This will open the camera with backend integration
3. The detection will use your configured mode

## API Integration Details

### Backend API Requirements

Your backend server should support these endpoints:

#### Health Check

```
GET /health
Response: {"status": "healthy"}
```

#### ASL Prediction

```
POST /predict-image
Content-Type: multipart/form-data or application/json

Multipart Form Data:
- image: binary image file
- session_id: string (optional)

JSON Format:
- image_base64: base64 encoded image
- session_id: string (optional)

Response:
{
  "prediction": "A",  // Single letter prediction
  "confidence": 0.95,
  "session_text": "HELLO" // Assembled text from session
}
```

### Session Management

The app supports session-based text assembly:

- Each camera session gets a unique session ID
- The backend can accumulate predictions into words/sentences
- Use `session_text` in responses for assembled text

## Files Created/Modified

- `lib/services/asl_backend_service.dart` - Backend API communication
- `lib/services/asl_detection_service_v2.dart` - Enhanced detection service
- `lib/pages/enhanced_camera_page.dart` - Camera with backend integration
- `lib/pages/backend_test_page.dart` - Backend testing interface
- `lib/pages/asl_settings_page.dart` - Configuration settings
- `lib/pages/enhanced_dashboard.dart` - Enhanced navigation dashboard
- `assets/.env` - Environment configuration

## Troubleshooting

### Common Issues

1. **Backend Connection Failed**

   - Check if your backend server is running
   - Verify the URL in `.env` file
   - Test with "Backend Connection Test" page

2. **Detection Not Working**

   - Try different detection modes in settings
   - Check camera permissions
   - Verify backend API response format

3. **Import Errors**
   - Run `flutter clean` and `flutter pub get`
   - Check that all dependencies are installed

### Debug Mode

The enhanced camera page shows real-time status:

- Green dot: Backend connected
- Red dot: Backend disconnected
- Status text shows current detection mode

## Next Steps

1. Deploy your ASL recognition backend server
2. Update the `.env` file with your server URL
3. Test the integration using the test page
4. Configure your preferred detection mode
5. Start using enhanced ASL detection!

For additional support, check the in-app backend test page which provides detailed connection diagnostics.
