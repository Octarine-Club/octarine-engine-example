#pragma once

#include <memory>

#include "Components/ArmorHealthComponent.h"
#include "Components/GlobalTransformComponent.h"
#include "Components/PositionComponent.h"
#include "ECS/Context.h"
#include "ECS/Query.h"

// Bulk render system emitting lightweight world-space health bars directly into
// RenderQueue.
class HealthBarRenderSystem {
 public:
  void operator()(const ContextFacade& ctx);

  void SetEnabled(const bool enabled) noexcept { enabled_ = enabled; }
  [[nodiscard]] bool IsEnabled() const noexcept { return enabled_; }

 private:
  std::unique_ptr<ComponentQuery<PositionComponent, ArmorHealthComponent, Opt<GlobalTransformComponent>>> query_{};
  bool enabled_ = true;
};
