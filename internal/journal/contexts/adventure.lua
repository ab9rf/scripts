--@ module = true

AdventurerJournalContext = defclass(AdventurerJournalContext)
AdventurerJournalContext.ATTRS{
  save_prefix='',
}

function get_adventurer_context_key(prefix, adventurer_id)
    return string.format(
      '%sjournal:adventurer:%s',
      prefix,
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
