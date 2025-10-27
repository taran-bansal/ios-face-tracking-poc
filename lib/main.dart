import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'dart:async';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Face Tracking Test',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const FaceTrackingTest(),
    );
  }
}

class FaceTrackingTest extends StatefulWidget {
  const FaceTrackingTest({super.key});

  @override
  State<FaceTrackingTest> createState() => _FaceTrackingTestState();
}

class _FaceTrackingTestState extends State<FaceTrackingTest> {
  CameraController? _cameraController;
  late FaceDetector _faceDetector;
  bool _isInitialized = false;

  // PDF viewer variables
  late PdfViewerController _pdfViewerController;

  // Face tracking variables
  Timer? _debounceTimer;
  Timer? _faceDetectionTimeoutTimer;
  Timer? _resetTimer;
  bool _faceDetected = false;
  String _lastMovement = 'none';
  String _navigationStatus = 'ready'; // ready, navigating, failed
  int _currentPdfPage = 1; // Track PDF page manually since pageNumber might not work

  // Frame throttling variables
  DateTime? _lastFaceDetectionTime;
  static const Duration _faceDetectionInterval = Duration(milliseconds: 700);

  // Movement thresholds
  double _tiltThreshold = 5.0; // degrees (lowered for easier detection)
  static const int _debounceMs = 400; // milliseconds (reduced for faster response)

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
    _currentPdfPage = 1; // Start at page 1
    print('PDF viewer controller initialized: $_pdfViewerController');
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    print('Starting app initialization...');

    // Initialize camera and face detection only
    _initializeCameraAndFaceDetection();

    print('App initialization complete');
    setState(() {
      _isInitialized = true;
    });
  }

  Future<void> _initializeCameraAndFaceDetection() async {
    try {
      print('Initializing camera...');
      final cameras = await availableCameras().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('Camera enumeration timed out');
          throw TimeoutException('Camera enumeration timed out');
        },
      );

      if (cameras.isEmpty) {
        print('No cameras available');
        return;
      }

      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      print('Using camera: ${frontCamera.name}');
      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.low, // Lower resolution for better performance
        enableAudio: false,
      );

      // Add timeout to camera initialization
      await _cameraController!.initialize().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('Camera controller initialization timed out');
          throw TimeoutException('Camera controller initialization timed out');
        },
      );

      await _cameraController!.startImageStream(_processCameraImage);
      print('Camera initialized successfully');
    } catch (e) {
      print('Error initializing camera: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera initialization failed: $e\nFace tracking disabled.'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }

    // Always initialize face detector
    _initializeFaceDetector();
  }

  void _initializeFaceDetector() {
    try {
      _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableContours: false,
          enableLandmarks: false,
          enableClassification: false,
          enableTracking: false, // Disable tracking for simpler processing
        ),
      );
      print('Face detector initialized successfully');
    } catch (e) {
      print('Error initializing face detector: $e');
    }
  }

  void _processCameraImage(CameraImage image) async {
    // Throttle face detection to prevent UI freezing
    final now = DateTime.now();
    if (_lastFaceDetectionTime != null &&
        now.difference(_lastFaceDetectionTime!) < _faceDetectionInterval) {
      return;
    }
    _lastFaceDetectionTime = now;

    try {
      final inputImage = _convertCameraImageToInputImage(image);
      if (inputImage != null) {
        try {
          // Add timeout to face detection
          final faces = await _faceDetector.processImage(inputImage).timeout(
            const Duration(milliseconds: 500),
            onTimeout: () {
              print('Face detection timed out');
              return <Face>[];
            },
          );

          if (faces.isNotEmpty) {
            print('Face detected! Processing movement...');
            _handleFaceDetection(faces.first);
          } else {
            // No face detected - update status
            if (mounted) {
              setState(() {
                _faceDetected = false;
              });
            }
            // Cancel timeout timer since no face is detected
            _faceDetectionTimeoutTimer?.cancel();
          }
        } catch (e) {
          print('Face detection error: $e');
        }
      }
    } catch (e) {
      print('Error processing camera image: $e');
    }
  }

  InputImage? _convertCameraImageToInputImage(CameraImage image) {
    try {
      // For iOS, try using the standard BGRA format
      final bytes = image.planes.first.bytes;

      final inputImageMetadata = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: InputImageRotation.rotation90deg,
        format: InputImageFormat.bgra8888,
        bytesPerRow: image.planes.first.bytesPerRow,
      );

      return InputImage.fromBytes(bytes: bytes, metadata: inputImageMetadata);
    } catch (e) {
      print('Error converting camera image: $e');
      return null;
    }
  }

  void _scrollPdfHorizontally(double offset) {
    try {
      print('Attempting to scroll PDF by $offset');

      // Update status
      setState(() {
        _navigationStatus = 'navigating';
      });

      // Get current page for debugging
      int currentPage = _pdfViewerController.pageNumber;
      print('Current page before navigation (controller): $currentPage');
      print('Current page before navigation (manual): $_currentPdfPage');

      // Update manual page tracking
      if (offset < 0) {
        // Scroll left - go to previous page
        print('Going to previous page...');
        if (_currentPdfPage > 1) {
          _currentPdfPage--;
          _pdfViewerController.jumpToPage(_currentPdfPage);
          print('Jumped to page $_currentPdfPage');
        } else {
          print('Already at first page, cannot go back');
        }
      } else {
        // Scroll right - go to next page
        print('Going to next page...');
        if (_currentPdfPage < 3) { // We know we have 3 pages
          _currentPdfPage++;
          _pdfViewerController.jumpToPage(_currentPdfPage);
          print('Jumped to page $_currentPdfPage');
        } else {
          print('Already at last page, cannot go forward');
        }
      }

      // Update the UI to show current page immediately
      if (mounted) {
        setState(() {
          _navigationStatus = 'ready';
        });
        print('Page after navigation (manual): $_currentPdfPage');
      }

      print('PDF scrolled horizontally by $offset');
    } catch (e) {
      print('Error scrolling PDF: $e');
      setState(() {
        _navigationStatus = 'failed';
      });

      // Reset status after a delay
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _navigationStatus = 'ready';
          });
        }
      });
    }
  }

  void _setMovementDirection(String direction) {
    if (!mounted) return;

    // Only update if direction actually changed to avoid unnecessary UI updates
    if (_lastMovement != direction) {
      print('Movement direction changed from ${_lastMovement} to $direction');

      // Cancel any existing reset timer
      _resetTimer?.cancel();

      setState(() {
        _lastMovement = direction;
      });

      // Handle PDF scrolling for left/right movements
      if (direction == 'left') {
        _scrollPdfHorizontally(-200); // Scroll left by 200 pixels
      } else if (direction == 'right') {
        _scrollPdfHorizontally(200); // Scroll right by 200 pixels
      }

      // Set timer to reset to 'none' after showing the movement
      _resetTimer = Timer(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() {
            _lastMovement = 'none';
            _navigationStatus = 'ready';
          });
        }
      });
    }
  }

  void _handleFaceDetection(Face face) {
    // Cancel previous debounce timer
    _debounceTimer?.cancel();

    // Start new debounce timer
    _debounceTimer = Timer(const Duration(milliseconds: _debounceMs), () {
      if (mounted) {
        _processFaceMovements(face);
      }
    });
  }

  void _processFaceMovements(Face face) {
    if (!mounted) {
      print('Widget not mounted, skipping movement processing');
      return;
    }

    final headEulerAngleX = face.headEulerAngleX ?? 0.0; // Up-down tilt
    final headEulerAngleY = face.headEulerAngleY ?? 0.0; // Left-right tilt

    print('Processing face movement - X: $headEulerAngleX, Y: $headEulerAngleY');

    // Update face detection status
    _faceDetected = true;

    // Cancel existing timeout timer
    _faceDetectionTimeoutTimer?.cancel();

    // Start new timeout timer (reset face detection after 3 seconds of no detection)
    _faceDetectionTimeoutTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _faceDetected = false;
        });
      }
    });

    // Only check horizontal movement (left/right tilt) - no up/down as requested
    if (headEulerAngleY.abs() > _tiltThreshold) {
      print('Horizontal tilt detected: $headEulerAngleY (threshold: ${_tiltThreshold})');
      if (headEulerAngleY > 0) {
        // Head tilted right
        _setMovementDirection('right');
      } else {
        // Head tilted left
        _setMovementDirection('left');
      }
    }
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Face Control Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Tilt Sensitivity'),
                subtitle: Slider(
                  value: _tiltThreshold,
                  min: 2.0,
                  max: 20.0,
                  divisions: 18,
                  label: '${_tiltThreshold.toStringAsFixed(1)}°',
                  onChanged: (value) {
                    setState(() {
                      _tiltThreshold = value;
                    });
                  },
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Adjust tilt sensitivity.\nLower values = more sensitive',
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    print('Disposing face tracking test...');
    _debounceTimer?.cancel();
    _faceDetectionTimeoutTimer?.cancel();
    _resetTimer?.cancel();
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: Container(
        color: Colors.grey[100],
        child: Stack(
          children: [
            // PDF Viewer as background
            Positioned.fill(
              child: SfPdfViewer.asset(
                'assets/sample.pdf',
                controller: _pdfViewerController,
                enableTextSelection: false,
                canShowScrollHead: false,
                canShowScrollStatus: false,
                canShowPaginationDialog: false,
                interactionMode: PdfInteractionMode.pan,
                scrollDirection: PdfScrollDirection.vertical,
                initialZoomLevel: 1.0,
                onDocumentLoaded: (details) {
                  print('PDF loaded successfully! Total pages: ${details.document.pages.count}');
                  if (mounted) {
                    setState(() {
                      _navigationStatus = 'ready';
                    });
                  }
                },
                onPageChanged: (details) {
                  print('Page changed from ${details.oldPageNumber} to ${details.newPageNumber}');
                  if (mounted) {
                    setState(() {
                      _currentPdfPage = details.newPageNumber;
                    });
                  }
                },
              ),
            ),

            // Camera preview overlay (small, top-right corner)
            Positioned(
              top: 20,
              right: 20,
              width: 120,
              height: 160,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    children: [
                      _cameraController != null &&
                              _cameraController!.value.isInitialized
                          ? CameraPreview(_cameraController!)
                          : const Center(
                              child: Text(
                                'Camera\nInitializing...',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                      // Face detection status indicator
                      Positioned(
                        bottom: 5,
                        right: 5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _faceDetected ? Colors.green : Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _faceDetected ? 'Face' : 'No Face',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Instructions overlay
            Positioned(
              bottom: 100,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'PDF Face Control Instructions:',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Tilt head LEFT to scroll to previous page',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    Text(
                      '• Tilt head RIGHT to scroll to next page',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    Text(
                      '• Keep face in camera view',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),

            // Large control arrows in center for testing (only left/right for PDF)
            Positioned(
              top: 200,
              left: 0,
              right: 0,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Left and Right arrows in a row (for PDF navigation)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: _lastMovement == 'left' ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_back,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 60),
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: _lastMovement == 'right' ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),
                  Text(
                    'Last Movement: ${_lastMovement.toUpperCase()}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Current Page: $_currentPdfPage',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Status: $_navigationStatus',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _navigationStatus == 'ready' ? Colors.green :
                             _navigationStatus == 'navigating' ? Colors.orange : Colors.red,
                    ),
                  ),
                ],
              ),
            ),

            // Settings button
            Positioned(
              top: 20,
              left: 20,
              child: Row(
                children: [
                  FloatingActionButton(
                    mini: true,
                    onPressed: () {
                      print('Manual next page test');
                      if (_currentPdfPage < 3) {
                        setState(() {
                          _currentPdfPage++;
                          _navigationStatus = 'navigating';
                        });
                        _pdfViewerController.jumpToPage(_currentPdfPage);
                        Future.delayed(const Duration(milliseconds: 200), () {
                          if (mounted) {
                            setState(() {
                              _navigationStatus = 'ready';
                            });
                            print('Manual next - Current page: $_currentPdfPage');
                          }
                        });
                      }
                    },
                    child: const Icon(Icons.arrow_forward),
                    tooltip: 'Next Page',
                  ),
                  const SizedBox(width: 10),
                  FloatingActionButton(
                    mini: true,
                    onPressed: () {
                      print('Manual previous page test');
                      if (_currentPdfPage > 1) {
                        setState(() {
                          _currentPdfPage--;
                          _navigationStatus = 'navigating';
                        });
                        _pdfViewerController.jumpToPage(_currentPdfPage);
                        Future.delayed(const Duration(milliseconds: 200), () {
                          if (mounted) {
                            setState(() {
                              _navigationStatus = 'ready';
                            });
                            print('Manual previous - Current page: $_currentPdfPage');
                          }
                        });
                      }
                    },
                    child: const Icon(Icons.arrow_back),
                    tooltip: 'Previous Page',
                  ),
                  const SizedBox(width: 10),
                  FloatingActionButton(
                    mini: true,
                    onPressed: _showSettingsDialog,
                    child: const Icon(Icons.settings),
                    tooltip: 'Settings',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
