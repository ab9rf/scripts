--@ module = true

local gui = require('gui')
local overlay = require('plugins.overlay')
local widgets = require('gui.widgets')

local toolbar_textures = (dfhack.textures.loadTileset('hack/data/art/mass_remove_toolbar.png', 8,12))

local BASELINE_OFFSET = 42

local function get_l_offset(parent_rect)
    local w = parent_rect.width
    return BASELINE_OFFSET + (w+1)//2 - 34
end

function launch_mass_remove()
    dfhack.run_command('gui/mass-remove')
end


-- --------------------------------
-- MassRemoveToolbarOverlay
--

MassRemoveToolbarOverlay = defclass(MassRemoveToolbarOverlay, overlay.OverlayWidget)
MassRemoveToolbarOverlay.ATTRS{
    desc='Adds widgets to the erase interface to open the mass removal tool',
    default_pos={x=BASELINE_OFFSET, y=-4},
    default_enabled=true,
    viewscreens={
        'dwarfmode/Designate/ERASE'
    },
    frame={w=26, h=11},
}

function MassRemoveToolbarOverlay:init()
    local button_chars = {
        {218, 196, 196, 191},
        {179, 'M', 'R', 179},
        {192, 196, 196, 217},
    }

    self:addviews{
        widgets.Panel{
            frame={t=0, r=0, w=26, h=7},
            frame_style=gui.FRAME_PANEL,
            frame_background=gui.CLEAR_PEN,
            frame_inset={l=1, r=1},
            visible=function() return not not self.subviews.icon:getMousePos() end,
            subviews={
                widgets.Label{
                    text={
                        'Open mass removal\ninterface.\n',
                        NEWLINE,
                        {text='Hotkey: ', pen=COLOR_GRAY}, {key='CUSTOM_CTRL_M'},
                    },
                },
            },
        },
        widgets.Panel{
            view_id='icon',
            frame={b=0, r=22, w=4, h=3},
            subviews={
                widgets.Label{
                    text=widgets.makeButtonLabelText{
                        chars=button_chars,
                        pens=COLOR_GRAY,
                        tileset=toolbar_textures,
                        tileset_offset=1,
                        tileset_stride=8,
                    },
                    on_click=launch_mass_remove,
                    visible=function () return not self.subviews.icon:getMousePos() end,
                },
                widgets.Label{
                    text=widgets.makeButtonLabelText{
                        chars=button_chars,
                        pens={
                            {COLOR_WHITE, COLOR_WHITE, COLOR_WHITE, COLOR_WHITE},
                            {COLOR_WHITE, COLOR_GRAY,  COLOR_GRAY,  COLOR_WHITE},
                            {COLOR_WHITE, COLOR_WHITE, COLOR_WHITE, COLOR_WHITE},
                        },
                        tileset=toolbar_textures,
                        tileset_offset=5,
                        tileset_stride=8,
                    },
                    on_click=launch_mass_remove,
                    visible=function() return not not self.subviews.icon:getMousePos() end,
                },
            },
        },
    }
end

function MassRemoveToolbarOverlay:preUpdateLayout(parent_rect)
    self.frame.w = get_l_offset(parent_rect) - BASELINE_OFFSET + 18
end

function MassRemoveToolbarOverlay:onInput(keys)
    if keys.CUSTOM_CTRL_M then
        launch_mass_remove()
        return true
    end
    return MassRemoveToolbarOverlay.super.onInput(self, keys)
end

OVERLAY_WIDGETS = {massremovetoolbar=MassRemoveToolbarOverlay}

if dfhack_flags.module then
    return
end
