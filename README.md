# sensemate-mobile

SenseMate Mobile is a Flutter-based application designed to assist users with visual impairments by providing real-time object detection using a device's camera. The app utilizes Google ML Kit for on-device machine learning, text-to-speech (TTS) for audio feedback, and volume button interactions for navigation.

## Features
- **Real-time Object Detection**: Uses Google ML Kit's object detection to identify objects in the camera feed.
- **Text-to-Speech Feedback**: Announces detected objects and navigation instructions via TTS.
- **Volume Button Navigation**: Press volume up to open the camera and volume down to return to the main page.
- **Accessibility**: Designed with accessibility in mind, featuring high-contrast visuals and audio cues.

## Prerequisites
To run the project, ensure you have the following installed:
- [Flutter](https://flutter.dev/docs/get-started/install) (version 3.7 or higher)
- [Dart](https://dart.dev/get-dart)
- [Android Studio](https://developer.android.com/studio) or [Visual Studio Code](https://code.visualstudio.com/) with Flutter plugins
- An Android or iOS device/emulator with camera support
- Git (to clone the repository)

## Project Setup
Follow these steps to set up and run the project locally:

1. **Clone the Repository**
   ```bash
   git clone https://github.com/Ahmed100102/sensemate-mobile.git
   cd sensemate-mobile
   ```

2. **Install Dependencies**
   Ensure you are in the project directory and run:
   ```bash
   flutter pub get
   ```

3. **Add Required Assets**
   Ensure the following assets are in the `assets/` directory:
    - `logo.png`: App logo for the starting and main pages

   Update the `pubspec.yaml` to include these assets:
   ```yaml
   flutter:
     assets:
       - assets/logo.png
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
- `assets/`: Contains the app logo.
- `pubspec.yaml`: Lists dependencies and assets.

## Dependencies
The project uses the following Flutter packages:
- `camera`: For accessing the device's camera.
- `volume_controller`: For handling volume button events.
- `permission_handler`: For requesting camera permissions.
- `flutter_tts`: For text-to-speech functionality.
- `tflite_flutter`: For running TensorFlow Lite models (not used in current implementation, but present in dependencies).
- `image`: For image processing.
- `google_mlkit_object_detection`: For real-time object detection.

Ensure these are listed in `pubspec.yaml`:
```yaml
dependencies:
  flutter:
    sdk: flutter
  camera: ^0.10.5+9
  volume_controller: ^3.3.3
  permission_handler: ^11.3.1
  flutter_tts: ^4.0.2
  tflite_flutter: ^0.11.0
  image: ^4.5.4
  google_mlkit_object_detection: ^0.15.0
```

## How to Use
1. **Launch the App**: The app starts with a splash screen displaying the logo and announces "Starting page" via TTS.
2. **Main Page**: After 3 seconds, the app navigates to the main page, which displays the logo and a camera button. TTS announces "Main page. Press volume up to open camera."
3. **Open Camera**: Press the volume up button or tap the camera icon to navigate to the camera page.
4. **Camera Page**: The camera feed starts, and the app performs real-time object detection. Detected objects are announced via TTS with their confidence scores. Bounding boxes and labels are drawn on the screen.
5. **Return to Main Page**: Press the volume down button or tap the home icon to return to the main page. TTS announces "Returning to main page."

## Troubleshooting
- **Camera Permission Denied**: Ensure camera permissions are granted in the device settings.
- **TTS Not Working**: Check if the device has TTS engines installed (Settings > Accessibility > Text-to-Speech).
- **No Detections**: Ensure your device supports Google ML Kit and camera functionality.

## Contributing
To contribute:
1. Fork the repository.
2. Create a feature branch (`git checkout -b feature/your-feature`).
3. Commit changes (`git commit -m "Add your feature"`).
4. Push to the branch (`git push origin feature/your-feature`).
5. Open a pull request.

