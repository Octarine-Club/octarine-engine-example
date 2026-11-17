# Octarine Engine Showcase (`octarine-engine-example`)

An interactive showcase and developer reference project built for **Octarine Engine v0.2.6**.

It runs **out-of-the-box** on any stock `OctarineEngine` player build (pure Lua 5.5 + `.oxml`/`.oss` + `.meta` asset pipeline) **and** ships an optional native C++20 game module under `native/` (`-DOCTARINE_GAME_MODULE_DIR`) demonstrating high-scale parallel ECS systems, custom `EventBus` events, direct `RenderQueue` submission, CTest unit tests, and Google Benchmarks.

---

## Quickstart

### 1. Run with Stock `OctarineEngine` (Pure Lua)
```bash
# From this directory (assumes sibling ../octarine-engine checkout, or set OCTARINE_ENGINE_DIR)
./run.sh

# Or invoke the engine binary directly with dev overlays, hot reload, and LuaLS stub export:
../octarine-engine/build/player-debug/bin/debug/OctarineEngine . --dev
```

### 2. Run with Optional Native C++ Game Module (`native/`)
```bash
./run.sh --native
```
Or configure manually:
```bash
cmake -S ../octarine-engine -B ../octarine-engine/build/example-debug --preset player-debug \
  -DOCTARINE_ENABLE_TESTS=ON \
  -DOCTARINE_GAME_MODULE_DIR="$(pwd)/native"
cmake --build ../octarine-engine/build/example-debug --target OctarineEngine OctarineShowcaseModuleTest
ctest --test-dir ../octarine-engine/build/example-debug -R ShowcaseModuleTest --output-on-failure
../octarine-engine/build/example-debug/bin/debug/OctarineEngine . --dev
```

### 3. Validate Assets, UI & Headless Invariants
```bash
./run.sh --bake    # Scans assets, packs _atlases/units.png, rasterizes font atlases, normalizes WAVs, validates .oxml/.oss
./run.sh --verify  # Headlessly exercises every showcase scene, tilemap, storage, and deterministic hash check
./run.sh --stress  # Headless benchmark workload (--startup-mode stress)
```

### 4. Remote Dev Stepping (`--dev-listen 4242`)
```bash
../octarine-engine/build/player-debug/bin/debug/OctarineEngine . --dev --dev-listen 4242
python3 ../octarine-engine/scripts/oct-agent.py inspect summary
python3 ../octarine-engine/scripts/oct-agent.py step 10 --dt 0.016666
```

---

## Showcase Tour

| Scene | Key Capabilities Highlighted |
|---|---|
| **Showcase Hub** ([scripts/scenes/hub.lua](scripts/scenes/hub.lua)) | Declarative `.oxml`/`.oss` navigator, `<Use>`/`<Slot>` widgets, keyboard/mouse/gamepad focus navigation, animated `color_grid`, spritesheet previews |
| **Operation: Jungle Strike** ([scripts/scenes/jungle_strike.lua](scripts/scenes/jungle_strike.lua)) | Playable vertical-slice mini-game using all 21 bundled textures, file-backed hot-reloadable player script, chunked tilemap, DDA enemy LoS raycasting, directional patrols, truck wrecks, MVVM HUD, and persistent high scores |
| **Declarative UI & Persistence Lab** ([scripts/scenes/ui_lab.lua](scripts/scenes/ui_lab.lua)) | Unified UI Spine (imperative `view.refs`, `set_context`, `ui.observable` MVVM), `ui.register_widget`, `<Grid>`, `<ScrollView>`, `set_inert`, `pointer-events="stop"`, `:set_outline()`, `settings.*`, and `storage.*` |
| **Colliders, SAT & Primitives Lab** ([scripts/scenes/physics_lab.lua](scripts/scenes/physics_lab.lua)) | All 5 SAT colliders (`box`, `circle`, `capsule`, `triangle`, `line`), bitmask filtering, `on_collision` / `on_collision_exit`, parent-child hierarchies, `pivot`, and all render primitives |
| **Chunked Tilemap & DDA Raycast Lab** ([scripts/scenes/tilemap_lab.lua](scripts/scenes/tilemap_lab.lua)) | `tilemap.load_data`, live `toroidal` / `procedural_hash` / `arena_fixed` switching, seed rerolls, `set_chunk_override`, prop consumption (`mark_prop_consumed`), `resolve_circle`, and interactive 2D DDA `tilemap.raycast()` |
| **Spatial & Doppler Audio Lab** ([scripts/scenes/audio_lab.lua](scripts/scenes/audio_lab.lua)) | `audio_listener`, spatial distance falloff & panning, `doppler = true` flyby pitch shift, non-spatial bed source, one-shot `play_sound()`, and BS.1770 `.wav.meta` normalization |
| **ECS Scale & Native C++ Lab** ([scripts/scenes/stress_lab.lua](scripts/scenes/stress_lab.lua)) | 250–2,500+ entity scaling, `set_deterministic(true)` + 64-bit `get_state_hash()` verification, and native C++ `ParallelForEach` swarm steering when compiled with `native/` |

---

## Feature-to-File Reference

| Engine Paradigm / Feature | Where to Look |
|---|---|
| Project config & `AngleUnit=degrees` | [config.ini](config.ini), [project.ini](project.ini) |
| Startup mode routing & module loader | [game.lua](game.lua) |
| Texture atlases, font ladders, audio normalization | [images/*.meta](images), [fonts/*.meta](fonts), [sounds/*.meta](sounds) |
| Declarative `.oxml` views & `.oss` theme | [ui/theme.oss](ui/theme.oss), [ui/hub.oxml](ui/hub.oxml), [ui/ui_lab.oxml](ui/ui_lab.oxml), [ui/widgets/stat_pill.oxml](ui/widgets/stat_pill.oxml) |
| Hot-reloadable entity script (`script = { source = ... }`) | [scripts/entities/chopper_player.lua](scripts/entities/chopper_player.lua) |
| Keyboard + canonical gamepad action bindings | [scripts/lib/input_map.lua](scripts/lib/input_map.lua) |
| Chunked procedural tilemap + IntGrid + props | [scripts/lib/jungle_tilemap.lua](scripts/lib/jungle_tilemap.lua) |
| Custom Lua `dev.*` panels, actions, toggles & watches | [scripts/dev/showcase_dev_tools.lua](scripts/dev/showcase_dev_tools.lua) |
| Native C++ `game_module::*` hooks & `native_showcase` Lua API | [native/GameModule.cpp](native/GameModule.cpp), [native/CMakeLists.txt](native/CMakeLists.txt) |
| Native POD components & `LuaBinding<T>` | [native/Components/ArmorHealthComponent.h](native/Components/ArmorHealthComponent.h), [native/Lua/Bindings/ArmorHealthComponentLuaBinding.h](native/Lua/Bindings/ArmorHealthComponentLuaBinding.h) |
| Native `ComponentQuery::ParallelForEach`, `EventBus`, `RenderQueue` | [native/Systems/SwarmSteeringSystem.cpp](native/Systems/SwarmSteeringSystem.cpp), [native/Systems/CombatEventSystem.cpp](native/Systems/CombatEventSystem.cpp), [native/Systems/HealthBarRenderSystem.cpp](native/Systems/HealthBarRenderSystem.cpp) |
| Native CTest unit tests & Google Benchmarks | [native/tests/ShowcaseModuleTest.cpp](native/tests/ShowcaseModuleTest.cpp), [native/benchmarks/ShowcaseSystemBenchmarks.cpp](native/benchmarks/ShowcaseSystemBenchmarks.cpp) |
| Automated headless showcase verification | [scripts/verify_showcase.lua](scripts/verify_showcase.lua) |
