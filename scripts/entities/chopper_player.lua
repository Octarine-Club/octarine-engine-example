-- scripts/entities/chopper_player.lua
-- File-backed hot-reloadable player controller for Operation: Jungle Strike.
-- Demonstrates `script = { source = "..." }`, analog+digital `input_map.get_move_vector()`,
-- `tilemap.resolve_circle()`, directional spritesheet rows, child laser sight, and weapon cooldowns.

local ROW_BY_DIR = { up = 0, right = 1, down = 2, left = 3 }
local VEC_BY_DIR = {
    up    = { 0, -1 },
    right = { 1, 0 },
    down  = { 0, 1 },
    left  = { -1, 0 },
}

local function update_facing(self, mx, my)
    if math.abs(mx) > math.abs(my) then
        if mx > 0.15 then
            self.dir = "right"
        elseif mx < -0.15 then
            self.dir = "left"
        end
    elseif math.abs(my) > 0.15 then
        if my > 0.15 then
            self.dir = "down"
        elseif my < -0.15 then
            self.dir = "up"
        end
    end
end

local function fire_burst(self, x, y, spread)
    local dir_vec = VEC_BY_DIR[self.dir]
    local bx = x + 16 + dir_vec[1] * 18
    local by = y + 16 + dir_vec[2] * 18
    local speed = 420.0
    local base_ang = math.atan(dir_vec[2], dir_vec[1])
    local offsets = spread and { -0.18, 0.0, 0.18 } or { 0.0 }

    for _, off in ipairs(offsets) do
        local ang = base_ang + off
        combat.spawn_bullet({
            x              = bx,
            y              = by,
            vx             = math.cos(ang) * speed,
            vy             = math.sin(ang) * speed,
            friendly       = true,
            entity_mask    = 4,
            collision_mask = 2,
            damage         = spread and 35 or 25,
            duration       = 1.4,
            check_tilemap  = true,
            on_hit         = self.on_bullet_hit,
        })
    end
    play_sound("sfx_cannon", 0.55)
end

return {
    speed           = 210.0,
    dir             = "up",
    fire_cooldown   = 0.0,
    special_charge  = 1.0,
    hp              = 100,
    max_hp          = 100,
    repair_accum    = 0.0,
    world_w         = 1536,
    world_h         = 1536,
    on_bullet_hit   = nil,
    on_state_sync   = nil,

    on_update = function(self, entity, dt)
        if registry.is_paused() then
            return
        end

        self.fire_cooldown = math.max(0.0, self.fire_cooldown - dt)
        self.special_charge = math.min(1.0, self.special_charge + dt * 0.22)

        local mx, my = input_map.get_move_vector()
        update_facing(self, mx, my)

        local pos = get_position(entity)
        local nx = pos.x + mx * self.speed * dt
        local ny = pos.y + my * self.speed * dt

        nx = math.max(16.0, math.min(self.world_w - 48.0, nx))
        ny = math.max(16.0, math.min(self.world_h - 48.0, ny))

        -- Slide chopper against rock/thicket barriers (TILE_SOLID | TILE_WALL), flying freely over water (TILE_CHASM).
        if tilemap.is_loaded() then
            local cx, cy = tilemap.resolve_circle(nx + 16.0, ny + 16.0, 12.0, tilemap.MASK_PROJECTILE_BLOCKED)
            nx = cx - 16.0
            ny = cy - 16.0
        end

        set_position(entity, nx, ny)
        set_sprite_src_rect(entity, 0, ROW_BY_DIR[self.dir] * 32)

        -- Heal armor when hovering over Helipad Bravo (landing-base)
        if self.repair_pad then
            local dx = (nx + 16.0) - self.repair_pad.x
            local dy = (ny + 16.0) - self.repair_pad.y
            if (dx * dx + dy * dy) < (44.0 * 44.0) and self.hp < self.max_hp then
                self.repair_accum = self.repair_accum + dt
                if self.repair_accum >= 0.25 then
                    self.repair_accum = 0.0
                    self.hp = math.min(self.max_hp, self.hp + 5)
                    play_sound("sfx_radar_ping", 0.35)
                end
            end
        end

        if input.is_action_down("fire") and self.fire_cooldown <= 0.0 then
            self.fire_cooldown = 0.16
            fire_burst(self, nx, ny, false)
        elseif input.is_action_pressed("alt_fire") and self.special_charge >= 0.99 then
            self.special_charge = 0.0
            self.fire_cooldown = 0.22
            fire_burst(self, nx, ny, true)
        end

        if self.on_state_sync then
            self.on_state_sync(self.hp, self.max_hp, self.special_charge)
        end
    end,

    on_collision = function(self, entity, other)
        -- Enemy shell hit handling when not protected by God Mode
        if self.god_mode or not registry.is_alive(other) then
            return
        end
        if self.invuln_timer and self.invuln_timer > 0 then
            return
        end
        self.hp = math.max(0, self.hp - 10)
        if self.on_state_sync then
            self.on_state_sync(self.hp, self.max_hp, self.special_charge)
        end
    end,
}
