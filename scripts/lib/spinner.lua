-- scripts/lib/spinner.lua
-- Continuous rotation, scale-breathing, and optional vertical bobbing in degrees (AngleUnit=degrees).

local M = {}

local function update(self, entity, dt)
    self.elapsed = self.elapsed + dt

    if self.speed_deg ~= 0 and registry.has_rotation(entity) then
        local rot = registry.get_rotation(entity)
        rot.value = rot.value + self.speed_deg * dt
    end

    if self.pulse > 0 and registry.has_scale(entity) then
        local s = self.base_scale + math.sin(self.elapsed * self.pulse_speed) * self.pulse
        local scale = registry.get_scale(entity)
        scale.value.x = s
        scale.value.y = s
    end

    if self.bob_amp > 0 and registry.has_position(entity) then
        local pos = registry.get_position(entity)
        if self.origin_y == nil then
            self.origin_y = pos.y
        end
        pos.y = self.origin_y + math.sin(self.elapsed * self.bob_speed) * self.bob_amp
    end
end

function M.new(opts)
    opts = opts or {}
    return {
        speed_deg   = opts.speed_deg   or 60.0,
        pulse       = opts.pulse       or 0.0,
        pulse_speed = opts.pulse_speed or 2.4,
        base_scale  = opts.base_scale  or 1.0,
        bob_amp     = opts.bob_amp     or 0.0,
        bob_speed   = opts.bob_speed   or 2.0,
        origin_y    = nil,
        elapsed     = 0.0,
        on_update   = update,
    }
end

return M
