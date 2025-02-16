--@ module = true

local widgets = require 'gui.widgets'

local JOURNAL_PERSIST_KEY = 'journal'

function journal_context_factory(save_on_change, save_prefix)
  if not save_on_change then
    return DummyJournalContext{}
  elseif dfhack.world.isFortressMode() then
    return FortJournalContext{save_prefix}
  elseif dfhack.world.isAdventureMode() then
    return AdventurerJournalContext{
      save_prefix,
      adventurer_id=dfhack.world.getAdventurer().id
    }
  else
    qerror('unsupported game mode')
  end
end


-- Fortress Context --

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

-- Dummy Context, no storage --

DummyJournalContext = defclass(DummyJournalContext)

function DummyJournalContext:save(text, cursor)
end

function DummyJournalContext:load()
  return {text={''}, cursor={1}, show_tutorial=true}
end

-- Dummy Context, no storage --

DummyJournalContext = defclass(DummyJournalContext)

function DummyJournalContext:save(text, cursor)
end

function DummyJournalContext:load()
  return {text={''}, cursor={1}, show_tutorial=true}
end

-- Adventure Context --

AdventurerJournalContext = defclass(AdventurerJournalContext)
AdventurerJournalContext.ATTRS{
  save_prefix='',
  adventurer_id=''
}

function get_adventurer_context_key(prefix, adventurer_id)
    return string.format(
      '%s%s:adventurer:%s',
      prefix,
      JOURNAL_PERSIST_KEY,
      adventurer_id
    )
end

function AdventurerJournalContext:save(text, cursor)
  if dfhack.isWorldLoaded() then
    dfhack.persistent.saveSiteData(
        get_adventurer_context_key(self.save_prefix, self.adventurer_id),
        {text={text}, cursor={cursor}}
    )
  end
end

function AdventurerJournalContext:load()
  if dfhack.isWorldLoaded() then
    local site_data = dfhack.persistent.getSiteData(
        get_adventurer_context_key(self.save_prefix, self.adventurer_id)
    ) or {}

    if not site_data.text then
        site_data.text={''}
        site_data.show_tutorial = true
    end
    site_data.cursor = site_data.cursor or {#site_data.text[1] + 1}
    return site_data
  end
end
