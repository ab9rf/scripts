--@ module = true

local overlay = require('plugins.overlay')

RightClickWidget = defclass(RightClickWidget, overlay.OverlayWidget)
RightClickWidget.ATTRS{
    desc='When painting a rectangle, makes right click cancel selection instead of exiting.',
    default_enabled=true,
    viewscreens={
        'dwarfmode/Building/Placement',
        'dwarfmode/Designate',
        'dwarfmode/Stockpile/Paint',
        'dwarfmode/Zone/Paint',
        'dwarfmode/Burrow/Paint'
        },
}

local selection_rect = df.global.selection_rect
local buildreq = df.global.buildreq

function RightClickWidget:onInput(keys)
    if keys._MOUSE_R or keys.LEAVESCREEN then
        -- building mode, do not run if buildingplan.planner is enabled since it already provides this functionality
        if buildreq.selection_pos.x >= 0 and not overlay.get_state().config['buildingplan.planner'].enabled then
            buildreq.selection_pos:clear()
            return true
        -- all other modes
        elseif selection_rect.start_x >= 0 then
            selection_rect.start_x = -30000
            selection_rect.start_y = -30000
            selection_rect.start_z = -30000
            return true
        end
    end
end

OVERLAY_WIDGETS = {selection=RightClickWidget}