-- scripts/lib/combat.lua
-- Shared projectile, explosion VFX, and directional sprite helpers for gameplay & physics demos.

local M = {}

function M.spawn_explosion(wx, wy, opts)
    opts = opts or {}
    local max_r = opts.radius or 26
    local color = opts.color or { r = 255, g = 180, b = 60, a = 240 }

    load_entity({
        components = {
            transform = { position = { x = wx, y = wy } },
            circle = {
                position   = { x = 0, y = 0 },
                radius     = 6,
                thickness  = 3,
                filled     = false,
                color      = color,
                layer      = 7,
                blend_mode = "add",
            },
            lifetime = { duration = 0.28 },
            script = {
                age = 0.0,
                max_r = max_r,
                on_update = function(self, entity, dt)
                    self.age = self.age + dt
                    local t = math.min(1.0, self.age / 0.28)
                    if registry.has_circle(entity) then
                        local c = registry.get_circle(entity)
                        c.radius = 6.0 + t * self.max_r
                        c.color.a = math.floor(240 * (1.0 - t))
                    end
                end,
            },
        },
    })

    if opts.sound ~= false then
        play_sound(opts.sound_id or "sfx_explosion", opts.volume or 0.65)
    end
end

function M.spawn_bullet(opts)
    local x          = opts.x or 0
    local y          = opts.y or 0
    local vx         = opts.vx or 0
    local vy         = opts.vy or -300
    local friendly   = (opts.friendly ~= false)
    local damage     = opts.damage or 25
    local mask_self  = opts.entity_mask or (friendly and 4 or 8)
    local mask_hit   = opts.collision_mask or (friendly and 2 or 1)
    local tint       = opts.color_mod or (friendly and { r = 120, g = 240, b = 255, a = 255 } or { r = 255, g = 90, b = 70, a = 255 })
    local on_hit     = opts.on_hit

    return load_entity({
        tag = friendly and "player_bullet" or "enemy_bullet",
        entity_mask = mask_self,
        components = {
            transform = {
                position = { x = x, y = y },
                scale    = { x = opts.scale or 2.0, y = opts.scale or 2.0 },
            },
            rigidbody = { velocity = { x = vx, y = vy } },
            sprite = {
                texture_asset_id = "bullet-texture",
                width            = 4,
                height           = 4,
                layer            = 5,
                color_mod        = tint,
            },
            circle_collider = {
                radius         = opts.radius or 5,
                offset         = { x = 0, y = 0 },
                collision_mask = mask_hit,
            },
            lifetime = { duration = opts.duration or 2.5 },
            script = {
                hit_done = false,
                damage = damage,
                on_update = function(self, entity, dt)
                    if opts.check_tilemap and tilemap.is_loaded() then
                        local pos = get_position(entity)
                        if tilemap.is_solid_at(pos.x, pos.y, tilemap.MASK_PROJECTILE_BLOCKED) then
                            M.spawn_explosion(pos.x, pos.y, { radius = 14, sound = false, color = tint })
                            blam(entity)
                        end
                    end
                end,
                on_collision = function(self, entity, other)
                    if self.hit_done then return end
                    self.hit_done = true
                    local pos = get_position(entity)
                    if on_hit then
                        on_hit(other, self.damage, pos.x, pos.y)
                    end
                    M.spawn_explosion(pos.x, pos.y, { radius = 14, sound = false, color = tint })
                    blam(entity)
                end,
            },
        },
    })
end

function M.dir_sprite_id(family, dir)
    if family == "tiger" then
        if dir == "up" then return "tank-texture" end
        return "tank-tiger-" .. dir
    elseif family == "panther" then
        return "tank-panther-" .. dir
    elseif family == "truck" then
        if dir == "up" then return "truck-texture" end
        return "truck-ford-" .. dir
    end
    return "tank-texture"
end

return M
