-- scripts/stress-test.lua
-- Headless / benchmark workload invoked by `--startup-mode stress` (e.g., octarine-engine/scripts/bench.sh).
-- Uses only modern v0.2.6 built-in ECS components (plus optional native C++ swarm when linked)
-- so stock player-profile runs execute cleanly with zero script warnings.

local stress_test = {}

function stress_test.run()
    math.randomseed(42)
    set_sim_seed(42)
    set_game_map_dimensions(game_window_width, game_window_height)

    local native_on = (native_showcase ~= nil and native_showcase.is_enabled())

    acquire_scene_assets({
        preload = {
            "tank-texture",
            "chopper-drone",
            "bullet-texture",
        },
    })

    if native_on then
        native_showcase.spawn_swarm_batch(1600, game_window_width * 0.5, game_window_height * 0.5)
        log("Stress test loaded 1600 native C++ swarm entities.")
        return
    end

    local count = 0
    for gx = 32, game_window_width - 32, 32 do
        for gy = 32, game_window_height - 32, 32 do
            local vx = math.random(-90, 90)
            local vy = math.random(-90, 90)
            load_entity({
                tag         = "enemies",
                entity_mask = 2,
                components  = {
                    transform    = { position = { x = gx, y = gy } },
                    rigidbody    = { velocity = { x = vx, y = vy } },
                    sprite       = { texture_asset_id = "tank-texture", width = 32, height = 32, layer = 2 },
                    box_collider = { width = 28, height = 28, offset = { x = 2, y = 2 }, collision_mask = 2 },
                },
            })
            count = count + 1
        end
    end

    log("Loaded " .. tostring(count) .. " stress test entities")
end

return stress_test
