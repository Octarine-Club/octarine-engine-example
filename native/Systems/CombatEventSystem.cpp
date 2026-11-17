#include "Systems/CombatEventSystem.h"

#include "Components/ArmorHealthComponent.h"
#include "Components/PositionComponent.h"
#include "ECS/Registry.h"

namespace {
constexpr float kCollisionContactDamage = 10.0F;
}  // namespace

void CombatEventSystem::Init(Registry* registry, const std::unique_ptr<EventBus>& eventBus) {
  registry_ = registry;
  event_bus_ = eventBus.get();
  if (event_bus_ == nullptr) {
    return;
  }
  collision_sub_ =
      event_bus_->SubscribeEvent<CombatEventSystem, CollisionBatchEvent>(this, &CombatEventSystem::OnCollisionBatch);
  defeat_sub_ =
      event_bus_->SubscribeEvent<CombatEventSystem, EntityDefeatedEvent>(this, &CombatEventSystem::OnEntityDefeated);
}

void CombatEventSystem::OnCollisionBatch(const CollisionBatchEvent& event) {
  if (registry_ == nullptr) {
    return;
  }
  for (const auto& [a, b] : event.pairs) {
    ApplyTeamCollision(a, b);
    ApplyTeamCollision(b, a);
  }
}

void CombatEventSystem::OnEntityDefeated(const EntityDefeatedEvent& /*event*/) { ++total_defeats_; }

void CombatEventSystem::ApplyTeamCollision(const Entity attacker, const Entity target) {
  if (!registry_->IsAlive(attacker) || !registry_->IsAlive(target) ||
      !registry_->HasComponent<ArmorHealthComponent>(target)) {
    return;
  }
  auto& targetHp = registry_->GetComponent<ArmorHealthComponent>(target);
  if (targetHp.IsDead() || targetHp.invulnerable) {
    return;
  }
  if (registry_->HasComponent<ArmorHealthComponent>(attacker) &&
      registry_->GetComponent<ArmorHealthComponent>(attacker).team == targetHp.team) {
    return;
  }

  targetHp.ApplyDamage(kCollisionContactDamage);
  ++total_hits_;

  if (targetHp.IsDead() && event_bus_ != nullptr) {
    float wx = 0.0F;
    float wy = 0.0F;
    if (registry_->HasComponent<PositionComponent>(target)) {
      const auto& pos = registry_->GetComponent<PositionComponent>(target);
      wx = pos.value.x;
      wy = pos.value.y;
    }
    event_bus_->EmitEvent<EntityDefeatedEvent>(target, attacker, wx, wy, targetHp.team);
  }
}
