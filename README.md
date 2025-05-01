# SenseMate Mobile

SenseMate Mobile is a Flutter-based application designed to assist users with visual impairments by providing real-time object detection using a device's camera. The app utilizes TensorFlow Lite for on-device machine learning, text-to-speech (TTS) for audio feedback, and volume button interactions for navigation.

## Features
- **Real-time Object Detection**: Uses the EfficientDet-Lite0 model to detect objects in the camera feed.
- **Text-to-Speech Feedback**: Announces detected objects and navigation instructions via TTS.
- **Volume Button Navigation**: Press volume up to open the camera and volume down to return to the main page.
- **Accessibility**: Designed with accessibility in mind, featuring high-contrast visuals and audio cues.

## Prerequisites
To run the project, ensure you have the following installed:
- [Flutter](https://flutter.dev/docs/get-started/install) (version 3.0 or higher)
- [Dart](https://dart.dev/get-dart)
- [Android Studio](https://developer.android.com/studio) or [Visual Studio Code](https://code.visualstudio.com/) with Flutter plugins
- An Android or iOS device/emulator with camera support
- Git (to clone the repository)

## Project Setup
Follow these steps to set up and run the project locally:

1. **Clone the Repository**
   ```bash
   git clone <your-repository-url>
   cd sensemate-mobile
   ```

2. **Install Dependencies**
   Ensure you are in the project directory and run:
   ```bash
   flutter pub get
   ```

3. **Add Required Assets**
   Ensure the following assets are in the `assets/` directory:
    - `efficientdet_lite0.tflite`: TensorFlow Lite model file for object detection
    - `labelmap.txt`: Text file containing labels for the COCO dataset
    - `logo.png`: App logo for the starting and main pages
    - `test_image.jpg`: Optional test image for static inference testing

   Update the `pubspec.yaml` to include these assets:
   ```yaml
   flutter:
     assets:
       - assets/efficientdet_lite0.tflite
       - assets/labelmap.txt
       - assets/logo.png
       - assets/test_image.jpg
   ```

4. **Configure Permissions**
   Ensure the following permissions are added in `android/app/src/main/AndroidManifest.xml`:
   ```xml
   <uses-permission android:name="android.permission.CAMERA" />
   ```

   For iOS, add the camera permission in `ios/Runner/Info.plist`:
   ```xml
   <key>NSCameraUsageDescription</key>
   <string>Camera access is required for object detection.</string>
   ```

5. **Connect a Device**
    - Connect an Android/iOS device via USB with developer mode enabled, or start an emulator.
    - Verify the device is recognized:
      ```bash
      flutter devices
      ```

6. **Run the App**
   Run the app in debug mode:
   ```bash
   flutter run
   ```

   To build a release version:
   ```bash
   flutter build apk  # For Android
   flutter build ios  # For iOS (requires a Mac)
   ```

## Project Structure
- `lib/main.dart`: Main entry point and core application logic.
- `assets/`: Contains the TensorFlow Lite model, label map, logo, and test image.
- `pubspec.yaml`: Lists dependencies and assets.

## Dependencies
The project uses the following Flutter packages:
- `camera`: For accessing the device's camera.
- `volume_controller`: For handling volume button events.
- `permission_handler`: For requesting camera permissions.
- `flutter_tts`: For text-to-speech functionality.
- `tflite_flutter`: For running TensorFlow Lite models.
- `image`: For image processing.

Ensure these are listed in `pubspec.yaml`:
```yaml
dependencies:
  flutter:
    sdk: flutter
  camera: ^0.10.0
  volume_controller: ^0.1.0
  permission_handler: ^10.0.0
  flutter_tts: ^3.0.0
  tflite_flutter: ^0.9.0
  image: ^4.0.0
```

## How to Use
1. **Launch the App**: The app starts with a splash screen displaying the logo and announces "Starting page" via TTS.
2. **Main Page**: After 3 seconds, the app navigates to the main page, which displays the logo and a camera button. TTS announces "Main page. Press volume up to open camera."
3. **Open Camera**: Press the volume up button or tap the camera icon to navigate to the camera page.
4. **Camera Page**: The camera feed starts, and the app performs real-time object detection. Detected objects are announced via TTS with their confidence scores. Bounding boxes and labels are drawn on the screen.
5. **Return to Main Page**: Press the volume down button or tap the home icon to return to the main page. TTS announces "Returning to main page."
6. **Test Static Image**: On the camera page, press the "Test Inference with Static Image" button to run object detection on `test_image.jpg`.

## Troubleshooting
- **Camera Permission Denied**: Ensure camera permissions are granted in the device settings.
- **Model Fails to Load**: Verify that `efficientdet_lite0.tflite` is correctly placed in `assets/` and listed in `pubspec.yaml`.
- **TTS Not Working**: Check if the device has TTS engines installed (Settings > Accessibility > Text-to-Speech).
- **No Detections**: Ensure `labelmap.txt` contains the correct labels and matches the model's output classes.

## Contributing
To contribute:
1. Fork the repository.
2. Create a feature branch (`git checkout -b feature/your-feature`).
3. Commit changes (`git commit -m "Add your feature"`).
4. Push to the branch (`git push origin feature/your-feature`).
5. Open a pull request.

## License
This project is licensed under the MIT License. See the `LICENSE` file for details.