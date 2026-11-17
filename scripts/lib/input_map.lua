-- scripts/lib/input_map.lua
-- Declarative keyboard + canonical gamepad action bindings.
-- Action bindings survive scene transitions; input.on_* callbacks reset on scene swap.

local M = {}

M.DEFAULT_BINDINGS = {
    move_up    = { keys = { "w", "up" },         gamepad = "dpad_up" },
    move_down  = { keys = { "s", "down" },       gamepad = "dpad_down" },
    move_left  = { keys = { "a", "left" },       gamepad = "dpad_left" },
    move_right = { keys = { "d", "right" },      gamepad = "dpad_right" },
    fire       = { keys = { "space" },           gamepad = { "south", "rt" } },
    alt_fire   = { keys = { "lshift", "e" },     gamepad = { "west", "rb" } },
    ui_confirm = { keys = { "return", "space" }, gamepad = "south" },
    ui_cancel  = { keys = { "escape" },          gamepad = "east" },
    pause      = { keys = { "p" },               gamepad = "start" },
}

function M.install()
    input.set_bindings(M.DEFAULT_BINDINGS)
end

-- Combines left analog stick with digital move_* bindings into a normalized vector (max len 1.0).
function M.get_move_vector()
    local stick = input.gamepad_stick("left", 0.18)
    local x = stick.x
    local y = stick.y

    if input.is_action_down("move_left")  then x = x - 1.0 end
    if input.is_action_down("move_right") then x = x + 1.0 end
    if input.is_action_down("move_up")    then y = y - 1.0 end
    if input.is_action_down("move_down")  then y = y + 1.0 end

    local len = math.sqrt(x * x + y * y)
    if len > 1.0 then
        x = x / len
        y = y / len
    end
    return x, y
end

return M
