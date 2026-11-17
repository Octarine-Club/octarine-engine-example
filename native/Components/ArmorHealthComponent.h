#pragma once

#include <algorithm>
#include <cstdint>

// POD health & regeneration component ordered largest-to-smallest field
// alignment.
struct ArmorHealthComponent {
  float max_hp = 100.0F;
  float current_hp = 100.0F;
  float regen_rate = 0.0F;
  std::uint8_t team = 0;
  bool invulnerable = false;

  void ApplyDamage(const float amount) noexcept {
    if (invulnerable || amount <= 0.0F) {
      return;
    }
    current_hp = std::max(0.0F, current_hp - amount);
  }

  void Heal(const float amount) noexcept {
    if (amount <= 0.0F) {
      return;
    }
    current_hp = std::min(max_hp, current_hp + amount);
  }

  [[nodiscard]] float Fraction() const noexcept {
    if (max_hp <= 0.0F) {
      return 0.0F;
    }
    return std::clamp(current_hp / max_hp, 0.0F, 1.0F);
  }

  [[nodiscard]] bool IsDead() const noexcept { return current_hp <= 0.0F; }
};
