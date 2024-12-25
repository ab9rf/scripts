fix/stuck-squad
===============

.. dfhack-tool::
    :summary: Allow squads returning from missions to rescue lost squads.
    :tags: fort bugfix military

Occasionally, squads that you send out on a mission get stuck on the world map.
They lose their ability to navigate and are unable to return to your fortress.
This tool allows another of your squads that is (successfully) returning from a
mission to rescue the lost squad along the way and bring them home.

This fix is enabled by default in the DFHack
`control panel <gui/control-panel>`, or you can run it as needed. However, it
is still up to you to send out another squad that can be tasked with the rescue
mission. You can send the squad out on a relatively innocuous mission, like
"Demand one-time tribute", to minimize risk to the squad.

This tool is integrated with `gui/notify`, so you will get a notification in
the DFHack notification panel when a squad is stuck and there are no squads
currently out traveling that can rescue them.

Note that there might be other reasons why your squad appears missing -- if it
got wiped out in combat and nobody survived to report back, for example -- but
this tool should fix the cases that are actual bugs.

Usage
-----

::

    fix/stuck-squad
