-- scripts/scenes/stress_lab.lua
-- Interactive ECS Scale, Determinism & Dual-Mode Native C++ Swarm Lab.

return {
    preload = {
        "chopper-drone",
        "tank-texture",
        "arial-font-12",
        "charriot-14",
        "charriot-16",
        "sfx_ui_hover",
        "sfx_ui_click",
    },

    setup = function()
        mark_lab_visited("stress_lab")
        set_game_map_dimensions(1280, 720)
        set_camera_zoom(1.0)

        local native_on = (native_showcase ~= nil and native_showcase.is_enabled())

        local vm = ui.observable({
            deterministic = is_deterministic(),
            stateHash     = get_state_hash(),
            modeStatus    = native_on
                and "Native C++ Swarm Active (move mouse to steer)"
                or "Stock Lua Mode (link native/ for C++ Parallel Swarm)",
        })

        local spawned_entities = {}

        local function clear_swarm()
            if #spawned_entities > 0 then
                blam(spawned_entities)
                spawned_entities = {}
            end
        end

        local function spawn_batch(count)
            clear_swarm()
            set_sim_seed(42)
            math.randomseed(42)

            if native_on then
                spawned_entities = native_showcase.spawn_swarm_batch(count, 640, 360)
                vm.modeStatus = string.format("Native C++ Swarm: %d agents (ParallelForEach)", #spawned_entities)
                return
            end

            for i = 1, count do
                local ang = (i * 2.39996)
                local rad = 20.0 + math.sqrt(i) * 8.0
                local sx = math.max(40, math.min(1240, 640 + math.cos(ang) * rad))
                local sy = math.max(90, math.min(640, 360 + math.sin(ang) * rad))
                local vx = math.cos(ang + 1.57) * 95.0
                local vy = math.sin(ang + 1.57) * 95.0
                spawned_entities[#spawned_entities + 1] = load_entity({
                    tag = "swarm",
                    components = {
                        transform = { position = { x = sx, y = sy }, scale = { x = 0.75, y = 0.75 } },
                        rigidbody = { velocity = { x = vx, y = vy } },
                        sprite    = { texture_asset_id = "chopper-drone", width = 32, height = 32, layer = 2 },
                        animation = { num_frames = 2, speed_rate = 12 },
                        script    = {
                            on_update = function(self, entity, dt)
                                local p = get_position(entity)
                                local rb = registry.get_rigidbody(entity)
                                if (p.x < 40 and rb.velocity.x < 0) or (p.x > 1240 and rb.velocity.x > 0) then
                                    rb.velocity.x = -rb.velocity.x
                                end
                                if (p.y < 80 and rb.velocity.y < 0) or (p.y > 640 and rb.velocity.y > 0) then
                                    rb.velocity.y = -rb.velocity.y
                                end
                            end,
                        },
                    },
                })
            end
            vm.modeStatus = string.format("Stock Lua Mode: %d bouncing sprites", count)
        end

        -- Coordinator entity updating live hash & native attractor position
        load_entity({
            name = "StressLabCoordinator",
            components = {
                script = {
                    accum = 0.0,
                    on_update = function(self, entity, dt)
                        if native_on and input.is_hovered() then
                            local mp = input.mouse_position()
                            native_showcase.set_attractor(mp.x, mp.y)
                        end
                        self.accum = self.accum + dt
                        if self.accum >= 0.2 then
                            self.accum = 0.0
                            vm.stateHash = get_state_hash()
                        end
                    end,
                },
            },
        })

        spawn_batch(250)

        ui.mount("ui/stress_lab.oxml", {
            context = vm,
            controller = {
                onSpawn250  = function() spawn_batch(250) end,
                onSpawn1000 = function() spawn_batch(1000) end,
                onSpawn2500 = function() spawn_batch(2500) end,
                onToggleDet = function(self, checked)
                    set_deterministic(checked)
                    set_sim_seed(42)
                    vm.modeStatus = checked and "Deterministic Serial Mode ENABLED (seed=42)" or "Multi-threaded Parallel Mode"
                end,
                onRunDeterminismCheck = function()
                    set_deterministic(true)
                    set_sim_seed(42)
                    spawn_batch(250)
                    vm.stateHash = get_state_hash()
                    vm.modeStatus = "Deterministic Serial Seed=42 (250 ents) | Hash=" .. vm.stateHash
                end,
            },
        })

        chrome.install({
            title = "ECS Scale, Determinism & Native C++",
            guide = "Spawn 250–2,500 entities and inspect live 64-bit State Hash.\n"
                 .. "Toggle Deterministic mode to force serial execution.\n"
                 .. "When compiled with -DOCTARINE_GAME_MODULE_DIR=native,\n"
                 .. "agents steer in C++ ParallelForEach toward your mouse!",
        })
    end,
}
