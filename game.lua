-- game.lua
-- Entry point executed via config.ini StartupScript=game.lua.
-- Sets up module loading, persistent settings & save profile, declarative input bindings,
-- and dispatches based on `oct_startup_mode`.

_G.__showcase_modules = _G.__showcase_modules or {}

function showcase_require(rel_path)
    if _G.__showcase_modules[rel_path] ~= nil then
        return _G.__showcase_modules[rel_path]
    end
    local full_path = get_asset_path(rel_path)
    local mod = dofile(full_path)
    if mod ~= nil then
        _G.__showcase_modules[rel_path] = mod
    else
        _G.__showcase_modules[rel_path] = true
    end
    return _G.__showcase_modules[rel_path]
end

-- Define typed user preferences stored in user_settings.ini under the OS save root.
settings.define({
    master_volume    = 0.85,
    audio_muted      = false,
    show_hints       = true,
    difficulty       = "normal",
    preferred_stitch = "toroidal",
    ui_wireframes    = false,
})

if not is_headless() then
    set_master_volume(settings.get("master_volume", 0.85))
    set_audio_muted(settings.get("audio_muted", false))
end

-- Persistent cross-scene player/showcase profile via sandboxed storage.* API.
local function default_profile()
    return {
        best_score         = 0,
        missions_played    = 0,
        missions_won       = 0,
        trees_cleared      = 0,
        labs_visited       = {},
        last_scene         = "hub",
    }
end

showcase_profile = storage.read_table("save_profile.lua")
if type(showcase_profile) ~= "table" then
    showcase_profile = default_profile()
else
    local defaults = default_profile()
    for k, v in pairs(defaults) do
        if showcase_profile[k] == nil then
            showcase_profile[k] = v
        end
    end
end

function save_showcase_profile()
    return storage.write_table("save_profile.lua", showcase_profile)
end

function mark_lab_visited(scene_id)
    showcase_profile.last_scene = scene_id
    showcase_profile.labs_visited = showcase_profile.labs_visited or {}
    showcase_profile.labs_visited[scene_id] = true
    save_showcase_profile()
end

-- Load shared libraries into globals so every scene can use them cleanly.
input_map      = showcase_require("scripts/lib/input_map.lua")
spinner        = showcase_require("scripts/lib/spinner.lua")
combat         = showcase_require("scripts/lib/combat.lua")
jungle_tilemap = showcase_require("scripts/lib/jungle_tilemap.lua")
showcase_dev   = showcase_require("scripts/dev/showcase_dev_tools.lua")
chrome         = showcase_require("scripts/lib/chrome.lua")

input_map.install()

if oct_startup_mode ~= "bake" and type(acquire_scene_assets) == "function" then
    acquire_scene_assets({
        preload = {
            "arial-font-10",
            "arial-font-12",
            "arial-font-14",
            "charriot-14",
            "charriot-16",
            "sfx_ui_hover",
            "sfx_ui_click",
        },
    })
end

if oct_startup_mode == "stress" then
    local stress_test = dofile(get_asset_path("scripts/stress-test.lua"))
    stress_test.run()
elseif oct_startup_mode == "verify" then
    local verifier = dofile(get_asset_path("scripts/verify_showcase.lua"))
    verifier.run()
elseif oct_startup_mode == "bake" then
    -- Validate every catalog asset referenced across all showcase scenes during `-m bake`
    -- (without calling load_scene, since bake mode has no SDL renderer / TTF video backend).
    local scene_paths = {
        "scripts/scenes/hub.lua",
        "scripts/scenes/jungle_strike.lua",
        "scripts/scenes/ui_lab.lua",
        "scripts/scenes/physics_lab.lua",
        "scripts/scenes/tilemap_lab.lua",
        "scripts/scenes/audio_lab.lua",
        "scripts/scenes/stress_lab.lua",
    }
    for _, sp in ipairs(scene_paths) do
        local tbl = dofile(get_asset_path(sp))
        if type(tbl) == "table" then
            acquire_scene_assets(tbl)
        end
    end
    acquire_scene_assets({
        preload = {
            "arial-font-10", "arial-font-12", "arial-font-14", "arial-font-18",
            "charriot-14", "charriot-16", "charriot-24", "charriot-32",
            "bullet-texture", "chopper-texture", "chopper-drone", "radar-sheet", "icon",
            "landing-base", "takeoff-base", "tree", "tilemap-texture",
            "tank-texture", "tank-tiger-down", "tank-tiger-left", "tank-tiger-right",
            "tank-panther-up", "tank-panther-down", "tank-panther-left", "tank-panther-right",
            "truck-texture", "truck-ford-down", "truck-ford-left", "truck-ford-right", "truck-ford-killed",
            "helicopter", "sfx_ui_hover", "sfx_ui_click", "sfx_cannon", "sfx_explosion", "sfx_radar_ping",
        }
    })
else
    local scene_shortcuts = {
        hub        = "scripts/scenes/hub.lua",
        jungle     = "scripts/scenes/jungle_strike.lua",
        ui         = "scripts/scenes/ui_lab.lua",
        physics    = "scripts/scenes/physics_lab.lua",
        tilemap    = "scripts/scenes/tilemap_lab.lua",
        audio      = "scripts/scenes/audio_lab.lua",
        stress_lab = "scripts/scenes/stress_lab.lua",
    }
    load_scene(scene_shortcuts[oct_startup_mode] or "scripts/scenes/hub.lua")
end
