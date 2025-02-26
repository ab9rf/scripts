--@ module = true

local widgets = require 'gui.widgets'
local utils = require('utils')
local DummyJournalContext = reqscript('internal/journal/contexts/dummy')
local FortressJournalContext = reqscript('internal/journal/contexts/fortress')
local AdventurerJournalContext = reqscript('internal/journal/contexts/adventure')

function journal_context_factory(save_on_change, save_prefix)
  if not save_on_change then
    return DummyJournalContext{}
  elseif dfhack.world.isFortressMode() then
    return FortressJournalContext{save_prefix}
  elseif dfhack.world.isAdventureMode() then
    local interactions = df.global.adventure.interactions
    if #interactions.party_core_members == 0 then
      qerror('Can not identify party core member')
    end

    local adventurer_id = interactions.party_core_members[0]

    return AdventurerJournalContext{
      save_prefix,
      adventurer_id=adventurer_id
    }
  else
    qerror('unsupported game mode')
  end
end
