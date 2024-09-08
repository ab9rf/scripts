-- Map notes
--@ module = true

local gui = require 'gui'
local widgets = require 'gui.widgets'
local script = require 'gui.script'
local text_editor = reqscript('internal/journal/text_editor')

local map_points = df.global.plotinfo.waypoints.points

local NOTE_LIST_RESIZE_MIN = {w=26}
local RESIZE_MIN = {w=65, h=30}
local NOTE_SEARCH_BATCH_SIZE = 25

NotesWindow = defclass(NotesWindow, widgets.Window)
NotesWindow.ATTRS {
    frame_title='DF Notes',
    resizable=true,
    resize_min=RESIZE_MIN,
    frame_inset={l=0,r=0,t=0,b=0},
}

function NotesWindow:init()
    self.selected_note = nil

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
                    on_submit=function (ind, note) self:loadNote(note) end
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
        widgets.Panel{
            view_id='note_details',
            frame={l=NOTE_LIST_RESIZE_MIN.w + 1,t=0,b=0},
            frame_inset=1,
            autoarrange_gap=1,
            subviews={
                widgets.Panel{
                    view_id="name_panel",
                    frame_title='Name',
                    frame_style=gui.FRAME_INTERIOR,
                    frame={l=0,r=0,t=0,h=4},
                    frame_inset={l=1,r=1},
                    auto_height=true,
                    subviews={
                        widgets.Label{
                            view_id='name',
                            frame={t=0,l=0,r=0}
                        },
                    },
                },
                widgets.Panel{
                    view_id="comment_panel",
                    frame_title='Comment',
                    frame_style=gui.FRAME_INTERIOR,
                    frame={l=0,r=0,t=4,b=2},
                    frame_inset={l=1,r=1,t=1},
                    subviews={
                        widgets.Label{
                            view_id='comment',
                            frame={t=0,l=0,r=0}
                        },
                    }
                },
                widgets.Panel{
                    frame={l=0,r=0,b=0,h=2},
                    frame_inset={l=1,r=1,t=1},
                    subviews={
                        widgets.HotkeyLabel{
                            view_id='edit',
                            frame={l=0,t=0,h=1},
                            auto_width=true,
                            label='Edit',
                            key='CUSTOM_ALT_U',
                            -- on_activate=function() self:createNote() end,
                            -- enabled=function() return #self.subviews.name:getText() > 0 end,
                        },
                        widgets.HotkeyLabel{
                            view_id='delete',
                            frame={r=0,t=0,h=1},
                            auto_width=true,
                            label='Delete',
                            key='CUSTOM_ALT_D',
                            -- on_activate=function() self:deleteNote() end,
                        },
                    }
                }
            }
        }
    }

    self:loadFilteredNotes('')
end

function NotesWindow:loadNote(note)
    self.selected_note = note

    local note_width = self.subviews.name_panel.frame_body.width
    local wrapped_name = note.point.name:wrap(note_width)
    local wrapped_comment = note.point.comment:wrap(note_width)

    self.subviews.name:setText(wrapped_name)
    self.subviews.comment:setText(wrapped_comment)
    self.subviews.note_details:updateLayout()

    dfhack.gui.pauseRecenter(note.point.pos)
end

function NotesWindow:loadFilteredNotes(search_phrase)
    local full_list_loaded = self.curr_search_phrase == ''

    search_phrase = search_phrase:lower()
    if #search_phrase < 3 then
        search_phrase = ''
    end

    self.curr_search_phrase = search_phrase

    script.start(function ()
        if #search_phrase == 0 and full_list_loaded then
            return
        end

        local choices = {}

        for ind, map_point in ipairs(map_points) do
            if ind > 0 and ind % NOTE_SEARCH_BATCH_SIZE == 0 then
                script.sleep(1, 'frames')
            end
            if self.curr_search_phrase ~= search_phrase then
                -- stop the work if user provided new search phrase
                return
            end

            local point_name_lowercase = map_point.name:lower()
            if (
                point_name_lowercase ~= nil and #point_name_lowercase > 0 and
                point_name_lowercase:find(search_phrase)
            ) then
                table.insert(choices, {
                    text=map_point.name,
                    point=map_point
                })
            end
        end

        self.subviews.note_list:setChoices(choices)
    end)
end

function NotesWindow:postUpdateLayout()
    if self.selected_note == nil then
        self.subviews.note_list:submit()
    else
        self:loadNote(self.selected_note)
    end
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
