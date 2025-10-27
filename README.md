# Face Tracking Test

A Flutter application that demonstrates real-time face tracking using head movements. **Perfect for testing face detection on iOS devices!**

## 📁 Repository Setup

This POC has been committed to GitHub. To get started:

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/ios-face-tracking-poc.git
cd ios-face-tracking-poc

# Install dependencies
flutter pub get

# Run on iOS (make sure camera permissions are enabled in Settings > Privacy & Security > Camera)
flutter run
```

## Features

- **Face Tracking Test**: Simple interface with large visual arrows that respond to head movements
- **Real-time Feedback**: Visual indicator shows when a face is detected
- **4-Direction Control**:
  - Tilt head UP (above threshold) → Up arrow turns green
  - Tilt head DOWN (above threshold) → Down arrow turns green
  - Tilt head LEFT (above threshold) → Left arrow turns green
  - Tilt head RIGHT (above threshold) → Right arrow turns green
- **Smart Movement Detection**: Uses absolute angles with dead zones to prevent false movements when returning to center position
- **Visual Feedback**: Arrows light up for 800ms when movement is detected, then return to grey

## How to Use

1. **Camera Access**: The app assumes camera permission is already granted (no permission request)
2. **Position Your Face**: Keep your face visible in the camera preview (top-right corner)
3. **Test Face Tracking**:
   - **Tilt head up** (above 8° threshold) → Up arrow turns green for 800ms
   - **Tilt head down** (above 8° threshold) → Down arrow turns green for 800ms
   - **Tilt head left** (above 8° threshold) → Left arrow turns green for 800ms
   - **Tilt head right** (above 8° threshold) → Right arrow turns green for 800ms
4. **Smart Detection**: The system uses absolute angles, so returning to center position won't trigger opposite movements
5. **Adjust Settings**: Use the settings button to fine-tune tilt sensitivity (default: 8°)

### Loading Process

When you start the app, you'll see:
- **Initial Loading**: Circular progress indicator while app initializes
- **Camera Setup**: Camera preview shows "Camera Initializing..." until ready
- **Face Detection**: Green "Face" indicator when a face is detected

## Important Note

⚠️ **Camera Permission Required**: This app assumes camera permission is already granted. If you see a black camera preview or error messages, please enable camera access in your device settings before running the app.

## Technical Implementation

- **Camera**: Uses `camera` package for camera access
- **Face Detection**: Google ML Kit for real-time face detection and landmark tracking
- **Visual Testing**: Interactive arrow interface for testing face movements
- **Permission-Free**: Assumes camera permission is pre-granted (no runtime permission requests)

## Platform Compatibility

### Android
- Assumes camera permission is pre-granted
- Optimized for front camera usage

### iOS
- **Minimum iOS Version**: 15.5+ (required by Google ML Kit)
- Assumes camera permission is pre-granted
- Camera access configured in Info.plist for system-level permission

## Dependencies

- `camera: ^0.11.0+2` - Camera access
- `google_mlkit_face_detection: ^0.12.0` - Face detection
- `path_provider: ^2.1.4` - File system access

## Getting Started

1. Ensure Flutter development environment is set up
2. Run `flutter pub get` to install dependencies
3. **For iOS**: Ensure your development environment supports iOS 15.5+ (required by Google ML Kit)
4. **Enable Camera Permission** (Required):
   - **Android**: Enable camera permission in device settings
   - **iOS**: Enable camera permission in device settings (Settings > Privacy & Security > Camera)
5. Connect a device or start an emulator
6. Run `flutter run` to launch the app

## Troubleshooting

### App Freezing on Startup

If the app freezes or doesn't load:

1. **Check Camera Permission**: Ensure camera access is enabled in device settings
2. **Network Issues**: The app loads a PDF from the internet - check your internet connection
3. **Device Compatibility**: Requires iOS 15.5+ or Android with camera support
4. **Memory Issues**: Close other apps if the device is low on memory

### Error Messages

- **"Camera initialization failed"**: Enable camera permission in device settings
- **"PDF failed to load"**: Check internet connection or the PDF URL may be unavailable
- **"No camera available"**: Ensure your device has a working camera

### Performance Tips

- Lower camera resolution is used for better performance
- Face detection runs efficiently with debouncing
- App shows loading states during initialization
