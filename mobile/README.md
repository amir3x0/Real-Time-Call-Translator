# Real-Time Call Translator - Mobile App

Flutter mobile application for real-time multilingual call translation with voice cloning.

## 📱 Platform Support

- ✅ **Android** 6.0+ (API level 23+)
- ✅ **iOS** 12.0+

## 🚀 Getting Started

### Prerequisites

- Flutter SDK 3.35.1 or higher
- Dart 3.9.0 or higher
- Android Studio (for Android development)
- Xcode (for iOS development, macOS only)

### Installation

1. **Navigate to mobile directory:**
	```powershell
	cd mobile
	```

2. **Install dependencies:**
	```powershell
	flutter pub get
	```

3. **Run on connected device:**
	```powershell
	flutter run
	```

4. **Build for release:**
	```powershell
	# Android APK
	flutter build apk --release
   
	# iOS (macOS only)
	flutter build ios --release
	```

## 📂 Project Structure

```
mobile/
├── lib/
│   ├── main.dart                  # App entry point
│   ├── config/
│   │   └── app_config.dart       # Configuration constants
│   ├── models/
│   │   ├── user.dart             # User data model
│   │   ├── call.dart             # Call session model
│   │   └── participant.dart      # Call participant model
│   ├── services/                 # API clients & business logic
│   ├── screens/                  # UI screens
│   └── widgets/                  # Reusable widgets
├── test/                         # Widget & unit tests
├── android/                      # Android-specific code
├── ios/                          # iOS-specific code
└── pubspec.yaml                  # Dependencies
```

## 📦 Dependencies

### Core
- **flutter**: UI framework
- **provider**: State management
- **http**: REST API communication
- **web_socket_channel**: Real-time WebSocket connection

### Audio
- **flutter_sound**: Audio recording
- **just_audio**: Audio playback
- **permission_handler**: Microphone permissions

### Utilities
- **shared_preferences**: Local storage
- **intl**: Internationalization

## 🎨 Features (Planned)

- [ ] User authentication (Google Sign-In, Firebase)
- [ ] Contact management
- [ ] Voice sample recording & upload
- [ ] Real-time call translation
- [ ] Voice cloning integration
- [ ] Multi-participant calls (2-4 people)
- [ ] Language selection (Hebrew, English, Russian)
- [ ] Call history
- [ ] Settings & preferences

## 🧪 Testing

Run all tests:
```powershell
flutter test
```

Run with coverage:
```powershell
flutter test --coverage
```

Run widget tests only:
```powershell
flutter test test/widget_test.dart
```

## 🔧 Configuration

Edit `lib/config/app_config.dart` to configure:

```dart
class AppConfig {
  static const String baseUrl = 'http://localhost:8000';
  static const String wsUrl = 'ws://localhost:8000';
  static const List<String> supportedLanguages = ['he', 'en', 'ru'];
}
```

## 📱 Running on Devices

### Android Emulator
```powershell
# List available devices
flutter devices

# Run on emulator
flutter run -d emulator-5554
```

### iOS Simulator (macOS only)
```powershell
# List available simulators
flutter devices

# Run on simulator
flutter run -d iPhone-15-Pro
```

### Physical Device
```powershell
# Enable USB debugging on device
# Connect via USB

flutter run
```

## 🐛 Troubleshooting

### Common Issues

**Issue:** `flutter pub get` fails
```powershell
# Clear cache and retry
flutter clean
flutter pub get
```

**Issue:** Build fails on Android
```powershell
cd android
./gradlew clean
cd ..
flutter build apk
```

**Issue:** iOS build fails
```powershell
cd ios
pod install
cd ..
flutter build ios
```

## 📚 Documentation

- [Flutter Documentation](https://docs.flutter.dev/)
- [Dart Language Guide](https://dart.dev/guides)
- [Provider State Management](https://pub.dev/packages/provider)

## 🤝 Contributing

See [CONTRIBUTING.md](../.github/docs/CONTRIBUTING.md) for guidelines.

## 📄 License

This project is licensed under the MIT License - see [LICENSE](../LICENSE) for details.

---

**Project:** Real-Time Call Translator  
**Institution:** Braude College - Software Engineering  
**Team:** Amir Mishayev, Daniel Fraimovich  
**Project Code:** 25-2-D-5
