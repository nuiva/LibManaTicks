# LibManaTicks

LibManaTicks is a *World of Warcraft: Classic* interface addon that provides events for the player's natural mana gains ("mana ticks").

## Interface

LibManaTicks works through the function
```LibManaTicks:RegisterCallback(event, function)```
The `event` parameter must be one of
* `ManaTick`: Occurs when the player gains a natural mana tick.
* `ManaTickAlways`: Occurs when the player would gain mana, even if the tick is blocked by casting a spell. This also occurs whenever `ManaTick` does.
* `Spellcast`: Occurs when the player casts a spell that interrupts mana ticks, that is, costs mana.

## WeakAuras

Since LibManaTicks has no graphical interface, you will need another addon or a WeakAura to properly use it. The file `WeakAura.txt` contains a WeakAura that shows the mana ticks and spellcast as progress bars.

## Installation

Click the green button that says *Clone or download*, then *Download ZIP*. Drop the `LibManaTicks` directory into your `/Interface/Addons`.

## How does it work?

LibManaTicks tracks player mana changes using the event `UNIT_POWER_UPDATE`. If the player mana goes down and a simultaneous `UNIT_SPELLCAST_SUCCEEDED`, mana ticks are blocked for 5 seconds. If the player mana goes up and a preceding combat log event `SPELL_ENERGIZE` is detected, then that mana gain is blocked. Mana gains that are not blocked are always interpreted to be mana ticks.

