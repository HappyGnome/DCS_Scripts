# Minitrons Readme

Minitrons adds a basic jammer functionality to DCS.

Mechanics overview:
* A minitrons profile is a list of jammable unit types
* Named player units can made "jammer units" be given one or more profiles.
* Jammer units receive Minitrons options in the radio menu
* Jammer units are alerted when in "audio range"" (with LOS) of a type they can jam
* Jammer units can activate their jammer in one profile via the comms menu. 
    * Units with types named in the profile within jamming range (and LOS) have their AI disabled
* When a jammer is switched off by the player, or overheats, or breaks, the jamming effect ceases.

Current limitations:
* The audio range is the same for all units and profles
* The jamming range is the same for all units and profles
* Ranges are based on distance on the map, not slant range.
* There is no cone of action for the jammer - fully effective within a circular zone
* No audio is played - everything is text-based.
* Control is via the comms menu - no cockpit switch control

## Download
This readme is for the [latest versions](https://github.com/HappyGnome/DCS_Scripts/releases/tag/Latest), including untagged changes. Other tagged versions are available [here](https://github.com/HappyGnome/DCS_Scripts/tags).

## Include HeLMS
All game scripts below require HeLMS to be initialized first.

Add the trigger `MISSION START -> DO SCRIPT FILE -> helms.lua`
**Before** calls to any of the game scripts
\* `MISSION START` can be replaced by another event, as long as it will happen before using any of these scripts

## Minitrons

Before using any of the methods detailed below trigger `DO SCRIPT FILE -> minitrons.lua` in your mission. The easiest time for this is immediately after initializsing HeLMS.

### Scripting

#### Create a profile

To add one or more jammable unit types to a profile by referencing named units in the mission:
`DO SCRIPT -> minitrons.addUnitToProfile(<profileName>,<unitName1>, <unitName2>,...)` 

Where
* `<profileName>` - name of the profile to add to / create. Appears in comms menus.
* `<unitName_>` - the type of the named unit is added to the profile

**Example:**  `minitrons.addUnitToProfile("Blue EWR","Ground-1-1","Ground-2-3")` Adds the unit types of units `Ground-1-1` and `Ground-2-3` to be vulnerable to units with jammer profile `Blue EWR`.

**Note:** `minitrons.rebuildConfig()` must be called once all profiles are created

#### Complete building configs

To reconfigure minitrons once all profiles are created:
`DO SCRIPT -> minitrons.rebuildConfig()` 

#### Assign a jammer unit

To make a named (player unit) a jammer unit, with minitrons comms menu options:
`DO SCRIPT -> minitrons.addJammerUnit(<unitName>,{<profileName1>, <profileName2>, ...})` 

Where
* `<unitName>` - name of the player unit who can jam
* `<profileName_>` - name of a profile available to the jammer unit.

**Example:**  `minitrons.addJammerUnit("Rotary-1-1",{"SA-3", "Manpads", "Blue EWR"})` Makes the player unit `Rotary-1-1` a jammer, with available profiles `SA-3`, `Manpads`, and `Blue EWR`.

##### Example

|Trigger|Action|Action Detail|
|---|---|---|
|MISSION START|DO SCRIPT FILE|helms.lua|
|MISSION START|DO SCRIPT FILE|minitrons.lua|
|MISSION START|DO SCRIPT|`minitrons.addUnitToProfile("Blue EWR","Ground-1-1","Ground-2-3")`|
|MISSION START|DO SCRIPT|`minitrons.addUnitToProfile("SA-2","Ground-5-1")`|
|MISSION START|DO SCRIPT|`minitrons.rebuildConfig()`|
|MISSION START|DO SCRIPT|`minitrons.addJammerUnit("Aerial-1-1",{"SA-2", "Blue EWR"})`|

