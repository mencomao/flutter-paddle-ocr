# v0.3 migration plan — switch native backends to ONNX Runtime Mobile

**Status:** implemented for Android and iOS native inference. The plugin now uses ONNX Runtime Mobile with PP-OCRv5 mobile `.onnx` det/rec models. Remaining follow-up: replace the iOS OpenCV framework so Apple Silicon iOS 26+ simulators do not need the arm64-simulator exclusion.

## Why

- PaddleOCR mainline has effectively de-prioritized the Paddle Lite path. PP-OCRv5 ships as `.onnx` (used by paddleocr-js on web) but not as `.nb`.
- The plugin's web backend already runs ONNX Runtime via paddleocr-js. Migrating the native sides to ONNX Runtime Mobile **converges all three platforms on the same model format**.
- Side benefit: ONNX Runtime ships proper iOS XCFrameworks with arm64-simulator slices, so the "device-only" iOS gap goes away.

## Scope

Same Dart public API. `ModelSource.filePaths` keeps working; the files are now `.onnx` (det + rec) plus the same character dictionary. No callers should need to change.

| Layer | Today | After v0.3 |
| --- | --- | --- |
| Android engine | Paddle Lite v2.10 `libpaddle_light_api_shared.so` | `com.microsoft.onnxruntime:onnxruntime-android` (gradle dep) |
| iOS engine | Paddle Lite v2.10 `libpaddle_api_light_bundled.a` (arm64-device only) | `onnxruntime-c` CocoaPod |
| Models | PP-OCRv2/v3 slim `.nb` from PaddleOCR's bcebos bucket | PP-OCRv5 mobile `.onnx` from `paddle-model-ecology.bj.bcebos.com/paddlex/official_inference_model/paddle3.0.0/` |
| Pre/postprocessing C++ | `ocr_db_post_process`, `ocr_crnn_process`, `ocr_clipper`, perspective-warp helpers | **Reused as-is** — they're plain OpenCV + vector math, engine-agnostic |
| JNI / Obj-C++ wrappers | Talk to `paddle::lite_api::MobileConfig` | Talk to `Ort::Session` |
| Web backend | paddleocr-js (no change) | paddleocr-js (no change) |
| Plugin Dart API | `PaddleOcr.create(source: ModelSource.filePaths(...))` | Same |

## Critical files to touch

**Android**
- `android/build.gradle` — dropped the Paddle Lite archive download; added `onnxruntime-android` and AAR extraction for C++ headers/libs. OpenCV download remains for pre/post.
- `android/src/main/cpp/native.cpp` + `ocr_ppredictor.{cpp,h}` + `ppredictor.{cpp,h}` + `predictor_input.{cpp,h}` + `predictor_output.{cpp,h}` — Paddle Lite calls replaced with ORT C++ session calls.
- `android/src/main/cpp/CMakeLists.txt` — dropped `paddle_light_api_shared`; links `libonnxruntime.so` from the extracted AAR.
- `android/src/main/java/com/baidu/paddle/lite/demo/ocr/OCRPredictorNative.java` — keep the JNI surface shape (init/forward/release) so Kotlin doesn't change; reimplement the C++ side.

**iOS**
- `ios/flutter_paddle_ocr_v5.podspec` — dropped Paddle Lite download/static lib; added `onnxruntime-c ~> 1.20.0` to preserve iOS 13 support. OpenCV is still downloaded by `prepare_command`.
- `ios/Classes/ppocr/ort_predictor.{h,cpp}` — new shared ORT C++ session wrapper.
- `ios/Classes/ppocr/det_process.cpp`, `rec_process.cpp`, `cls_process.cpp` — Paddle Lite calls replaced with `OrtPredictor`; pre/postprocess kept and adjusted for PP-OCRv5 mobile rec height/det thresholds.

**Plugin Dart** — no API changes. README + CHANGELOG update only.

**Example** — update `mobile_bootstrap.dart` to download `.onnx` files instead of `.tar.gz` of `.nb` files. Same `ModelSource.filePaths(det, rec, dict)` call.

## Open questions to settle before starting

1. **Which PP-OCRv5 ONNX variant** — there are server (large) and mobile-tuned ONNX exports. The web backend uses `PP-OCRv5_mobile_*` based on the paddleocr-js defaults; mirror those for parity.
2. **OpenCV on iOS** — keep pulling the 4.5.5 framework via `prepare_command` (works today) or switch to a CocoaPods `OpenCV` pod for cleaner integration?
3. **Bundle size delta** — onnxruntime-android is ~7-12 MB per ABI vs Paddle Lite's ~5 MB. Worth measuring before locking in.
4. **Quantization** — Paddle Lite slim models were INT8; the published PP-OCRv5 ONNX may be FP32 only, which would slow inference noticeably. Check what paddleocr-js loads (its config probably reveals the quantized variant) and use the same.
5. **Cold-start time** — ORT sessions take longer to warm up than Paddle Lite. May need to expose a warmup option in the Dart API.

## Non-goals

- **Don't ship PaddleOCR-VL** (the v3.5 flagship VLM). At ~0.9 B params it's gigabytes on disk and needs gigabytes of RAM — server/desktop only.
- **Don't add a Python embedding fallback.** Heavy, slow, App Store-hostile.

## Out of scope but related

- If we ever add `ModelSource.bundled` support on mobile (the v0.2 stub throws `UnsupportedError`), the model-download helper currently in `example/lib/mobile_bootstrap.dart` would move into the plugin. ONNX URLs are well-known and stable, so this becomes more attractive after v0.3.

## Estimated effort

~1 week per platform once the open questions are answered. Most of the C++ glue is replaceable in chunks; Dart and Kotlin/Swift surfaces don't move.
