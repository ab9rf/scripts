fixrightclick
================

.. dfhack-tool::
    :summary: Adjust properties of caravans on the map.
    :tags: fort interface bugfix

This overlay changes the behavior of the right mouse button and other keys mapped to "Leave screen" to only reset the selection rectangle when painting designations, constructions, minecart tracks, zones, etc., instead of outright quitting the painting mode. It can be toggled in the UI Overlays tab of `gui/control-panel`.

Usage
-----

::

    overlay enable|disable fixrightclick.selection
