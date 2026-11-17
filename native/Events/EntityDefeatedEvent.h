#pragma once

#include <cstdint>

#include "ECS/Entity.h"
#include "EventBus/Event.h"

// EventBus payload emitted when ArmorHealthComponent drops to zero from a
// native combat collision.
struct EntityDefeatedEvent final : public Event {
  Entity victim{};
  Entity attacker{};
  float world_x = 0.0F;
  float world_y = 0.0F;
  std::uint8_t team = 0;

  EntityDefeatedEvent() = default;
  EntityDefeatedEvent(const Entity v, const Entity a, const float wx, const float wy, const std::uint8_t t)
      : victim(v), attacker(a), world_x(wx), world_y(wy), team(t) {}
};
