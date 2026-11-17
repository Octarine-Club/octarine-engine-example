#include <cmath>
#include <memory>

#include "Components/ArmorHealthComponent.h"
#include "Components/PositionComponent.h"
#include "Components/RigidBodyComponent.h"
#include "Components/SwarmAgentComponent.h"
#include "ECS/Context.h"
#include "ECS/Registry.h"
#include "Engine/GameModuleHooks.h"
#include "EventBus/EventBus.h"
#include "Events/CollisionBatchEvent.h"
#include "Lua/Bindings/LuaComponentRegistry.h"
#include "Lua/Modules/LuaModuleRegistry.h"
#include "Systems/CombatEventSystem.h"
#include "Systems/SwarmSteeringSystem.h"
#include "TestHarness.h"

using octarine::test::Check;
using octarine::test::CheckEq;

namespace {

void TestSwarmSteeringAndPauseGuard() {
  auto registry = std::make_unique<Registry>();
  SwarmSteeringSystem steering;

  const Entity agent = registry->CreateEntity();
  registry->AddComponent(agent, PositionComponent({100.0F, 100.0F}));
  registry->AddComponent(agent, RigidBodyComponent({0.0F, 0.0F}));
  registry->AddComponent(agent, SwarmAgentComponent{400.0F, 100.0F, 150.0F, 40.0F, 0.0F, 1});
  registry->AddComponent(agent, ArmorHealthComponent{100.0F, 50.0F, 10.0F, 1, false});

  registry->SetPaused(true);
  ContextFacade pausedCtx(registry.get(), 1.0F, nullptr, &Internal::BulkGetComponent);
  steering(pausedCtx);
  CheckEq(registry->GetComponent<ArmorHealthComponent>(agent).current_hp, 50.0F,
          "Paused step leaves ArmorHealth unchanged");

  registry->SetPaused(false);
  ContextFacade activeCtx(registry.get(), 1.0F, nullptr, &Internal::BulkGetComponent);
  steering(activeCtx);

  const auto& rb = registry->GetComponent<RigidBodyComponent>(agent);
  Check(rb.velocity.x > 0.0F, "SwarmSteering steers agent toward positive-X target");
  Check(std::abs(registry->GetComponent<ArmorHealthComponent>(agent).current_hp - 60.0F) < 1e-3F,
        "ArmorHealthComponent regenerates by regen_rate * dt");
  CheckEq(steering.LastAgentCount(), std::size_t{1}, "SwarmSteeringSystem reports agent count");

  registry->ValidateInvariants();
}

void TestCombatEventSystemDefeat() {
  auto registry = std::make_unique<Registry>();
  auto eventBus = std::make_unique<EventBus>();
  registry->Set<CombatEventSystem>(CombatEventSystem());
  auto& combat = registry->Get<CombatEventSystem>();
  combat.Init(registry.get(), eventBus);

  const Entity attacker = registry->CreateEntity();
  registry->AddComponent(attacker, ArmorHealthComponent{100.0F, 100.0F, 0.0F, 1, false});

  const Entity victim = registry->CreateEntity();
  registry->AddComponent(victim, PositionComponent({10.0F, 20.0F}));
  registry->AddComponent(victim, ArmorHealthComponent{100.0F, 10.0F, 0.0F, 2, false});

  const std::vector<std::pair<Entity, Entity>> pairs = {{attacker, victim}};
  eventBus->EmitEvent<CollisionBatchEvent>(pairs);

  Check(registry->GetComponent<ArmorHealthComponent>(victim).IsDead(), "Victim defeated after lethal collision");
  Check(std::abs(registry->GetComponent<ArmorHealthComponent>(attacker).current_hp - 90.0F) < 1e-3F,
        "Attacker takes reciprocal contact damage");
  CheckEq(combat.TotalHits(), std::uint64_t{2}, "CombatEventSystem recorded mutual hits");
  CheckEq(combat.TotalDefeats(), std::uint64_t{1}, "CombatEventSystem observed EntityDefeatedEvent");

  registry->ValidateInvariants();
}

void TestComponentBindingsRegistered() {
  LuaComponentRegistry::clear();
  game_module::RegisterComponentBindings();
  Check(LuaComponentRegistry::find("armor_health") != nullptr, "armor_health component binding registered");
  Check(LuaComponentRegistry::find("swarm_agent") != nullptr, "swarm_agent component binding registered");
}

}  // namespace

int main() {
  TestSwarmSteeringAndPauseGuard();
  TestCombatEventSystemDefeat();
  TestComponentBindingsRegistered();
  return octarine::test::ReportSummary("ShowcaseModuleTest");
}
