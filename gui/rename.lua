--@module = true

local argparse = require('argparse')
local dlg = require('gui.dialogs')
local gui = require('gui')
local sitemap = reqscript('gui/sitemap')
local utils = require('utils')
local widgets = require('gui.widgets')

local CH_UP = string.char(30)
local CH_DN = string.char(31)
local ENGLISH_COL_WIDTH = 16
local NATIVE_COL_WIDTH = 16

local language = df.global.world.raws.language
local translations = df.language_translation.get_vector()

--
-- target selection
--

local function get_artifact_target(item)
    if not item or not item.flags.artifact then return end
    local gref = dfhack.items.getGeneralRef(item, df.general_ref_type.IS_ARTIFACT)
    if not gref then return end
    local rec = df.artifact_record.find(gref.artifact_id)
    if not rec then return end
    return rec.name
end

local function get_hf_target(hf)
    if not hf then return end
    local target = dfhack.units.getVisibleName(hf)
    local unit = df.unit.find(hf.unit_id)
    local sync_targets = {}
    if unit then
        local unit_name = dfhack.units.getVisibleName(unit)
        if unit_name ~= target then
            table.insert(sync_targets, unit_name)
        end
    end
    return target, sync_targets
end

local function get_unit_target(unit)
    if not unit then return end
    local hf = df.historical_figure.find(unit.hist_figure_id)
    if hf then
        return get_hf_target(hf)
    end
    -- unit with no hf
    return dfhack.units.getVisibleName(unit), {}
end

local function get_location_target(site, loc_id)
    if not site or loc_id < 0 then return end
    local loc = utils.binsearch(site.buildings, loc_id, 'id')
    if not loc then return end
    return loc.name
end

local function select_artifact(cb)
    local choices = {}
    for _, item in ipairs(df.global.world.items.other.ANY_ARTIFACT) do
        if item.flags.garbage_collect then goto continue end
        local target = get_artifact_target(item)
        if not target then goto continue end
        table.insert(choices, {
            text=dfhack.items.getReadableDescription(item),
            data={target=target},
        })
        ::continue::
    end
    dlg.showListPrompt('Rename', 'Select an artifact to rename:', COLOR_WHITE,
        choices, function(_, choice) cb(choice.data.target) end, nil, nil, true)
end

local function select_location(site, cb)
    local choices = {}
    for _,loc in ipairs(site.buildings) do
        local desc, pen = sitemap.get_location_desc(loc)
        table.insert(choices, {
            text={
                dfhack.TranslateName(loc.name, true),
                ' (',
                {text=desc, pen=pen},
                ')',
            },
            data={target=loc.name},
        })
    end
    dlg.showListPrompt('Rename', 'Select a location to rename:', COLOR_WHITE,
        choices, function(_, choice) cb(choice.data.target) end, nil, nil, true)
end

local function select_site(site, cb)
    cb(site.name)
end

local function select_squad(fort, cb)
    local choices = {}
    for _,squad_id in ipairs(fort.squads) do
        local squad = df.squad.find(squad_id)
        if squad then
            table.insert(choices, {
                text=dfhack.military.getSquadName(squad.id),
                data={target=squad.name},
            })
        end
    end
    dlg.showListPrompt('Rename', 'Select a squad to rename:', COLOR_WHITE,
        choices, function(_, choice) cb(choice.data.target) end, nil, nil, true)
end

local function select_unit(cb)
    local choices = {}
    for _,unit in ipairs(df.global.world.units.active) do
        local target, sync_targets = get_unit_target(unit)
        if target then
            table.insert(choices, {
                text=dfhack.units.getReadableName(unit),
                data={target=target, sync_targets=sync_targets},
            })
        end
    end
    dlg.showListPrompt('Rename', 'Select a unit to rename:', COLOR_WHITE,
        choices, function(_, choice) cb(choice.data.target, choice.data.sync_targets) end,
        nil, nil, true)
end

local function select_world(cb)
    cb(df.global.world.world_data.name)
end

local function select_new_target(cb)
    local choices = {}
    if #df.global.world.items.other.ANY_ARTIFACT > 0 then
        table.insert(choices, {text='An artifact', data={fn=select_artifact}})
    end
    local site = dfhack.world.getCurrentSite()
    if site then
        if #site.buildings > 0 then
            table.insert(choices, {text='A location', data={fn=curry(select_location, site)}})
        end
        table.insert(choices, {text='This fortress', data={fn=curry(select_site, site)}})
        local fort = df.historical_entity.find(df.global.plotinfo.group_id)
        if fort and #fort.squads > 0 then
            table.insert(choices, {text='A squad', data={fn=curry(select_squad, fort)}})
        end
    end
    if #df.global.world.units.active > 0 then
        table.insert(choices, {text='A unit', data={fn=select_unit}})
    end
    table.insert(choices, {text='This world', data={fn=select_world}})
    dlg.showListPrompt('Rename', 'What would you like to rename?', COLOR_WHITE,
        choices, function(_, choice) choice.data.fn(cb) end)
end

--
-- Rename
--

Rename = defclass(Rename, widgets.Window)
Rename.ATTRS {
    frame_title='Rename',
    frame={w=89, h=43},
    resizable=true,
    resize_min={w=61},
}

local function get_language_options()
    local options, max_width = {}, 5
    for idx, lang in ipairs(translations) do
        max_width = math.max(max_width, #lang.name)
        table.insert(options, {label=dfhack.capitalizeStringWords(dfhack.lowerCp437(lang.name)), value=idx, pen=COLOR_CYAN})
    end
    return options, max_width
end

local function pad_text(text, width)
    return (' '):rep((width - #text)//2) .. text
end

local function sort_by_english_desc(a, b)
    if a.data.english ~= b.data.english then
        return a.data.english < b.data.english
    end
    local a_native, b_native = a.data.native_fn(), b.data.native_fn()
    if a_native ~= b_native then
        return a_native < b_native
    end
    return a.data.part_of_speech < b.data.part_of_speech
end

local function sort_by_english_asc(a, b)
    if a.data.english ~= b.data.english then
        return a.data.english > b.data.english
    end
    local a_native, b_native = a.data.native_fn(), b.data.native_fn()
    if a_native ~= b_native then
        return a_native < b_native
    end
    return a.data.part_of_speech < b.data.part_of_speech
end

local function sort_by_native_desc(a, b)
    local a_native, b_native = a.data.native_fn(), b.data.native_fn()
    if a_native ~= b_native then
        return a_native < b_native
    end
    if a.data.english ~= b.data.english then
        return a.data.english < b.data.english
    end
    return a.data.part_of_speech < b.data.part_of_speech
end

local function sort_by_native_asc(a, b)
    local a_native, b_native = a.data.native_fn(), b.data.native_fn()
    if a_native ~= b_native then
        return a_native > b_native
    end
    if a.data.english ~= b.data.english then
        return a.data.english < b.data.english
    end
    return a.data.part_of_speech < b.data.part_of_speech
end

local function sort_by_part_of_speech_desc(a, b)
    if a.data.part_of_speech ~= b.data.part_of_speech then
        return a.data.part_of_speech < b.data.part_of_speech
    end
    if a.data.english ~= b.data.english then
        return a.data.english < b.data.english
    end
    local a_native, b_native = a.data.native_fn(), b.data.native_fn()
    return a_native < b_native
end

local function sort_by_part_of_speech_asc(a, b)
    if a.data.part_of_speech ~= b.data.part_of_speech then
        return a.data.part_of_speech > b.data.part_of_speech
    end
    if a.data.english ~= b.data.english then
        return a.data.english < b.data.english
    end
    local a_native, b_native = a.data.native_fn(), b.data.native_fn()
    return a_native < b_native
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
                    auto_width=true,
                    on_activate=function()
                        select_new_target(function(target, sync_targets)
                            if not target then return end
                            self.target, self.sync_targets = target, sync_targets or {}
                            self.subviews.language:setOption(self.target.language)
                        end)
                    end,
                    visible=info.show_selector,
                },
                widgets.HotkeyLabel{
                    frame={t=0, r=0},
                    key='CUSTOM_CTRL_G',
                    label='Generate random name',
                    auto_width=true,
                    on_activate=self:callback('generate_random_name'),
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
                    on_change=self:callback('set_language'),
                },
                widgets.Label{
                    frame={t=6, l=7},
                    text={'Name type: ', {pen=COLOR_CYAN, text=function() return df.language_name_type[self.target.type] end}},
                },
            },
        },
        widgets.Divider{frame={t=8, l=29, w=1},
            frame_style=gui.FRAME_THIN,
            frame_style_t=false,
            frame_style_b=false,
        },
        widgets.Panel{frame={t=8}, -- body
            subviews={
                widgets.Panel{frame={t=0, l=0, w=30}, -- component selector
                    subviews={
                        widgets.Label{
                            frame={t=0, l=0},
                            text='Name components:',
                        },
                        widgets.List{
                            frame={t=2, l=0, b=4, w=ENGLISH_COL_WIDTH+2},
                            view_id='component_list',
                            on_select=self:callback('refresh_list'),
                            choices=self:get_component_choices(),
                            row_height=3,
                            scroll_keys={},
                        },
                        widgets.List{
                            frame={t=2, l=ENGLISH_COL_WIDTH+4, b=4},
                            on_submit=function(_, choice) choice.data.fn() end,
                            choices=self:get_component_action_choices(),
                            cursor_pen=COLOR_CYAN,
                            scroll_keys={},
                        },
                        widgets.HotkeyLabel{
                            frame={b=3, l=0},
                            key='SECONDSCROLL_UP',
                            label='Prev component',
                            on_activate=function()
                                local clist = self.subviews.component_list
                                local move = self.target.type ~= df.language_name_type.Figure and
                                    clist:getSelected() == 2 and #clist:getChoices()-2 or -1
                                self.subviews.component_list:moveCursor(move)
                            end,
                        },
                        widgets.HotkeyLabel{
                            frame={b=2, l=0},
                            key='SECONDSCROLL_DOWN',
                            label='Next component',
                            on_activate=function()
                                local clist = self.subviews.component_list
                                local move = self.target.type ~= df.language_name_type.Figure and
                                    clist:getSelected() == #clist:getChoices() and -#clist:getChoices()+2 or 1
                                self.subviews.component_list:moveCursor(move)
                            end,
                        },
                        widgets.HotkeyLabel{
                            frame={b=1, l=0},
                            key='CUSTOM_CTRL_D',
                            label='Randomize component',
                            on_activate=function()
                                local _, comp_choice = self.subviews.component_list:getSelected()
                                if comp_choice.data.is_first_name then
                                    self:randomize_first_name()
                                else
                                    self:randomize_component_word(comp_choice.data.val)
                                end
                            end,
                        },
                        widgets.HotkeyLabel{
                            frame={b=0, l=0},
                            key='CUSTOM_CTRL_H',
                            label='Clear component',
                            on_activate=function()
                                local _, comp_choice = self.subviews.component_list:getSelected()
                                self:clear_component_word(comp_choice.data.val)
                            end,
                            enabled=function()
                                local _, comp_choice = self.subviews.component_list:getSelected()
                                if comp_choice.data.is_first_name then return false end
                                return self.target.words[comp_choice.data.val] >= 0
                            end,
                        },
                    },
                },
                widgets.Panel{frame={t=0, l=31}, -- words table
                    subviews={
                        widgets.CycleHotkeyLabel{
                            view_id='sort',
                            frame={t=0, l=0, w=19},
                            label='Change sort',
                            key='CUSTOM_CTRL_O',
                            options={
                                {label='', value=sort_by_english_desc},
                                {label='', value=sort_by_english_asc},
                                {label='', value=sort_by_native_desc},
                                {label='', value=sort_by_native_asc},
                                {label='', value=sort_by_part_of_speech_desc},
                                {label='', value=sort_by_part_of_speech_asc},
                            },
                            initial_option=sort_by_english_desc,
                            on_change=self:callback('refresh_list', 'sort'),
                        },
                        widgets.EditField{
                            view_id='search',
                            frame={t=0, l=22},
                            label_text='Search: ',
                            ignore_keys={'SECONDSCROLL_DOWN', 'SECONDSCROLL_UP'}
                        },
                        widgets.CycleHotkeyLabel{
                            view_id='sort_english',
                            frame={t=2, l=0, w=8},
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
                            frame={t=2, l=ENGLISH_COL_WIDTH+2, w=7},
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
                            frame={t=2, l=ENGLISH_COL_WIDTH+2+NATIVE_COL_WIDTH+2, w=15},
                            options={
                                {label='part of speech', value=DEFAULT_NIL},
                                {label='part_of_speech'..CH_DN, value=sort_by_part_of_speech_desc},
                                {label='part_of_speech'..CH_UP, value=sort_by_part_of_speech_asc},
                            },
                            option_gap=0,
                            on_change=self:callback('refresh_list', 'sort_part_of_speech'),
                        },
                        widgets.FilteredList{
                            view_id='words_list',
                            frame={t=4, l=0, b=0, r=0},
                            on_submit=self:callback('set_component_word'),
                        },
                    },
                },
            },
        },
    }

    -- replace the FilteredList's built-in EditField with our own
    self.subviews.words_list.list.frame.t = 0
    self.subviews.words_list.edit.visible = false
    self.subviews.words_list.edit = self.subviews.search
    self.subviews.search.on_change = self.subviews.words_list:callback('onFilterChange')

    self:refresh_list()
end

function Rename:get_component_choices()
    local choices = {}
    table.insert(choices, {
            text={
                {text='First Name',
                    pen=function() return self.target.type ~= df.language_name_type.Figure and COLOR_GRAY or nil end},
                NEWLINE,
                {gap=2, pen=COLOR_YELLOW, text=function() return self.target.first_name end}
            },
            data={val=df.language_name_component.TheX, is_first_name=true}})
    for val, comp in ipairs(df.language_name_component) do
        local text = {
            {text=comp:gsub('(%l)(%u)', '%1 %2')}, NEWLINE,
            {gap=2, pen=COLOR_YELLOW, text=function()
                local word = self.target.words[val]
                if word < 0 then return end
                return ('%s'):format(language.words[word].forms[self.target.parts_of_speech[val]])
            end},
        }
        table.insert(choices, {text=text, data={val=val}})
    end
    return choices
end

function Rename:get_component_action_choices()
    local choices = {}
    table.insert(choices, {
        text={
            {text='[', pen=function() return self.target.type ~= df.language_name_type.Figure and COLOR_GRAY or COLOR_RED end},
            {text='Random', pen=function() return self.target.type ~= df.language_name_type.Figure and COLOR_GRAY or nil end},
            {text=']', pen=function() return self.target.type ~= df.language_name_type.Figure and COLOR_GRAY or COLOR_RED end}
        },
        data={fn=self:callback('randomize_first_name')},
    })
    table.insert(choices, {text='', data={fn=function() end}}) -- shouldn't be able to clear a first name, only overwrite
    table.insert(choices, {text='', data={fn=function() end}})

    local randomize_text = {{text='[', pen=COLOR_RED}, 'Random', {text=']', pen=COLOR_RED}}
    for val, comp in ipairs(df.language_name_component) do
        local randomize_fn = self:callback('randomize_component_word', comp)
        table.insert(choices, {text=randomize_text, data={fn=randomize_fn}})
        local clear_text = {
            {text=function() return self.target.words[val] >= 0 and '[' or '' end, pen=COLOR_RED},
            {text=function() return self.target.words[val] >= 0 and 'Clear' or '' end },
            {text=function() return self.target.words[val] >= 0 and ']' or '' end, pen=COLOR_RED}
        }
        local clear_fn = self:callback('clear_component_word', comp)
        table.insert(choices, {text=clear_text, data={fn=clear_fn}})
        table.insert(choices, {text='', data={fn=function() end}})
    end
    return choices
end

function Rename:clear_component_word(comp)
    self.target.words[comp] = -1
    for _, sync_target in ipairs(self.sync_targets) do
        sync_target.words[comp] = -1
    end
end

function Rename:set_first_name(choice)
    self.target.first_name = translations[self.subviews.language:getOptionValue()].words[choice.data.idx].value
    for _, sync_target in ipairs(self.sync_targets) do
        sync_target.first_name = self.target.first_name
    end
end

function Rename:set_component_word(_, choice)
    local _, comp_choice = self.subviews.component_list:getSelected()
    if comp_choice.data.is_first_name then
        self:set_first_name(choice)
        return
    end
    self.target.words[comp_choice.data.val] = choice.data.idx
    self.target.parts_of_speech[comp_choice.data.val] = choice.data.part_of_speech
    for _, sync_target in ipairs(self.sync_targets) do
        sync_target.words[comp_choice.data.val] = choice.data.idx
        sync_target.parts_of_speech[comp_choice.data.val] = choice.data.part_of_speech
    end
end

function Rename:set_language(val, prev_val)
    self.target.language = val
    -- translate current first name into target language
    local idx = utils.linear_index(translations[prev_val].words, self.target.first_name, 'value')
    if idx then self.target.first_name = translations[val].words[idx].value end
    for _, sync_target in ipairs(self.sync_targets) do
        sync_target.language = val
        sync_target.first_name = self.target.first_name
    end
end

local langauge_name_type_to_category = {
    [df.language_name_type.Figure] = {df.language_name_category.Unit},
    [df.language_name_type.Artifact] = {df.language_name_category.Artifact, df.language_name_category.ArtifactEvil},
    [df.language_name_type.Civilization] = {df.language_name_category.EntityMerchantCompany},
    [df.language_name_type.Squad] = {df.language_name_category.Battle},
    [df.language_name_type.Site] = {df.language_name_category.Keep},
    [df.language_name_type.World] = {df.language_name_category.Region},
    [df.language_name_type.EntitySite] = {df.language_name_category.Keep},
    [df.language_name_type.Temple] = {df.language_name_category.Temple},
    [df.language_name_type.MeadHall] = {df.language_name_category.MeadHall},
    [df.language_name_type.Library] = {df.language_name_category.Library},
    [df.language_name_type.Guildhall] = {df.language_name_category.Guildhall},
    [df.language_name_type.Hospital] = {df.language_name_category.Hospital},
}

local language_name_component_to_word_table_index = {
    [df.language_name_component.FrontCompound] = df.language_word_table_index.FrontCompound,
    [df.language_name_component.RearCompound] = df.language_word_table_index.RearCompound,
    [df.language_name_component.FrontCompound] = df.language_word_table_index.FirstName,
    [df.language_name_component.FirstAdjective] = df.language_word_table_index.Adjectives,
    [df.language_name_component.SecondAdjective] = df.language_word_table_index.Adjectives,
    [df.language_name_component.FrontCompound] = df.language_word_table_index.TheX,
    [df.language_name_component.FrontCompound] = df.language_word_table_index.OfX,

}

function Rename:randomize_first_name()
    if self.target.type ~= df.language_name_type.Figure then return end
    local choices = self:get_word_choices(df.language_name_component.TheX)
    self:set_first_name(choices[math.random(#choices)])
end

function Rename:randomize_component_word(comp)
    local categories = langauge_name_type_to_category[self.target.type]
    local category = categories[math.random(#categories)]
    local word_table = language.word_table[0][category]
    local words = word_table.words[comp]
    local idx = math.random(#words)-1
    self.target.words[comp] = words[idx]
    self.target.parts_of_speech[comp] = word_table.parts[comp][idx]
    for _, sync_target in ipairs(self.sync_targets) do
        sync_target.words[comp] = words[idx]
        sync_target.parts_of_speech[comp] = word_table.parts[comp][idx]
    end
end

function Rename:generate_random_name()
    print('TODO: generate_random_name')
end

local part_of_speech_to_display = {
    [df.part_of_speech.Noun] = 'Singular Noun',
    [df.part_of_speech.NounPlural] = 'Plural Noun',
    [df.part_of_speech.Adjective] = 'Adjective',
    [df.part_of_speech.Prefix] = 'Prefix',
    [df.part_of_speech.Verb] = 'Present (1st)',
    [df.part_of_speech.Verb3rdPerson] = 'Present (3rd)',
    [df.part_of_speech.VerbPast] = 'Preterite',
    [df.part_of_speech.VerbPassive] = 'Past Participle',
    [df.part_of_speech.VerbGerund] = 'Present Participle',
}

function Rename:add_word_choice(choices, comp, idx, word, part_of_speech)
    local english = word.forms[part_of_speech]
    if #english == 0 then return end
    local function get_native()
        return translations[self.subviews.language:getOptionValue()].words[idx].value
    end
    local part = part_of_speech_to_display[part_of_speech]
    local clist = self.subviews.component_list
    local function get_pen()
        local _, comp_choice = clist:getSelected()
        if comp_choice.data.is_first_name then
            return get_native() == self.target.first_name and COLOR_YELLOW or nil
        end
        if idx == self.target.words[comp] and part_of_speech == self.target.parts_of_speech[comp] then
            return COLOR_YELLOW
        end
    end
    table.insert(choices, {
        text={
            {text=english, width=ENGLISH_COL_WIDTH, pen=get_pen},
            {gap=2, text=get_native, width=NATIVE_COL_WIDTH, pen=get_pen},
            {gap=2, text=part, width=15, pen=get_pen},
        },
        search_key=function() return ('%s %s %s'):format(english, get_native(), part) end,
        data={idx=idx, english=english, native_fn=get_native, part_of_speech=part_of_speech},
    })
end

function Rename:get_word_choices(comp)
    if self.cache[comp] then
        return self.cache[comp]
    end

    local choices = {}
    for idx, word in ipairs(language.words) do
        local flags = word.flags
        if comp == df.language_name_component.FrontCompound then
            if flags.front_compound_noun_sing then self:add_word_choice(choices, comp, idx, word, df.part_of_speech.Noun) end
            if flags.front_compound_noun_plur then self:add_word_choice(choices, comp, idx, word, df.part_of_speech.NounPlural) end
            if flags.front_compound_adj then self:add_word_choice(choices, comp, idx, word, df.part_of_speech.Adjective) end
            if flags.front_compound_prefix then self:add_word_choice(choices, comp, idx, word, df.part_of_speech.Prefix) end
            if flags.standard_verb then
                self:add_word_choice(choices, comp, idx, word, df.part_of_speech.Verb)
                self:add_word_choice(choices, comp, idx, word, df.part_of_speech.VerbPassive)
            end
        elseif comp == df.language_name_component.RearCompound then
            if flags.rear_compound_noun_sing then self:add_word_choice(choices, comp, idx, word, df.part_of_speech.Noun) end
            if flags.rear_compound_noun_plur then self:add_word_choice(choices, comp, idx, word, df.part_of_speech.NounPlural) end
            if flags.rear_compound_adj then self:add_word_choice(choices, comp, idx, word, df.part_of_speech.Adjective) end
            if flags.standard_verb then
                self:add_word_choice(choices, comp, idx, word, df.part_of_speech.Verb)
                self:add_word_choice(choices, comp, idx, word, df.part_of_speech.Verb3rdPerson)
                self:add_word_choice(choices, comp, idx, word, df.part_of_speech.VerbPast)
                self:add_word_choice(choices, comp, idx, word, df.part_of_speech.VerbPassive)
            end
        elseif comp == df.language_name_component.FirstAdjective or comp == df.language_name_component.SecondAdjective then
            self:add_word_choice(choices, comp, idx, word, df.part_of_speech.Adjective)
        elseif comp == df.language_name_component.HyphenCompound then
            if flags.the_compound_noun_sing then self:add_word_choice(choices, comp, idx, word, df.part_of_speech.Noun) end
            if flags.the_compound_noun_plur then self:add_word_choice(choices, comp, idx, word, df.part_of_speech.NounPlural) end
            if flags.the_compound_adj then self:add_word_choice(choices, comp, idx, word, df.part_of_speech.Adjective) end
            if flags.the_compound_prefix then self:add_word_choice(choices, comp, idx, word, df.part_of_speech.Prefix) end
        elseif comp == df.language_name_component.TheX then
            if flags.the_noun_sing then self:add_word_choice(choices, comp, idx, word, df.part_of_speech.Noun) end
            if flags.the_noun_plur then self:add_word_choice(choices, comp, idx, word, df.part_of_speech.NounPlural) end
        elseif comp == df.language_name_component.OfX then
            if flags.of_noun_sing then self:add_word_choice(choices, comp, idx, word, df.part_of_speech.Noun) end
            if flags.of_noun_plur then self:add_word_choice(choices, comp, idx, word, df.part_of_speech.NounPlural) end
            if flags.standard_verb then
                self:add_word_choice(choices, comp, idx, word, df.part_of_speech.VerbGerund)
            end
        end
    end

    self.cache[comp] = choices
    return choices
end

function Rename:refresh_list(sort_widget, sort_fn)
    local clist = self.subviews.component_list
    if not clist then return end
    if self.target.type ~= df.language_name_type.Figure and clist:getSelected() == 1 then
        clist:setSelected(self.prev_selected_component or 2)
    end
    self.prev_selected_component = clist:getSelected()

    sort_widget = sort_widget or 'sort'
    sort_fn = sort_fn or self.subviews.sort:getOptionValue()
    if sort_fn == DEFAULT_NIL then
        self.subviews[sort_widget]:cycle()
        return
    end
    for _,widget_name in ipairs{'sort', 'sort_english', 'sort_native', 'sort_part_of_speech'} do
        self.subviews[widget_name]:setOption(sort_fn)
    end
    local list = self.subviews.words_list
    local saved_filter = list:getFilter()
    list:setFilter('')
    local _, comp_choice = clist:getSelected()
    local choices = self:get_word_choices(comp_choice.data.val)
    table.sort(choices, self.subviews.sort:getOptionValue())
    list:setChoices(choices)
    list:setFilter(saved_filter)
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
            sync_targets=info.sync_targets or {},
            show_selector=info.show_selector,
        }
    }
end

function RenameScreen:onDismiss()
    view = nil
end

--
-- Overlays
--

OVERLAY_WIDGETS = {}

--
-- CLI
--

if dfhack_flags.module then
    return
end

if not dfhack.isWorldLoaded() then
    qerror('This script requires a world to be loaded')
end

local function get_target(opts)
    local target, sync_targets = nil, {}
    if opts.histfig_id then
        target, sync_targets = get_hf_target(df.historical_figure.find(opts.histfig_id))
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
        target, sync_targets = get_unit_target(df.unit.find(opts.unit_id))
        if not target then qerror('Unit not found') end
    elseif opts.world then
        target = df.global.world.world_data.name
    end
    return target, sync_targets
end

local function main(args)
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
    local positionals = argparse.processArgsGetopt(args, {
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

    local function launch(target, sync_targets)
        view = view and view:raise() or RenameScreen{
            target=target,
            sync_targets=sync_targets,
            show_selector=opts.show_selector,
        }:show()
    end

    local target, sync_targets = get_target(opts)
    if target then
        launch(target, sync_targets)
        return
    end

    local unit = dfhack.gui.getSelectedUnit(true)
    local item = dfhack.gui.getSelectedItem(true)
    local zone = dfhack.gui.getSelectedCivZone(true)
    if unit then
        target, sync_targets = get_unit_target(unit)
    elseif item then
        target = get_artifact_target(item)
    elseif zone then
        target = get_location_target(df.world_site.find(zone.site_id), zone.location_id)
    end
    if target then
        launch(target, sync_targets)
        return
    end

    if not opts.show_selector then
        qerror('No target selected')
    end

    select_new_target(launch)
end

main{...}
