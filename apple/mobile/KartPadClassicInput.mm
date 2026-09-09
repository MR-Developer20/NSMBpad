#include "KartPadClassicInput.h"

#include <algorithm>
#include <cmath>

namespace kartpad::mobile {
namespace {

struct ButtonMapping {
  SunPadButton source;
  std::uint32_t destination;
};

/* Nintendo's Mario Kart Wii manual defines the Classic Controller gameplay
 * mapping: A accelerate, B or R drift/brake/reverse/hop, L item, X or ZR rear
 * view, Plus pause, and D-pad tricks/wheelies. Y and ZL are retained as their
 * physical Classic inputs so menus or title code can still observe them. */
constexpr ButtonMapping kButtonMappings[] = {
    {SunPadButtonDpadUp, kClassicButtonUp},
    {SunPadButtonDpadLeft, kClassicButtonLeft},
    {SunPadButtonDpadDown, kClassicButtonDown},
    {SunPadButtonDpadRight, kClassicButtonRight},
    {SunPadButtonZ, kClassicButtonZr},
    {SunPadButtonR, kClassicButtonR},
    {SunPadButtonL, kClassicButtonL},
    {SunPadButtonA, kClassicButtonA},
    {SunPadButtonB, kClassicButtonB},
    {SunPadButtonX, kClassicButtonX},
    {SunPadButtonY, kClassicButtonY},
    {SunPadButtonStart, kClassicButtonPlus},
};

}  // namespace

KartPadClassicInputState AdaptSunPadInput(const SunPadInputState input) noexcept {
  KartPadClassicInputState output;
  output.leftStickX = input.stickX;
  output.leftStickY = input.stickY;
  output.rightStickX = input.cStickX;
  output.rightStickY = input.cStickY;
  output.connected = input.connected != 0;
  for (const ButtonMapping mapping : kButtonMappings) {
    if ((input.buttons & mapping.source) != 0) {
      output.buttons |= mapping.destination;
    }
  }
  return output;
}

void ApplyMotionInput(KartPadClassicInputState& input, const float steering,
                      const bool shakeTrick) noexcept {
  const float boundedSteering =
      std::isfinite(steering) ? std::clamp(steering, -1.0f, 1.0f) : 0.0f;
  const int motionStick = static_cast<int>(std::lround(boundedSteering * 127.0f));
  if (std::abs(motionStick) > std::abs(static_cast<int>(input.leftStickX))) {
    input.leftStickX = static_cast<std::int8_t>(motionStick);
  }
  if (shakeTrick) {
    input.buttons |= kClassicButtonUp;
  }
}

}  // namespace kartpad::mobile
