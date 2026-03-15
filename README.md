# live_beauty_filter

A Flutter plugin for iOS that applies a real-time **milky/soft beauty filter** to the live camera feed, entirely on the GPU. Built on AVFoundation + CoreImage + Metal — zero CPU pixel processing.

---

## Features

- Live camera preview with milky filter applied in real-time
- GPU-only pipeline — no frame drops, no battery drain from CPU processing
- Adjustable filter intensity at runtime (0.0 → 1.0)
- Front camera with correct mirroring and portrait orientation
- Zero-copy frame delivery to Flutter via `Texture` widget
- Filter chain: Gaussian blur → Bloom/Glow → Color grade (brightness + contrast lift)

---

## Platform support

| Platform | Supported |
|----------|-----------|
| iOS      | ✅ iOS 14+ |
| Android  | ❌ Not supported |

---

## Installation

This is a local plugin — add it to your `pubspec.yaml`:

```yaml
dependencies:
  live_beauty_filter:
    path: ../live_beauty_filter
```

Add camera permission to your app's `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Camera is used for the live beauty filter preview.</string>
```

Plugin registration is automatic via Flutter's `GeneratedPluginRegistrant` — no `AppDelegate.swift` changes needed.

---

## Usage

### Basic live preview

```dart
import 'package:live_beauty_filter/live_beauty_filter.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final _controller = MilkyFilterController();

  @override
  void initState() {
    super.initState();
    _controller.initialize().then((_) => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Texture(textureId: _controller.textureId!);
  }
}
```

### Adjusting filter intensity

```dart
// intensity: 0.0 = no filter, 1.0 = full milky
await _controller.setFilterIntensity(0.7);
```

### Drop-in widget with built-in intensity slider

```dart
MilkyCameraView()
```

---

## How the filter works

The milky look is achieved by chaining three CoreImage GPU passes on every frame:

```
CVPixelBuffer (raw frame)
    │
    ▼
CIGaussianBlur          — light softening (radius scales with intensity)
    │
    ▼
Bloom / Screen blend    — blurred copy composited over original for glow
    │
    ▼
CIColorControls         — brightness +, contrast -, saturation slight -
    │
    ▼
CIColorPolynomial       — raises black point (lifted shadows, milky whites)
    │
    ▼
CVPixelBuffer (filtered) → FlutterTexture → Texture() widget
```

All operations run on the Metal GPU via a `CIContext` created with `useSoftwareRenderer: false`. Frames are pooled with `CVPixelBufferPool` to eliminate per-frame heap allocation.

---

## API reference

### `MilkyFilterController`

| Method | Description |
|--------|-------------|
| `initialize()` | Starts the camera session and registers the GPU texture |
| `setFilterIntensity(double)` | Updates filter strength live (0.0–1.0, default 0.7) |
| `dispose()` | Stops capture and releases the texture |
| `textureId` | The Flutter texture ID — pass to `Texture(textureId: ...)` |
| `isInitialized` | Whether the camera and filter pipeline are ready |

### `MilkyFilterPipeline` (iOS internal)

| Property | Type | Description |
|----------|------|-------------|
| `intensity` | `Float` | Master filter strength, updated from Flutter via MethodChannel |

---

## Tuning the filter

Edit the constants in `MilkyFilterPipeline.swift` to adjust the look:

```swift
// MilkyFilterPipeline.swift

// Blur softness (max radius at intensity 1.0)
let blurRadius = Double(intensity) * 4.0          // increase for dreamier blur

// Bloom strength (how much glow blends back in)
let bloomStrength = Double(intensity) * 0.45      // increase for stronger glow

// Color grade
let brightnessBoost      = Double(intensity) * 0.08   // raise for brighter
let contrastReduction    = 1.0 - Double(intensity) * 0.15  // lower = flatter/milkier
let saturationReduction  = 1.0 - Double(intensity) * 0.12  // lower = more faded

// Blue channel lift in CIColorPolynomial
// inputBlueCoefficients: CIVector(x: intensity * 0.06, ...)
// Increase x for a cooler (more blue-white) milky tone
// Decrease for a warmer tone
```

---

## Testing

Integration tests must run on a physical device — the camera does not work on Simulator.

Grant camera permission by running the example app once manually first:

```bash
cd example
flutter run -d <your-device-id>
```

Then run the integration tests:

```bash
flutter test integration_test/plugin_integration_test.dart -d <your-device-id>
```

Expected output:
```
+2: All tests passed!
```

---

## Requirements

- iOS 14.0+
- Xcode 14+
- A physical device (camera does not work on Simulator)
- Swift 5.7+

---

## File structure

```
live_beauty_filter/
├── ios/
│   ├── Classes/
│   │   ├── LiveBeautyFilterPlugin.swift      # Flutter plugin entry + MethodChannel
│   │   ├── MilkyCameraController.swift       # AVCapture session + frame delivery
│   │   └── MilkyFilterPipeline.swift         # CIFilter GPU chain (blur + bloom + grade)
│   ├── Resources/
│   │   └── PrivacyInfo.xcprivacy             # App Store privacy manifest
│   └── live_beauty_filter.podspec
├── lib/
│   ├── live_beauty_filter.dart               # Barrel export (main entry point)
│   ├── milky_filter_controller.dart          # MethodChannel Dart wrapper
│   ├── milky_camera_view.dart                # Drop-in Flutter widget with slider
│   ├── live_beauty_filter_platform_interface.dart
│   └── live_beauty_filter_method_channel.dart
├── example/
│   ├── lib/
│   │   └── main.dart                         # Example app — fullscreen filter preview
│   ├── integration_test/
│   │   └── plugin_integration_test.dart      # Integration tests (run on physical device)
│   └── ios/
│       └── Runner/
│           └── Info.plist                    # Must contain NSCameraUsageDescription
├── pubspec.yaml
└── README.md
```

---

## License

This project is licensed under the MIT License see the [LICENSE](LICENSE) file for details.