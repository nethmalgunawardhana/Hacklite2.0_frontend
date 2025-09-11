import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? _controller;
  List<CameraDescription>? cameras;
  bool _isCameraInitialized = false;
  bool _isPermissionGranted = false;
  String _translationText = "Sign language translation will appear here...";
  String _statusText = "Initializing camera...";

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    final cameraStatus = await Permission.camera.request();
    await Permission.microphone.request();

    if (cameraStatus.isGranted) {
      setState(() {
        _isPermissionGranted = true;
        _statusText = "Permissions granted. Initializing camera...";
      });
      _initializeCamera();
    } else {
      setState(() {
        _statusText =
            "Camera permission denied. Please grant permission to use camera.";
      });
    }
  }

  Future<void> _initializeCamera() async {
    try {
      cameras = await availableCameras();
      if (cameras != null && cameras!.isNotEmpty) {
        _controller = CameraController(
          cameras![0], // Use the first available camera
          ResolutionPreset.medium,
        );

        await _controller!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
            _statusText = "Camera ready. Tap Start to begin translation.";
          });
        }
      } else {
        setState(() {
          _statusText = "No cameras found on this device.";
        });
      }
    } catch (e) {
      print('Error initializing camera: $e');
      setState(() {
        _statusText = "Error initializing camera: $e";
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Camera preview at the top
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.black,
              child: _isPermissionGranted
                  ? (_isCameraInitialized && _controller != null
                        ? CameraPreview(_controller!)
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _statusText,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ))
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _statusText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _requestPermissions,
                            child: const Text('Grant Permissions'),
                          ),
                        ],
                      ),
                    ),
            ),
          ),

          // Sign language translation section at the bottom
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(16.0),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sign Language Translation',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          _translationText,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isCameraInitialized
                            ? () {
                                // TODO: Implement start translation with ML model
                                setState(() {
                                  _translationText =
                                      "Starting sign language recognition...\n\nDetected gestures will appear here.";
                                });
                              }
                            : null,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Start'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          // TODO: Implement stop translation
                          setState(() {
                            _translationText =
                                "Sign language translation stopped.";
                          });
                        },
                        icon: const Icon(Icons.stop),
                        label: const Text('Stop'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
