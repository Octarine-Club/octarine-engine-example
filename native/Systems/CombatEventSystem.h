#pragma once

#include <cstdint>
#include <memory>

#include "ECS/Entity.h"
#include "EventBus/EventBus.h"
#include "Events/CollisionBatchEvent.h"
#include "Events/EntityDefeatedEvent.h"

class Registry;

// EventBus subscriber demonstrating native C++ collision handling and custom
// event emission.
class CombatEventSystem {
 public:
  void Init(Registry* registry, const std::unique_ptr<EventBus>& eventBus);

  void OnCollisionBatch(const CollisionBatchEvent& event);
  void OnEntityDefeated(const EntityDefeatedEvent& event);

  void ResetStats() noexcept {
    total_hits_ = 0;
    total_defeats_ = 0;
  }

  [[nodiscard]] std::uint64_t TotalHits() const noexcept { return total_hits_; }
  [[nodiscard]] std::uint64_t TotalDefeats() const noexcept { return total_defeats_; }

 private:
  void ApplyTeamCollision(Entity attacker, Entity target);

  Registry* registry_ = nullptr;
  EventBus* event_bus_ = nullptr;
  EventBus::SubscriptionHandle collision_sub_{};
  EventBus::SubscriptionHandle defeat_sub_{};
  std::uint64_t total_hits_ = 0;
  std::uint64_t total_defeats_ = 0;
};
