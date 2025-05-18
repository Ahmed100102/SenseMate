import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'dart:convert';
import 'dart:io';
import 'package:http_parser/http_parser.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  List<CameraDescription> cameras = [];
  try {
    if (await Permission.camera.request().isGranted) {
      cameras = await availableCameras();
      print('Cameras available: $cameras');
    } else {
      print('Camera permission denied');
      cameras = [];
    }
  } catch (e) {
    print('Camera error: $e');
    cameras = [];
  }
  runApp(MyApp(cameras: cameras));
}

class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;
  TtsService._();
  static Future<TtsService> create() async {
    final instance = TtsService._();
    await instance._initializeTts();
    return instance;
  }

  Future<void> _initializeTts() async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      final engines = await _tts.getEngines;
      if (engines == null || engines.isEmpty) {
        throw Exception('No TTS engines available on this device.');
      }
      print('Available TTS engines: $engines');
      _isInitialized = true;
      print('TTS initialized successfully');
    } catch (e) {
      print('TTS initialization error: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  Future<void> speak(String text) async {
    try {
      if (!_isInitialized) {
        print('TTS not initialized, reinitializing...');
        await _initializeTts();
      }
      double currentVolume;
      try {
        currentVolume = await VolumeController.instance.getVolume();
        print('Current media volume: $currentVolume');
      } catch (e) {
        print('Failed to get volume: $e');
        currentVolume = 0.0;
      }
      if (currentVolume < 0.1) {
        print('Media volume too low, setting to 0.5');
        try {
          await VolumeController.instance.setVolume(0.5);
        } catch (e) {
          print('Failed to set volume: $e');
        }
      }
      await _tts.stop();
      await _tts.speak(text);
      print('TTS speaking: $text');
    } catch (e) {
      print('TTS speak error: $e');
      rethrow;
    }
  }

  Future<void> testTts() async {
    await speak('TTS test successful.');
  }

  void dispose() {
    _tts.stop();
  }
}

class MyApp extends StatefulWidget {
  final List<CameraDescription> cameras;

  const MyApp({Key? key, required this.cameras}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ValueNotifier<double> _volumeNotifier = ValueNotifier<double>(0.0);
  StreamSubscription<double>? _volumeSubscription;
  bool _isFirstVolumeEvent = true;
  double _previousVolume = 0.0;
  TtsService? _ttsService;

  @override
  void initState() {
    super.initState();
    print('MyApp: initState called');
    _initializeTtsService();
    _initializeVolumeListener();
  }

  Future<void> _initializeTtsService() async {
    try {
      _ttsService = await TtsService.create();
      await _ttsService!.testTts();
    } catch (e) {
      print('Failed to initialize TTS service: $e');
    }
  }

  void _initializeVolumeListener() {
    _volumeSubscription?.cancel();
    _volumeSubscription = VolumeController.instance.addListener((volume) {
      print('MyApp: Volume changed: current=$volume, previous=$_previousVolume at ${DateTime.now()}');
      if (_isFirstVolumeEvent) {
        _isFirstVolumeEvent = false;
        _previousVolume = volume;
      }
      _volumeNotifier.value = volume;
      _previousVolume = volume;
    }, fetchInitialVolume: true);
  }

  @override
  void dispose() {
    print('MyApp: dispose called');
    _volumeSubscription?.cancel();
    _volumeNotifier.dispose();
    _ttsService?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('MyApp: build called');
    return MaterialApp(
      title: 'SenseMate Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFFFFD700),
        scaffoldBackgroundColor: Colors.black,
      ),
      home: StartingPage(
        cameras: widget.cameras,
        ttsService: _ttsService ?? TtsService._(),
        volumeNotifier: _volumeNotifier,
        reinitializeVolumeListener: _initializeVolumeListener,
      ),
      routes: {
        '/main': (context) => MainPage(
          cameras: widget.cameras,
          volumeNotifier: _volumeNotifier,
          reinitializeVolumeListener: _initializeVolumeListener,
          ttsService: _ttsService ?? TtsService._(),
        ),
        '/camera': (context) => CameraPage(
          cameras: widget.cameras,
          volumeNotifier: _volumeNotifier,
          ttsService: _ttsService ?? TtsService._(),
        ),
      },
    );
  }
}

class StartingPage extends StatefulWidget {
  final List<CameraDescription> cameras;
  final TtsService ttsService;
  final ValueNotifier<double> volumeNotifier;
  final VoidCallback reinitializeVolumeListener;

  const StartingPage({
    Key? key,
    required this.cameras,
    required this.ttsService,
    required this.volumeNotifier,
    required this.reinitializeVolumeListener,
  }) : super(key: key);

  @override
  _StartingPageState createState() => _StartingPageState();
}

class _StartingPageState extends State<StartingPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      print('StartingPage: Speaking "Starting page"');
      try {
        await widget.ttsService.speak('Starting page');
      } catch (e) {
        print('Failed to speak in StartingPage: $e');
      }
    });
    Future.delayed(const Duration(seconds: 3), () {
      print('StartingPage: Navigating to MainPage');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MainPage(
            cameras: widget.cameras,
            volumeNotifier: widget.volumeNotifier,
            reinitializeVolumeListener: widget.reinitializeVolumeListener,
            ttsService: widget.ttsService,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Image.asset(
          'assets/logo.png',
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Text(
              'Logo not found',
              style: TextStyle(color: Colors.white),
            );
          },
        ),
      ),
    );
  }
}

class MainPage extends StatefulWidget {
  final List<CameraDescription> cameras;
  final ValueNotifier<double> volumeNotifier;
  final VoidCallback reinitializeVolumeListener;
  final TtsService ttsService;

  const MainPage({
    Key? key,
    required this.cameras,
    required this.volumeNotifier,
    required this.reinitializeVolumeListener,
    required this.ttsService,
  }) : super(key: key);

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  bool _isNavigating = false;
  Timer? _debounceTimer;
  double _previousVolume = 0.0;
  bool _isInitialVolumeSet = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      widget.reinitializeVolumeListener();
      print('MainPage: Speaking "Main page"');
      try {
        await widget.ttsService.speak('Main page. Press volume up to open camera.');
      } catch (e) {
        print('Failed to speak in MainPage: $e');
      }
    });
  }

  void _navigateToCamera() {
    if (_isNavigating) return;
    setState(() {
      _isNavigating = true;
    });
    print('MainPage: Speaking "Opening camera page"');
    widget.ttsService.speak('Opening camera page').then((_) {
      Navigator.pushNamed(context, '/camera').then((_) {
        setState(() {
          _isNavigating = false;
        });
        Future.delayed(const Duration(milliseconds: 500), () {
          widget.reinitializeVolumeListener();
          print('MainPage: Speaking "Returned to main page"');
          widget.ttsService.speak('Returned to main page. Press volume up to open camera.');
        });
      });
    }).catchError((e) {
      print('Failed to speak in MainPage (navigateToCamera): $e');
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: ValueListenableBuilder<double>(
        valueListenable: widget.volumeNotifier,
        builder: (context, volume, child) {
          if (_debounceTimer?.isActive ?? false) return child!;
          _debounceTimer = Timer(const Duration(milliseconds: 100), () {
            print('MainPage: Processing volume: $volume, previous: $_previousVolume, isInitial: $_isInitialVolumeSet');
            if (!_isInitialVolumeSet) {
              _previousVolume = volume;
              _isInitialVolumeSet = true;
              print('MainPage: Initial volume set to $_previousVolume');
              return;
            }
            if (volume > _previousVolume + 0.05 && !_isNavigating) {
              if (widget.cameras.isNotEmpty) {
                _navigateToCamera();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No cameras available')),
                );
                print('MainPage: Speaking "No cameras available"');
                widget.ttsService.speak('No cameras available').catchError((e) {
                  print('Failed to speak in MainPage (no cameras): $e');
                });
              }
            }
            _previousVolume = volume;
          });
          return child!;
        },
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/logo.png',
                width: MediaQuery.of(context).size.width * 0.5,
                height: MediaQuery.of(context).size.width * 0.5,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Text(
                    'Logo not found',
                    style: TextStyle(color: Colors.white),
                  );
                },
              ),
              const SizedBox(height: 48),
              Semantics(
                label: 'Start camera',
                child: IconButton(
                  icon: const Icon(Icons.camera_alt, color: Color(0xFFFFD700)),
                  iconSize: 120, // Increased from 96 to 120
                  onPressed: widget.cameras.isNotEmpty
                      ? _navigateToCamera
                      : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No cameras available')),
                    );
                    print('MainPage: Speaking "No cameras available"');
                    widget.ttsService.speak('No cameras available').catchError((e) {
                      print('Failed to speak in MainPage (button press): $e');
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CameraPage extends StatefulWidget {
  final List<CameraDescription> cameras;
  final ValueNotifier<double> volumeNotifier;
  final TtsService ttsService;

  const CameraPage({
    Key? key,
    required this.cameras,
    required this.volumeNotifier,
    required this.ttsService,
  }) : super(key: key);

  @override
  _CameraPageState createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  double _previousVolume = 0.5;
  bool _isCameraInitialized = false;
  Timer? _debounceTimer;
  bool _isNavigating = false;
  List<Map<String, dynamic>> _detections = [];
  String? _errorMessage;
  bool _isProcessing = false;
  DateTime? _lastProcessedTime;
  DateTime? _lastErrorSpokenTime;
  Timer? _captureTimer;
  final String _serverUrl = 'http://172.174.232.66:5000/detect';
  String? _lastSpokenLabel;

  @override
  void initState() {
    super.initState();
    if (widget.cameras.isNotEmpty) {
      _controller = CameraController(
        widget.cameras[0],
        ResolutionPreset.medium,
        enableAudio: false,
      );
      _initializeControllerFuture = _initializeCamera();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.ttsService.speak('No cameras available');
      });
    }
  }

  Future<void> _initializeCamera() async {
    try {
      print('Initializing camera...');
      await _controller!.initialize();
      print('Camera initialized successfully');

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
        _startJpegCapture();
        widget.ttsService.speak('Camera page. Press volume down to return to main page.');
      }
    } catch (e) {
      print('Camera initialization error: $e');
      widget.ttsService.speak('Failed to initialize camera');
    }
  }

  void _startJpegCapture() {
    _captureTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      if (!_isCameraInitialized || !mounted || _isProcessing) {
        print('Skipping JPEG capture: cameraInitialized=$_isCameraInitialized, processing=$_isProcessing');
        return;
      }

      final now = DateTime.now();
      if (_lastProcessedTime != null && now.difference(_lastProcessedTime!).inMilliseconds < 500) {
        return;
      }

      _isProcessing = true;
      _lastProcessedTime = now;

      try {
        print('Capturing JPEG at $now');
        final XFile picture = await _controller!.takePicture();
        await _processJpegImage(picture);
      } catch (e) {
        print('JPEG capture or processing error: $e');
        final now = DateTime.now();
        if (_lastErrorSpokenTime == null || now.difference(_lastErrorSpokenTime!).inSeconds >= 5) {
          widget.ttsService.speak('Error capturing or processing image');
          _lastErrorSpokenTime = now;
        }
        setState(() {
          _errorMessage = 'Error: $e';
        });
      } finally {
        _isProcessing = false;
      }
    });
  }

  Future<void> _processJpegImage(XFile picture) async {
    try {
      final bytes = await picture.readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      final aspectRatio = image.width / image.height;
      int newWidth = 640;
      int newHeight = (640 / aspectRatio).round();
      if (newHeight > 480) {
        newHeight = 480;
        newWidth = (480 * aspectRatio).round();
      }
      image = img.copyResize(image, width: newWidth, height: newHeight);

      final jpegBytes = img.encodeJpg(image, quality: 70);

      final request = http.MultipartRequest('POST', Uri.parse(_serverUrl));
      request.files.add(http.MultipartFile.fromBytes(
        'image',
        jpegBytes,
        filename: 'frame.jpg',
        contentType: MediaType('image', 'jpeg'),
      ));

      final response = await request.send().timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final data = jsonDecode(responseData);
        final detections = List<Map<String, dynamic>>.from(data['detections'] ?? []);

        final previewWidth = _controller!.value.previewSize!.width;
        final previewHeight = _controller!.value.previewSize!.height;
        final normalizedDetections = detections.map((det) {
          final bbox = det['bbox'] as List<dynamic>;
          if (bbox.length != 4) return det;
          return {
            'label': det['label'] ?? det['class'] ?? 'Unknown',
            'bbox': [
              bbox[0] * previewWidth,
              bbox[1] * previewHeight,
              bbox[2] * previewWidth,
              bbox[3] * previewHeight,
            ],
          };
        }).toList();

        if (normalizedDetections.isNotEmpty) {
          final label = normalizedDetections.first['label'];
          if (_lastSpokenLabel == null || _lastSpokenLabel != label) {
            widget.ttsService.speak('$label detected');
            _lastSpokenLabel = label;
          }
        } else {
          _lastSpokenLabel = null;
        }

        setState(() {
          _detections = normalizedDetections;
          _errorMessage = null;
        });
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Processing error: $e');
      setState(() {
        _errorMessage = 'Error: $e';
      });
      rethrow;
    } finally {
      try {
        final file = File(picture.path);
        if (await file.exists()) {
          await file.delete();
          print('Temporary JPEG file deleted: ${picture.path}');
        }
      } catch (e) {
        print('Error deleting temporary JPEG file: $e');
      }
    }
  }

  Future<void> _stopCamera() async {
    if (_controller != null && _controller!.value.isInitialized) {
      try {
        await _controller!.stopImageStream(); // Stop any ongoing streams
        _captureTimer?.cancel();
        print('JPEG capture timer stopped');
      } catch (e) {
        print('Error stopping capture timer: $e');
      }

      try {
        await _controller!.dispose();
        print('Camera controller disposed');
      } catch (e) {
        print('Error disposing camera controller: $e');
      }
      _controller = null;
    }
  }

  Future<void> _navigateBack() async {
    if (_isNavigating) return;
    setState(() {
      _isNavigating = true;
    });

    await widget.ttsService.speak('Returning to main page');
    await _stopCamera(); // Ensure camera is fully stopped before navigating
    if (mounted) {
      Navigator.pop(context); // Pop only if still mounted
    }
  }

  @override
  void dispose() {
    print('CameraPage: dispose called');
    _debounceTimer?.cancel();
    _stopCamera(); // Ensure cleanup on dispose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cameras.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: Text(
            'No cameras available',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: ValueListenableBuilder<double>(
        valueListenable: widget.volumeNotifier,
        builder: (context, volume, child) {
          if (_debounceTimer?.isActive ?? false) return child!;
          _debounceTimer = Timer(const Duration(milliseconds: 100), () {
            if (volume < _previousVolume - 0.05 && _isCameraInitialized && !_isNavigating) {
              _navigateBack();
            }
            _previousVolume = volume;
          });
          return child!;
        },
        child: FutureBuilder<void>(
          future: _initializeControllerFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              if (snapshot.hasError || _controller == null || !_controller!.value.isInitialized) {
                return const Center(
                  child: Text(
                    'Failed to initialize camera',
                    style: TextStyle(color: Colors.white),
                  ),
                );
              }
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: MediaQuery.of(context).size.width,
                      height: MediaQuery.of(context).size.height * 0.7,
                      constraints: const BoxConstraints(maxHeight: 600),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AspectRatio(
                          aspectRatio: _controller!.value.aspectRatio,
                          child: CameraPreview(_controller!),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Semantics(
                      label: 'Return to home',
                      child: IconButton(
                        icon: const Icon(Icons.home, color: Color(0xFFFFD700)),
                        iconSize: 96,
                        onPressed: _isCameraInitialized && !_isNavigating ? _navigateBack : null,
                      ),
                    ),
                  ],
                ),
              );
            } else {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFFFFD700)),
              );
            }
          },
        ),
      ),
    );
  }
}