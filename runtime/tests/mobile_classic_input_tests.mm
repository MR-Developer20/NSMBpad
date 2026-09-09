#include "../../apple/mobile/KartPadClassicInput.h"

#include <array>
#include <cstdlib>
#include <iostream>
#include <stdexcept>

namespace {

void Require(const bool condition, const char* message) {
  if (!condition) {
    throw std::runtime_error(message);
  }
}

void TestAxesAndConnection() {
  SunPadInputState input{};
  input.stickX = -127;
  input.stickY = 126;
  input.cStickX = 75;
  input.cStickY = -74;
  input.connected = 1;
  const KartPadClassicInputState output = kartpad::mobile::AdaptSunPadInput(input);
  Require(output.leftStickX == -127 && output.leftStickY == 126, "left stick changed");
  Require(output.rightStickX == 75 && output.rightStickY == -74, "right stick changed");
  Require(output.connected, "connection state was lost");
}

void TestEveryButton() {
  struct Expected {
    SunPadButton source;
    std::uint32_t destination;
  };
  constexpr std::array expected{
      Expected{SunPadButtonDpadUp, kartpad::mobile::kClassicButtonUp},
      Expected{SunPadButtonDpadLeft, kartpad::mobile::kClassicButtonLeft},
      Expected{SunPadButtonDpadDown, kartpad::mobile::kClassicButtonDown},
      Expected{SunPadButtonDpadRight, kartpad::mobile::kClassicButtonRight},
      Expected{SunPadButtonZ, kartpad::mobile::kClassicButtonZr},
      Expected{SunPadButtonR, kartpad::mobile::kClassicButtonR},
      Expected{SunPadButtonL, kartpad::mobile::kClassicButtonL},
      Expected{SunPadButtonA, kartpad::mobile::kClassicButtonA},
      Expected{SunPadButtonB, kartpad::mobile::kClassicButtonB},
      Expected{SunPadButtonX, kartpad::mobile::kClassicButtonX},
      Expected{SunPadButtonY, kartpad::mobile::kClassicButtonY},
      Expected{SunPadButtonStart, kartpad::mobile::kClassicButtonPlus},
  };

  std::uint32_t allDestinations = 0;
  std::uint16_t allSources = 0;
  for (const Expected mapping : expected) {
    SunPadInputState input{};
    input.buttons = mapping.source;
    const KartPadClassicInputState output = kartpad::mobile::AdaptSunPadInput(input);
    Require(output.buttons == mapping.destination, "single-button mapping mismatch");
    allSources |= mapping.source;
    allDestinations |= mapping.destination;
  }

  SunPadInputState combined{};
  combined.buttons = allSources;
  const KartPadClassicInputState output = kartpad::mobile::AdaptSunPadInput(combined);
  Require(output.buttons == allDestinations, "simultaneous-button mapping mismatch");
}

void TestMotionInput() {
  KartPadClassicInputState input;
  input.leftStickX = 90;
  input.buttons = kartpad::mobile::kClassicButtonA;
  kartpad::mobile::ApplyMotionInput(input, -0.5f, true);
  Require(input.leftStickX == 90, "motion overrode stronger touch steering");
  Require((input.buttons & kartpad::mobile::kClassicButtonUp) != 0,
          "shake did not produce D-pad Up");
  Require((input.buttons & kartpad::mobile::kClassicButtonA) != 0,
          "shake cleared an existing button");

  kartpad::mobile::ApplyMotionInput(input, -1.0f, false);
  Require(input.leftStickX == -127, "stronger motion steering was ignored");
}

}  // namespace

int main() {
  @autoreleasepool {
    try {
      TestAxesAndConnection();
      TestEveryButton();
      TestMotionInput();
      std::cout << "KartPad mobile Classic input adapter passed\n";
      return EXIT_SUCCESS;
    } catch (const std::exception& error) {
      std::cerr << "KartPad mobile Classic input adapter failed: " << error.what() << '\n';
      return EXIT_FAILURE;
    }
  }
}
