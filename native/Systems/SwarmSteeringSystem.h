#pragma once

#include <cstddef>
#include <memory>

#include "Components/ArmorHealthComponent.h"
#include "Components/PositionComponent.h"
#include "Components/RigidBodyComponent.h"
#include "Components/SwarmAgentComponent.h"
#include "ECS/Context.h"
#include "ECS/Query.h"

// Bulk/parallel simulation system steering SwarmAgentComponent entities and
// regenerating ArmorHealthComponent.
class SwarmSteeringSystem {
 public:
  void operator()(const ContextFacade& ctx);

  void SetAttractor(float wx, float wy) noexcept;
  void ClearAttractor() noexcept { has_global_attractor_ = false; }
  [[nodiscard]] bool HasAttractor() const noexcept { return has_global_attractor_; }
  [[nodiscard]] float AttractorX() const noexcept { return attractor_x_; }
  [[nodiscard]] float AttractorY() const noexcept { return attractor_y_; }
  [[nodiscard]] std::size_t LastAgentCount() const noexcept { return last_agent_count_; }

 private:
  std::unique_ptr<ComponentQuery<PositionComponent, RigidBodyComponent, SwarmAgentComponent>> swarm_query_{};
  std::unique_ptr<ComponentQuery<ArmorHealthComponent>> regen_query_{};
  float attractor_x_ = 640.0F;
  float attractor_y_ = 360.0F;
  std::size_t last_agent_count_ = 0;
  bool has_global_attractor_ = false;
};
