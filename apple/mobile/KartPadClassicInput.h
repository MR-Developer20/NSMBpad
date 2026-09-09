#pragma once

#import <Foundation/Foundation.h>

#include "../third_party/sunpad/SunPadInputState.h"

#include <cstdint>

/*
 * KartPad adaptation, 2026-08-29.
 * Derived from the GPLv3 SunPad input boundary. See
 * apple/third_party/sunpad/UPSTREAM.md and LICENSES/GPL-3.0.txt.
 */

struct KartPadClassicInputState {
  std::int8_t leftStickX = 0;
  std::int8_t leftStickY = 0;
  std::int8_t rightStickX = 0;
  std::int8_t rightStickY = 0;
  std::uint32_t buttons = 0;
  bool connected = false;
};

namespace kartpad::mobile {

inline constexpr std::uint32_t kClassicButtonUp = 0x00000001;
inline constexpr std::uint32_t kClassicButtonLeft = 0x00000002;
inline constexpr std::uint32_t kClassicButtonZr = 0x00000004;
inline constexpr std::uint32_t kClassicButtonX = 0x00000008;
inline constexpr std::uint32_t kClassicButtonA = 0x00000010;
inline constexpr std::uint32_t kClassicButtonY = 0x00000020;
inline constexpr std::uint32_t kClassicButtonB = 0x00000040;
inline constexpr std::uint32_t kClassicButtonZl = 0x00000080;
inline constexpr std::uint32_t kClassicButtonR = 0x00000200;
inline constexpr std::uint32_t kClassicButtonPlus = 0x00000400;
inline constexpr std::uint32_t kClassicButtonMinus = 0x00001000;
inline constexpr std::uint32_t kClassicButtonL = 0x00002000;
inline constexpr std::uint32_t kClassicButtonDown = 0x00004000;
inline constexpr std::uint32_t kClassicButtonRight = 0x00008000;

/* Translate the exact SunPad GameCube-shaped touch component into Mario Kart
 * Wii's Classic Controller ABI. The copied visuals and multitouch behavior stay
 * unchanged; only this boundary is game-specific. */
[[nodiscard]] KartPadClassicInputState AdaptSunPadInput(SunPadInputState input) noexcept;

/* Merge phone motion after touch adaptation. A shake is exposed as one Classic
 * D-pad Up sample; Mario Kart decides whether that means a trick or wheelie. */
void ApplyMotionInput(KartPadClassicInputState& input, float steering,
                      bool shakeTrick) noexcept;

}  // namespace kartpad::mobile
