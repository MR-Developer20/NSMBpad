# Native input regression fixtures

These fixtures use no game, profile or save data. Use the fetched SDL source
from a prepared iOS build so the test exercises the pinned runtime version.
The focus fixture applies the same narrow text-observer patch as the app.

```sh
cmake -S runtime/tests/uikit_focus -B build/uikit-focus -G Ninja \
  -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT=iphonesimulator \
  -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=16.0 \
  -Dsdl_SOURCE_DIR=/absolute/path/to/ios-build/_deps/sdl-src \
  -DCMAKE_BUILD_TYPE=Release
cmake --build build/uikit-focus
xcrun simctl install booted build/uikit-focus/KartPadUIKitFocus.app
xcrun simctl launch --console booted dev.kartpad.fixture.text-focus
```

The real SDL window hosts a native alert. Five character insertions and two
backspaces must retain first-responder focus and produce `AAA`. A PASS line
confirms this regression check, not physical keyboard acceptance.

Run the independent floating-stick touch-ownership fixture with the same
Simulator runtime:

```sh
xcrun --sdk iphonesimulator clang++ \
  -target arm64-apple-ios16.0-simulator \
  -isysroot "$(xcrun --sdk iphonesimulator --show-sdk-path)" \
  -std=c++20 -fobjc-arc -Iapple/ios -Iapple/third_party/sunpad \
  runtime/tests/floating_stick_tests.mm \
  apple/third_party/sunpad/SunPadGameOverlay.mm \
  apple/third_party/sunpad/SunPadInputMixer.mm \
  apple/third_party/sunpad/SunPadSettings.mm \
  apple/third_party/sunpad/SunPadDiagnostics.mm \
  -framework Foundation -framework UIKit -framework QuartzCore \
  -framework CoreGraphics -framework GameController \
  -framework UniformTypeIdentifiers -o build/floating-stick-tests
xcrun simctl spawn booted "$PWD/build/floating-stick-tests"
```
