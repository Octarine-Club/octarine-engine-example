#pragma once

#include <algorithm>
#include <cstdint>
#include <sol/sol.hpp>

#include "Components/ArmorHealthComponent.h"
#include "Lua/Bindings/LuaBinding.h"

template <>
struct LuaBinding<ArmorHealthComponent> {
  static constexpr const char* kLuaKey = "armor_health";
  static constexpr const char* kUsertypeName = "armor_health_component";

  static ArmorHealthComponent fromLua(const sol::object& data) {
    const auto t = data.as<sol::table>();
    using namespace LuaComponentHelpers;
    ArmorHealthComponent comp{};
    comp.max_hp = std::max(1.0F, SafeGetOptionalValue<float>(t, "max_hp", 100.0F));
    comp.current_hp = std::clamp(SafeGetOptionalValue<float>(t, "current_hp", comp.max_hp), 0.0F, comp.max_hp);
    comp.regen_rate = SafeGetOptionalValue<float>(t, "regen_rate", 0.0F);
    comp.team = static_cast<std::uint8_t>(SafeGetOptionalValue<int>(t, "team", 0));
    comp.invulnerable = SafeGetOptionalValue<bool>(t, "invulnerable", false);
    return comp;
  }

  static void bindUsertype(sol::state& lua) {
    lua.new_usertype<ArmorHealthComponent>(
        kUsertypeName, sol::no_constructor, "current_hp",
        sol::property([](const ArmorHealthComponent& h) { return h.current_hp; },
                      [](ArmorHealthComponent& h, const float v) { h.current_hp = std::clamp(v, 0.0F, h.max_hp); }),
        "max_hp", &ArmorHealthComponent::max_hp, "regen_rate", &ArmorHealthComponent::regen_rate, "team",
        &ArmorHealthComponent::team, "invulnerable", &ArmorHealthComponent::invulnerable, "fraction",
        sol::property(&ArmorHealthComponent::Fraction), "is_dead", sol::property(&ArmorHealthComponent::IsDead),
        "apply_damage", &ArmorHealthComponent::ApplyDamage, "heal", &ArmorHealthComponent::Heal);
  }
};
