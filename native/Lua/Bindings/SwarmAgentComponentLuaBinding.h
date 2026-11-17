#pragma once

#include <cstdint>
#include <sol/sol.hpp>

#include "Components/SwarmAgentComponent.h"
#include "Lua/Bindings/LuaBinding.h"

template <>
struct LuaBinding<SwarmAgentComponent> {
  static constexpr const char* kLuaKey = "swarm_agent";
  static constexpr const char* kUsertypeName = "swarm_agent_component";

  static SwarmAgentComponent fromLua(const sol::object& data) {
    const auto t = data.as<sol::table>();
    using namespace LuaComponentHelpers;
    SwarmAgentComponent comp{};
    comp.target_x = SafeGetOptionalValue<float>(t, "target_x", 640.0F);
    comp.target_y = SafeGetOptionalValue<float>(t, "target_y", 360.0F);
    comp.max_speed = SafeGetOptionalValue<float>(t, "max_speed", 160.0F);
    comp.orbit_radius = SafeGetOptionalValue<float>(t, "orbit_radius", 90.0F);
    comp.phase = SafeGetOptionalValue<float>(t, "phase", 0.0F);
    comp.team = static_cast<std::uint8_t>(SafeGetOptionalValue<int>(t, "team", 1));
    return comp;
  }

  static void bindUsertype(sol::state& lua) {
    lua.new_usertype<SwarmAgentComponent>(
        kUsertypeName, sol::no_constructor, "target_x", &SwarmAgentComponent::target_x, "target_y",
        &SwarmAgentComponent::target_y, "max_speed", &SwarmAgentComponent::max_speed, "orbit_radius",
        &SwarmAgentComponent::orbit_radius, "phase", &SwarmAgentComponent::phase, "team", &SwarmAgentComponent::team);
  }
};
