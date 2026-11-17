-- scripts/verify_showcase.lua
-- Automated headless end-to-end verification across all showcase scenes & engine seams.
-- Invoked via: OctarineEngine <example_dir> --headless --startup-mode verify

local M = {}

local function check(cond, msg)
    if not cond then
        log_e("[VERIFY FAIL] " .. tostring(msg))
        error("[VERIFY FAIL] " .. tostring(msg))
    end
end

local function verify_storage_and_settings()
    local probe = { ok = true, version = "0.2.6", value = 42 }
    check(storage.write_table("verify_probe.lua", probe), "storage.write_table failed")
    check(storage.exists("verify_probe.lua"), "storage.exists failed")
    local read_back = storage.read_table("verify_probe.lua")
    check(type(read_back) == "table" and read_back.ok == true and read_back.value == 42,
          "storage.read_table roundtrip mismatch")
    check(storage.remove("verify_probe.lua"), "storage.remove failed")

    settings.set("difficulty", "hard")
    check(settings.get("difficulty") == "hard", "settings.set/get mismatch")
    settings.reset("difficulty")
    check(settings.get("difficulty") == "normal", "settings.reset failed")
end

local function verify_scenes()
    load_scene("scripts/scenes/hub.lua")
    check(find_entity_by_name("HubBackdropGrid") ~= nil, "hub missing HubBackdropGrid")
    check(find_entity_by_name("HubAmbientChopper") ~= nil, "hub missing HubAmbientChopper")
    check(find_entity_by_name("HubAmbientRadar") ~= nil, "hub missing HubAmbientRadar")

    load_scene("scripts/scenes/ui_lab.lua")
    check(get_entity_count() >= 10, "ui_lab entity count unexpectedly low")

    load_scene("scripts/scenes/physics_lab.lua")
    local box_t  = find_entity_by_name("Target_AABB")
    local circ_t = find_entity_by_name("Target_Circle")
    local cap_t  = find_entity_by_name("Target_Capsule")
    local tri_t  = find_entity_by_name("Target_Triangle")
    local line_t = find_entity_by_name("Target_Line")
    check(box_t ~= nil and registry.has_box_collider(box_t), "physics_lab missing box_collider")
    check(circ_t ~= nil and registry.has_circle_collider(circ_t), "physics_lab missing circle_collider")
    check(cap_t ~= nil and registry.has_capsule_collider(cap_t), "physics_lab missing capsule_collider")
    check(tri_t ~= nil and registry.has_triangle_collider(tri_t), "physics_lab missing triangle_collider")
    check(line_t ~= nil and registry.has_line_collider(line_t), "physics_lab missing line_collider")

    load_scene("scripts/scenes/tilemap_lab.lua")
    check(tilemap.is_loaded(), "tilemap_lab tilemap failed to load")
    check(tilemap.get_active_chunk_count() >= 9, "tilemap_lab expected at least 9 active chunks")
    check(tilemap.set_chunk_override(0, 0, "highland_clearing"), "set_chunk_override failed")
    check(tilemap.get_chunk_template_id(0, 0) == "highland_clearing", "get_chunk_template_id mismatch")
    tilemap.clear_chunk_overrides()
    tilemap.set_stitch_mode("procedural_hash", 999)
    check(tilemap.get_stitch_mode() == "procedural_hash", "set_stitch_mode failed")
    tilemap.mark_prop_consumed(0, 0, 0)
    check(tilemap.is_prop_consumed(0, 0, 0), "mark_prop_consumed failed")
    tilemap.clear_consumed_props()
    local hit, hx, hy = tilemap.raycast(64, 64, 480, 480, tilemap.MASK_PROJECTILE_BLOCKED)
    check(hx ~= nil and hy ~= nil, "tilemap.raycast returned invalid coords")

    load_scene("scripts/scenes/audio_lab.lua")
    local listener = find_entity_by_name("AudioListenerMarker")
    local doppler  = find_entity_by_name("DopplerDrone")
    check(listener ~= nil and registry.has_audio_listener(listener), "audio_lab missing audio_listener")
    check(doppler ~= nil and registry.has_audio_source(doppler), "audio_lab missing doppler audio_source")

    load_scene("scripts/scenes/jungle_strike.lua")
    check(tilemap.is_loaded(), "jungle_strike tilemap not loaded")
    check(find_entity_by_name("PlayerChopper") ~= nil, "jungle_strike missing PlayerChopper")
    check(find_entity_by_name("EnemyRadar") ~= nil, "jungle_strike missing EnemyRadar")
    check(find_entity_by_name("HelipadAlpha") ~= nil, "jungle_strike missing HelipadAlpha")
    check(find_entity_by_name("HelipadBravo") ~= nil, "jungle_strike missing HelipadBravo")
    check(find_entity_by_name("TigerNorth") ~= nil, "jungle_strike missing TigerNorth")
    check(find_entity_by_name("PantherN") ~= nil, "jungle_strike missing PantherN")
    check(find_entity_by_name("ConvoyN") ~= nil, "jungle_strike missing ConvoyN")

    -- Determinism check: verify identical entity counts across seeded reloads and valid state hash
    set_deterministic(true)
    set_sim_seed(42)
    load_scene("scripts/scenes/stress_lab.lua")
    local c1 = get_entity_count()
    local h1 = get_state_hash()
    set_sim_seed(42)
    load_scene("scripts/scenes/stress_lab.lua")
    local c2 = get_entity_count()
    local h2 = get_state_hash()
    check(c1 >= 250 and c1 == c2, "deterministic scene load entity count mismatch: " .. tostring(c1) .. " vs " .. tostring(c2))
    check(h1 ~= "" and h2 ~= "", "state hash should be non-empty")
end

local function verify_native_module_if_present()
    if native_showcase == nil or not native_showcase.is_enabled() then
        log_i("[VERIFY] Running in Stock Lua mode (native_showcase not linked).")
        return
    end
    local ents = native_showcase.spawn_swarm_batch(16, 640, 360)
    check(#ents == 16, "native_showcase.spawn_swarm_batch did not spawn 16 entities")
    local first = ents[1]
    check(registry.has_armor_health(first), "native entity missing armor_health binding")
    check(registry.has_swarm_agent(first), "native entity missing swarm_agent binding")
    native_showcase.set_attractor(700, 400)
    log_i("[VERIFY] Native C++ module bindings verified.")
end

function M.run()
    verify_storage_and_settings()
    verify_scenes()
    verify_native_module_if_present()

    -- Reload physics_lab and spawn probe bullets on all 6 Row-1 collider targets so live
    -- KDTreeCollisionSystem + ScriptCollisionSystem callbacks (on_collision / on_collision_exit)
    -- and octarine::Color userdata mutations are exercised end-to-end.
    set_deterministic(false)
    load_scene("scripts/scenes/physics_lab.lua")
    local box_t  = find_entity_by_name("Target_AABB")
    local obb_t  = find_entity_by_name("Target_OBB_Spin")
    local circ_t = find_entity_by_name("Target_Circle")
    local cap_t  = find_entity_by_name("Target_Capsule")
    local tri_t  = find_entity_by_name("Target_Triangle")
    local line_t = find_entity_by_name("Target_Line")

    local target_coords = {
        { x = 128,  y = 165 },
        { x = 252,  y = 163 },
        { x = 405,  y = 168 },
        { x = 605,  y = 168 },
        { x = 835,  y = 172 },
        { x = 1060, y = 168 },
    }
    for _, pt in ipairs(target_coords) do
        combat.spawn_bullet({
            x              = pt.x,
            y              = pt.y,
            vx             = 0,
            vy             = 0,
            friendly       = true,
            entity_mask    = 4,
            collision_mask = 2,
            duration       = 0.5,
        })
    end

    load_entity({
        name = "VerifyStepper",
        components = {
            script = {
                ticks     = 0,
                elapsed   = 0.0,
                saw_flash = false,
                on_update = function(self, entity, dt)
                    self.ticks = self.ticks + 1
                    self.elapsed = self.elapsed + dt

                    local box_r  = registry.get_square(box_t).color.r
                    local obb_r  = registry.get_square(obb_t).color.r
                    local circ_r = registry.get_circle(circ_t).color.r
                    local cap_r  = registry.get_capsule(cap_t).color.r
                    local tri_r  = registry.get_triangle(tri_t).color.r
                    local line_r = registry.get_line(line_t).color.r
                    if box_r == 250 and obb_r == 250 and circ_r == 250
                       and cap_r == 250 and tri_r == 250 and line_r == 250 then
                        self.saw_flash = true
                    end

                    if self.ticks >= 16 and self.elapsed >= 0.18 then
                        check(self.saw_flash, "Row-1 collider targets did not all flash yellow on collision")
                        check(box_r == 56, "Target_AABB color did not restore after collision exit (got r=" .. tostring(box_r) .. ")")
                        check(circ_r == 34, "Target_Circle color did not restore after collision exit (got r=" .. tostring(circ_r) .. ")")
                        check(obb_r == 168, "Target_OBB_Spin color did not restore")
                        check(cap_r == 249, "Target_Capsule color did not restore")
                        check(tri_r == 236, "Target_Triangle color did not restore")
                        check(line_r == 45, "Target_Line color did not restore")
                        local final_hash = get_state_hash()
                        check(final_hash ~= nil and #final_hash > 0, "final state hash empty")
                        log_i("[VERIFY PASS] All showcase scenes, tilemap, UI, audio, and ECS checks passed. hash=" .. final_hash)
                        quit_game()
                    end
                end,
            },
        },
    })
end

return M
