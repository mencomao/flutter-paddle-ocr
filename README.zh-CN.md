# flutter_paddle_ocr_v5

[![License: Apache-2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-plugin-02569B.svg)](https://flutter.dev)
[![PaddleOCR](https://img.shields.io/badge/PaddleOCR-PP--OCRv5-1E88E5.svg)](https://github.com/PaddlePaddle/PaddleOCR)

[English](README.md) | 简体中文

一个面向 Flutter 的端侧 OCR 插件，基于 PaddleOCR 兼容的 PP-OCR 模型和
ONNX Runtime。

这个项目的目标是用一套 Dart API 在 Android、iOS 和 Web 上调用高质量 OCR。
它是独立的社区项目，不是 PaddleOCR 官方插件。

<p align="center">
  <img src="doc/screenshots/android.png" width="280" alt="Android example running OCR" />
  &nbsp;
  <img src="doc/screenshots/web_result.png" width="280" alt="Web example running OCR" />
</p>

## 功能特性

- Android、iOS、Web 共用一套 Dart API。
- 移动端通过 ONNX Runtime 和原生 PaddleOCR 风格预处理/后处理运行。
- Web 端通过
  [`@paddleocr/paddleocr-js`](https://www.npmjs.com/package/@paddleocr/paddleocr-js)
  运行。
- 支持 PP-OCRv5 mobile ONNX 模型。
- 返回文本框多边形、识别文本和置信度。
- 示例 App 包含模型下载、UTF-8 字典提取、内置样例图、相册选图和 Web 初始化脚本。

## 平台支持

| 平台 | 状态 | 后端 | 模型来源 |
| --- | --- | --- | --- |
| Android arm64-v8a | 支持 | ONNX Runtime Android `1.27.0` + OpenCV | `ModelSource.filePaths` |
| iOS arm64 真机 | 支持 | `onnxruntime-c ~> 1.20.0` + OpenCV | `ModelSource.filePaths` |
| Web | 支持 | paddleocr-js + ONNX Runtime Web | `ModelSource.bundled` |
| Android 32 位 | 暂未打包 | N/A | N/A |
| iOS Apple Silicon 模拟器 | 有限制 | 当前 OpenCV framework 缺少 arm64-simulator slice | 使用真机，或可用时使用 x86_64 模拟器 |

## PaddleOCR 模型支持

| PaddleOCR 模型族 | 状态 | 说明 |
| --- | --- | --- |
| PP-OCRv5 mobile ONNX | 已支持 | 当前 Android、iOS、Web 的默认模型族 |
| PP-OCRv6 small/tiny ONNX | 计划支持 | ONNX Runtime 后端适合承接 v6，但仍需要下载器调整、YAML 解析、参数传递和真机 benchmark |
| PP-OCRv6 medium ONNX | 不作为移动端目标 | 模型体积和延迟更偏服务端 |
| Paddle Lite `.nb` PP-OCRv2/v3 | 已替换 | 当前分支已经移除旧 Paddle Lite 移动端后端 |

Dart API 本身不绑定具体模型族，但 PaddleOCR 的预处理和后处理与模型配置相关。
不要假设只替换 `.onnx` 文件路径就能直接支持新的模型。

## 安装

发布到 pub.dev 后可以直接安装：

```sh
flutter pub add flutter_paddle_ocr_v5
```

或者依赖本地 checkout：

```yaml
dependencies:
  flutter_paddle_ocr_v5:
    path: ../flutter-paddle-ocr
```

## 快速开始

```dart
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_paddle_ocr_v5/flutter_paddle_ocr_v5.dart';

Future<List<OcrResult>> recognizeImage(Uint8List imageBytes) async {
  final source = kIsWeb
      ? const ModelSource.bundled(lang: 'ch', version: 'PP-OCRv5')
      : const ModelSource.filePaths(
          det: '/absolute/path/PP-OCRv5_mobile_det.onnx',
          rec: '/absolute/path/PP-OCRv5_mobile_rec.onnx',
          dict: '/absolute/path/ppocr_keys_v5_utf8.txt',
        );

  final ocr = await PaddleOcr.create(
    source: source,
    cpuThreadNum: 4,
    useSpaceChar: true,
    useDilation: false,
  );

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

每个 `OcrResult` 包含：

- `text`：识别文本
- `confidence`：识别置信度
- `points`：原图像素坐标系下的文本框多边形
- `isUpsideDown` 和 `angleConfidence`：可选方向分类结果

`PaddleOcr.create` 还为移动端后端暴露了两个 PaddleOCR 兼容的后处理开关：

- `useSpaceChar`：是否在识别字典末尾追加普通空格。默认 `true`，保持插件之前的
  行为，也符合 PaddleOCR 中文 OCR 常见配置。
- `useDilation`：是否在 DB 检测 bitmap 提框前执行 2x2 膨胀。默认 `false`，保持
  插件之前的行为。

Web 端的模型加载和后处理仍由 `paddleocr-js` 管理。

## 移动端模型

Android 和 iOS 当前使用 `ModelSource.filePaths`，因此应用需要提供本地模型和字典
文件。示例 App 首次启动会下载 PP-OCRv5 mobile ONNX 资源：

- 检测模型：
  `https://paddle-model-ecology.bj.bcebos.com/paddlex/official_inference_model/paddle3.0.0/PP-OCRv5_mobile_det_onnx_infer.tar`
- 识别模型：
  `https://paddle-model-ecology.bj.bcebos.com/paddlex/official_inference_model/paddle3.0.0/PP-OCRv5_mobile_rec_onnx_infer.tar`

识别模型压缩包中包含 `inference.yml`。示例会从
`PostProcess.character_dict` 提取字符表，并用 UTF-8 写入
`ppocr_keys_v5_utf8.txt`。这对中文和多语言识别非常关键；错误编码的字典会导致
识别结果乱码。

完整下载和字典生成逻辑见
[example/lib/mobile_bootstrap.dart](example/lib/mobile_bootstrap.dart)。

## 运行示例

移动端：

```sh
cd example
flutter run
```

Web：

```sh
cd example
./prepare_web.sh
flutter run -d chrome
```

示例内置了一张测试图片，也支持从相册选择图片。移动端首次运行会下载约 21 MB 的
PP-OCRv5 ONNX 模型文件。

## 接入说明

### Android

- Minimum SDK：24
- 当前打包 ABI：`arm64-v8a`
- NDK：`27.3.13750724`

如果缺少对应 NDK：

```sh
sdkmanager --install "ndk;27.3.13750724"
```

插件构建时会从 Maven Central 下载 ONNX Runtime Android，并从 Paddle Lite demo
存储下载 OpenCV Android SDK。生成的 native 依赖会缓存到 `android/cache/`、
`android/OpenCV/` 和 `android/OnnxRuntime/`。

### iOS

- iOS 13+
- arm64 真机
- CocoaPods

`pod install` 阶段会解析 `onnxruntime-c` 并下载 OpenCV iOS framework。如果你的
App 需要从相册选图，请添加权限：

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>OCR on images from your photo library.</string>
```

### Web

Web 后端需要页面上存在 `window.PaddleOCR`。示例使用 esbuild 把
`@paddleocr/paddleocr-js` 打包成 `web/paddleocr_bundle.js`。

你可以参考 [example/prepare_web.sh](example/prepare_web.sh) 和
[example/web/index.html](example/web/index.html)，在自己的应用中复用同样的初始化方式。

## 架构

```text
Dart PaddleOcr
  -> FlutterPaddleOcrPlatform
    -> Android MethodChannel -> Kotlin -> JNI -> C++ -> ONNX Runtime
    -> iOS MethodChannel     -> Swift  -> Obj-C++ -> ONNX Runtime
    -> Web                   -> dart:js_interop -> paddleocr-js
```

原生预处理和后处理逻辑参考 PaddleOCR/Paddle-Lite demo pipeline。当前分支把推理适配层
从 Paddle Lite 替换为 ONNX Runtime，让移动端和 Web 能共享 ONNX 模型体系。

## 常见问题

### 中文识别结果是乱码

重新生成 UTF-8 编码的字典。示例会从 `inference.yml` 写出
`ppocr_keys_v5_utf8.txt`。如果之前已经缓存过错误字典，删除 App 数据或重装示例 App。

### 报 `character_dict not found in recognition inference.yml`

请使用最新的 [example/lib/mobile_bootstrap.dart](example/lib/mobile_bootstrap.dart)。
PP-OCRv5 的字典位于 `PostProcess.character_dict`，第一项可能是全角空格。对字典行
做 trim 会破坏提取逻辑。

### iOS 安装时报 `objective_c.framework` invalid signature

不要安装 `flutter build ios --no-codesign` 生成的真机包。清理无签名产物后用正常签名
重新运行：

```sh
cd example
flutter clean
flutter pub get
flutter run -d <device-id>
```

### iOS 模拟器 arm64 构建失败

当前 OpenCV framework 缺少 arm64-simulator slice。建议使用真机，或在可用环境下使用
x86_64 模拟器。

## 路线图

- 增加一等支持的 `PP-OCRv6_small` 和 `PP-OCRv6_tiny` 配置。
- 更完整地解析 `inference.yml`，减少检测和识别参数硬编码。
- 把移动端模型下载逻辑从 example 移入插件，实现移动端 `ModelSource.bundled`。
- 增加 Android/iOS benchmark 页面，记录冷启动、检测耗时、识别耗时、总耗时和内存峰值。
- 改进 iOS OpenCV 分发方式，让 Apple Silicon 模拟器不再需要排除 arm64。
- 在正确性稳定后评估 iOS Core ML Execution Provider、Android NNAPI 等 ONNX Runtime
  加速路径。

## 贡献

欢迎提交 Issue 和 Pull Request。以下方向尤其有帮助：

- Android 和 iOS 真机 benchmark 数据
- PP-OCRv6 模型配置支持
- OpenCV 打包方式改进
- Web 打包方式改进
- 更完整的示例和文档

提交运行时或识别效果问题时，请尽量附上设备型号、系统版本、Flutter 版本和模型版本。

## 上游项目与致谢

这个项目受益于 OCR、Flutter 和原生推理社区的大量优秀开源工作。

特别感谢：

- [PaddleOCR](https://github.com/PaddlePaddle/PaddleOCR) 提供 PP-OCR 模型体系和 OCR
  pipeline 设计。
- [PaddleOCR Android demo](https://github.com/PaddlePaddle/PaddleOCR/tree/main/deploy/android_demo)
  和 [Paddle-Lite-Demo iOS ppocr demo](https://github.com/PaddlePaddle/Paddle-Lite-Demo/tree/develop/ocr/ios/ppocr_demo)
  提供原生预处理/后处理参考。
- [phanbaohuy96/flutter-paddle-ocr](https://github.com/phanbaohuy96/flutter-paddle-ocr)，
  本项目最初基于这个 Flutter 插件继续演进。
- [ONNX Runtime](https://github.com/microsoft/onnxruntime) 提供跨平台 ONNX 推理能力。
- [paddleocr-js](https://www.npmjs.com/package/@paddleocr/paddleocr-js) 提供 Web OCR
  运行时。
- [OpenCV](https://opencv.org/) 提供图像处理基础能力。
- [Flutter](https://flutter.dev/) 提供跨平台应用框架。

本仓库不是 PaddlePaddle、PaddleOCR、Microsoft、OpenCV 或 Flutter 的官方项目，也未被
上述项目赞助或背书。

## 许可证

本项目以 [Apache License 2.0](LICENSE) 发布。

模型文件和第三方依赖由各自所有者按其许可证和条款分发。在商业应用中重新分发模型权重
或 native 二进制文件前，请自行确认对应项目的许可要求。
