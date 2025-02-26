--@ module = true

FortressJournalContext = defclass(FortressJournalContext)
FortressJournalContext.ATTRS{
  save_prefix=''
}

function get_fort_context_key(prefix)
    return prefix .. 'journal'
end

function FortressJournalContext:save(text, cursor)
  if dfhack.isWorldLoaded() then
    dfhack.persistent.saveSiteData(
        get_fort_context_key(self.save_prefix),
        {text={text}, cursor={cursor}}
    )
  end
end

function FortressJournalContext:load()
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
