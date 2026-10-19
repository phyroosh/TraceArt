# TraceArt 🎨

TraceArt transforms your Android smartphone or tablet into a digital tracing lightbox. Select any sketch, line art, or photo from your device, lock the screen against accidental touch, and place physical paper directly over your display to trace effortlessly.

---

## ✨ Features

- **🖼️ Gallery Image Import**: Easily pick reference sketches, portraits, calligraphy, or designs from your device gallery.
- **🔒 Canvas Lock Mode**: Completely disables accidental gestures, drags, and taps so you can rest your hand and paper directly on the display while tracing.
- **🛡️ 3-Dot Safety Unlock**: Unlocking requires tapping the floating 3-dot control button, ensuring your tracing workflow isn't interrupted by random hand movements.
- **💡 Lightbox Brightness & Keep-Awake**: Automatically maximizes display brightness and keeps the screen awake so your backlight illuminates through thick drawing paper.
- **🌓 Inverted Contrast Mode**: Toggle color inversion with one tap to maximize edge visibility for dark or complex line art.
- **🔄 Precision Transformations**: Smooth pinch-to-zoom, two-finger panning, 90° canvas rotation, fit-to-screen, and quick-reset.
- **📱 Clean Modern UI**: Built with Material Design 3 for a minimal, distraction-free creative workspace.

---

## 🚀 Download & Install

Download the latest production-ready APK directly from the **[Releases](https://github.com/phyroosh/TraceArt/releases)** page.

1. Download `app-release.apk` on your Android device.
2. Open the file and allow installation from unknown sources if prompted.
3. Launch **TraceArt** and start tracing!

---

## 🛠️ Building From Source

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.13.5 or newer)
- [Android SDK](https://developer.android.com/studio) with Java 17+

### Steps

1. **Clone the repository:**
   ```bash
   git clone https://github.com/phyroosh/TraceArt.git
   cd TraceArt
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run tests:**
   ```bash
   flutter test
   ```

4. **Build release APK:**
   ```bash
   flutter build apk --release
   ```
   The generated APK will be available at:
   `build/app/outputs/flutter-apk/app-release.apk`

---

## 🏗️ Architecture & Stack

- **Framework**: [Flutter](https://flutter.dev) (Dart)
- **Pattern**: MVVM architecture (`TracingViewModel` with `ChangeNotifier`)
- **Key Packages**:
  - `image_picker`: Device gallery integration
  - `screen_brightness`: Display illumination management
  - `wakelock_plus`: Prevents screen timeout during tracing
  - `flutter_lints`: Strict code quality guidelines

---

## 📄 License

This project is open-source under the MIT License.
