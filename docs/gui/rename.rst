gui/rename
==========

.. dfhack-tool::
    :summary: Modify the name of anything that is nameable.
    :tags: adventure fort productivity animals items units

Once you select a target (by clicking on the game map, by passing a commandline
parameter, or by using the provided selection widget) this tool allows you
change its language name, generate a new random name, or rename it with your
preferred component words. It provides an interface similar to the in-game
naming panel that you can use to customize your fortress name at embark. That
is, it allows you to choose words from an in-game language to assemble a name,
just like the default names that the game generates. You will be able to assign
units new given and last names. You can also use this tool to set freeform
"nicknames" for targets that support it.

Usage
-----

::

    gui/rename [<options>]

Examples
--------

``gui/rename``
    Load the selected artifact, location, or unit for renaming. If nothing is
    selected, you can select a target from a list.
``gui/rename -u 123 --no-target-selector``
    Load the unit with id ``123`` for renaming and remove the widget that
    allows selecting a different target.
``gui/rename --location 2 --site 456``
    Load the location with "abstract building" ID ``2`` attached to the site
    with id ``456`` for renaming.

Options
-------

``-a``, ``--artifact <id>``
    Rename the artifact with the given item ID.
``-e``, ``--entity <id>``
    Rename the historical entity (e.g. site government, world religion, etc)
    with the given ID.
``-f``, ``--histfig <id>``
    Rename the historical figure with the given ID.
``-l``, ``--location <id>``
    Rename the location (e.g. tavern, hospital, guildhall, temple) with the
    given ID. If this option is used, ``--site`` can be specified to indicate
    locations attached to a specific site. If ``--site`` is not specified, the
    location will be loaded from the current site.
``-q``, ``--squad <id>``
    Rename the squad with the given ID.
``-s``, ``--site <id>``
    Rename the site with the given ID.
``-u``, ``--unit <id>``
    Rename the unit with the given ID. Renaming a unit also renames the
    associated historical figure.
``-w``, ``--world``
    Rename the current world.
``--no-target-selector``
    Do not allow the player to switch naming targets. An option that sets the
    initial target is required when using this option.

Overlays
--------

This tool supports the following overlays:

``gui/rename.embark``
    Adds widgets to the embark preparation screen for renaming the starting
    dwarves.
``gui/rename.world``
    Adds a widget to the world generation screen for renaming the world.
