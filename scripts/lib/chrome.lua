-- scripts/lib/chrome.lua
-- Shared scene navigation bar, toggleable guide panel, shortcuts (Esc/F2/F5), and dev tools hookup.

local M = {}

function M.install(opts)
    opts = opts or {}
    local title       = opts.title or "Showcase Scene"
    local guide_body  = opts.guide or ""
    local show_guide  = settings.get("show_hints", true)
    if opts.show_guide ~= nil then
        show_guide = opts.show_guide
    end

    local native_label = (native_showcase ~= nil and native_showcase.is_enabled())
        and "Native C++: ON"
        or "Native C++: Lua Mode"

    local vm = ui.observable({
        sceneTitle  = title,
        guideText   = guide_body,
        showGuide   = show_guide,
        guideBtnLbl = show_guide and "Hide Guide" or "Show Guide",
        nativeBadge = native_label,
        perfText    = "Entities: 0 | 60 FPS",
        wireframes  = settings.get("ui_wireframes", false),
    })

    ui.debug_draw(vm.wireframes)

    local controller = {
        onHub = function()
            load_scene("scripts/scenes/hub.lua")
        end,
        onReset = function()
            reload_scene()
        end,
        onToggleGuide = function()
            vm.showGuide = not vm.showGuide
            vm.guideBtnLbl = vm.showGuide and "Hide Guide" or "Show Guide"
            settings.set("show_hints", vm.showGuide)
            settings.save()
        end,
        onToggleWireframes = function()
            vm.wireframes = ui.debug_draw()
            settings.set("ui_wireframes", vm.wireframes)
            settings.save()
        end,
    }

    local view = nil
    if not opts.skip_mount then
        view = ui.mount("ui/demo_chrome.oxml", {
            context    = vm,
            controller = controller,
        })
    end

    -- Periodic HUD telemetry ticker entity (zero-allocation update every 0.25s)
    load_entity({
        name = "ChromeTelemetry",
        components = {
            script = {
                accum = 0.0,
                on_update = function(self, entity, dt)
                    self.accum = self.accum + dt
                    if self.accum >= 0.25 then
                        self.accum = 0.0
                        vm.perfText = string.format("Entities: %d | %.0f FPS", get_entity_count(), get_fps())
                    end
                end,
            },
        },
    })

    -- Global scene shortcuts (cleared automatically on scene transitions, so re-installed here)
    if not opts.skip_key_hooks then
        input.on_key_down(function(key)
            if key == "escape" then
                load_scene("scripts/scenes/hub.lua")
            elseif key == "f5" then
                reload_scene()
            elseif key == "f2" then
                controller.onToggleWireframes()
            elseif key == "f1" and toggle_debug_gui ~= nil then
                toggle_debug_gui()
            end
        end)
    end

    if showcase_dev then
        showcase_dev.install({ on_dev_spawn = opts.on_dev_spawn })
    end

    return {
        vm         = vm,
        view       = view,
        controller = controller,
    }
end

return M
