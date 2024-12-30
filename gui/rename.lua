local argparse = require('argparse')
local gui = require('gui')
local utils = require('utils')
local widgets = require('gui.widgets')

--
-- Rename
--

Rename = defclass(Rename, widgets.Window)
Rename.ATTRS {
    frame_title='Rename',
    frame={w=87, h=30},
    resizable=true,
    resize_mid={w=50, h=20},
}

function Rename:init(info)
    self.target = info.target
    self.sync_targets = info.sync_targets or {}

    self:addviews{
        widgets.Label{
            text={
                self.target and dfhack.TranslateName(self.target) or 'No target', NEWLINE,
                self.target and dfhack.TranslateName(self.target, true),
            },
            auto_width=true,
        },
    }
end

--
-- RenameScreen
--

RenameScreen = defclass(RenameScreen, gui.ZScreen)
RenameScreen.ATTRS {
    focus_path='rename',
}

function RenameScreen:init(info)
    self:addviews{
        Rename{
            target=info.target,
            sync_targets=info.sync_targets,
            show_selector=info.show_selector,
        }
    }
end

function RenameScreen:onDismiss()
    view = nil
end

--
-- CLI
--

if not dfhack.isWorldLoaded() then
    qerror('This script requires a world to be loaded')
end

local function get_artifact_target(item)
    if not item or not item.flags.artifact then return end
    local gref = dfhack.items.getGeneralRef(item, df.general_ref_type.IS_ARTIFACT)
    if not gref then return end
    local rec = df.artifact_record.find(gref.artifact_id)
    if not rec then return end
    return rec.name
end

local function get_unit_target(unit, sync_targets)
    if not unit then return end
    local hf = df.historical_figure.find(unit.hist_figure_id)
    if hf then table.insert(sync_targets, hf.name) end
    return unit.name
end

local function get_location_target(site, loc_id)
    if not site or loc_id < 0 then return end
    local loc = utils.binsearch(site.buildings, loc_id, 'id')
    if not loc then return end
    return loc.name
end

local function get_target(opts)
    local target, sync_targets = nil, {}
    if opts.histfig_id then
        local hf = df.historical_figure.find(opts.histfig_id)
        if not hf then qerror('Historical figure not found') end
        target = hf.name
        local unit = df.unit.find(hf.unit_id)
        if unit then table.insert(sync_targets, unit.name) end
    elseif opts.item_id then
        target = get_artifact_target(df.item.find(opts.item_id))
        if not target then qerror('Artifact not found') end
    elseif opts.location_id then
        local site = opts.site_id and df.world_site.find(opts.site_id) or dfhack.world.getCurrentSite()
        if not site then qerror('Site not found') end
        target = get_location_target(site, opts.location_id)
        if not target then qerror('Location not found') end
    elseif opts.site_id then
        local site = df.world_site.find(opts.site_id)
        if not site then qerror('Site not found') end
        target = site.name
    elseif opts.squad_id then
        local squad = df.squad.find(opts.squad_id)
        if not squad then qerror('Squad not found') end
        target = squad.name
    elseif opts.unit_id then
        target = get_unit_target(df.unit.find(opts.unit_id), sync_targets)
        if not target then qerror('Unit not found') end
    elseif opts.world then
        target = df.global.world.world_data.name
    end
    return target, sync_targets
end

local opts = {
    help=false,
    entity_id=nil,
    histfig_id=nil,
    item_id=nil,
    location_id=nil,
    site_id=nil,
    squad_id=nil,
    unit_id=nil,
    world=false,
    show_selector=true,
}
local positionals = argparse.processArgsGetopt({...}, {
    { 'a', 'artifact', handler=function(optarg) opts.item_id = argparse.nonnegativeInt(optarg, 'artifact') end },
    { 'e', 'entity', handler=function(optarg) opts.entity_id = argparse.nonnegativeInt(optarg, 'entity') end },
    { 'f', 'histfig', handler=function(optarg) opts.histfig_id = argparse.nonnegativeInt(optarg, 'histfig') end },
    { 'h', 'help', handler = function() opts.help = true end },
    { 'l', 'location', handler=function(optarg) opts.location_id = argparse.nonnegativeInt(optarg, 'location') end },
    { 'q', 'squad', handler=function(optarg) opts.squad_id = argparse.nonnegativeInt(optarg, 'squad') end },
    { 's', 'site', handler=function(optarg) opts.site_id = argparse.nonnegativeInt(optarg, 'site') end },
    { 'u', 'unit', handler=function(optarg) opts.unit_id = argparse.nonnegativeInt(optarg, 'unit') end },
    { 'w', 'world', handler=function() opts.world = true end },
    { '', 'no-target-selector', handler=function() opts.show_selector = false end },
})

if opts.help or positionals[1] == 'help' then
    print(dfhack.script_help())
    return
end

local target, sync_targets = get_target(opts)

if not target then
    local unit = dfhack.gui.getSelectedUnit(true)
    local item = dfhack.gui.getSelectedItem(true)
    local zone = dfhack.gui.getSelectedCivZone(true)
    if unit then
        target = get_unit_target(unit, sync_targets)
    elseif item then
        target = get_artifact_target(item)
    elseif zone then
        target = get_location_target(df.world_site.find(zone.site_id), zone.location_id)
    end
end

view = view and view:raise() or RenameScreen{
    target=target,
    sync_targets=sync_targets,
    show_selector=opts.show_selector
}:show()
