Pod::Spec.new do |s|
  s.name             = 'flutter_paddle_ocr'
  s.version          = '0.0.2'
  s.summary          = 'On-device OCR for Flutter, powered by PaddleOCR + Paddle Lite.'
  s.description      = <<-DESC
On-device OCR for Flutter. Wraps the Paddle-Lite-Demo iOS ppocr pipeline
(detection -> optional angle classification -> CRNN recognition) behind a
Swift MethodChannel handler.
                       DESC
  s.homepage         = 'https://github.com/phanbaohuy96/flutter-paddle-ocr'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Huy Phan' => 'baohuy.phan1996@gmail.com' }
  s.source           = { :path => '.' }

  s.source_files     = 'Classes/**/*.{h,hpp,m,mm,cpp}', 'Classes/**/*.swift'
  s.public_header_files = 'Classes/PaddleOcrEngine.h'
  s.preserve_paths   = 'Frameworks/**/*'

  s.dependency       'Flutter'
  s.platform         = :ios, '13.0'
  s.swift_version    = '5.0'

  # Fetch Paddle Lite + OpenCV iOS prebuilts once per `pod install`. Same URLs
  # the Paddle-Lite-Demo libs/download.sh uses.
  s.prepare_command = <<-CMD
    set -e
    mkdir -p Frameworks
    cd Frameworks
    if [ ! -d inference_lite_lib.ios64.armv8 ]; then
      curl -sSL -o pl.tar.gz "https://paddlelite-demo.bj.bcebos.com/libs/ios/paddle_lite_libs_v2_10_rc.tar.gz"
      tar xzf pl.tar.gz
      rm pl.tar.gz
    fi
    if [ ! -d opencv2.framework ]; then
      # OpenCV 4.5.5 — needed for `imgcodecs.hpp` (upstream ppocr includes it;
      # the older 2.4 framework at paddlelite-demo/.../opencv2.framework.tar.gz
      # still lived in highgui and breaks the build).
      curl -sSL -o cv.tar.gz "https://paddlelite-demo.bj.bcebos.com/libs/ios/opencv-4.5.5-ios-framework.tar.gz"
      tar xzf cv.tar.gz
      rm cv.tar.gz
    fi
    # Upstream ppocr_demo uses `#include "opencv2/core.hpp"` (quote form). Clang
    # only resolves that path via header-path search, not framework-aware
    # lookup, so point HEADER_SEARCH_PATHS at Frameworks/ and symlink the
    # framework Headers dir as `opencv2`.
    ln -sfn opencv2.framework/Headers opencv2
  CMD

  # Paddle Lite ships as a static .a + headers (not a .framework). OpenCV is a
  # fat framework with arm64 device + x86_64 sim slices but no arm64-simulator.
  s.vendored_libraries  = 'Frameworks/inference_lite_lib.ios64.armv8/lib/libpaddle_api_light_bundled.a'
  s.vendored_frameworks = 'Frameworks/opencv2.framework'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE'                       => 'YES',
    'CLANG_CXX_LANGUAGE_STANDARD'          => 'c++14',
    'CLANG_CXX_LIBRARY'                    => 'libc++',
    'HEADER_SEARCH_PATHS'                  => [
      '"$(PODS_TARGET_SRCROOT)/Frameworks/inference_lite_lib.ios64.armv8/include"',
      '"$(PODS_TARGET_SRCROOT)/Frameworks"',
    ].join(' '),
    'GCC_PREPROCESSOR_DEFINITIONS'         => 'TARGET_IOS=1',
    # opencv2.framework is missing an arm64-simulator slice; fall back to
    # Rosetta (x86_64) on Apple Silicon simulators.
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64',
  }
  s.user_target_xcconfig = {
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64',
  }
end
