import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:async';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;

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
            print('MainPage: Processing volume: $volume, previous: $_previousVolume');
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
                  iconSize: 96,
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
  List<String> _labels = [];
  Interpreter? _interpreter;
  List<int>? _inputShape;
  int _maxDetections = 100; // Default for EfficientDet-Lite0
  double _scoreThreshold = 0.5; // Confidence threshold
  bool _modelLoadedSuccessfully = false;
  int _inputSize = 320; // EfficientDet-Lite0 input size
  DateTime? _lastProcessedTime;
  bool _isProcessing = false;
  String? _lastSpokenLabel; // Track last spoken label

  @override
  void initState() {
    super.initState();
    if (widget.cameras.isNotEmpty) {
      _controller = CameraController(
        widget.cameras[0],
        ResolutionPreset.medium,
        enableAudio: false,
      );
      _initializeControllerFuture = _initializeCameraAndModel();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.ttsService.speak('No cameras available');
      });
    }
  }

  Future<void> _initializeCameraAndModel() async {
    try {
      print('Initializing camera...');
      await _controller!.initialize();
      print('Camera initialized successfully');

      print('Loading model and labels...');
      await _loadModel();
      if (_interpreter == null) {
        print('Model loading failed, aborting initialization');
        widget.ttsService.speak('Cannot start camera: detection model failed to load');
        return;
      }
      await _loadLabels();
      print('Model and labels loaded');

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _modelLoadedSuccessfully = true;
        });
        try {
          await _controller!.startImageStream(_processCameraImage);
          print('Image stream started successfully');
          widget.ttsService.speak('Camera page. Press volume down to return to main page.');
        } catch (e) {
          print('Failed to start image stream: $e');
          widget.ttsService.speak('Failed to start camera stream');
        }
      }
    } catch (e) {
      print('Camera or model initialization error: $e');
      widget.ttsService.speak('Failed to initialize camera or model');
    }
  }

  Future<void> _loadModel() async {
    try {
      try {
        String modelPath = 'assets/efficientdet_lite0.tflite';
        ByteData modelData = await DefaultAssetBundle.of(context).load(modelPath);
        print('Model asset loaded: $modelPath, size: ${modelData.lengthInBytes} bytes');
        if (modelData.lengthInBytes == 0) {
          throw Exception('Model file is empty');
        }
      } catch (e) {
        print('Failed to access model asset: $e');
        widget.ttsService.speak('Failed to access detection model file');
        _interpreter = null;
        return;
      }

      _interpreter = await Interpreter.fromAsset('assets/efficientdet_lite0.tflite');
      print('Model loaded successfully');
      _inputShape = _interpreter!.getInputTensor(0).shape;
      print('Input shape: $_inputShape');
      var inputTensor = _interpreter!.getInputTensor(0);
      print('Input tensor data type: ${inputTensor.type}');

      if (_inputShape != null && _inputShape!.length >= 3) {
        _inputSize = _inputShape![2];
        print('Model input size set to: $_inputSize x $_inputSize');
      }

      List<List<int>> outputShapes = [];
      int i = 0;
      while (true) {
        try {
          var shape = _interpreter!.getOutputTensor(i).shape;
          outputShapes.add(shape);
          print('Output tensor $i shape: $shape');
          i++;
        } catch (e) {
          print('No more output tensors at index $i');
          break;
        }
      }

      if (outputShapes.length >= 2) {
        _maxDetections = outputShapes[1][1];
        print('Max detections set to: $_maxDetections');
      } else {
        print('Could not determine max detections, using default: $_maxDetections');
      }
    } catch (e, stackTrace) {
      print('Failed to load model: $e');
      print('Stack trace: $stackTrace');
      _interpreter = null;
      widget.ttsService.speak('Failed to load detection model');
    }
  }

  Future<void> _loadLabels() async {
    try {
      String labelsFile = await rootBundle.loadString('assets/labelmap.txt');
      _labels = labelsFile
          .split('\n')
          .where((label) => label.trim().isNotEmpty && label.trim() != '???')
          .toList();
      print('Loaded labels: ${_labels.length} labels');
      if (_labels.length < 80) {
        print('Warning: Label file has ${_labels.length} labels, expected 80 for COCO dataset');
        widget.ttsService.speak('Warning: Incomplete label file loaded');
      }
    } catch (e) {
      print('Failed to load labels: $e');
      widget.ttsService.speak('Failed to load labels');
    }
  }

  void _processCameraImage(CameraImage image) async {
    if (!_isCameraInitialized || _interpreter == null || !mounted || !_modelLoadedSuccessfully) {
      print('Skipping image processing: cameraInitialized=$_isCameraInitialized, interpreter=${_interpreter != null}, modelLoaded=$_modelLoadedSuccessfully');
      return;
    }

    final now = DateTime.now();
    if (_isProcessing || (_lastProcessedTime != null && now.difference(_lastProcessedTime!).inMilliseconds < 1000)) {
      return;
    }
    _isProcessing = true;
    _lastProcessedTime = now;

    try {
      print('Processing camera image at $now');
      img.Image? rgbImage = _convertCameraImageToImage(image);
      if (rgbImage == null) {
        print('Failed to convert camera image');
        _isProcessing = false;
        return;
      }

      img.Image? resized = img.copyResize(rgbImage, width: _inputSize, height: _inputSize);
      rgbImage = null;
      var input = _imageToByteList(resized);
      resized = null;

      print('Input tensor shape: [1, $_inputSize, $_inputSize, 3], length: ${input.length}, type: Uint8List');

      var outputBoxes = List.filled(1 * _maxDetections * 4, 0.0).reshape([1, _maxDetections, 4]);
      var outputClasses = List.filled(1 * _maxDetections, 0.0).reshape([1, _maxDetections]);
      var outputScores = List.filled(1 * _maxDetections, 0.0).reshape([1, _maxDetections]);
      var outputNum = List.filled(1, 0.0).reshape([1]);

      try {
        _interpreter!.runForMultipleInputs(
          [input.reshape([1, _inputSize, _inputSize, 3])],
          {
            0: outputBoxes,
            1: outputClasses,
            2: outputScores,
            3: outputNum,
          },
        );
        print('Inference completed successfully');
      } catch (e) {
        print('Inference error: $e');
        widget.ttsService.speak('Error processing camera image');
        _isProcessing = false;
        return;
      }

      int numDetections = outputNum[0].toInt();
      print('Number of detections: $numDetections');
      List<Map<String, dynamic>> detections = [];
      Map<String, dynamic>? highestConfidenceDetection;

      for (int i = 0; i < numDetections && i < _maxDetections; i++) {
        double score = outputScores[0][i];
        if (score > _scoreThreshold) {
          int classId = outputClasses[0][i].toInt();
          if (classId > 0 && classId <= _labels.length) {
            var detection = {
              'ymin': outputBoxes[0][i][0] / _inputSize,
              'xmin': outputBoxes[0][i][1] / _inputSize,
              'ymax': outputBoxes[0][i][2] / _inputSize,
              'xmax': outputBoxes[0][i][3] / _inputSize,
              'class': classId - 1,
              'score': score,
            };
            detections.add(detection);
            print('High confidence detection $i: class $classId (${_labels[classId - 1]}), score $score');
            if (highestConfidenceDetection == null || score > highestConfidenceDetection['score']) {
              highestConfidenceDetection = detection;
            }
          } else {
            print('Invalid class ID: $classId');
          }
        }
      }

      if (detections.isEmpty && numDetections > 0) {
        print('No detections above threshold $_scoreThreshold');
        _lastSpokenLabel = null; // Reset if no detections
      }

      if (highestConfidenceDetection != null) {
        int classIndex = highestConfidenceDetection['class'];
        String currentLabel = _labels[classIndex];
        double score = highestConfidenceDetection['score'];
        if (currentLabel != _lastSpokenLabel) {
          widget.ttsService.speak('$currentLabel detected with ${(score * 100).toStringAsFixed(1)} percent confidence');
          _lastSpokenLabel = currentLabel;
        } else {
          print('Skipping TTS: Same label as last spoken ($currentLabel)');
        }
      }

      setState(() {
        _detections = detections;
      });
    } catch (e) {
      print('Processing error: $e');
      widget.ttsService.speak('Error processing camera image');
    } finally {
      _isProcessing = false;
    }
  }

  Uint8List _imageToByteList(img.Image image) {
    if (image.width != _inputSize || image.height != _inputSize) {
      print('Image dimensions invalid: ${image.width}x${image.height}, expected: $_inputSize x $_inputSize');
      throw Exception('Invalid image dimensions for model input');
    }

    var convertedBytes = Uint8List(1 * _inputSize * _inputSize * 3);
    var buffer = Uint8List.view(convertedBytes.buffer);
    int pixelIndex = 0;
    for (int y = 0; y < _inputSize; y++) {
      for (int x = 0; x < _inputSize; x++) {
        var pixel = image.getPixel(x, y);
        buffer[pixelIndex++] = pixel.r.toInt();
        buffer[pixelIndex++] = pixel.g.toInt();
        buffer[pixelIndex++] = pixel.b.toInt();
      }
    }
    return convertedBytes;
  }

  img.Image? _convertCameraImageToImage(CameraImage image) {
    try {
      final yPlane = image.planes[0];
      final uPlane = image.planes[1];
      final vPlane = image.planes[2];
      final int width = image.width;
      final int height = image.height;
      final int uvRowStride = image.planes[1].bytesPerRow;
      final int uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

      img.Image rgbImage = img.Image(width: width, height: height, numChannels: 3);
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final int yIndex = y * width + x;
          final int uvIndex = (y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;
          final int Y = yPlane.bytes[yIndex] & 0xFF;
          final int U = uPlane.bytes[uvIndex] & 0xFF;
          final int V = vPlane.bytes[uvIndex] & 0xFF;
          int R = (Y + 1.402 * (V - 128)).round().clamp(0, 255);
          int G = (Y - 0.344136 * (U - 128) - 0.714136 * (V - 128)).round().clamp(0, 255);
          int B = (Y + 1.772 * (U - 128)).round().clamp(0, 255);
          rgbImage.setPixel(x, y, img.ColorRgb8(R, G, B));
        }
      }
      print('RGB image dimensions: ${rgbImage.width}x${rgbImage.height}');
      return rgbImage;
    } catch (e) {
      print('Error converting camera image: $e');
      return null;
    }
  }

  Future<void> _testInferenceWithStaticImage() async {
    if (_interpreter == null || !mounted) {
      print('Cannot test inference: interpreter not loaded');
      widget.ttsService.speak('Cannot test image: detection model not loaded');
      return;
    }

    try {
      ByteData data = await rootBundle.load('assets/test_image.jpg');
      Uint8List bytes = data.buffer.asUint8List();
      img.Image? testImage = img.decodeImage(bytes);
      if (testImage == null) {
        print('Failed to decode test image');
        widget.ttsService.speak('Failed to load test image');
        return;
      }

      img.Image? resized = img.copyResize(testImage, width: _inputSize, height: _inputSize);
      testImage = null;
      var input = _imageToByteList(resized);
      resized = null;

      print('Test image input tensor shape: [1, $_inputSize, $_inputSize, 3], length: ${input.length}, type: Uint8List');

      var outputBoxes = List.filled(1 * _maxDetections * 4, 0.0).reshape([1, _maxDetections, 4]);
      var outputClasses = List.filled(1 * _maxDetections, 0.0).reshape([1, _maxDetections]);
      var outputScores = List.filled(1 * _maxDetections, 0.0).reshape([1, _maxDetections]);
      var outputNum = List.filled(1, 0.0).reshape([1]);

      try {
        _interpreter!.runForMultipleInputs(
          [input.reshape([1, _inputSize, _inputSize, 3])],
          {
            0: outputBoxes,
            1: outputClasses,
            2: outputScores,
            3: outputNum,
          },
        );
        print('Test image inference completed successfully');
      } catch (e) {
        print('Test image inference error: $e');
        widget.ttsService.speak('Error processing test image');
        return;
      }

      int numDetections = outputNum[0].toInt();
      print('Test image - Number of detections: $numDetections');
      List<Map<String, dynamic>> detections = [];
      Map<String, dynamic>? highestConfidenceDetection;

      for (int i = 0; i < numDetections && i < _maxDetections; i++) {
        double score = outputScores[0][i];
        if (score > _scoreThreshold) {
          int classId = outputClasses[0][i].toInt();
          if (classId > 0 && classId <= _labels.length) {
            print('Test image - High confidence detection $i: class $classId (${_labels[classId - 1]}), score $score');
            var detection = {
              'ymin': outputBoxes[0][i][0] / _inputSize,
              'xmin': outputBoxes[0][i][1] / _inputSize,
              'ymax': outputBoxes[0][i][2] / _inputSize,
              'xmax': outputBoxes[0][i][3] / _inputSize,
              'class': classId - 1,
              'score': score,
            };
            detections.add(detection);
            if (highestConfidenceDetection == null || score > highestConfidenceDetection['score']) {
              highestConfidenceDetection = detection;
            }
          } else {
            print('Test image - Invalid class ID: $classId');
          }
        }
      }

      if (detections.isEmpty && numDetections > 0) {
        print('Test image - No detections above threshold $_scoreThreshold');
      }

      if (highestConfidenceDetection != null) {
        int classIndex = highestConfidenceDetection['class'];
        String currentLabel = _labels[classIndex];
        double score = highestConfidenceDetection['score'];
        widget.ttsService.speak('$currentLabel detected in test image with ${(score * 100).toStringAsFixed(1)} percent confidence');
      }

      setState(() {
        _detections = detections;
      });
    } catch (e) {
      print('Test inference error: $e');
      widget.ttsService.speak('Error processing test image');
    }
  }

  Future<void> _stopCamera() async {
    if (_controller != null && _controller!.value.isInitialized) {
      try {
        if (_controller!.value.isStreamingImages) {
          await _controller!.stopImageStream();
          print('Image stream stopped');
        }
      } catch (e) {
        print('Error stopping image stream: $e');
      }
      try {
        await _controller!.setFlashMode(FlashMode.off);
        print('Flash mode set to off');
      } catch (e) {
        print('Error setting flash mode: $e');
      }
      await Future.delayed(const Duration(milliseconds: 1000));
      try {
        await _controller!.dispose();
        _controller = null;
        print('Camera controller disposed');
      } catch (e) {
        print('Error disposing camera controller: $e');
      }
    }
  }

  Future<void> _navigateBack() async {
    if (_isNavigating) return;
    setState(() {
      _isNavigating = true;
    });
    await widget.ttsService.speak('Returning to main page');
    await _stopCamera();
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    print('CameraPage: dispose called');
    _debounceTimer?.cancel();
    _stopCamera();
    _interpreter?.close();
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
              if (snapshot.hasError || !_modelLoadedSuccessfully) {
                return const Center(
                  child: Text(
                    'Failed to initialize camera or model',
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
                      constraints: BoxConstraints(
                        maxHeight: 600,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            AspectRatio(
                              aspectRatio: _controller!.value.aspectRatio,
                              child: CameraPreview(_controller!),
                            ),
                            CustomPaint(
                              painter: BoundingBoxPainter(_detections, _labels),
                              size: Size.infinite,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Semantics(
                      label: 'Return to home',
                      child: IconButton(
                        icon: const Icon(Icons.home, color: Color(0xFFFFD700)),
                        iconSize: 96,
                        onPressed: _isCameraInitialized && !_isNavigating
                            ? _navigateBack
                            : null,
                      ),
                    ),
                    if (!_isNavigating)
                      ElevatedButton(
                        onPressed: _isCameraInitialized && _interpreter != null
                            ? _testInferenceWithStaticImage
                            : null,
                        child: const Text('Test Inference with Static Image'),
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
class BoundingBoxPainter extends CustomPainter {
  final List<Map<String, dynamic>> detections;
  final List<String> labels;

  BoundingBoxPainter(this.detections, this.labels);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final textStyle = TextStyle(
      color: Colors.red,
      fontSize: 16,
      backgroundColor: Colors.black.withOpacity(0.5),
    );

    for (var detection in detections) {
      final ymin = detection['ymin'] * size.height;
      final xmin = detection['xmin'] * size.width;
      final ymax = detection['ymax'] * size.height;
      final xmax = detection['xmax'] * size.width;
      final classIndex = detection['class'] as int;
      final score = detection['score'] as double;

      // Draw bounding box
      canvas.drawRect(
        Rect.fromLTRB(xmin, ymin, xmax, ymax),
        paint,
      );

      // Draw label and score
      if (classIndex >= 0 && classIndex < labels.length) {
        final label = labels[classIndex];
        final textSpan = TextSpan(
          text: '$label (${(score * 100).toStringAsFixed(1)}%)',
          style: textStyle,
        );
        final textPainter = TextPainter(
          text: textSpan,
          textAlign: TextAlign.left,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(xmin, ymin - textPainter.height - 4),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}