#include "Systems/SwarmSteeringSystem.h"

#include <algorithm>
#include <cmath>

#include "ECS/Registry.h"

namespace {
constexpr float kMinDistSq = 1.0F;
constexpr float kSwarmAngVel = 1.6F;

void SteerSingleAgent(const PositionComponent& pos, RigidBodyComponent& rb, SwarmAgentComponent& agent, const float dt,
                      const bool useGlobalAttractor, const float globalX, const float globalY) noexcept {
  agent.phase += kSwarmAngVel * dt;
  const float anchorX = useGlobalAttractor ? globalX : agent.target_x;
  const float anchorY = useGlobalAttractor ? globalY : agent.target_y;
  const float goalX = anchorX + std::cos(agent.phase) * agent.orbit_radius;
  const float goalY = anchorY + std::sin(agent.phase) * agent.orbit_radius;

  const float dx = goalX - pos.value.x;
  const float dy = goalY - pos.value.y;
  const float distSq = dx * dx + dy * dy;
  if (distSq <= kMinDistSq) {
    rb.velocity = {0.0F, 0.0F};
    return;
  }
  const float invDist = 1.0F / std::sqrt(distSq);
  const float speed = std::min(agent.max_speed, std::sqrt(distSq) * 3.0F);
  rb.velocity.x = dx * invDist * speed;
  rb.velocity.y = dy * invDist * speed;
}
}  // namespace

void SwarmSteeringSystem::SetAttractor(const float wx, const float wy) noexcept {
  attractor_x_ = wx;
  attractor_y_ = wy;
  has_global_attractor_ = true;
}

void SwarmSteeringSystem::operator()(const ContextFacade& ctx) {
  if (ctx.IsPaused()) {
    return;
  }
  auto* registry = ctx.GetRegistry();
  if (registry == nullptr) {
    return;
  }

  const float dt = ctx.GetDeltaTime();
  if (!swarm_query_) {
    swarm_query_ = registry->CreateQuery<PositionComponent, RigidBodyComponent, SwarmAgentComponent>();
  }
  swarm_query_->Update();

  std::size_t count = 0;
  const bool useAttractor = has_global_attractor_;
  const float ax = attractor_x_;
  const float ay = attractor_y_;
  swarm_query_->ForEach([&count](Entity, PositionComponent&, RigidBodyComponent&, SwarmAgentComponent&) { ++count; });
  last_agent_count_ = count;

  swarm_query_->ParallelForEach([dt, useAttractor, ax, ay](Entity, const PositionComponent& pos, RigidBodyComponent& rb,
                                                           SwarmAgentComponent& agent) {
    SteerSingleAgent(pos, rb, agent, dt, useAttractor, ax, ay);
  });

  if (!regen_query_) {
    regen_query_ = registry->CreateQuery<ArmorHealthComponent>();
  }
  regen_query_->Update();
  regen_query_->ParallelForEach([dt](Entity, ArmorHealthComponent& hp) {
    if (hp.regen_rate > 0.0F && !hp.IsDead()) {
      hp.Heal(hp.regen_rate * dt);
    }
  });
}
