--@ module = true

local JOURNAL_WELCOME_COPY =  [=[
Welcome to gui/journal. This is dummy context and it should be available only
in automatic tests.
]=]

local TOC_WELCOME_COPY =  [=[
This is Table of Contenst test welcome copy
]=]


-- Dummy Context, no storage --

DummyJournalContext = defclass(DummyJournalContext)

function DummyJournalContext:save_content(text, cursor)
end

function DummyJournalContext:load_content()
  return {text={''}, cursor={1}, show_tutorial=true}
end

function DummyJournalContext:welcomeCopy()
  return JOURNAL_WELCOME_COPY
end

function DummyJournalContext:tocWelcomeCopy()
  return TOC_WELCOME_COPY
end
