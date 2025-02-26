--@ module = true

-- Dummy Context, no storage --

DummyJournalContext = defclass(DummyJournalContext)

function DummyJournalContext:save(text, cursor)
end

function DummyJournalContext:load()
  return {text={''}, cursor={1}, show_tutorial=true}
end

