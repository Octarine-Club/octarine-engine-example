-- scripts/scenes/audio_lab.lua
-- Interactive Spatial & Doppler Audio Lab.
-- Showcases: audio_listener, spatial attenuation (min_distance / max_distance),
-- stereo panning, DopplerSystem pitch shift from relative rigidbody velocity,
-- non-spatial constant sources, and EventBus play_sound().

return {
    preload = {
        "chopper-drone",
        "radar-sheet",
        "tank-texture",
        "takeoff-base",
        "helicopter",
        "sfx_radar_ping",
        "sfx_cannon",
        "sfx_explosion",
        "sfx_ui_hover",
        "sfx_ui_click",
        "arial-font-12",
        "charriot-14",
        "charriot-16",
    },

    setup = function()
        mark_lab_visited("audio_lab")
        set_game_map_dimensions(1280, 720)
        set_camera_zoom(1.0)

        local vm = ui.observable({
            muted           = is_audio_muted(),
            volumePct       = math.floor(get_master_volume() * 100 + 0.5),
            listenerReadout = "Listener: (640, 360)",
        })

        local function label(x, y, text, color)
            load_entity({
                components = {
                    transform  = { position = { x = x, y = y } },
                    text_label = { text = text, font_id = "arial-font-12", color = color, is_fixed = false, layer = 6 },
                },
            })
        end

        -- Background grid
        load_entity({
            components = {
                transform = { position = { x = 0, y = 0 } },
                color_grid = {
                    cell_size = 48,
                    color1    = { r = 13, g = 20, b = 36, a = 255 },
                    color2    = { r = 18, g = 27, b = 48, a = 255 },
                    layer     = 0,
                    is_fixed  = false,
                },
            },
        })

        -- Spatial Source A: Tight Sonar Beacon (radar-sheet)
        load_entity({
            name = "SpatialBeaconA",
            components = {
                transform = { position = { x = 230, y = 240 } },
                sprite    = { texture_asset_id = "radar-sheet", width = 64, height = 64, layer = 3 },
                animation = { num_frames = 8, speed_rate = 10 },
                audio_source = {
                    clip_id       = "helicopter",
                    loop          = true,
                    play_on_spawn = true,
                    volume        = 0.85,
                    spatial       = true,
                    min_distance  = 70,
                    max_distance  = 310,
                },
            },
            entities = {
                {
                    components = {
                        transform = { position = { x = 32, y = 32 } },
                        circle    = { radius = 70, thickness = 1.5, filled = false, color = { r = 249, g = 115, b = 22, a = 180 }, layer = 1 },
                    },
                },
                {
                    components = {
                        transform = { position = { x = 32, y = 32 } },
                        circle    = { radius = 310, thickness = 1.5, filled = false, color = { r = 249, g = 115, b = 22, a = 80 }, layer = 1 },
                    },
                },
            },
        })
        label(195, 210, "Spatial A (min=70, max=310)", { r = 251, g = 146, b = 60, a = 255 })

        -- Spatial Source B: Wide Range Engine (tank-texture)
        load_entity({
            name = "SpatialBeaconB",
            components = {
                transform = { position = { x = 1010, y = 460 }, scale = { x = 1.4, y = 1.4 } },
                sprite    = { texture_asset_id = "tank-texture", width = 32, height = 32, layer = 3 },
                audio_source = {
                    clip_id       = "helicopter",
                    loop          = true,
                    play_on_spawn = true,
                    volume        = 0.75,
                    spatial       = true,
                    min_distance  = 110,
                    max_distance  = 480,
                },
            },
            entities = {
                {
                    components = {
                        transform = { position = { x = 16, y = 16 } },
                        circle    = { radius = 110, thickness = 1.5, filled = false, color = { r = 56, g = 189, b = 248, a = 180 }, layer = 1 },
                    },
                },
                {
                    components = {
                        transform = { position = { x = 16, y = 16 } },
                        circle    = { radius = 480, thickness = 1.5, filled = false, color = { r = 56, g = 189, b = 248, a = 70 }, layer = 1 },
                    },
                },
            },
        })
        label(930, 425, "Spatial B (min=110, max=480)", { r = 125, g = 211, b = 252, a = 255 })

        -- High-speed Doppler Flyby Drone (doppler = true + high rigidbody velocity!)
        load_entity({
            name = "DopplerDrone",
            components = {
                transform = { position = { x = 200, y = 135 }, scale = { x = 1.6, y = 1.6 } },
                rigidbody = { velocity = { x = 320, y = 0 } },
                sprite    = { texture_asset_id = "chopper-drone", width = 32, height = 32, layer = 4 },
                animation = { num_frames = 2, speed_rate = 16 },
                audio_source = {
                    clip_id       = "helicopter",
                    loop          = true,
                    play_on_spawn = true,
                    volume        = 0.8,
                    spatial       = true,
                    min_distance  = 80,
                    max_distance  = 650,
                    doppler       = true,
                },
                script = {
                    on_update = function(self, entity, dt)
                        local p = get_position(entity)
                        local rb = registry.get_rigidbody(entity)
                        if p.x > 1180 and rb.velocity.x > 0 then
                            rb.velocity.x = -320
                        elseif p.x < 80 and rb.velocity.x < 0 then
                            rb.velocity.x = 320
                        end
                    end,
                },
            },
        })
        label(490, 96, "Doppler Flyby Lane (doppler=true, v=+/-320 px/s)", { r = 250, g = 204, b = 21, a = 255 })

        -- Non-spatial constant source (never attenuates with distance; avoid `global` keyword in Lua 5.5!)
        load_entity({
            name = "ConstantBedSource",
            components = {
                transform = { position = { x = 620, y = 555 }, scale = { x = 1.2, y = 1.2 } },
                sprite    = { texture_asset_id = "takeoff-base", width = 32, height = 32, layer = 2 },
                audio_source = {
                    clip_id       = "helicopter",
                    loop          = true,
                    play_on_spawn = true,
                    volume        = 0.16,
                    spatial       = false,
                },
            },
        })
        label(525, 528, "Non-Spatial Source (spatial=false, constant)", { r = 167, g = 139, b = 250, a = 255 })

        -- Movable Player Audio Listener
        load_entity({
            name = "AudioListenerMarker",
            components = {
                transform      = { position = { x = 626, y = 346 } },
                circle         = { radius = 14, color = { r = 34, g = 197, b = 94, a = 255 }, layer = 5 },
                audio_listener = { max_distance = 900, rolloff = 1.0, doppler_factor = 1.0, speed_of_sound = 343.0 },
                script         = {
                    on_update = function(self, entity, dt)
                        local mx, my = input_map.get_move_vector()
                        local p = get_position(entity)
                        local nx = math.max(30, math.min(1250, p.x + mx * 240.0 * dt))
                        local ny = math.max(70, math.min(640, p.y + my * 240.0 * dt))
                        set_position(entity, nx, ny)
                        vm.listenerReadout = string.format("Listener: (%.0f, %.0f)", nx, ny)
                    end,
                },
            },
        })

        ui.mount("ui/audio_lab.oxml", {
            context = vm,
            controller = {
                onToggleMute = function(self, checked)
                    set_audio_muted(checked)
                    settings.set("audio_muted", checked)
                    settings.save()
                end,
                onVolumeChange = function(self, val)
                    local vol = math.max(0.0, math.min(1.0, (val or 85) / 100.0))
                    set_master_volume(vol)
                    settings.set("master_volume", vol)
                    settings.save()
                end,
                onPlayPing      = function() play_sound("sfx_radar_ping", 0.85) end,
                onPlayCannon    = function() play_sound("sfx_cannon", 0.85) end,
                onPlayExplosion = function() play_sound("sfx_explosion", 0.85) end,
            },
        })

        chrome.install({
            title = "Spatial & Doppler Audio Lab",
            guide = "WASD / Stick: Move green audio_listener\n\n"
                 .. "Move near Orange/Blue rings to hear\n"
                 .. "distance attenuation & stereo panning.\n\n"
                 .. "Stand near top lane to hear Doppler\n"
                 .. "pitch shift as the chopper flies past!",
        })
    end,
}
