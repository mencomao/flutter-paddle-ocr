## 0.0.2

* **iOS support**: arm64 device builds wrapping Paddle-Lite-Demo's ppocr pipeline. Simulator is blocked by Paddle Lite v2.10 shipping only an arm64-device `.a`.
* **Web support**: `FlutterPaddleOcrWeb` binds paddleocr-js (ONNX Runtime Web + OpenCV.js) via `dart:js_interop`. PP-OCRv5 models auto-fetched from the CDN.
* **API refactor (breaking)**: `PaddleOcr.create` now takes a sealed `ModelSource` (`ModelSource.filePaths(...)` for native, `ModelSource.bundled(...)` for web) instead of positional `detModelPath` / `recModelPath` / `labelPath` / `clsModelPath` arguments.
* Android implementation moved behind `FlutterPaddleOcrPlatform` so iOS and Web can register alongside it.
* Example app branches between mobile/web via `kIsWeb`; ships `prepare_web.sh` for bundling paddleocr-js.

## 0.0.1

* Initial release — Android only (arm64-v8a).
* Reuses PaddleOCR's `deploy/android_demo/` C++/Java verbatim (Paddle Lite v2.10).
* Dart API: `PaddleOcr.create`, `recognize`, `dispose`; `OcrResult`, `CpuPower`.
* iOS is a stub; all methods return `PlatformException(UNIMPLEMENTED)`.
