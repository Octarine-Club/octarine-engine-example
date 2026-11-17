-- scripts/scenes/tilemap_lab.lua
-- Interactive Chunked Tilemap & 2D DDA Raycast Lab.
-- Showcases: tilemap.load_data, live stitch mode switching (toroidal / procedural_hash / arena_fixed),
-- set_window_radii, set_chunk_override, prop streaming & mark_prop_consumed, resolve_circle,
-- set_debug_overlay, and live mouse-targeted 2D DDA tilemap.raycast().

return {
    preload = {
        "tilemap-texture",
        "chopper-texture",
        "bullet-texture",
        "tree",
        "arial-font-12",
        "charriot-14",
        "charriot-16",
        "sfx_cannon",
        "sfx_explosion",
        "sfx_ui_hover",
        "sfx_ui_click",
    },

    setup = function()
        mark_lab_visited("tilemap_lab")
        set_game_map_dimensions(0, 0) -- Infinite world scrolling!
        set_camera_zoom(1.0)

        local override_active = false
        local trees_consumed = 0

        local vm = ui.observable({
            debugOverlay = true,
            tileInfo     = "Chunks: 0 | Mode: toroidal",
        })

        local function refresh_tile_info()
            if tilemap.is_loaded() then
                local cx, cy = tilemap.get_camera_chunk()
                vm.tileInfo = string.format("Ch:%d | Cam:(%d,%d) | %s | s=%d | T=%d",
                    tilemap.get_active_chunk_count(), cx, cy, tilemap.get_stitch_mode(), tilemap.get_seed(), trees_consumed)
            end
        end

        jungle_tilemap.mount({
            stitch_mode   = settings.get("preferred_stitch", "toroidal"),
            seed          = 1337,
            load_radius   = 1,
            unload_radius = 2,
            on_tree_harvest = function(wx, wy)
                trees_consumed = trees_consumed + 1
                combat.spawn_explosion(wx + 8, wy + 16, { radius = 18, color = { r = 74, g = 222, b = 128, a = 220 } })
                refresh_tile_info()
            end,
        })
        tilemap.set_debug_overlay(true, true)
        refresh_tile_info()

        -- Visualizers for live 2D DDA raycast beam + impact marker + surface normal
        local ray_beam = load_entity({
            name = "DdaRayBeam",
            components = {
                transform = { position = { x = 240, y = 240 } },
                line      = { start = { x = 0, y = 0 }, ["end"] = { x = 100, y = 0 }, thickness = 2.5, color = { r = 56, g = 189, b = 248, a = 230 }, layer = 6 },
            },
        })
        local ray_hit = load_entity({
            name = "DdaHitMarker",
            components = {
                transform = { position = { x = 240, y = 240 } },
                circle    = { radius = 8, thickness = 2, filled = false, color = { r = 250, g = 204, b = 21, a = 0 }, layer = 7 },
            },
        })
        local ray_normal = load_entity({
            name = "DdaNormalLine",
            components = {
                transform = { position = { x = 240, y = 240 } },
                line      = { start = { x = 0, y = 0 }, ["end"] = { x = 0, y = 0 }, thickness = 3.0, color = { r = 239, g = 68, b = 68, a = 0 }, layer = 7 },
            },
        })

        -- Movable Scout Chopper (resolved against solid + chasm + wall via resolve_circle)
        load_entity({
            name        = "TilemapScout",
            tag         = "player",
            entity_mask = 1,
            components  = {
                transform     = { position = { x = 240, y = 240 }, scale = { x = 1.25, y = 1.25 } },
                sprite        = { texture_asset_id = "chopper-texture", width = 32, height = 32, layer = 5 },
                animation     = { num_frames = 2, speed_rate = 14 },
                box_collider  = { width = 26, height = 24, offset = { x = 3, y = 4 }, collision_mask = 2 },
                camera_follow = {},
                script        = {
                    cooldown = 0.0,
                    on_update = function(self, entity, dt)
                        self.cooldown = math.max(0.0, self.cooldown - dt)
                        local mx, my = input_map.get_move_vector()
                        local pos = get_position(entity)
                        local nx = pos.x + mx * 220.0 * dt
                        local ny = pos.y + my * 220.0 * dt

                        -- Resolve circle collision against IntGrid solid + wall + chasm channels
                        local cx, cy = tilemap.resolve_circle(nx + 16.0, ny + 16.0, 13.0, tilemap.MASK_GROUND_BLOCKED)
                        nx = cx - 16.0
                        ny = cy - 16.0
                        set_position(entity, nx, ny)

                        local sx, sy = nx + 16.0, ny + 16.0
                        local cam = get_camera_position()
                        local zoom = math.max(0.1, get_camera_zoom())
                        local mp = input.mouse_position()
                        local tx = cam.x + mp.x / zoom
                        local ty = cam.y + mp.y / zoom

                        local hit, hx, hy, rnx, rny = tilemap.raycast(sx, sy, tx, ty, tilemap.MASK_PROJECTILE_BLOCKED)
                        local ex = hit and hx or tx
                        local ey = hit and hy or ty

                        set_position(ray_beam, sx, sy)
                        local beam_line = registry.get_line(ray_beam)
                        beam_line["end"].x = ex - sx
                        beam_line["end"].y = ey - sy

                        set_position(ray_hit, hx, hy)
                        local hc = registry.get_circle(ray_hit)
                        hc.color.a = hit and 255 or 0

                        set_position(ray_normal, hx, hy)
                        local nl = registry.get_line(ray_normal)
                        nl["end"].x = hit and (rnx * 30.0) or 0.0
                        nl["end"].y = hit and (rny * 30.0) or 0.0
                        nl.color.a = hit and 255 or 0

                        if input.is_action_pressed("fire") and self.cooldown <= 0.0 then
                            self.cooldown = 0.2
                            local dx, dy = tx - sx, ty - sy
                            local len = math.sqrt(dx * dx + dy * dy)
                            if len > 1.0 then
                                combat.spawn_bullet({
                                    x              = sx,
                                    y              = sy,
                                    vx             = (dx / len) * 380.0,
                                    vy             = (dy / len) * 380.0,
                                    friendly       = true,
                                    entity_mask    = 4,
                                    collision_mask = 2,
                                    check_tilemap  = true,
                                })
                                play_sound("sfx_cannon", 0.45)
                            end
                        end

                        refresh_tile_info()
                    end,
                },
            },
        })

        ui.mount("ui/tilemap_lab.oxml", {
            context = vm,
            controller = {
                onModeToroidal = function()
                    tilemap.set_stitch_mode("toroidal", tilemap.get_seed())
                    refresh_tile_info()
                end,
                onModeProcedural = function()
                    tilemap.set_stitch_mode("procedural_hash", tilemap.get_seed())
                    refresh_tile_info()
                end,
                onModeArena = function()
                    tilemap.set_stitch_mode("arena_fixed", tilemap.get_seed())
                    refresh_tile_info()
                end,
                onRollSeed = function()
                    local next_seed = (tilemap.get_seed() * 1103515245 + 12345) % 99999
                    tilemap.set_stitch_mode(tilemap.get_stitch_mode(), next_seed)
                    refresh_tile_info()
                end,
                onToggleOverride = function()
                    override_active = not override_active
                    if override_active then
                        tilemap.set_chunk_override(0, 0, "highland_clearing")
                    else
                        tilemap.clear_chunk_overrides()
                    end
                    refresh_tile_info()
                end,
                onResetProps = function()
                    trees_consumed = 0
                    tilemap.clear_consumed_props()
                    tilemap.set_stitch_mode(tilemap.get_stitch_mode(), tilemap.get_seed())
                    refresh_tile_info()
                end,
                onToggleOverlay = function(self, checked)
                    tilemap.set_debug_overlay(checked, checked)
                end,
            },
        })

        chrome.install({
            title = "Chunked Tilemap & DDA Raycast Lab",
            guide = "WASD / Stick: Fly across infinite chunks\n"
                 .. "Mouse Aim: Cast live 2D DDA tilemap.raycast()\n"
                 .. "Space: Fire to harvest streamed Tree props\n\n"
                 .. "Yellow circle = ray hit; Red vector = surface normal.\n"
                 .. "Switch stitch modes or override chunk (0,0) live!",
        })
    end,
}
