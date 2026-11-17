#include <algorithm>
#include <cmath>
#include <cstdint>
#include <functional>
#include <sol/sol.hpp>
#include <string>
#include <vector>

#include "Components/AnimationComponent.h"
#include "Components/ArmorHealthComponent.h"
#include "Components/BoxColliderComponent.h"
#include "Components/EntityMaskComponent.h"
#include "Components/GlobalTransformComponent.h"
#include "Components/PositionComponent.h"
#include "Components/RigidBodyComponent.h"
#include "Components/ScaleComponent.h"
#include "Components/SpriteComponent.h"
#include "Components/SwarmAgentComponent.h"
#include "Debug/DebugMenuRegistry.h"
#include "ECS/Registry.h"
#include "Engine/GameModuleHooks.h"
#include "EventBus/EventBus.h"
#include "General/Constants.h"
#include "Lua/Bindings/ArmorHealthComponentLuaBinding.h"
#include "Lua/Bindings/LuaComponentRegistry.h"
#include "Lua/Bindings/SwarmAgentComponentLuaBinding.h"
#include "Lua/LuaBindingContext.h"
#include "Systems/CombatEventSystem.h"
#include "Systems/HealthBarRenderSystem.h"
#include "Systems/SwarmSteeringSystem.h"

#ifdef OCTARINE_WITH_IMGUI
#include <imgui.h>

#include "Debug/DebugComponentInspectors.h"
#endif

namespace {

std::vector<Entity> SpawnSwarmAgents(Registry& registry, const int count, const float centerX, const float centerY) {
  std::vector<Entity> spawned;
  const int clamped = std::clamp(count, 0, 10000);
  spawned.reserve(static_cast<std::size_t>(clamped));

  constexpr float kGoldenAngle = 2.3999632F;
  for (int i = 0; i < clamped; ++i) {
    const float fi = static_cast<float>(i + 1);
    const float angle = fi * kGoldenAngle;
    const float radius = 24.0F + std::sqrt(fi) * 7.5F;
    const float sx = centerX + std::cos(angle) * radius;
    const float sy = centerY + std::sin(angle) * radius;

    const Entity e = registry.CreateEntity();
    registry.AddComponent(e, PositionComponent({sx, sy}));
    registry.AddComponent(e, ScaleComponent(0.75F, 0.75F));
    registry.AddComponent(e, GlobalTransformComponent{{sx, sy}, {0.75F, 0.75F}, 0.0F, {0.0F, 0.0F}});
    registry.AddComponent(e, RigidBodyComponent({0.0F, 0.0F}));
    registry.AddComponent(e, SpriteComponent("chopper-drone", 32.0F, 32.0F, 2, false));
    registry.AddComponent(e, AnimationComponent(2, 12, true));
    registry.AddComponent(e, SwarmAgentComponent{centerX, centerY, 190.0F, 65.0F + std::fmod(fi * 11.0F, 140.0F), angle,
                                                 static_cast<std::uint8_t>((i % 2) + 1)});
    const float startHp = (i % 5 == 0) ? 25.0F : ((i % 3 == 0) ? 60.0F : 100.0F);
    registry.AddComponent(e,
                          ArmorHealthComponent{100.0F, startHp, 2.0F, static_cast<std::uint8_t>((i % 2) + 1), false});
    spawned.push_back(e);
  }
  return spawned;
}

#ifdef OCTARINE_WITH_IMGUI
void RegisterInspectors() {
  octarine::debug::DebugComponentInspectorRegistry::Register<ArmorHealthComponent>(
      "ArmorHealthComponent", [](Registry&, Entity, ArmorHealthComponent& hp) {
        ImGui::SliderFloat("Current HP", &hp.current_hp, 0.0F, hp.max_hp);
        ImGui::DragFloat("Max HP", &hp.max_hp, 1.0F, 1.0F, 2000.0F);
        ImGui::DragFloat("Regen/s", &hp.regen_rate, 0.5F, 0.0F, 100.0F);
        int teamInt = static_cast<int>(hp.team);
        if (ImGui::InputInt("Team", &teamInt)) {
          hp.team = static_cast<std::uint8_t>(std::clamp(teamInt, 0, 255));
        }
        ImGui::Checkbox("Invulnerable", &hp.invulnerable);
      });

  octarine::debug::DebugComponentInspectorRegistry::Register<SwarmAgentComponent>(
      "SwarmAgentComponent", [](Registry&, Entity, SwarmAgentComponent& agent) {
        ImGui::DragFloat("Target X", &agent.target_x, 2.0F, -2000.0F, 4000.0F);
        ImGui::DragFloat("Target Y", &agent.target_y, 2.0F, -2000.0F, 4000.0F);
        ImGui::SliderFloat("Max Speed", &agent.max_speed, 10.0F, 600.0F);
        ImGui::SliderFloat("Orbit Radius", &agent.orbit_radius, 10.0F, 400.0F);
      });
}

void DrawSwarmPanel(Registry& reg) {
  auto* steering = reg.TryGet<SwarmSteeringSystem>();
  auto* combat = reg.TryGet<CombatEventSystem>();
  auto* healthBars = reg.TryGet<HealthBarRenderSystem>();

  ImGui::Text("Native C++ Showcase Module");
  ImGui::Separator();
  if (steering != nullptr) {
    ImGui::Text("Tracked Swarm Agents: %zu", steering->LastAgentCount());
    if (ImGui::Button("Clear Global Attractor")) {
      steering->ClearAttractor();
    }
  }
  if (combat != nullptr) {
    ImGui::Text("EventBus Hits: %llu | Defeats: %llu", static_cast<unsigned long long>(combat->TotalHits()),
                static_cast<unsigned long long>(combat->TotalDefeats()));
    if (ImGui::Button("Reset Combat Telemetry")) {
      combat->ResetStats();
    }
  }
  if (healthBars != nullptr) {
    bool enabled = healthBars->IsEnabled();
    if (ImGui::Checkbox("Render Native World Health Bars", &enabled)) {
      healthBars->SetEnabled(enabled);
    }
  }
}
#endif

}  // namespace

namespace game_module {

void RegisterComponentBindings() {
  LuaComponentRegistry::registerComponent<ArmorHealthComponent>();
  LuaComponentRegistry::registerComponent<SwarmAgentComponent>();
}

void InstallSingletons(Registry& registry) {
  registry.Set<SwarmSteeringSystem>(SwarmSteeringSystem());
  registry.Set<CombatEventSystem>(CombatEventSystem());
  registry.Set<HealthBarRenderSystem>(HealthBarRenderSystem());
}

void RegisterSimulationSystems(Registry& registry, const std::unique_ptr<EventBus>& /*eventBus*/,
                               const SystemId velocityIntegration) {
  if (auto* steering = registry.TryGet<SwarmSteeringSystem>()) {
    const auto steerHandle = registry.RegisterBulkSystem(std::ref(*steering));
    registry.Order(velocityIntegration).After(steerHandle);
  }
  if (auto* healthBars = registry.TryGet<HealthBarRenderSystem>()) {
    const auto barHandle = registry.RegisterBulkSystem(std::ref(*healthBars));
    registry.Order(barHandle).After(velocityIntegration);
  }
}

void RegisterEventSystems(Registry& registry, const std::unique_ptr<EventBus>& eventBus) {
  if (auto* combat = registry.TryGet<CombatEventSystem>()) {
    combat->Init(&registry, eventBus);
  }
}

void InstallLuaFunctions(sol::state& lua, LuaBindingContext& ctx) {
  sol::table ns = lua.create_named_table("native_showcase");

  ns.set_function("is_enabled", []() -> bool { return true; });

  ns.set_function("set_attractor", [&ctx](const float wx, const float wy) {
    if (auto* reg = ctx.GetRegistry()) {
      if (auto* steering = reg->TryGet<SwarmSteeringSystem>()) {
        steering->SetAttractor(wx, wy);
      }
    }
  });

  ns.set_function("clear_attractor", [&ctx]() {
    if (auto* reg = ctx.GetRegistry()) {
      if (auto* steering = reg->TryGet<SwarmSteeringSystem>()) {
        steering->ClearAttractor();
      }
    }
  });

  ns.set_function("spawn_swarm_batch",
                  [&ctx](sol::this_state ts, const int count, const float cx, const float cy) -> sol::table {
                    sol::state_view sv(ts);
                    sol::table result = sv.create_table();
                    auto* reg = ctx.GetRegistry();
                    if (reg == nullptr) {
                      return result;
                    }
                    const auto entities = SpawnSwarmAgents(*reg, count, cx, cy);
                    for (std::size_t i = 0; i < entities.size(); ++i) {
                      result[i + 1] = entities[i];
                    }
                    return result;
                  });

  ns.set_function("get_stats", [&ctx](sol::this_state ts) -> sol::table {
    sol::state_view sv(ts);
    sol::table stats = sv.create_table();
    auto* reg = ctx.GetRegistry();
    if (reg == nullptr) {
      return stats;
    }
    const auto* steering = reg->TryGet<SwarmSteeringSystem>();
    const auto* combat = reg->TryGet<CombatEventSystem>();
    stats["swarm_count"] = steering != nullptr ? steering->LastAgentCount() : std::size_t{0};
    stats["total_hits"] = combat != nullptr ? combat->TotalHits() : std::uint64_t{0};
    stats["total_defeats"] = combat != nullptr ? combat->TotalDefeats() : std::uint64_t{0};
    return stats;
  });

  ns.set_function("reset_stats", [&ctx]() {
    if (auto* reg = ctx.GetRegistry()) {
      if (auto* combat = reg->TryGet<CombatEventSystem>()) {
        combat->ResetStats();
      }
    }
  });
}

void RegisterDebugUI(Registry& registry) {
#ifdef OCTARINE_WITH_IMGUI
  RegisterInspectors();
  auto* debugReg = registry.TryGet<octarine::debug::DebugMenuRegistry>();
  if (debugReg == nullptr) {
    return;
  }

  debugReg->RegisterPanel(octarine::debug::DebugPanelDescriptor{
      .id = "showcase.native_swarm",
      .category = "Game",
      .title = "Native C++ Swarm & Combat",
      .shortcut = "F9",
      .isOpen = false,
      .autoWindow = true,
      .isLuaOwned = false,
      .drawCallback = [](Registry& reg) { DrawSwarmPanel(reg); },
  });

  debugReg->RegisterWatch("Native Swarm Agents", [&registry]() -> std::string {
    const auto* steering = registry.TryGet<SwarmSteeringSystem>();
    return steering != nullptr ? std::to_string(steering->LastAgentCount()) : "0";
  });
#else
  (void)registry;
#endif
}

}  // namespace game_module
