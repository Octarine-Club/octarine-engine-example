#include "Systems/HealthBarRenderSystem.h"

#include <SDL3/SDL.h>

#include <algorithm>

#include "Components/CameraComponents.h"
#include "ECS/Registry.h"
#include "Game/GameConfig.h"
#include "Renderer/RenderCulling.h"
#include "Renderer/RenderQueue.h"

namespace {
constexpr float kBarWidth = 30.0F;
constexpr float kBarHeight = 4.0F;
constexpr float kBarOffsetY = -8.0F;
constexpr unsigned int kHealthBarLayer = 5U;

SDL_Color HealthFillColor(const float frac) noexcept {
  if (frac > 0.6F) {
    return SDL_Color{34, 197, 94, 235};
  }
  if (frac > 0.3F) {
    return SDL_Color{234, 179, 8, 235};
  }
  return SDL_Color{239, 68, 68, 240};
}
}  // namespace

void HealthBarRenderSystem::operator()(const ContextFacade& ctx) {
  // No IsPaused() guard so health bars remain visible when the developer pauses
  // simulation.
  if (!enabled_) {
    return;
  }
  auto* registry = ctx.GetRegistry();
  if (registry == nullptr) {
    return;
  }
  auto* renderQueue = registry->TryGet<RenderQueue>();
  const auto* camera = registry->TryGet<CameraComponent>();
  const auto* cfg = registry->TryGet<GameConfig>();
  if (renderQueue == nullptr || camera == nullptr || cfg == nullptr) {
    return;
  }

  if (!query_) {
    query_ = registry->CreateQuery<PositionComponent, ArmorHealthComponent, Opt<GlobalTransformComponent>>();
  }
  query_->Update();

  const float zoom = camera->zoom > 0.001F ? camera->zoom : 1.0F;
  const float winW = static_cast<float>(cfg->windowWidth);
  const float winH = static_cast<float>(cfg->windowHeight);

  query_->ForEach([&](Entity, const PositionComponent& pos, const ArmorHealthComponent& hp,
                      const GlobalTransformComponent* globalTx) {
    if (hp.IsDead() || hp.Fraction() >= 0.999F) {
      return;
    }
    const float worldX = globalTx != nullptr ? globalTx->position.x : pos.value.x;
    const float worldY = (globalTx != nullptr ? globalTx->position.y : pos.value.y) + kBarOffsetY;
    if (IsRenderableOutsideViewport(worldX, worldY, kBarWidth, kBarHeight, false, camera->viewport, winW, winH)) {
      return;
    }

    const float sx = (worldX - camera->viewport.x) * zoom;
    const float sy = (worldY - camera->viewport.y) * zoom;
    const float sw = kBarWidth * zoom;
    const float sh = kBarHeight * zoom;

    auto& track = renderQueue->EmplaceSquare(kHealthBarLayer, worldY, nullptr, octarine::BlendMode::Blend);
    track.destRect = SDL_FRect{sx, sy, sw, sh};
    track.color = SDL_Color{15, 23, 42, 210};
    track.blendMode = SDL_BLENDMODE_BLEND;

    auto& fill = renderQueue->EmplaceSquare(kHealthBarLayer, worldY + 0.1F, nullptr, octarine::BlendMode::Blend);
    fill.destRect = SDL_FRect{sx, sy, sw * hp.Fraction(), sh};
    fill.color = HealthFillColor(hp.Fraction());
    fill.blendMode = SDL_BLENDMODE_BLEND;
  });
}
