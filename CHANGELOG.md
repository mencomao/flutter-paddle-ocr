## 0.0.1

* Initial `flutter_paddleorc` release.
* Supports Android arm64-v8a, iOS arm64 devices, and Web through one Dart API.
* Runs PP-OCRv5 mobile ONNX detection and recognition models on Android and iOS with ONNX Runtime.
* Uses `paddleocr-js` for the Web backend.
* Provides `ModelSource.filePaths(...)` for mobile model paths and `ModelSource.bundled(...)` for Web.
* Includes an example app with PP-OCRv5 model download, UTF-8 dictionary extraction, sample image OCR, gallery picking, and web bootstrap support.
