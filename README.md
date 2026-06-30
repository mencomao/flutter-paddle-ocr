# flutter_paddleorc

[![License: Apache-2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-plugin-02569B.svg)](https://flutter.dev)
[![PaddleOCR](https://img.shields.io/badge/PaddleOCR-PP--OCRv5-1E88E5.svg)](https://github.com/PaddlePaddle/PaddleOCR)

English | [简体中文](README.zh-CN.md)

A Flutter plugin for on-device OCR, powered by PaddleOCR-compatible PP-OCR
models and ONNX Runtime.

The goal of this project is to make high-quality OCR usable from one Dart API
across Android, iOS, and Web. It is an independent community project, not an
official PaddleOCR package.

<p align="center">
  <img src="doc/screenshots/android.png" width="280" alt="Android example running OCR" />
  &nbsp;
  <img src="doc/screenshots/web_result.png" width="280" alt="Web example running OCR" />
</p>

## Features

- One Dart API for Android, iOS, and Web.
- Mobile inference through ONNX Runtime and native PaddleOCR-style
  pre/post-processing.
- Web inference through
  [`@paddleocr/paddleocr-js`](https://www.npmjs.com/package/@paddleocr/paddleocr-js).
- PP-OCRv5 mobile ONNX model support.
- Text box polygons, recognized text, and confidence scores.
- Example app with model download, UTF-8 dictionary extraction, sample image,
  gallery picking, and web bootstrap script.

## Platform Support

| Platform | Status | Backend | Model source |
| --- | --- | --- | --- |
| Android arm64-v8a | Supported | ONNX Runtime Android `1.27.0` + OpenCV | `ModelSource.filePaths` |
| iOS arm64 device | Supported | `onnxruntime-c ~> 1.20.0` + OpenCV | `ModelSource.filePaths` |
| Web | Supported | paddleocr-js + ONNX Runtime Web | `ModelSource.bundled` |
| Android 32-bit | Not packaged | N/A | N/A |
| iOS Apple Silicon simulator | Limited | Current OpenCV framework lacks arm64-simulator slice | Use a real device or x86_64 simulator where available |

## PaddleOCR Model Support

| PaddleOCR model family | Status | Notes |
| --- | --- | --- |
| PP-OCRv5 mobile ONNX | Supported | Current default for Android, iOS, and Web |
| PP-OCRv6 small/tiny ONNX | Planned | The ONNX Runtime backend is a good fit, but v6 still needs downloader changes, YAML parsing, parameter wiring, and device benchmarks |
| PP-OCRv6 medium ONNX | Not targeted for mobile | Server-oriented model size and latency profile |
| Paddle Lite `.nb` PP-OCRv2/v3 | Replaced | The old Paddle Lite mobile backend has been removed in this branch |

The Dart API is model-family agnostic, but PaddleOCR preprocessing and
postprocessing are model-specific. A newer `.onnx` file should not be assumed to
work by path replacement alone.

## Installation

Use the package from pub.dev when published:

```sh
flutter pub add flutter_paddleorc
```

Or depend on a local checkout:

```yaml
dependencies:
  flutter_paddleorc:
    path: ../flutter-paddle-ocr
```

## Quick Start

```dart
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_paddleorc/flutter_paddleorc.dart';

Future<List<OcrResult>> recognizeImage(Uint8List imageBytes) async {
  final source = kIsWeb
      ? const ModelSource.bundled(lang: 'ch', version: 'PP-OCRv5')
      : const ModelSource.filePaths(
          det: '/absolute/path/PP-OCRv5_mobile_det.onnx',
          rec: '/absolute/path/PP-OCRv5_mobile_rec.onnx',
          dict: '/absolute/path/ppocr_keys_v5_utf8.txt',
        );

  final ocr = await PaddleOcr.create(source: source, cpuThreadNum: 4);

  try {
    return await ocr.recognize(
      imageBytes,
      maxSideLen: 960,
      runDetection: true,
      runClassification: false,
      runRecognition: true,
    );
  } finally {
    await ocr.dispose();
  }
}
```

Each `OcrResult` contains:

- `text`: recognized string
- `confidence`: recognition confidence
- `points`: text polygon in source-image pixels
- `isUpsideDown` and `angleConfidence`: optional angle-classifier result

## Mobile Models

Android and iOS currently use `ModelSource.filePaths`, so the application must
provide local model and dictionary files. The example app downloads PP-OCRv5
mobile ONNX assets on first launch:

- Detection model:
  `https://paddle-model-ecology.bj.bcebos.com/paddlex/official_inference_model/paddle3.0.0/PP-OCRv5_mobile_det_onnx_infer.tar`
- Recognition model:
  `https://paddle-model-ecology.bj.bcebos.com/paddlex/official_inference_model/paddle3.0.0/PP-OCRv5_mobile_rec_onnx_infer.tar`

The recognition archive includes `inference.yml`. The example extracts
`PostProcess.character_dict` into `ppocr_keys_v5_utf8.txt` using UTF-8. This is
important for Chinese and multilingual recognition; a dictionary written with a
wrong charset will produce garbled text.

See [example/lib/mobile_bootstrap.dart](example/lib/mobile_bootstrap.dart) for
the complete downloader and dictionary extractor.

## Run The Example

Mobile:

```sh
cd example
flutter run
```

Web:

```sh
cd example
./prepare_web.sh
flutter run -d chrome
```

The example includes a bundled sample image and supports selecting an image from
the gallery. Mobile first launch downloads about 21 MB of PP-OCRv5 ONNX model
files.

## Setup Notes

### Android

- Minimum SDK: 24
- Packaged ABI: `arm64-v8a`
- NDK: `27.3.13750724`

Install the NDK if needed:

```sh
sdkmanager --install "ndk;27.3.13750724"
```

The plugin build downloads ONNX Runtime Android from Maven Central and OpenCV
Android SDK from Paddle Lite demo storage. Generated native files are cached
under `android/cache/`, `android/OpenCV/`, and `android/OnnxRuntime/`.

### iOS

- iOS 13+
- Real device: arm64
- CocoaPods

During `pod install`, the plugin resolves `onnxruntime-c` and downloads an
OpenCV iOS framework. If your app picks images from the photo library, add:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>OCR on images from your photo library.</string>
```

### Web

The web backend expects `window.PaddleOCR`. The example uses esbuild to bundle
`@paddleocr/paddleocr-js` into `web/paddleocr_bundle.js`.

Your own app can copy the same bootstrap approach from
[example/prepare_web.sh](example/prepare_web.sh) and
[example/web/index.html](example/web/index.html).

## Architecture

```text
Dart PaddleOcr
  -> FlutterPaddleOcrPlatform
    -> Android MethodChannel -> Kotlin -> JNI -> C++ -> ONNX Runtime
    -> iOS MethodChannel     -> Swift  -> Obj-C++ -> ONNX Runtime
    -> Web                   -> dart:js_interop -> paddleocr-js
```

The native preprocessing and postprocessing code follows PaddleOCR/Paddle-Lite
demo pipelines. The inference adapter has been changed from Paddle Lite to ONNX
Runtime so mobile and web can share ONNX model families.

## Troubleshooting

### Chinese text is garbled

Regenerate the dictionary as UTF-8. The example writes
`ppocr_keys_v5_utf8.txt` from `inference.yml`. If an older bad dictionary is
already cached, delete app data or reinstall the example app.

### `character_dict not found in recognition inference.yml`

Use the latest [example/lib/mobile_bootstrap.dart](example/lib/mobile_bootstrap.dart).
PP-OCRv5 stores the dictionary under `PostProcess.character_dict`, and the first
item can be a fullwidth space. Trimming dictionary lines can break extraction.

### iOS install fails with `objective_c.framework` invalid signature

Do not install an app produced by `flutter build ios --no-codesign`. Clean
unsigned output and rebuild with normal code signing:

```sh
cd example
flutter clean
flutter pub get
flutter run -d <device-id>
```

### iOS simulator cannot build for arm64

The current OpenCV framework does not include an arm64-simulator slice. Use a
real device or an x86_64 simulator runtime where available.

## Roadmap

- Add first-class `PP-OCRv6_small` and `PP-OCRv6_tiny` profiles.
- Parse `inference.yml` more completely instead of hardcoding detection and
  recognition parameters.
- Move the mobile model downloader from the example into the plugin as mobile
  `ModelSource.bundled`.
- Add Android/iOS benchmark views for cold start, detection time, recognition
  time, total latency, and peak memory.
- Improve iOS OpenCV distribution so Apple Silicon simulators do not require
  excluding arm64.
- Evaluate optional ONNX Runtime acceleration paths such as iOS Core ML
  Execution Provider and Android NNAPI after correctness is stable.

## Contributing

Issues and pull requests are welcome. Helpful contributions include:

- Android and iOS device benchmark results
- PP-OCRv6 model profile support
- OpenCV packaging improvements
- Web bundling improvements
- Better examples and documentation

Please keep changes focused and include the device, OS, Flutter version, and
model version when reporting runtime or accuracy issues.

## Upstream Projects And Acknowledgements

This project is possible because of excellent open-source work from the OCR,
Flutter, and native inference communities.

Special thanks to:

- [PaddleOCR](https://github.com/PaddlePaddle/PaddleOCR) for the PP-OCR model
  family and OCR pipeline design.
- [PaddleOCR Android demo](https://github.com/PaddlePaddle/PaddleOCR/tree/main/deploy/android_demo)
  and [Paddle-Lite-Demo iOS ppocr demo](https://github.com/PaddlePaddle/Paddle-Lite-Demo/tree/develop/ocr/ios/ppocr_demo)
  for native preprocessing/postprocessing references.
- [flutter-paddle-ocr by phanbaohuy96](https://github.com/phanbaohuy96/flutter-paddle-ocr),
  the original Flutter plugin this work started from.
- [ONNX Runtime](https://github.com/microsoft/onnxruntime) for cross-platform
  ONNX inference.
- [paddleocr-js](https://www.npmjs.com/package/@paddleocr/paddleocr-js) for the
  web OCR runtime.
- [OpenCV](https://opencv.org/) for image processing primitives.
- [Flutter](https://flutter.dev/) for the cross-platform application framework.

This repository is not affiliated with, sponsored by, or endorsed by
PaddlePaddle, PaddleOCR, Microsoft, OpenCV, or Flutter.

## License

This project is released under the [Apache License 2.0](LICENSE).

Model files and third-party dependencies are distributed by their respective
owners under their own licenses and terms. Check those projects before
redistributing model weights or native binaries in a commercial application.
