-- scripts/dev/showcase_dev_tools.lua
-- In-player developer tooling via `dev.*` and `ImGui.*`.
-- Safely no-ops on builds where ImGui is compiled out (player-release, ship-release, player-profile).

local M = {}

local function is_dev_ui_available()
    return dev ~= nil and ImGui ~= nil
end

function M.install(opts)
    if not is_dev_ui_available() then
        return
    end
    opts = opts or {}

    local state = {
        chunk_bounds = false,
        tile_cols    = false,
        spawn_kind   = 1,
        spawn_kinds  = { "Tiger Tank", "Panther Tank", "Supply Truck", "Radar Dish" },
    }

    dev.register_panel("showcase.director", {
        title       = "Showcase Director",
        category    = "Game",
        shortcut    = "F8",
        auto_window = true,
        draw        = function()
            ImGui.Text("Octarine Showcase Director")
            ImGui.Separator()

            ImGui.Text(string.format("Entities: %d   FPS: %.1f", get_entity_count(), get_fps()))
            ImGui.Text("State Hash: " .. tostring(get_state_hash()))

            if tilemap.is_loaded() then
                local cx, cy = tilemap.get_camera_chunk()
                ImGui.Text(string.format("Tilemap: chunks=%d cam=(%d,%d) mode=%s",
                    tilemap.get_active_chunk_count(), cx, cy, tilemap.get_stitch_mode()))
            end

            ImGui.Separator()
            ImGui.Text("Quick Scene Jump:")
            if ImGui.Button("Hub") then load_scene("scripts/scenes/hub.lua") end
            ImGui.SameLine()
            if ImGui.Button("Jungle Strike") then load_scene("scripts/scenes/jungle_strike.lua") end
            ImGui.SameLine()
            if ImGui.Button("UI Lab") then load_scene("scripts/scenes/ui_lab.lua") end
            if ImGui.Button("Physics Lab") then load_scene("scripts/scenes/physics_lab.lua") end
            ImGui.SameLine()
            if ImGui.Button("Tilemap Lab") then load_scene("scripts/scenes/tilemap_lab.lua") end
            ImGui.SameLine()
            if ImGui.Button("Audio Lab") then load_scene("scripts/scenes/audio_lab.lua") end
            ImGui.SameLine()
            if ImGui.Button("Stress Lab") then load_scene("scripts/scenes/stress_lab.lua") end

            ImGui.Separator()
            local changed_zoom, new_zoom = ImGui.SliderFloat("Camera Zoom", get_camera_zoom(), 0.5, 2.5)
            if changed_zoom then
                set_camera_zoom(new_zoom)
            end

            local changed_det, det_val = ImGui.Checkbox("Deterministic (Serial)", is_deterministic())
            if changed_det then
                set_deterministic(det_val)
            end

            if ImGui.Button("Reload Scene [F5]") then
                reload_scene()
            end
            ImGui.SameLine()
            if ImGui.Button("Write State Dump") then
                write_state_dump("showcase_state_dump.json")
            end

            if opts.on_dev_spawn then
                ImGui.Separator()
                ImGui.Text("Spawn Unit: " .. state.spawn_kinds[state.spawn_kind])
                if ImGui.Button("< Prev") then
                    state.spawn_kind = ((state.spawn_kind - 2) % #state.spawn_kinds) + 1
                end
                ImGui.SameLine()
                if ImGui.Button("Next >") then
                    state.spawn_kind = (state.spawn_kind % #state.spawn_kinds) + 1
                end
                ImGui.SameLine()
                if ImGui.Button("Spawn Near Player") then
                    opts.on_dev_spawn(state.spawn_kinds[state.spawn_kind])
                end
            end

            if native_showcase ~= nil and native_showcase.is_enabled() then
                ImGui.Separator()
                local stats = native_showcase.get_stats()
                ImGui.Text("Native C++ Module: LINKED")
                ImGui.Text(string.format("Swarm Agents: %d | Hits: %d | Defeats: %d",
                    stats.swarm_count or 0, stats.total_hits or 0, stats.total_defeats or 0))
            end
        end,
    })

    dev.register_action("Game/Reload Current Scene", function() reload_scene() end, "F5")
    dev.register_action("Game/Return to Hub", function() load_scene("scripts/scenes/hub.lua") end, "Esc")
    dev.register_action("Game/Dump Canonical State JSON", function()
        write_state_dump("showcase_state_dump.json")
    end)

    dev.register_toggle("World/Tilemap Chunk Bounds",
        function() return state.chunk_bounds end,
        function(v)
            state.chunk_bounds = v
            if tilemap.is_loaded() then tilemap.set_debug_overlay(state.chunk_bounds, state.tile_cols) end
        end)

    dev.register_toggle("World/Tilemap IntGrid Collisions",
        function() return state.tile_cols end,
        function(v)
            state.tile_cols = v
            if tilemap.is_loaded() then tilemap.set_debug_overlay(state.chunk_bounds, state.tile_cols) end
        end)

    dev.watch("Live Entities", function() return get_entity_count() end)
    dev.watch("FPS", function() return string.format("%.1f", get_fps()) end)
    dev.watch("Camera", function()
        local c = get_camera_position()
        return string.format("(%.0f, %.0f) x%.2f", c.x, c.y, get_camera_zoom())
    end)
    dev.watch("State Hash", function() return get_state_hash() end)
    if native_showcase ~= nil then
        dev.watch("Native C++ Module", function() return native_showcase.is_enabled() and "LINKED" or "NOOP" end)
    end
end

return M
