--@ module = true

local JOURNAL_WELCOME_COPY =  [=[
Welcome to gui/journal, the adventurer's notebook for Dwarf Fortress!

Here, you can jot down your travels, keep track of important places, or note anything worth remembering.
The text you write here is saved together with your adventurer.

For guidance on navigation and hotkeys, tap the ? button in the upper right corner.
Safe travels!
]=]

local TOC_WELCOME_COPY =  [=[
Start a line with # symbols and a space to create a header. For example:

# My section heading

or

## My section subheading

Those headers will appear here, and you can click on them to jump to them in the text.]=]


AdventurerJournalContext = defclass(AdventurerJournalContext)
AdventurerJournalContext.ATTRS{
  save_prefix='',
  adventurer_id=DEFAULT_NIL
}

function get_adventurer_context_key(prefix, adventurer_id)
    return string.format(
      '%sjournal:adventurer:%s',
      prefix,
      adventurer_id
    )
end

function AdventurerJournalContext:save_content(text, cursor)
  if dfhack.isWorldLoaded() then
    dfhack.persistent.saveSiteData(
        get_adventurer_context_key(self.save_prefix, self.adventurer_id),
        {text={text}, cursor={cursor}}
    )
  end
end

function AdventurerJournalContext:load_content()
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

function AdventurerJournalContext:welcomeCopy()
  return JOURNAL_WELCOME_COPY
end

function AdventurerJournalContext:tocWelcomeCopy()
  return TOC_WELCOME_COPY
end
