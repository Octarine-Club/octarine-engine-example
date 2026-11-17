-- scripts/scenes/jungle_strike.lua
-- Playable Vertical Slice: "Operation: Jungle Strike"
-- Showcases all sprite assets, chunked tilemap streaming, DDA enemy LoS raycasting,
-- directional patrols, destructible convoy trucks -> wrecks, hot-reloadable player script,
-- reactive MVVM HUD, spatial audio, and storage.* high-score persistence.

local WORLD_W = 1536
local WORLD_H = 1536

return {
    preload = {
        "tilemap-texture",
        "chopper-texture",
        "bullet-texture",
        "takeoff-base",
        "landing-base",
        "radar-sheet",
        "tree",
        "tank-texture", "tank-tiger-down", "tank-tiger-left", "tank-tiger-right",
        "tank-panther-up", "tank-panther-down", "tank-panther-left", "tank-panther-right",
        "truck-texture", "truck-ford-down", "truck-ford-left", "truck-ford-right", "truck-ford-killed",
        "helicopter", "sfx_cannon", "sfx_explosion", "sfx_radar_ping",
        "sfx_ui_hover", "sfx_ui_click",
        "arial-font-12", "arial-font-14", "charriot-14", "charriot-16", "charriot-24",
    },

    setup = function()
        mark_lab_visited("jungle_strike")
        set_game_map_dimensions(WORLD_W, WORLD_H)
        set_camera_zoom(1.0)

        local mission = {
            score             = 0,
            targets_alive     = 0,
            radar_alive       = true,
            ended             = false,
            god_mode          = false,
            player_entity     = nil,
            player_hp         = 100,
        }

        local hud_vm = ui.observable({
            hp               = 100,
            maxHp            = 100,
            specialCharge    = 1.0,
            score            = "0",
            targetsRemaining = "0",
            radarStatus      = "ONLINE",
            activeChunks     = "0",
            missionEnded     = false,
            missionBanner    = "",
            missionSummary   = "",
        })

        local function finish_mission(won)
            if mission.ended then return end
            mission.ended = true
            showcase_profile.missions_played = (showcase_profile.missions_played or 0) + 1
            if won then
                showcase_profile.missions_won = (showcase_profile.missions_won or 0) + 1
                mission.score = mission.score + 500
            end
            if mission.score > (showcase_profile.best_score or 0) then
                showcase_profile.best_score = mission.score
            end
            save_showcase_profile()

            hud_vm.score = tostring(mission.score)
            hud_vm.missionEnded = true
            hud_vm.missionBanner = won and "MISSION ACCOMPLISHED" or "CHOPPER DOWN"
            hud_vm.missionSummary = string.format(
                "Final Score: %d   |   Best Record: %d\nSaved to user save_profile.lua via storage.write_table().",
                mission.score, showcase_profile.best_score or mission.score)
        end

        local function register_target_destroyed(points)
            mission.score = mission.score + points
            mission.targets_alive = math.max(0, mission.targets_alive - 1)
            hud_vm.score = tostring(mission.score)
            hud_vm.targetsRemaining = tostring(mission.targets_alive)
            if mission.targets_alive == 0 and not mission.radar_alive then
                finish_mission(true)
            end
        end

        -- 1. Mount chunked tilemap with dynamic destructible Tree props
        jungle_tilemap.mount({
            stitch_mode   = "toroidal",
            seed          = 2026,
            load_radius   = 1,
            unload_radius = 2,
            on_tree_harvest = function(wx, wy)
                mission.score = mission.score + 25
                showcase_profile.trees_cleared = (showcase_profile.trees_cleared or 0) + 1
                hud_vm.score = tostring(mission.score)
                combat.spawn_explosion(wx + 8, wy + 16, { radius = 18, color = { r = 100, g = 230, b = 120, a = 220 } })
            end,
        })
        hud_vm.activeChunks = tostring(tilemap.get_active_chunk_count())

        -- 2. Helipads (takeoff-base + landing-base repair pad)
        load_entity({
            name = "HelipadAlpha",
            components = {
                transform = { position = { x = 220, y = 210 }, scale = { x = 1.6, y = 1.6 } },
                sprite    = { texture_asset_id = "takeoff-base", width = 32, height = 32, layer = 1 },
            },
        })
        load_entity({
            name = "HelipadBravo",
            components = {
                transform = { position = { x = 860, y = 250 }, scale = { x = 1.6, y = 1.6 } },
                sprite    = { texture_asset_id = "landing-base", width = 32, height = 32, layer = 1 },
            },
            entities = {
                {
                    components = {
                        transform  = { position = { x = -14, y = -16 } },
                        text_label = { text = "REPAIR PAD", font_id = "arial-font-12",
                                       color = { r = 74, g = 222, b = 128, a = 240 }, is_fixed = false, layer = 6 },
                    },
                },
            },
        })

        -- 3. Enemy Radar Command Station (animated 8-frame radar-sheet + spatial sonar ping)
        load_entity({
            name        = "EnemyRadar",
            tag         = "enemies",
            entity_mask = 2,
            components  = {
                transform    = { position = { x = 880, y = 760 }, scale = { x = 1.1, y = 1.1 } },
                sprite       = { texture_asset_id = "radar-sheet", width = 64, height = 64, layer = 3 },
                animation    = { num_frames = 8, speed_rate = 10 },
                box_collider = { width = 56, height = 56, offset = { x = 4, y = 4 }, collision_mask = 4 },
                script       = {
                    hp = 120,
                    max_hp = 120,
                    ping_timer = 0.0,
                    on_update = function(self, entity, dt)
                        self.ping_timer = self.ping_timer + dt
                        if self.ping_timer >= 2.6 then
                            self.ping_timer = 0.0
                            play_sound("sfx_radar_ping", 0.35)
                        end
                    end,
                    on_collision = function(self, entity, other)
                        if self.hp <= 0 then return end
                        self.hp = self.hp - 25
                        if self.hp <= 0 then
                            local p = get_position(entity)
                            combat.spawn_explosion(p.x + 32, p.y + 32, { radius = 48 })
                            mission.radar_alive = false
                            hud_vm.radarStatus = "DESTROYED"
                            register_target_destroyed(300)
                            blam(entity)
                        end
                    end,
                },
            },
        })
        mission.targets_alive = mission.targets_alive + 1

        -- 4. Enemy Unit Spawner Helper (Tiger tanks, Panther flankers, Ford supply trucks)
        local function spawn_enemy_unit(cfg)
            local tex = combat.dir_sprite_id(cfg.family, cfg.dir)
            local speed = cfg.speed or 55.0
            local vx = (cfg.dir == "right" and speed) or (cfg.dir == "left" and -speed) or 0.0
            local vy = (cfg.dir == "down" and speed) or (cfg.dir == "up" and -speed) or 0.0
            local fire_rate = cfg.fire_rate or 2.2
            local hp = cfg.hp or 75

            mission.targets_alive = mission.targets_alive + 1
            hud_vm.targetsRemaining = tostring(mission.targets_alive)

            local comp_table = {
                transform    = { position = { x = cfg.x, y = cfg.y }, scale = { x = 1.25, y = 1.25 } },
                rigidbody    = { velocity = { x = vx, y = vy } },
                sprite       = { texture_asset_id = tex, width = 32, height = 32, layer = 3 },
                box_collider = { width = 26, height = 26, offset = { x = 3, y = 3 }, collision_mask = 4 },
                script       = {
                    hp           = hp,
                    max_hp       = hp,
                    family       = cfg.family,
                    dir          = cfg.dir,
                    origin_x     = cfg.x,
                    origin_y     = cfg.y,
                    patrol_span  = cfg.span or 180.0,
                    speed        = speed,
                    fire_timer   = cfg.initial_delay or 1.0,
                    fire_rate    = fire_rate,
                    can_shoot    = (cfg.family ~= "truck"),
                    on_update = function(self, entity, dt)
                        local pos = get_position(entity)
                        local rb = registry.get_rigidbody(entity)
                        if self.speed > 0 then
                            local dist = math.abs(pos.x - self.origin_x) + math.abs(pos.y - self.origin_y)
                            if dist > self.patrol_span then
                                rb.velocity.x = -rb.velocity.x
                                rb.velocity.y = -rb.velocity.y
                                self.origin_x = pos.x
                                self.origin_y = pos.y
                            end
                        end

                        if not self.can_shoot or mission.ended then return end
                        self.fire_timer = self.fire_timer - dt
                        if self.fire_timer <= 0.0 then
                            self.fire_timer = self.fire_rate
                            if mission.player_entity and registry.is_alive(mission.player_entity) then
                                local ppos = get_position(mission.player_entity)
                                local sx, sy = pos.x + 16, pos.y + 16
                                local tx, ty = ppos.x + 16, ppos.y + 16
                                local dx, dy = tx - sx, ty - sy
                                local dlen = math.sqrt(dx * dx + dy * dy)
                                if dlen > 1.0 and dlen < 440.0 then
                                    local blocked = false
                                    if tilemap.is_loaded() then
                                        local hit = tilemap.raycast(sx, sy, tx, ty, tilemap.MASK_PROJECTILE_BLOCKED)
                                        blocked = hit
                                    end
                                    if not blocked then
                                        combat.spawn_bullet({
                                            x              = sx,
                                            y              = sy,
                                            vx             = (dx / dlen) * 230.0,
                                            vy             = (dy / dlen) * 230.0,
                                            friendly       = false,
                                            entity_mask    = 8,
                                            collision_mask = 1,
                                            damage         = 10,
                                            duration       = 2.0,
                                            check_tilemap  = true,
                                        })
                                    end
                                end
                            end
                        end
                    end,
                    on_collision = function(self, entity, other)
                        if self.hp <= 0 then return end
                        self.hp = self.hp - 25
                        if self.hp <= 0 then
                            local p = get_position(entity)
                            combat.spawn_explosion(p.x + 16, p.y + 16, { radius = 30 })
                            if self.family == "truck" then
                                -- Spawn persistent smoldering truck-ford-killed wreck on destruction!
                                load_entity({
                                    name = "TruckWreck",
                                    components = {
                                        transform = { position = { x = p.x, y = p.y }, scale = { x = 1.25, y = 1.25 } },
                                        sprite    = { texture_asset_id = "truck-ford-killed", width = 32, height = 32, layer = 2 },
                                    },
                                })
                            end
                            register_target_destroyed(self.family == "tiger" and 150 or 100)
                            blam(entity)
                        end
                    end,
                },
            }

            if native_showcase ~= nil and native_showcase.is_enabled() then
                comp_table.armor_health = { max_hp = hp, current_hp = hp, regen_rate = 0.0 }
            end

            load_entity({
                name        = cfg.name or cfg.family,
                tag         = "enemies",
                entity_mask = 2,
                components  = comp_table,
            })
        end

        -- Populate Tiger, Panther, and Ford Truck squads using all 4 directional sprites!
        local initial_units = {
            { name = "TigerNorth",  family = "tiger",   dir = "up",    x = 420, y = 460, speed = 42, span = 120, hp = 80, initial_delay = 0.8 },
            { name = "TigerEast",   family = "tiger",   dir = "right", x = 360, y = 620, speed = 50, span = 180, hp = 80, initial_delay = 1.4 },
            { name = "TigerSouth",  family = "tiger",   dir = "down",  x = 760, y = 420, speed = 42, span = 140, hp = 80, initial_delay = 1.1 },
            { name = "TigerWest",   family = "tiger",   dir = "left",  x = 980, y = 640, speed = 50, span = 170, hp = 80, initial_delay = 1.9 },
            { name = "PantherN",    family = "panther", dir = "up",    x = 640, y = 840, speed = 65, span = 150, hp = 60, initial_delay = 0.9 },
            { name = "PantherE",    family = "panther", dir = "right", x = 520, y = 320, speed = 70, span = 160, hp = 60, initial_delay = 1.5 },
            { name = "PantherS",    family = "panther", dir = "down",  x = 960, y = 920, speed = 65, span = 140, hp = 60, initial_delay = 1.2 },
            { name = "PantherW",    family = "panther", dir = "left",  x = 840, y = 520, speed = 70, span = 160, hp = 60, initial_delay = 1.7 },
            { name = "ConvoyN",     family = "truck",   dir = "up",    x = 300, y = 780, speed = 48, span = 130, hp = 45 },
            { name = "ConvoyE",     family = "truck",   dir = "right", x = 560, y = 560, speed = 48, span = 160, hp = 45 },
            { name = "ConvoyS",     family = "truck",   dir = "down",  x = 700, y = 260, speed = 48, span = 130, hp = 45 },
            { name = "ConvoyW",     family = "truck",   dir = "left",  x = 940, y = 420, speed = 48, span = 160, hp = 45 },
        }
        for _, u in ipairs(initial_units) do
            spawn_enemy_unit(u)
        end

        -- 5. Player Helicopter (file-backed hot-reloadable script + child targeting reticle + spatial listener)
        local player_comp_script = dofile(get_asset_path("scripts/entities/chopper_player.lua"))
        local player = load_entity({
            name        = "PlayerChopper",
            tag         = "player",
            entity_mask = 1,
            components  = {
                transform    = { position = { x = 224, y = 212 }, scale = { x = 1.25, y = 1.25 } },
                rigidbody    = { velocity = { x = 0, y = 0 } },
                sprite       = { texture_asset_id = "chopper-texture", width = 32, height = 32, layer = 4 },
                animation    = { num_frames = 2, speed_rate = 14 },
                box_collider = { width = 26, height = 24, offset = { x = 3, y = 4 }, collision_mask = 8 },
                camera_follow  = {},
                audio_listener = { max_distance = 1000, rolloff = 1.0, doppler_factor = 1.0 },
                audio_source   = { clip_id = "helicopter", loop = true, play_on_spawn = true, volume = 0.28, spatial = false },
                script         = { source = "scripts/entities/chopper_player.lua" },
            },
            entities = {
                {
                    name = "ChopperShieldRing",
                    components = {
                        transform = { position = { x = 16, y = 16 } },
                        circle    = {
                            position  = { x = 0, y = 0 },
                            radius    = 20,
                            thickness = 1.5,
                            filled    = false,
                            color     = { r = 56, g = 189, b = 248, a = 120 },
                            layer     = 4,
                        },
                    },
                },
            },
        })
        mission.player_entity = player

        -- Wire runtime callbacks onto the hot-reloadable player script component table
        if player and registry.has_script(player) then
            local p_script = registry.get_script(player).data
            p_script.world_w = WORLD_W
            p_script.world_h = WORLD_H
            p_script.repair_pad = { x = 885, y = 275 }
            p_script.on_state_sync = function(hp, max_hp, charge)
                hud_vm.hp = hp
                hud_vm.maxHp = max_hp
                hud_vm.specialCharge = charge
                hud_vm.activeChunks = tostring(tilemap.get_active_chunk_count())
                if hp <= 0 and not mission.ended then
                    finish_mission(false)
                end
            end
        end

        -- 6. Mount Reactive MVVM Mission HUD + Shared Scene Chrome
        ui.mount("ui/jungle_hud.oxml", {
            context = hud_vm,
            controller = {
                onRestartMission = function()
                    reload_scene()
                end,
                onReturnHub = function()
                    load_scene("scripts/scenes/hub.lua")
                end,
            },
        })

        chrome.install({
            title = "Operation: Jungle Strike",
            guide = "WASD / Left Stick: Fly Chopper\n"
                 .. "Space / South / RT: Rapid Cannon\n"
                 .. "Shift / E / West: 3-Way Burst\n"
                 .. "Hover on Helipad Bravo (H) to repair.\n\n"
                 .. "Destroy the Enemy Radar & all 12 ground units.\n"
                 .. "Edit scripts/entities/chopper_player.lua in --dev to watch live hot-reload!",
            on_dev_spawn = function(kind)
                if not player or not registry.is_alive(player) then return end
                local p = get_position(player)
                local fam = (kind == "Panther Tank" and "panther")
                         or (kind == "Supply Truck" and "truck")
                         or "tiger"
                spawn_enemy_unit({
                    name   = "DevSpawned_" .. fam,
                    family = fam,
                    dir    = "down",
                    x      = p.x + 120,
                    y      = p.y + 80,
                    speed  = 45,
                    hp     = 60,
                })
            end,
        })
    end,
}
