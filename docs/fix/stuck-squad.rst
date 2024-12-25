fix/stuck-squad
===============

.. dfhack-tool::
    :summary: Allow squads returning from missions to rescue lost squads.
    :tags: fort bugfix military

Occasionally, squads that you send out on a mission get stuck on the world map.
They lose their ability to navigate and are unable to return to your fortress.
This tool finds another of your squads that is returning from a mission and
assigns them to rescue the lost squad.

This fix is enabled by default in the DFHack
`control panel <gui/control-panel>`, or you can run it as needed. However, it
is still up to you to send out another squad that can be tasked with the rescue
mission. You can send the rescue squad out on an innocuous "Demand tribute"
mission to minimize risk to the squad.

Usage
-----

::

    fix/stuck-squad
