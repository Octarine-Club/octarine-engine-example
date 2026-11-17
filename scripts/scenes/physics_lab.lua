-- scripts/scenes/physics_lab.lua
-- Demonstrates all 5 SAT collider types, all geometric render primitives,
-- collision masks, on_collision / on_collision_exit callbacks, pivot anchors,
-- and parent-child transform hierarchies.

return {
    preload = {
        "chopper-texture",
        "bullet-texture",
        "tank-panther-up",
        "truck-texture",
        "arial-font-10",
        "arial-font-12",
        "charriot-14",
        "charriot-16",
        "sfx_cannon",
        "sfx_explosion",
        "sfx_ui_hover",
        "sfx_ui_click",
    },

    setup = function()
        mark_lab_visited("physics_lab")
        set_game_map_dimensions(1280, 720)
        set_camera_zoom(1.0)

        local function label(x, y, text, color)
            load_entity({
                components = {
                    transform  = { position = { x = x, y = y } },
                    text_label = {
                        text     = text,
                        font_id  = "arial-font-12",
                        color    = color or { r = 203, g = 213, b = 225, a = 255 },
                        is_fixed = false,
                        layer    = 6,
                    },
                },
            })
        end

        -- Scrolling background grid
        load_entity({
            components = {
                transform = { position = { x = 0, y = 0 } },
                color_grid = {
                    cell_size       = 48,
                    color1          = { r = 12, g = 18, b = 34, a = 255 },
                    color2          = { r = 17, g = 25, b = 46, a = 255 },
                    scroll_velocity = { x = 14, y = 0 },
                    layer           = 0,
                    is_fixed        = false,
                },
            },
        })

        local function set_rgba(c, r, g, b, a)
            c.r = r
            c.g = g
            c.b = b
            c.a = a
        end

        local function make_hit_flash_script(has_fn, get_fn, base_color, extra_update)
            return {
                flash_timer = 0.0,
                touching    = false,
                t           = 0.0,
                on_collision = function(self, entity)
                    self.touching = true
                    self.flash_timer = 0.14
                    if has_fn(entity) then
                        set_rgba(get_fn(entity).color, 250, 204, 21, 255)
                    end
                end,
                on_collision_exit = function(self, entity)
                    self.touching = false
                    if self.flash_timer <= 0.0 and has_fn(entity) then
                        set_rgba(get_fn(entity).color, base_color.r, base_color.g, base_color.b, base_color.a)
                    end
                end,
                on_update = function(self, entity, dt)
                    if extra_update then
                        extra_update(self, entity, dt)
                    end
                    if self.flash_timer > 0.0 then
                        self.flash_timer = self.flash_timer - dt
                        if self.flash_timer <= 0.0 and not self.touching and has_fn(entity) then
                            set_rgba(get_fn(entity).color, base_color.r, base_color.g, base_color.b, base_color.a)
                        end
                    end
                end,
            }
        end

        -- 1. Box Collider (AABB + Spinning OBB + Scale-Pulsing OBB)
        label(70, 84, "1. BOX (AABB & SAT OBB)", { r = 234, g = 179, b = 8, a = 255 })
        load_entity({
            name        = "Target_AABB",
            entity_mask = 2,
            components  = {
                transform    = { position = { x = 110, y = 150 } },
                square       = { width = 56, height = 38, color = { r = 56, g = 189, b = 248, a = 220 }, border_thickness = 2, border_color = { r = 186, g = 230, b = 253, a = 255 }, corner_radius = 6, layer = 2 },
                box_collider = { width = 56, height = 38, collision_mask = 4 },
                script       = make_hit_flash_script(registry.has_square, registry.get_square, { r = 56, g = 189, b = 248, a = 220 }),
            },
        })
        local spin_obb = spinner.new({ speed_deg = 70.0 })
        load_entity({
            name        = "Target_OBB_Spin",
            entity_mask = 2,
            components  = {
                transform    = { position = { x = 220, y = 150 }, rotation = 30.0 },
                square       = { width = 64, height = 26, color = { r = 168, g = 85, b = 247, a = 220 }, border_thickness = 2, border_color = { r = 233, g = 213, b = 255, a = 255 }, layer = 2 },
                box_collider = { width = 64, height = 26, collision_mask = 4 },
                script       = make_hit_flash_script(
                    registry.has_square,
                    registry.get_square,
                    { r = 168, g = 85, b = 247, a = 220 },
                    function(_, entity, dt) spin_obb:on_update(entity, dt) end
                ),
            },
        })

        -- 2. Circle Collider + Circle Primitive (Filled + Ring)
        label(340, 84, "2. CIRCLE COLLIDER", { r = 234, g = 179, b = 8, a = 255 })
        load_entity({
            name        = "Target_Circle",
            entity_mask = 2,
            components  = {
                transform       = { position = { x = 405, y = 168 } },
                circle          = { position = { x = 0, y = 0 }, radius = 30, filled = true, color = { r = 34, g = 197, b = 94, a = 210 }, layer = 2 },
                circle_collider = { radius = 30, collision_mask = 4 },
                script          = make_hit_flash_script(registry.has_circle, registry.get_circle, { r = 34, g = 197, b = 94, a = 210 }),
            },
        })

        -- 3. Capsule Collider + Animated Capsule Fill Ratio
        label(540, 84, "3. CAPSULE COLLIDER", { r = 234, g = 179, b = 8, a = 255 })
        load_entity({
            name        = "Target_Capsule",
            entity_mask = 2,
            components  = {
                transform        = { position = { x = 605, y = 168 }, rotation = 20.0 },
                capsule          = { start = { x = -36, y = 0 }, ["end"] = { x = 36, y = 0 }, radius = 16, fill_ratio = 0.75, color = { r = 249, g = 115, b = 22, a = 220 }, layer = 2 },
                capsule_collider = { start = { x = -36, y = 0 }, ["end"] = { x = 36, y = 0 }, radius = 16, collision_mask = 4 },
                script           = make_hit_flash_script(
                    registry.has_capsule,
                    registry.get_capsule,
                    { r = 249, g = 115, b = 22, a = 220 },
                    function(self, entity, dt)
                        self.t = self.t + dt
                        if registry.has_rotation(entity) then
                            registry.get_rotation(entity).value = 20.0 + self.t * 45.0
                        end
                        if registry.has_capsule(entity) then
                            registry.get_capsule(entity).fill_ratio = 0.5 + 0.45 * math.sin(self.t * 2.5)
                        end
                    end
                ),
            },
        })

        -- 4. Triangle Collider + Triangle Primitive
        label(765, 84, "4. TRIANGLE COLLIDER", { r = 234, g = 179, b = 8, a = 255 })
        local spin_tri = spinner.new({ speed_deg = -55.0 })
        load_entity({
            name        = "Target_Triangle",
            entity_mask = 2,
            components  = {
                transform         = { position = { x = 835, y = 172 }, rotation = 0.0 },
                triangle          = { p1 = { x = 0, y = -34 }, p2 = { x = 32, y = 26 }, p3 = { x = -32, y = 26 }, filled = true, color = { r = 236, g = 72, b = 153, a = 220 }, layer = 2 },
                triangle_collider = { p1 = { x = 0, y = -34 }, p2 = { x = 32, y = 26 }, p3 = { x = -32, y = 26 }, collision_mask = 4 },
                script            = make_hit_flash_script(
                    registry.has_triangle,
                    registry.get_triangle,
                    { r = 236, g = 72, b = 153, a = 220 },
                    function(_, entity, dt) spin_tri:on_update(entity, dt) end
                ),
            },
        })

        -- 5. Line Collider + Line Primitive
        label(990, 84, "5. LINE COLLIDER", { r = 234, g = 179, b = 8, a = 255 })
        local spin_line = spinner.new({ speed_deg = 40.0 })
        load_entity({
            name        = "Target_Line",
            entity_mask = 2,
            components  = {
                transform     = { position = { x = 1060, y = 168 }, rotation = 0.0 },
                line          = { start = { x = -50, y = -20 }, ["end"] = { x = 50, y = 20 }, thickness = 6, color = { r = 45, g = 212, b = 191, a = 240 }, layer = 2 },
                line_collider = { start = { x = -50, y = -20 }, ["end"] = { x = 50, y = 20 }, collision_mask = 4 },
                script        = make_hit_flash_script(
                    registry.has_line,
                    registry.get_line,
                    { r = 45, g = 212, b = 191, a = 240 },
                    function(_, entity, dt) spin_line:on_update(entity, dt) end
                ),
            },
        })

        -- Row 2: Pivot Anchors + Scale Pulse + Parent-Child Hierarchy + Additive Glow
        label(70, 290, "6. PIVOT (TOP-LEFT vs CENTER)", { r = 56, g = 189, b = 248, a = 255 })
        load_entity({
            name        = "PivotCorner",
            entity_mask = 2,
            components  = {
                transform    = { position = { x = 140, y = 360 }, pivot = { x = 0.0, y = 0.0 } },
                sprite       = { texture_asset_id = "truck-texture", width = 32, height = 32, layer = 3 },
                box_collider = { width = 32, height = 32, collision_mask = 4 },
                script       = spinner.new({ speed_deg = 65.0 }),
            },
        })
        label(95, 420, "pivot={0,0}", { r = 148, g = 163, b = 184, a = 255 })

        load_entity({
            name        = "PivotCenterPulse",
            entity_mask = 2,
            components  = {
                transform    = { position = { x = 275, y = 360 }, pivot = { x = 0.5, y = 0.5 } },
                sprite       = { texture_asset_id = "tank-panther-up", width = 32, height = 32, layer = 3 },
                box_collider = { width = 32, height = 32, collision_mask = 4 },
                script       = spinner.new({ speed_deg = 65.0, pulse = 0.35, base_scale = 1.25 }),
            },
        })
        label(232, 420, "pivot={0.5,0.5} + pulse", { r = 148, g = 163, b = 184, a = 255 })

        -- Parent-Child Hierarchy (nested `entities` orbiting parent anchor)
        label(510, 290, "7. PARENT-CHILD HIERARCHY", { r = 56, g = 189, b = 248, a = 255 })
        load_entity({
            name        = "OrbitalHub",
            entity_mask = 2,
            components  = {
                transform       = { position = { x = 620, y = 380 }, rotation = 0.0 },
                circle          = { radius = 18, color = { r = 234, g = 179, b = 8, a = 255 }, layer = 3 },
                circle_collider = { radius = 18, collision_mask = 4 },
                script          = spinner.new({ speed_deg = 75.0 }),
            },
            entities = {
                {
                    name = "OrbitalSatelliteA",
                    components = {
                        transform = { position = { x = 68, y = 0 } },
                        circle    = { radius = 10, color = { r = 56, g = 189, b = 248, a = 255 }, layer = 4 },
                    },
                },
                {
                    name = "OrbitalSatelliteB",
                    components = {
                        transform = { position = { x = -68, y = 0 } },
                        circle    = { radius = 10, color = { r = 244, g = 63, b = 94, a = 255 }, layer = 4 },
                    },
                },
            },
        })

        -- Additive Blending Showcase
        label(870, 290, "8. ADDITIVE BLEND PRIMITIVES", { r = 56, g = 189, b = 248, a = 255 })
        local add_colors = {
            { x = 960,  y = 375, c = { r = 255, g = 60,  b = 60,  a = 170 } },
            { x = 995,  y = 375, c = { r = 60,  g = 255, b = 80,  a = 170 } },
            { x = 977,  y = 345, c = { r = 60,  g = 120, b = 255, a = 170 } },
        }
        for _, orb in ipairs(add_colors) do
            load_entity({
                components = {
                    transform = { position = { x = orb.x, y = orb.y } },
                    circle    = { radius = 34, color = orb.c, filled = true, blend_mode = "add", layer = 3 },
                },
            })
        end

        -- Movable Shooter Chopper (Space or Left Click to fire SAT-tested projectiles)
        local shooter = load_entity({
            name        = "PhysicsLabShooter",
            tag         = "player",
            entity_mask = 1,
            components  = {
                transform    = { position = { x = 620, y = 580 }, scale = { x = 1.4, y = 1.4 } },
                sprite       = { texture_asset_id = "chopper-texture", width = 32, height = 32, layer = 5 },
                animation    = { num_frames = 2, speed_rate = 14 },
                box_collider = { width = 28, height = 24, offset = { x = 2, y = 4 }, collision_mask = 2 },
                script       = {
                    cooldown = 0.0,
                    on_update = function(self, entity, dt)
                        self.cooldown = math.max(0.0, self.cooldown - dt)
                        local mx, my = input_map.get_move_vector()
                        local pos = get_position(entity)
                        local nx = math.max(20, math.min(1230, pos.x + mx * 240 * dt))
                        local ny = math.max(80, math.min(670, pos.y + my * 240 * dt))
                        set_position(entity, nx, ny)

                        if (input.is_action_down("fire") or input.is_mouse_down(1)) and self.cooldown <= 0.0 then
                            self.cooldown = 0.18
                            local vx, vy = 0.0, -440.0
                            if input.is_mouse_down(1) then
                                local mp = input.mouse_position()
                                local dx, dy = mp.x - (nx + 16), mp.y - (ny + 16)
                                local len = math.sqrt(dx * dx + dy * dy)
                                if len > 1.0 then
                                    vx = (dx / len) * 440.0
                                    vy = (dy / len) * 440.0
                                end
                            end
                            combat.spawn_bullet({
                                x              = nx + 16,
                                y              = ny + 16,
                                vx             = vx,
                                vy             = vy,
                                friendly       = true,
                                entity_mask    = 4,
                                collision_mask = 2,
                                duration       = 2.2,
                            })
                            play_sound("sfx_cannon", 0.45)
                        end
                    end,
                },
            },
        })

        chrome.install({
            title = "Colliders, SAT & Primitives Lab",
            guide = "WASD / Left Stick: Move Chopper\n"
                 .. "Space: Fire Straight Up\n"
                 .. "Left Click / Hold: Aimed Fire\n\n"
                 .. "Watch SAT narrowphase resolve\n"
                 .. "Box, OBB, Circle, Capsule,\n"
                 .. "Triangle, and Line colliders!",
        })
    end,
}
