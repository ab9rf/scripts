-- Map notes
--@ module = true

local gui = require 'gui'
local widgets = require 'gui.widgets'
local script = require 'gui.script'
local text_editor = reqscript('internal/journal/text_editor')

local map_points = df.global.plotinfo.waypoints.points

local NOTE_LIST_RESIZE_MIN = {w=26}
local RESIZE_MIN = {w=65, h=30}
local NOTE_SEARCH_BATCH_SIZE = 10

NotesWindow = defclass(NotesWindow, widgets.Window)
NotesWindow.ATTRS {
    frame_title='DF Notes',
    resizable=true,
    resize_min=RESIZE_MIN,
    frame_inset={l=0,r=0,t=0,b=0},
}

function NotesWindow:init()
    self:addviews{
        widgets.Panel{
            view_id='note_list_panel',
            frame={l=0, w=NOTE_LIST_RESIZE_MIN.w, t=0, b=1},
            visible=true,
            frame_inset={l=1, t=1, b=1, r=1},
            autoarrange_subviews=true,

            subviews={
                widgets.HotkeyLabel {
                    key='CUSTOM_ALT_S',
                    label='Search',
                    frame={l=0},
                    auto_width=true,
                    on_activate=function() self.subviews.search:setFocus(true) end,
                },
                text_editor.TextEditor{
                    view_id='search',
                    frame={l=0,h=3},
                    frame_style=gui.FRAME_INTERIOR,
                    one_line_mode=true,
                    on_text_change=self:callback('loadFilteredNotes')
                },
                widgets.List{
                    view_id='note_list',
                    frame={l=0},
                    frame_inset={t=1},
                    row_height=1,
                    on_submit=self:callback('loadNote')
                },
            }
        },
        widgets.Divider{
            view_id='note_list_divider',

            frame={l=NOTE_LIST_RESIZE_MIN.w,t=0,b=0,w=1},

            interior_b=false,
            frame_style_t=false,
            frame_style_b=false,
        },
    }

    self:loadFilteredNotes('')
end

function NotesWindow:loadNote(ind, note)
    dfhack.gui.pauseRecenter(note.point.pos)
end

function NotesWindow:loadFilteredNotes(search_phrase)
    script.start(function ()
        local choices = {}

        for ind, map_point in ipairs(map_points) do
            if ind > 0 and ind % NOTE_SEARCH_BATCH_SIZE == 0 then
                script.sleep(1, 'frames')
            end

            if #search_phrase < 3 or map_point.name:find(search_phrase) then
                table.insert(choices, {
                    text=map_point.name,
                    point=map_point
                })
            end
        end

        self.subviews.note_list:setChoices(choices)
    end)
end


NotesScreen = defclass(NotesScreen, gui.ZScreen)
NotesScreen.ATTRS {
    focus_path='gui/notes',
}

function NotesScreen:init()
    self:addviews{
        NotesWindow{
            view_id='notes_window',
            frame={w=RESIZE_MIN.w, h=35},
        },
    }
end

function NotesScreen:onDismiss()
    view = nil
end

function main(options)
    if not dfhack.isMapLoaded() or not dfhack.world.isFortressMode() then
        qerror('notes requires a fortress map to be loaded')
    end

    view = view and view:raise() or NotesScreen{
    }:show()
end

if not dfhack_flags.module then
    main()
end
