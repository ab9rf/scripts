-- Show tooltips on units and/or mouse

local RELOAD = false -- set to true when actively working on this script

local gui = require('gui')
local widgets = require('gui.widgets')
local ResizingPanel = require('gui.widgets.containers.resizing_panel')

--------------------------------------------------------------------------------

local follow_units = true;
local follow_mouse = true;
local function change_follow_units(new, old)
    follow_units = new
end
local function change_follow_mouse(new, old)
    follow_mouse = new
end

local shortenings = {
    ["Store item in stockpile"] = "Store item",
}

--------------------------------------------------------------------------------

local TITLE = "Tooltips"

if RELOAD then TooltipControlWindow = nil end
TooltipControlWindow = defclass(TooltipControlWindow, widgets.Window)
TooltipControlWindow.ATTRS {
    frame_title=TITLE,
    frame_inset=0,
    resizable=false,
    frame = {
        w = 25,
        h = 4,
        -- just under the minimap:
        r = 2,
        t = 18,
    },
}

function TooltipControlWindow:init()
    self:addviews{
        widgets.ToggleHotkeyLabel{
            view_id = 'btn_follow_units',
            frame={t=0, h=1},
            label="Follow units",
            key='CUSTOM_ALT_U',
            on_change=change_follow_units,
        },
        widgets.ToggleHotkeyLabel{
            view_id = 'btn_follow_mouse',
            frame={t=1, h=1},
            label="Follow mouse",
            key='CUSTOM_ALT_M',
            on_change=change_follow_mouse,
        },
    }
end

local function GetUnitHappiness(unit)
    -- keep in mind, this will look differently with game's font
    local mapToEmoticon = {[0] = "=C", ":C", ":(", ":]", ":)", ":D", "=D" }
    -- same as in ASCII mode, but for then middle (3), which is GREY instead of WHITE
    local mapToColor = {[0] = COLOR_RED, COLOR_LIGHTRED, COLOR_YELLOW, COLOR_GREY, COLOR_GREEN, COLOR_LIGHTGREEN, COLOR_LIGHTCYAN}
    local stressCat = dfhack.units.getStressCategory(unit)
    if stressCat > 6 then stressCat = 6 end
    return mapToEmoticon[stressCat], mapToColor[stressCat]
end

local function GetUnitJob(unit)
    local job = unit.job.current_job
    return job and dfhack.job.getName(job)
end

local function GetUnitNameAndJob(unit)
    local sb = {}
    sb[#sb+1] = dfhack.units.getReadableName(unit)
    local jobName = GetUnitJob(unit)
    if jobName then
        sb[#sb+1] = ": "
        sb[#sb+1] = jobName
    end
    return table.concat(sb)
end

local function GetTooltipText(x,y,z)
    local txt = {}
    local units = dfhack.units.getUnitsInBox(x,y,z,x,y,z) or {} -- todo: maybe (optionally) use filter parameter here?

    for _,unit in ipairs(units) do
        txt[#txt+1] = GetUnitNameAndJob(unit)
        txt[#txt+1] = NEWLINE
    end

    return txt
end

--------------------------------------------------------------------------------
-- MouseTooltip is an almost copy&paste of the DimensionsTooltip
--
if RELOAD then MouseTooltip = nil end
MouseTooltip = defclass(MouseTooltip, ResizingPanel)

MouseTooltip.ATTRS{
    frame_style=gui.FRAME_THIN,
    frame_background=gui.CLEAR_PEN,
    no_force_pause_badge=true,
    auto_width=true,
    display_offset={x=3, y=3},
}

function MouseTooltip:init()
    ensure_key(self, 'frame').w = 17
    self.frame.h = 4

    self.label = widgets.Label{
        frame={t=0},
        auto_width=true,
    }

    self:addviews{
        widgets.Panel{
            -- set minimum size for tooltip frame so the DFHack frame badge fits
            frame={t=0, l=0, w=7, h=2},
        },
        self.label,
    }
end

function MouseTooltip:render(dc)
    if not follow_mouse then return end

    local x, y = dfhack.screen.getMousePos()
    if not x then return end

    local pos = dfhack.gui.getMousePos()
    local text = GetTooltipText(pos2xyz(pos))
    if #text == 0 then return end
    self.label:setText(text)

    local sw, sh = dfhack.screen.getWindowSize()
    local frame_width = math.max(9, self.label:getTextWidth() + 2)
    self.frame.l = math.min(x + self.display_offset.x, sw - frame_width)
    self.frame.t = math.min(y + self.display_offset.y, sh - self.frame.h)
    self:updateLayout()
    MouseTooltip.super.render(self, dc)
end

--------------------------------------------------------------------------------

if RELOAD then TooltipsVizualizer = nil end
TooltipsVizualizer = defclass(TooltipsVizualizer, gui.ZScreen)
TooltipsVizualizer.ATTRS{
    focus_path='TooltipsVizualizer',
    pass_movement_keys=true,
}

function TooltipsVizualizer:init()
    local controls = TooltipControlWindow{view_id = 'controls'}
    local tooltip = MouseTooltip{view_id = 'tooltip'}
    self:addviews{controls, tooltip}
end

-- map coordinates -> interface layer coordinates
function GetScreenCoordinates(map_coord)
    if not map_coord then return end
    -- -> map viewport offset
    local vp = df.global.world.viewport
    local vp_Coord = vp.corner
    local map_offset_by_vp = {
        x = map_coord.x - vp_Coord.x,
        y = map_coord.y - vp_Coord.y,
        z = map_coord.z - vp_Coord.z,
    }

    if not dfhack.screen.inGraphicsMode() then
        return map_offset_by_vp
    else
        -- -> pixel offset
        local gps = df.global.gps
        local map_tile_pixels = gps.viewport_zoom_factor // 4;
        local screen_coord_px = {
            x = map_tile_pixels * map_offset_by_vp.x,
            y = map_tile_pixels * map_offset_by_vp.y,
        }
        -- -> interface layer coordinates
        local screen_coord_text = {
            x = math.ceil( screen_coord_px.x / gps.tile_pixel_x ),
            y = math.ceil( screen_coord_px.y / gps.tile_pixel_y ),
        }

        return screen_coord_text
    end
end

function TooltipsVizualizer:onRenderFrame(dc, rect)
    TooltipsVizualizer.super.onRenderFrame(self, dc, rect)

    if not follow_units then return end

    if not dfhack.screen.inGraphicsMode() and not gui.blink_visible(500) then
        return
    end

    local vp = df.global.world.viewport
    local topleft = vp.corner
    local width = vp.max_x
    local height = vp.max_y
    local bottomright = {x = topleft.x + width, y = topleft.y + height, z = topleft.z}

    local units = dfhack.units.getUnitsInBox(topleft.x,topleft.y,topleft.z,bottomright.x,bottomright.y,bottomright.z) or {}
    if #units == 0 then return end

    local oneTileOffset = GetScreenCoordinates({x = topleft.x + 1, y = topleft.y + 1, z = topleft.z + 0})
    local pen = COLOR_WHITE

    local used_tiles = {}
    for i = #units, 1, -1 do
        local unit = units[i]

        local happiness, happyPen = GetUnitHappiness(unit)
        local job = GetUnitJob(unit)
        job = shortenings[job] or job
        if not job and not happiness then goto continue end

        local pos = xyz2pos(dfhack.units.getPosition(unit))
        if not pos then goto continue end

        local txt = table.concat({happiness, job}, " ")

        local scrPos = GetScreenCoordinates(pos)
        local y = scrPos.y - 1 -- subtract 1 to move the text over the heads
        local x = scrPos.x + oneTileOffset.x - 1 -- subtract 1 to move the text inside the map tile

        -- to resolve overlaps, we'll mark every coordinate we write anything in,
        -- and then check if the new tooltip will overwrite any used coordinate.
        -- if it will, try the next row, to a maximum offset of 4.
        local row
        local dy = 0
        -- todo: search for the "best" offset instead, f.e. max `usedAt` value, with `-1` the best
        local usedAt = -1
        for yOffset = 0, 4 do
            dy = yOffset

            row = used_tiles[y + dy]
            if not row then
                row = {}
                used_tiles[y + dy] = row
            end

            usedAt = -1
            for j = 0, #txt - 1 do
                if row[x + j] then
                    usedAt = j
                    break
                end
            end

            if usedAt == -1 then break end
        end -- for dy

        -- in case there isn't enough space, cut the text off
        if usedAt > 0 then
            local s = happiness and #happiness + 1 or 0
            job = job:sub(0, usedAt - s - 1) .. '_'
            txt = txt:sub(0, usedAt - 1) .. '_' -- for marking
        end

        dc:seek(x, y + dy)
            :pen(happyPen):string(happiness or "")
            :string((happiness and job) and " " or "")
            :pen(pen):string(job or "")

        -- mark coordinates as used
        for j = 0, #txt - 1 do
            row[x + j] = true
        end

        ::continue::
    end
end

function TooltipsVizualizer:onDismiss()
    view = nil
end

----------------------------------------------------------------

if not dfhack.isMapLoaded() then
    qerror('gui/tooltips requires a map to be loaded')
end

if RELOAD and view then
    view:dismiss()
    -- view is nil now
end

view = view and view:raise() or TooltipsVizualizer{}:show()
