-- scripts/scenes/ui_lab.lua
-- Interactive Declarative UI & Persistence Lab.
-- Covers: Paradigm A (view.refs), Paradigm B (context), Paradigm C (ui.observable MVVM),
-- <Use>/<Slot> templates, ui.register_widget, <Grid>, <ScrollView>, inert subtrees,
-- pointer-blocking modals, settings.*, and storage.*.

return {
    preload = {
        "arial-font-10", "arial-font-12", "arial-font-14",
        "charriot-14", "charriot-16", "charriot-24",
        "sfx_ui_hover", "sfx_ui_click", "sfx_radar_ping",
    },

    setup = function()
        mark_lab_visited("ui_lab")
        set_game_map_dimensions(0, 0)

        -- Register custom widget tag BEFORE mounting ui/ui_lab.oxml
        ui.register_widget("StatusBeacon", {
            props = {
                title  = "SYS",
                status = "ONLINE",
                active = true,
            },
            template = [[
                <Row width="152px" height="28px" padding="0px 8px"
                     background-color="{active and '#064e3b' or '#450a0a'}"
                     border-width="1"
                     border-color="{active and '#34d399' or '#f87171'}"
                     align="center" justify="space-between">
                    <Label text="{title}" font="arial-font-10" color="#cbd5e1" width="auto" height="18px" />
                    <Label text="{status}" font="arial-font-10" color="{active and '#34d399' or '#f87171'}" width="auto" height="18px" />
                </Row>
            ]],
        })

        local roster_pool = {
            { name = "Valkyrie-01", role = "Gunship" },
            { name = "Tiger-Alpha", role = "Heavy Armor" },
            { name = "Panther-04",  role = "Scout" },
            { name = "Ford-Supply", role = "Logistics" },
            { name = "Radar-North", role = "Recon" },
            { name = "Helipad-B",   role = "Repair" },
        }

        local vm = ui.observable({
            volumePct      = math.floor((settings.get("master_volume", 0.85)) * 100 + 0.5),
            isMuted        = settings.get("audio_muted", false),
            beaconStatus   = settings.get("audio_muted", false) and "MUTED" or "ONLINE",
            difficulty     = settings.get("difficulty", "normal"),
            powerLevel     = 65,
            settingsStatus = "Loaded defaults from user_settings.ini",
            unitCount      = tostring(#roster_pool),
            bestScore      = tostring(showcase_profile.best_score or 0),
            roster         = {
                roster_pool[1],
                roster_pool[2],
                roster_pool[3],
                roster_pool[4],
            },
            storageOutput  = "Click 'Write Note' to test sandboxed storage.write_table / read_table.",
            modalOpen      = false,
        })

        local view = nil
        local ping_count = 0
        local inert_active = false

        local controller = {
            onVolumeChange = function(self, val)
                local vol = math.max(0.0, math.min(1.0, (val or 85) / 100.0))
                set_master_volume(vol)
                settings.set("master_volume", vol)
            end,
            onMuteChange = function(self, muted)
                set_audio_muted(muted)
                settings.set("audio_muted", muted)
                vm.beaconStatus = muted and "MUTED" or "ONLINE"
            end,
            onDifficultyChange = function(self, diff)
                settings.set("difficulty", diff)
                vm.settingsStatus = "Active difficulty set to '" .. tostring(diff) .. "' (unsaved)"
            end,
            onSaveSettings = function()
                settings.save()
                vm.settingsStatus = "Persisted user_settings.ini via settings.save()!"
                play_sound("sfx_radar_ping", 0.45)
            end,
            onAddItem = function()
                local next_item = roster_pool[(#vm.roster % #roster_pool) + 1]
                local copy = {}
                for _, entry in ipairs(vm.roster) do copy[#copy + 1] = entry end
                copy[#copy + 1] = { name = next_item.name .. " #" .. (#copy + 1), role = next_item.role }
                vm.roster = copy
                vm.unitCount = tostring(#copy)
            end,
            onShuffleItems = function()
                local copy = {}
                for i = #vm.roster, 1, -1 do
                    copy[#copy + 1] = vm.roster[i]
                end
                vm.roster = copy
            end,
            onPingRef = function()
                if not view then return end
                ping_count = ping_count + 1
                local lbl = view.refs.imperativeLabel
                lbl:set_text("Ref Ping #" .. ping_count)
                if ping_count % 2 == 1 then
                    lbl:set_outline({ r = 56, g = 189, b = 248, a = 255 }, 2.0)
                else
                    lbl:set_outline(false)
                end
                play_sound("sfx_ui_click", 0.6)
            end,
            onToggleInert = function()
                if not view then return end
                inert_active = not inert_active
                view.refs.inertGroup:set_inert(inert_active)
                view.refs.imperativeLabel:set_text(inert_active and "Subtree INERT (visuals kept!)" or "Subtree ACTIVE")
            end,
            onOpenModal = function()
                vm.modalOpen = true
            end,
            onCloseModal = function()
                vm.modalOpen = false
            end,
            onSaveNote = function()
                local payload = {
                    note       = "Octarine UI Lab snapshot",
                    power      = vm.powerLevel,
                    difficulty = vm.difficulty,
                    pings      = ping_count,
                }
                local ok = storage.write_table("ui_lab_note.lua", payload)
                vm.storageOutput = ok
                    and string.format("Saved ui_lab_note.lua (power=%d%%, diff=%s, pings=%d)", vm.powerLevel, vm.difficulty, ping_count)
                    or "Failed to write ui_lab_note.lua"
            end,
            onReadNote = function()
                local tbl = storage.read_table("ui_lab_note.lua")
                if type(tbl) == "table" then
                    vm.storageOutput = string.format("Read back: '%s' | power=%s%% | diff=%s | pings=%s",
                        tostring(tbl.note), tostring(tbl.power), tostring(tbl.difficulty), tostring(tbl.pings))
                else
                    vm.storageOutput = "ui_lab_note.lua not found in save directory."
                end
            end,
            onDeleteNote = function()
                local ok = storage.remove("ui_lab_note.lua")
                vm.storageOutput = ok and "Deleted ui_lab_note.lua via storage.remove()." or "Nothing to delete."
            end,
        }

        -- Subtle animated grid behind the UI
        load_entity({
            components = {
                transform = { position = { x = 0, y = 0 } },
                color_grid = {
                    cell_size       = 40,
                    color1          = { r = 10, g = 15, b = 28, a = 255 },
                    color2          = { r = 14, g = 21, b = 39, a = 255 },
                    scroll_velocity = { x = -12, y = 10 },
                    layer           = 0,
                    is_fixed        = true,
                },
            },
        })

        view = ui.mount("ui/ui_lab.oxml", {
            context    = vm,
            controller = controller,
        })

        chrome.install({
            title      = "Declarative UI & Persistence Lab",
            show_guide = false,
            guide      = "Edit ui/ui_lab.oxml or ui/theme.oss while running --dev to watch hot-reload!\n"
                      .. "Press F2 to toggle UI wireframe bounding boxes (ui.debug_draw).",
        })
    end,
}
