local gui = require('gui')
local spectate = require('plugins.spectate')
local widgets = require('gui.widgets')

--------------------------------------------------------------------------------
--- ToggleLabel

-- pens are the same as gui/control-panel.lua
local textures = require('gui.textures')
local function get_icon_pens()
    local enabled_pen_left = dfhack.pen.parse{fg=COLOR_CYAN,
            tile=curry(textures.tp_control_panel, 1), ch=string.byte('[')}
    local enabled_pen_center = dfhack.pen.parse{fg=COLOR_LIGHTGREEN,
            tile=curry(textures.tp_control_panel, 2) or nil, ch=251} -- check
    local enabled_pen_right = dfhack.pen.parse{fg=COLOR_CYAN,
            tile=curry(textures.tp_control_panel, 3) or nil, ch=string.byte(']')}
    local disabled_pen_left = dfhack.pen.parse{fg=COLOR_CYAN,
            tile=curry(textures.tp_control_panel, 4) or nil, ch=string.byte('[')}
    local disabled_pen_center = dfhack.pen.parse{fg=COLOR_RED,
            tile=curry(textures.tp_control_panel, 5) or nil, ch=string.byte('x')}
    local disabled_pen_right = dfhack.pen.parse{fg=COLOR_CYAN,
            tile=curry(textures.tp_control_panel, 6) or nil, ch=string.byte(']')}
    local button_pen_left = dfhack.pen.parse{fg=COLOR_CYAN,
            tile=curry(textures.tp_control_panel, 7) or nil, ch=string.byte('[')}
    local button_pen_right = dfhack.pen.parse{fg=COLOR_CYAN,
            tile=curry(textures.tp_control_panel, 8) or nil, ch=string.byte(']')}
    local help_pen_center = dfhack.pen.parse{
            tile=curry(textures.tp_control_panel, 9) or nil, ch=string.byte('?')}
    local configure_pen_center = dfhack.pen.parse{
            tile=curry(textures.tp_control_panel, 10) or nil, ch=15} -- gear/masterwork symbol
    return enabled_pen_left, enabled_pen_center, enabled_pen_right,
            disabled_pen_left, disabled_pen_center, disabled_pen_right,
            button_pen_left, button_pen_right,
            help_pen_center, configure_pen_center
end
local ENABLED_PEN_LEFT, ENABLED_PEN_CENTER, ENABLED_PEN_RIGHT,
      DISABLED_PEN_LEFT, DISABLED_PEN_CENTER, DISABLED_PEN_RIGHT,
      BUTTON_PEN_LEFT, BUTTON_PEN_RIGHT,
      HELP_PEN_CENTER, CONFIGURE_PEN_CENTER = get_icon_pens()

ToggleLabel = defclass(ToggleLabel, widgets.CycleHotkeyLabel)
ToggleLabel.ATTRS{
    options={{value=true},
             {value=false}},
}
function ToggleLabel:init()
    ToggleLabel.super.init(self)

    local text = self.text
    -- the very last token is the On/Off text -- we'll repurpose it as an indicator
    text[#text] =     { tile = function() return self:getOptionValue() and ENABLED_PEN_LEFT or DISABLED_PEN_LEFT end }
    text[#text + 1] = { tile = function() return self:getOptionValue() and ENABLED_PEN_CENTER or DISABLED_PEN_CENTER end }
    text[#text + 1] = { tile = function() return self:getOptionValue() and ENABLED_PEN_RIGHT or DISABLED_PEN_RIGHT end }
    self:setText(text)
end

--------------------------------------------------------------------------------
--- Spectate config window
Spectate = defclass(Spectate, widgets.Window)
Spectate.ATTRS {
    frame_title='Spectate',
    frame={l=3, t=5, w=35, h=30},
    resizable=true,
    resize_min={w=35, h=30},
}

local function append(t, args)
    for i = 1, #args do
        t[#t + 1] = args[i]
    end
    return t
end

local function create_toggle_button(cfg, cfg_key, left, top, hotkey, label)
    return ToggleLabel{
        frame={t=top,l=left},
        initial_option = cfg[cfg_key],
        on_change = function(new, old) cfg[cfg_key] = new; spectate.save_state() end,
        key = hotkey,
        label = label,
    }
end

local function create_numeric_edit_field(cfg, cfg_key, left, top, hotkey, label)
    local editOnSubmit
    local ef = widgets.EditField{
        frame={t=top,l=left},
        label_text = label,
        text = tostring(cfg[cfg_key]),
        modal = true,
        key = hotkey,
        on_char = function(new_char,text) return '0' <= new_char and new_char <= '9' end,
        on_submit = function(text) editOnSubmit(text) end,
    }
    editOnSubmit = function(text)
        if text == '' then
            ef:setText(tostring(cfg[cfg_key]))
        else
            cfg[cfg_key] = tonumber(text)
            spectate.save_state()
        end
    end

    return ef
end

local function create_toggle_buttons(cfgFollow, keyFollow, cfgHover, keyHover, colFollow, colHover, top)
    local tlFollow = create_toggle_button(cfgFollow, keyFollow, colFollow + 2, top)
    local tlHover = create_toggle_button(cfgHover, keyHover, colHover + 1, top)

    return tlFollow, tlHover
end

local function create_row(label, hotkey, suffix, colFollow, colHover, top)
    local config = spectate.config

    suffix = suffix or ''
    if suffix ~= '' then suffix = '-'..suffix end

    local keyFollow = 'tooltip-follow'..suffix
    local keyHover = 'tooltip-hover'..suffix

    local tlFollow, tlHover = create_toggle_buttons(config, keyFollow, config, keyHover, colFollow, colHover, top)
    local views = {
        widgets.HotkeyLabel{
            frame={t=top,l=0,w=1},
            key = 'CUSTOM_' .. hotkey,
            key_sep = '',
            on_activate = function() tlFollow:cycle() end,
        },
        widgets.HotkeyLabel{
            frame={t=top,l=1,w=1},
            key = 'CUSTOM_SHIFT_' .. hotkey,
            key_sep = '',
            on_activate = function() tlHover:cycle() end,
        },
        widgets.Label{
            frame={t=top,l=2},
            text = ': ' .. label,
        },
        tlFollow,
        tlHover,
    }

    return views
end

local function make_choice(text, tlFollow, tlHover)
    return {
        text=text,
        data={tlFollow=tlFollow, tlHover=tlHover},
    }
end

local function pairsByKeys(t, f)
    local a = {}
    for n in pairs(t) do table.insert(a, n) end
    table.sort(a, f)
    local i = 0      -- iterator variable
    local iter = function ()   -- iterator function
        i = i + 1
        if a[i] == nil then return nil
        else return a[i], t[a[i]]
        end
    end
    return iter
end

local function rpad(s, i)
    return string.format("%-"..i.."s", s)
end

local overlay = require('plugins.overlay')
local OVERLAY_NAME = 'spectate.tooltip'
local function isOverlayEnabled()
    return overlay.get_state().config[OVERLAY_NAME].enabled
end

local function enable_overlay(enabled)
    local tokens = {'overlay'}
    table.insert(tokens, enabled and 'enable' or 'disable')
    table.insert(tokens, OVERLAY_NAME)
    dfhack.run_command(tokens)
end

function Spectate:updateOverlayDisabledGag(widget)
    local w = widget or self.subviews.overlayIsDisabledGag

    if isOverlayEnabled() then
        if w.frame.t < 500 then
            w.frame.t = w.frame.t + 500
        end
    else
        if w.frame.t > 500 then
            w.frame.t = w.frame.t - 500
        end
    end

    if not widget then
        self:updateLayout()
    end
end

function Spectate:init()
    local config = spectate.config

    local views = {}
    local t = 0

    local len = 20
    append(views, {create_toggle_button(config, 'auto-disengage', 0, t, 'CUSTOM_ALT_D', rpad("Auto disengage", len))}); t = t + 1
    append(views, {create_toggle_button(config, 'auto-unpause', 0, t, 'CUSTOM_ALT_U', rpad("Auto unpause", len))}); t = t + 1
    append(views, {create_toggle_button(config, 'cinematic-action', 0, t, 'CUSTOM_ALT_C', rpad("Cinematic action", len))}); t = t + 1
    append(views, {create_numeric_edit_field(config, 'follow-seconds', 0, t, 'CUSTOM_ALT_F', "Follow (s): ")}); t = t + 1
    append(views, {create_toggle_button(config, 'include-animals', 0, t, 'CUSTOM_ALT_A', rpad("Include animals", len))}); t = t + 1
    append(views, {create_toggle_button(config, 'include-hostiles', 0, t, 'CUSTOM_ALT_H', rpad("Include hostiles", len))}); t = t + 1
    append(views, {create_toggle_button(config, 'include-visitors', 0, t, 'CUSTOM_ALT_V', rpad("Include visitors", len))}); t = t + 1
    append(views, {create_toggle_button(config, 'include-wildlife', 0, t, 'CUSTOM_ALT_W', rpad("Include wildlife", len))}); t = t + 1
    append(views, {create_toggle_button(config, 'prefer-conflict', 0, t, 'CUSTOM_ALT_B', rpad("Prefer conflict", len))}); t = t + 1
    append(views, {create_toggle_button(config, 'prefer-new-arrivals', 0, t, 'CUSTOM_ALT_N', rpad("Prefer new arrivals", len))}); t = t + 1

    t = t + 1 -- add a blank line
    local colFollow, colHover = 15, 25
    -- tooltips headers
    append(views, {
        widgets.Label{
            frame={t=t,l=0},
            text="Tooltips:"
        },
    })
    -- t = t + 1
    -- overlay is prerequisite for any other tooltip option
    local overlayIsDisabledGag = nil
    local lblOverlayOnChange = function(new, old)
        enable_overlay(new)
        self:updateOverlayDisabledGag()
    end
    append(views, {
        ToggleLabel{
            frame={t=t,l=12},
            initial_option = isOverlayEnabled(),
            on_change = lblOverlayOnChange,
            key = 'CUSTOM_ALT_O',
            label = "Overlay ",
        }
    })
    t = t + 1
    overlayIsDisabledGag = widgets.Panel{
        view_id='overlayIsDisabledGag',
        frame={t=t,l=0,r=0,b=1}, -- b=1 because the very last row is where the HelpButton is placed
        frame_background=gui.CLEAR_PEN,
        subviews = {
            widgets.WrappedLabel{
                frame={t=0,l=0,r=0,b=0},
                frame_background=gui.CLEAR_PEN,
                text_to_wrap="Overlay has to be enabled for tooltips.",
            }
        },
    }

    append(views, {
        widgets.Label{
            frame={t=t,l=colFollow},
            text="Follow"
        },
        widgets.Label{
            frame={t=t,l=colHover},
            text="Hover"
        },
    })
    t = t + 1

    -- enable/disable
    append(views, create_row("Enable", 'E', '', colFollow, colHover, t)); t = t + 1
    append(views, create_row("Job", 'J', 'job', colFollow, colHover, t)); t = t + 1
    append(views, create_row("Name", 'N', 'name', colFollow, colHover, t)); t = t + 1
    append(views, create_row("Stress", 'S', 'stress', colFollow, colHover, t)); t = t + 1

    -- next are individual stress levels
    -- a list on the left to select one, individual buttons in two columns to be able to click on them
    local choices = {}
    local levels = config['tooltip-stress-levels']
    local stressFollow = config['tooltip-follow-stress-levels']
    local stressHover = config['tooltip-hover-stress-levels']
    local tList = t
    for l, cfg in pairsByKeys(levels) do
        local tlFollow, tlHover = create_toggle_buttons(stressFollow, l, stressHover, l, colFollow, colHover, t)
        append(views, { tlFollow, tlHover })

        table.insert(choices, make_choice({{text=cfg.text, pen=cfg.pen}, ' ', cfg.name}, tlFollow, tlHover))

        t = t + 1
    end
    append(views,{
        widgets.List{
            frame={t=tList,l=2},
            view_id='list_levels',
            on_submit=function(index, choice) choice.data.tlFollow:cycle() end,
            on_submit2=function(index, choice) choice.data.tlHover:cycle() end,
            row_height=1,
            choices = choices,
        },
    })

    append(views, {create_numeric_edit_field(config, 'tooltip-follow-blink-milliseconds', 0, t, 'CUSTOM_B', "Blink duration (ms): ")}); t = t + 1

    append(views, {
        widgets.HelpButton{
            frame={b=0,r=0},
            command = 'spectate',
        }
    })

    append(views, {overlayIsDisabledGag}) -- must be the very last thing
    self:updateOverlayDisabledGag(overlayIsDisabledGag)

    self:addviews(views)
end

SpectateScreen = defclass(SpectateScreen, gui.ZScreen)
SpectateScreen.ATTRS {
    focus_path='spectate',
}

function SpectateScreen:init()
    self:addviews{Spectate{}}
end

function SpectateScreen:onDismiss()
    view = nil
end

view = view and view:raise() or SpectateScreen{}:show()
