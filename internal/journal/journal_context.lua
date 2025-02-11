--@ module = true

local widgets = require 'gui.widgets'

local JOURNAL_PERSIST_KEY = 'journal'

function journal_context_factory(save_prefix, save_on_change)
  if not save_on_change then
    return DummyJournalContext{}
  elseif dfhack.world.isFortressMode() then
    return FortJournalContext{save_prefix}
  else
    qerror('unsupported game mode')
  end
end

FortJournalContext = defclass(FortJournalContext)
FortJournalContext.ATTRS{
  save_prefix=''
}

function get_fort_context_key(prefix)
    return prefix .. JOURNAL_PERSIST_KEY
end

function FortJournalContext:save(text, cursor)
  if dfhack.isWorldLoaded() then
    dfhack.persistent.saveSiteData(
        get_fort_context_key(self.save_prefix),
        {text={text}, cursor={cursor}}
    )
  end
end

function FortJournalContext:load()
  if dfhack.isWorldLoaded() then
    local site_data = dfhack.persistent.getSiteData(
        get_fort_context_key(self.save_prefix)
    ) or {}

    if not site_data.text then
        site_data.text={''}
        site_data.show_tutorial = true
    end
    site_data.cursor = site_data.cursor or {#site_data.text[1] + 1}
    return site_data
  end
end

DummyJournalContext = defclass(DummyJournalContext)

function DummyJournalContext:save(text, cursor)
end

function DummyJournalContext:load()
  return {text={''}, cursor={1}, show_tutorial=true}
end
