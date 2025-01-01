local argparse = require('argparse')
local gui = require('gui')
local utils = require('utils')
local widgets = require('gui.widgets')

local CH_UP = string.char(30)
local CH_DN = string.char(31)
local ENGLISH_COL_WIDTH = 16
local NATIVE_COL_WIDTH = 16

--
-- target selection
--

local function select_new_target()
end

--
-- Rename
--

Rename = defclass(Rename, widgets.Window)
Rename.ATTRS {
    frame_title='Rename',
    frame={w=87, h=30},
    resizable=true,
    resize_min={w=77, h=30},
}

local function get_language_options()
    local options, max_width = {}, 5
    for idx, lang in ipairs(df.language_translation.get_vector()) do
        max_width = math.max(max_width, #lang.name)
        table.insert(options, {label=dfhack.capitalizeStringWords(dfhack.lowerCp437(lang.name)), value=idx, pen=COLOR_CYAN})
    end
    return options, max_width
end

local function pad_text(text, width)
    return (' '):rep((width - #text)//2) .. text
end

local function sort_by_english_desc(a, b)
end

local function sort_by_english_asc(a, b)
end

local function sort_by_native_desc(a, b)
end

local function sort_by_native_asc(a, b)
end

local function sort_by_part_of_speech_desc(a, b)
end

local function sort_by_part_of_speech_asc(a, b)
end

function Rename:init(info)
    self.target = info.target
    self.sync_targets = info.sync_targets or {}
    self.cache = {}

    local language_options, max_lang_name_width = get_language_options()

    self:addviews{
        widgets.Panel{frame={t=0, h=7}, -- header
            subviews={
                widgets.HotkeyLabel{
                    frame={t=0, l=0},
                    key='CUSTOM_CTRL_N',
                    label='Select new target',
                    on_activate=function()
                        local target, sync_targets = select_new_target()
                        if target then
                            self.target, self.sync_targets = target, sync_targets
                            self.subviews.language:setOption(self.target.language)
                        end
                    end,
                    visible=info.show_selector,
                },
                widgets.HotkeyLabel{
                    frame={t=0, r=0},
                    label='Generate random name',
                    key='CUSTOM_CTRL_G',
                    on_activate=function() end,
                    auto_width=true,
                },
                widgets.Label{
                    frame={t=2},
                    text={{pen=COLOR_YELLOW, text=function() return pad_text(dfhack.TranslateName(self.target), self.frame_body.width) end}},
                },
                widgets.Label{
                    frame={t=3},
                    text={{pen=COLOR_LIGHTCYAN, text=function() return pad_text(('"%s"'):format(dfhack.TranslateName(self.target, true)), self.frame_body.width) end}},
                },
                widgets.CycleHotkeyLabel{
                    view_id='language',
                    frame={t=5, l=0, w=max_lang_name_width + 18},
                    key='CUSTOM_CTRL_T',
                    label='Language:',
                    options=language_options,
                    initial_option=self.target and self.target.language or 0,
                    on_change=function(val)
                        self.target.language = val
                        for _, sync_target in ipairs(self.sync_targets) do
                            sync_target.language = val
                        end
                    end,
                },
                widgets.Label{
                    frame={t=6, l=7},
                    text={'Name type: ', {pen=COLOR_CYAN, text=function() return df.language_name_type[self.target.type] end}},
                },
            },
        },
        widgets.Panel{frame={t=8}, -- body
            subviews={
                widgets.Panel{frame={t=0, h=1}, -- toolbar
                    subviews={
                        widgets.CycleHotkeyLabel{
                            view_id='sort',
                            frame={t=0, l=0, w=32},
                            label='Sort by:',
                            key='CUSTOM_CTRL_O',
                            options={
                                {label='English'..CH_DN, value=sort_by_english_desc},
                                {label='English'..CH_UP, value=sort_by_english_asc},
                                {label='native'..CH_DN, value=sort_by_native_desc},
                                {label='native'..CH_UP, value=sort_by_native_asc},
                                {label='part of speech'..CH_DN, value=sort_by_part_of_speech_desc},
                                {label='part of speech'..CH_UP, value=sort_by_part_of_speech_asc},
                            },
                            initial_option=sort_by_english_desc,
                            on_change=self:callback('refresh_list', 'sort'),
                        },
                        widgets.EditField{
                            view_id='search',
                            frame={t=0, l=35},
                            label_text='Search: ',
                            ignore_keys={'SECONDSCROLL_DOWN', 'SECONDSCROLL_UP'}
                        },
                    },
                },
                widgets.Panel{frame={t=2, l=0, w=30}, -- component selector
                    subviews={
                        widgets.List{frame={t=0, l=0, b=2},
                            view_id='component_list',
                            on_select=function(idx, choice) print('component choice', idx) printall_recurse(choice) end,
                            choices=self:get_component_choices(),
                            row_height=2,
                            scroll_keys={
                                SECONDSCROLL_UP = -1,
                                SECONDSCROLL_DOWN = 1,
                            },
                        },
                        widgets.HotkeyLabel{
                            frame={b=1, l=0},
                            key='SECONDSCROLL_UP',
                            label='Prev component',
                            on_activate=function() self.subviews.component_list:moveCursor(-1) end,
                        },
                        widgets.HotkeyLabel{
                            frame={b=0, l=0},
                            key='SECONDSCROLL_DOWN',
                            label='Next component',
                            on_activate=function() self.subviews.component_list:moveCursor(1) end,
                        },
                    },
                },
                widgets.Panel{frame={t=2, l=30}, -- words table
                    subviews={
                        widgets.CycleHotkeyLabel{
                            view_id='sort_english',
                            frame={t=0, l=0, w=8},
                            options={
                                {label='English', value=DEFAULT_NIL},
                                {label='English'..CH_DN, value=sort_by_english_desc},
                                {label='English'..CH_UP, value=sort_by_english_asc},
                            },
                            initial_option=sort_by_english_desc,
                            option_gap=0,
                            on_change=self:callback('refresh_list', 'sort_english'),
                        },
                        widgets.CycleHotkeyLabel{
                            view_id='sort_native',
                            frame={t=0, l=ENGLISH_COL_WIDTH+2, w=7},
                            options={
                                {label='native', value=DEFAULT_NIL},
                                {label='native'..CH_DN, value=sort_by_native_desc},
                                {label='native'..CH_UP, value=sort_by_native_asc},
                            },
                            option_gap=0,
                            on_change=self:callback('refresh_list', 'sort_native'),
                        },
                        widgets.CycleHotkeyLabel{
                            view_id='sort_part_of_speech',
                            frame={t=0, l=ENGLISH_COL_WIDTH+2+NATIVE_COL_WIDTH+2, w=15},
                            options={
                                {label='part of speech', value=DEFAULT_NIL},
                                {label='part_of_speech'..CH_DN, value=sort_by_part_of_speech_desc},
                                {label='part_of_speech'..CH_UP, value=sort_by_part_of_speech_asc},
                            },
                            option_gap=0,
                            on_change=self:callback('refresh_list', 'sort_part_of_speech'),
                        },
                        widgets.FilteredList{
                            view_id='list',
                            frame={t=2, l=0, b=0, r=0},
                            on_submit=function() end,
                        },
                    },
                },
            },
        },
    }

    -- replace the FilteredList's built-in EditField with our own
    self.subviews.list.list.frame.t = 0
    self.subviews.list.edit.visible = false
    self.subviews.list.edit = self.subviews.search
    self.subviews.search.on_change = self.subviews.list:callback('onFilterChange')

    self:refresh_list()
end

function Rename:get_component_choices()
    local choices = {}
    for val, comp in ipairs(df.language_name_component) do
        local text = {
            {text=comp:gsub('(%l)(%u)', '%1 %2')}, NEWLINE
            {text=function()
                local word = self.target.words[val]
                if word < 0 then return end
                return ('word: %s'):format(df.global.world.raws.language.words[word].forms.Noun)
            end}
        }
        table.insert(choices, {text=text, data={val=val}})
    end
    return choices
end

function Rename:get_word_choices()
    --if self.cache[]
    local translations = df.language_translation.get_vector()
    local choices = {}
    for idx, word in ipairs(world.raws.language.words) do
        table.insert(choices, {
            text={
                {text=function() return word.forms.Noun end, width=ENGLISH_COL_WIDTH},
                {gap=2, text=function() return translations[self.subviews.language:getOptionValue()].words[idx].value end, width=NATIVE_COL_WIDTH},
                {text=df.language_part_of_speech[word.part_of_speech], width=15},
            },
            search_key=function() end,
        })
    end
    return choices
end

function Rename:refresh_list()
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
    local target = dfhack.units.getVisibleName(unit)
    local hf = df.historical_figure.find(unit.hist_figure_id)
    if hf then
        local hf_name = dfhack.units.getVisibleName(hf)
        if hf_name ~= target then
            table.insert(sync_targets, hf_name)
        end
    end
    return target
end

local function get_hf_target(hf, sync_targets)
    if not hf then return end
    local target = dfhack.units.getVisibleName(hf)
    local unit = df.unit.find(hf.unit_id)
    if unit then
        local unit_name = dfhack.units.getVisibleName(unit)
        if unit_name ~= target then
            table.insert(sync_targets, unit_name)
        end
    end
    return target
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
        target = get_hf_target(df.historical_figure.find(opts.histfig_id), sync_targets)
        if not target then qerror('Historical figure not found') end
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
