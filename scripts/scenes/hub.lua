-- scripts/scenes/hub.lua
-- Showcase Hub: Declarative .oxml / .oss navigator + animated ECS backdrop.

local DEMOS = {
    {
        id        = "jungle_strike",
        title     = "Operation: Jungle Strike",
        tag       = "PLAYABLE MINI-GAME",
        path      = "scripts/scenes/jungle_strike.lua",
        source    = "scripts/scenes/jungle_strike.lua + scripts/entities/chopper_player.lua",
        desc      = "Complete top-down helicopter strike mission showcasing all 21 sprite textures, chunked tilemap streaming, 2D DDA enemy line-of-sight, directional Tiger/Panther/Ford patrols, persistent truck wrecks, reactive MVVM HUD, hot-reloadable player script, and storage.* high scores.",
        paradigms = {
            "Hot-reloadable script = { source = '...' } + analog/digital input_map",
            "Chunked TilemapSystem + IntGrid raycast/resolve_circle + destructible Tree props",
            "Reactive MVVM HUD (ui/jungle_hud.oxml) + sandboxed storage.* persistence",
            "4-way spritesheet animation, spatial audio, and dev.* Director panel",
        },
    },
    {
        id        = "ui_lab",
        title     = "Declarative UI & Persistence Lab",
        tag       = "UI / MVVM / STORAGE",
        path      = "scripts/scenes/ui_lab.lua",
        source    = "scripts/scenes/ui_lab.lua + ui/ui_lab.oxml + ui/theme.oss",
        desc      = "Interactive showcase of Octarine's Unified UI Spine: imperative refs, context snapshots, reactive ui.observable two-way bindings, custom Lua widgets, <Use>/<Slot> templates, <Grid>, <ScrollView>, pointer-blocking modals, settings.*, and storage.*.",
        paradigms = {
            "Paradigms A/B/C: view.refs + view:set_context + ui.observable MVVM",
            "<Use>/<Slot> declarative templates & ui.register_widget('StatusBeacon', ...)",
            "Inert subtrees (set_inert), pointer-events='stop', and text :set_outline()",
            "Typed user_settings.ini (settings.*) & sandboxed file storage (storage.*)",
        },
    },
    {
        id        = "physics_lab",
        title     = "Colliders, SAT & Primitives Lab",
        tag       = "PHYSICS / RENDERING",
        path      = "scripts/scenes/physics_lab.lua",
        source    = "scripts/scenes/physics_lab.lua",
        desc      = "Interactive range demonstrating all 5 SAT collider shapes (AABB/OBB box, circle, capsule, triangle, line), bitmask filtering, on_collision/on_collision_exit callbacks, parent-child hierarchies, pivot anchors, and all geometric render primitives.",
        paradigms = {
            "All 5 colliders: box_collider, circle_collider, capsule_collider, triangle_collider, line_collider",
            "SAT narrowphase on pre-rotated, live-spinning, and scale-pulsing OBB targets",
            "Parent-child hierarchies (entities / registry.set_parent) & normalized pivot anchors",
            "All primitives: square, circle, capsule (fill_ratio), triangle, line, color_grid, additive blend",
        },
    },
    {
        id        = "tilemap_lab",
        title     = "Chunked Tilemap & DDA Raycast Lab",
        tag       = "WORLD / RAYCAST",
        path      = "scripts/scenes/tilemap_lab.lua",
        source    = "scripts/scenes/tilemap_lab.lua + scripts/lib/jungle_tilemap.lua",
        desc      = "Explore infinite chunk streaming with live stitch-mode switching (toroidal, procedural_hash, arena_fixed), seed rerolls, chunk overrides, prop consumption persistence, circle collision resolution, and an interactive mouse-aimed 2D DDA raycast beam.",
        paradigms = {
            "tilemap.load_data() procedural chunk templates with hysteresis windowing",
            "Live stitch modes: toroidal, procedural_hash, arena_fixed + set_chunk_override()",
            "2D DDA tilemap.raycast() visualizing exact hit coordinate & surface normal",
            "Streamed Tree props with chunk_resident & mark_prop_consumed() persistence",
        },
    },
    {
        id        = "audio_lab",
        title     = "Spatial & Doppler Audio Lab",
        tag       = "AUDIO / MIXER",
        path      = "scripts/scenes/audio_lab.lua",
        source    = "scripts/scenes/audio_lab.lua",
        desc      = "Move an audio_listener around spatial emitters with min/max distance falloff rings, a high-speed Doppler flyby chopper drone, a non-spatial constant source, and BS.1770 loudness-normalized retro WAV SFX.",
        paradigms = {
            "SpatialAudioSystem: stereo panning & distance attenuation (min_distance / max_distance)",
            "DopplerSystem: pitch shift driven by relative rigidbody velocity (doppler = true)",
            "Non-spatial background tracks vs. one-shot EventBus play_sound() triggers",
            "AudioNormalizer bake-time -16 LUFS normalization via .wav.meta sidecars",
        },
    },
    {
        id        = "stress_lab",
        title     = "ECS Scale, Determinism & Native C++",
        tag       = "ECS / DETERMINISM / C++",
        path      = "scripts/scenes/stress_lab.lua",
        source    = "scripts/scenes/stress_lab.lua + native/GameModule.cpp",
        desc      = "Spawn hundreds to thousands of animated entities, verify deterministic serial simulation via 64-bit StateInspector FNV-1a hashes, and unlock multi-threaded C++ Swarm Steering, EventBus combat, and RenderQueue health bars when built with native/.",
        paradigms = {
            "Deterministic fixed-step replay: set_deterministic(true) + set_sim_seed() + get_state_hash()",
            "Dual-mode runtime: pure Lua fallback OR native C++ module (-DOCTARINE_GAME_MODULE_DIR)",
            "Native C++ ComponentQuery::ParallelForEach, EventBus SubscriptionHandle, & RenderQueue",
            "Custom C++ DebugComponentInspectorRegistry & DebugMenuRegistry ImGui integration",
        },
    },
}

local function count_visited_labs()
    local n = 0
    if showcase_profile and showcase_profile.labs_visited then
        for _, v in pairs(showcase_profile.labs_visited) do
            if v then n = n + 1 end
        end
    end
    return n
end

return {
    preload = {
        "icon",
        "chopper-drone",
        "radar-sheet",
        "arial-font-12",
        "arial-font-14",
        "charriot-14",
        "charriot-16",
        "charriot-24",
        "sfx_ui_hover",
        "sfx_ui_click",
    },

    entities = {
        -- Scrolling tactical background grid
        {
            name = "HubBackdropGrid",
            components = {
                transform = { position = { x = 0, y = 0 } },
                color_grid = {
                    cell_size       = 48,
                    color1          = { r = 13, g = 20, b = 38, a = 255 },
                    color2          = { r = 18, g = 27, b = 50, a = 255 },
                    scroll_velocity = { x = 18, y = 12 },
                    layer           = 0,
                    is_fixed        = true,
                },
            },
        },
        -- Ambient animated chopper flying across the backdrop
        {
            name = "HubAmbientChopper",
            components = {
                transform = { position = { x = 120, y = 635 }, scale = { x = 1.6, y = 1.6 } },
                sprite    = { texture_asset_id = "chopper-drone", width = 32, height = 32, layer = 2, fixed = true, alpha = 140 },
                animation = { num_frames = 2, speed_rate = 12 },
                script    = {
                    t = 0.0,
                    on_update = function(self, entity, dt)
                        self.t = self.t + dt
                        local x = ((self.t * 110.0) % 1400.0) - 60.0
                        local y = 610.0 + math.sin(self.t * 2.2) * 18.0
                        set_position(entity, x, y)
                    end,
                },
            },
        },
        -- Ambient animated 8-frame radar sweep
        {
            name = "HubAmbientRadar",
            components = {
                transform = { position = { x = 1140, y = 550 }, scale = { x = 1.5, y = 1.5 } },
                sprite    = { texture_asset_id = "radar-sheet", width = 64, height = 64, layer = 2, fixed = true, alpha = 120 },
                animation = { num_frames = 8, speed_rate = 10 },
            },
        },
    },

    setup = function()
        set_game_map_dimensions(0, 0)

        local native_on = (native_showcase ~= nil and native_showcase.is_enabled())
        local runtime_label = native_on and "NATIVE C++ + LUA" or "STOCK LUA"

        local selected_idx = 1
        local first = DEMOS[1]

        local vm = ui.observable({
            runtimeMode       = runtime_label,
            bestScore         = tostring(showcase_profile.best_score or 0),
            labsVisitedCount  = tostring(count_visited_labs()),
            demos             = DEMOS,
            selectedTitle     = first.title,
            selectedTag       = first.tag,
            selectedDesc      = first.desc,
            selectedParadigms = first.paradigms,
            selectedSource    = first.source,
            statusHint        = "Click a card to inspect, click again or press LAUNCH / Enter to start.",
            wireframes        = settings.get("ui_wireframes", false),
            audioMuted        = settings.get("audio_muted", false),
            volumePct         = math.floor((settings.get("master_volume", 0.85)) * 100 + 0.5),
        })

        ui.debug_draw(vm.wireframes)

        local function select_demo(item)
            if not item then return end
            for i, d in ipairs(DEMOS) do
                if d.id == item.id then
                    selected_idx = i
                    break
                end
            end
            vm.selectedTitle     = item.title
            vm.selectedTag       = item.tag
            vm.selectedDesc      = item.desc
            vm.selectedParadigms = item.paradigms
            vm.selectedSource    = item.source
        end

        local controller = {
            onFocusDemo = function(self, item)
                if item then
                    select_demo(item)
                end
            end,
            onSelectOrLaunch = function(self, item)
                if not item then return end
                if DEMOS[selected_idx] and DEMOS[selected_idx].id == item.id then
                    load_scene(item.path)
                    return
                end
                select_demo(item)
            end,
            onLaunchSelected = function()
                local target = DEMOS[selected_idx] or DEMOS[1]
                load_scene(target.path)
            end,
            onToggleWireframes = function(self, checked)
                ui.debug_draw(checked)
                settings.set("ui_wireframes", checked)
                settings.save()
            end,
            onToggleMute = function(self, checked)
                set_audio_muted(checked)
                settings.set("audio_muted", checked)
                settings.save()
            end,
            onVolumeChange = function(self, new_val)
                local vol = math.max(0.0, math.min(1.0, (new_val or 85) / 100.0))
                set_master_volume(vol)
                settings.set("master_volume", vol)
                settings.save()
            end,
            onToggleDevGui = function()
                if toggle_debug_gui then
                    toggle_debug_gui()
                end
            end,
            onQuit = function()
                quit_game()
            end,
        }

        local view = ui.mount("ui/hub.oxml", {
            context    = vm,
            controller = controller,
        })
        if view then
            view:focus_first()
        end

        input.on_key_down(function(key)
            if key == "f2" then
                vm.wireframes = not vm.wireframes
                controller:onToggleWireframes(vm.wireframes)
            elseif key == "f1" and toggle_debug_gui ~= nil then
                toggle_debug_gui()
            end
        end)

        if showcase_dev then
            showcase_dev.install({})
        end
    end,
}
