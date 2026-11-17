#ifdef OCTARINE_HAS_GAME_MODULE

#include <benchmark/benchmark.h>

#include <cmath>
#include <memory>

#include "BenchCommon.h"
#include "Components/ArmorHealthComponent.h"
#include "Components/PositionComponent.h"
#include "Components/RigidBodyComponent.h"
#include "Components/SwarmAgentComponent.h"
#include "ECS/Context.h"
#include "ECS/Registry.h"
#include "Systems/SwarmSteeringSystem.h"

namespace {

void BM_ShowcaseSwarmSteering(benchmark::State& state) {
  const int count = static_cast<int>(state.range(0));
  auto registry = std::make_unique<Registry>();
  SwarmSteeringSystem steering;

  for (int i = 0; i < count; ++i) {
    const float fi = static_cast<float>(i);
    const Entity e = registry->CreateEntity();
    registry->AddComponent(e, PositionComponent({fi * 2.0F, fi * 1.5F}));
    registry->AddComponent(e, RigidBodyComponent({0.0F, 0.0F}));
    registry->AddComponent(e, SwarmAgentComponent{640.0F, 360.0F, 180.0F, 120.0F, fi * 0.1F, 1});
    registry->AddComponent(e, ArmorHealthComponent{100.0F, 80.0F, 5.0F, 1, false});
  }

  ContextFacade ctx(registry.get(), bench::kDt, nullptr, &Internal::BulkGetComponent);
  for (auto _ : state) {
    steering(ctx);
    benchmark::DoNotOptimize(steering.LastAgentCount());
  }

  bench::ReportRegistry(state, *registry);
  state.SetItemsProcessed(static_cast<int64_t>(state.iterations()) * count);
}

BENCHMARK(BM_ShowcaseSwarmSteering)->Apply(bench::EntitySweepSmall)->Unit(benchmark::kMicrosecond);

}  // namespace

#endif
