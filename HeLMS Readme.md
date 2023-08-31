# HeLMS Readme

HeLMS - "Helpful Library of Mission Scripts" - contains common utilities for the other scripts. A lightweight substitute for MIST (formerly a dependency)

## Download
This readme is for the [latest versions](https://github.com/HappyGnome/DCS_Scripts/releases/tag/Latest), including untagged changes. Other tagged versions are available [here](https://github.com/HappyGnome/DCS_Scripts/tags).

## General Usage

### Initialization

Before using any of the methods detailed below trigger `DO SCRIPT FILE -> helms.lua` in your mission. The easiest time for this is immediately after initializsing MIST.

## Selected Utilities

### Generating random groups
`helms.mission.generateGroups` can be used to simplify creating large numbers of groups e.g. for the `constant_pressure_set.new` to make it easier to add variability to missions at runtime.

Usage: `helms.mission.generateGroups(<nameRoot>,<count>,<unitDonors>,<taskDonors>)`

Where
* `<nameRoot>` is a string used to generate names for the new groups e.g. `"EasyGroup"` to generate `EasyGroup-1,EasyGroup-2,...`. This should not clash with other groups in the mission.

* `<count>` is the number of groups to generate

* `<unitDonors>` is an array of group names specifying the groups to be copied (apart from their mission and tasks). I.e. this specifies the strength and unit type etc. **Note:** AI skill will be randomized

* `<taskDonors>` is an array of group names specifying the missions/task lists to give to generated groups

**Returns:** An unpacked list of group names added to the mission. These groups will be inactive. Each consists of the units from a random unit donor with the mission of a random task donor.

**Example:** `constant_pressure_set.new(2,2,1800,3600,10,120, helms.mission.generateGroups("Aerial",7, {"EasyUnits-1","EasyUnits-2"}, {"EasyTask-1","EasyTask-2", "EasyTask-3"}) )`

**Example:** Use `helms.util.multiunpack` to pass a union of generated groups `constant_pressure_set.new(2,2,1800,3600,10,120, helms.util.multiunpack({ap_utils.generateGroups("F16_B", 5, ap_utils.getNamesContaining("DefF15"), ap_utils.getNamesContaining("DedF16"))},{ap_utils.generateGroups("F16_A", 15, ap_utils.getNamesContaining("DefF16"), ap_utils.getNamesContaining("DedF16"))}) )`

### Checking for player proximity
`helms.dynamic.getClosestLateralPlayer` can be used to find the closest player (in lateral coordinates, i.e. ignoring altitude) to a unit from a specified group.

Usage: `helms.dynamic.getClosestLateralPlayer(<groupName>,<sides>, <options>)`

Where
* `<groupName>` is the name of the group for which to calculate separation from players
* `<sides>` a table of `coalition.side` objects for the faction of players to check e.g. `{coalition.side.BLUE}` will find the closest blue player to any unit in the group
* `<options>` is a table containing further options.

**Possible options:**
* `<options>.unitFilter` a function (unit) -> Boolean, or nil. If set the function should return true if a unit is to be counted. If `nil`, all living units in the group will count
* `<options>.pickUnit` - if `true`, only one unit in the group will be used for the calculation (saves time and works just as well if the units are near each other)
 
**Returns:** `<distance>, <playerUnit>, <closestUnit>`, or `nil,nil,nil` if no matching players or no matching units exist
Where
* `<distance>` (m) is the shortest distance between a matching player and a matching unit
* `<playerUnit>` (unit) is the player-controlled unit that achieves `<distance>` to the group
* `<closestUnit>` (unit) is the unit that attains `<distance>` to the `<playerUnit>`

**Example:**  `helms.dynamic.getClosestLateralPlayer("Raider-1",{coalition.side.BLUE}, {unitFilter = Object.inAir})` returns information about the airbourne unit in the group *Raider-1* that's closest to a blue player.

### Setting random trigger flags
`helms.dynamic.setRandomFlags` to set a random subset of a list of mission trigger flags to a certain value

Usage: `helms.dynamic.setRandomFlags(<n>,<toValue>, ...)`

Where
* `<n>` the number of flags to randomly select
* `<toValue>` the value that selected flags will be set to
* `...` a list of flags to slect from

**Example:**  `helms.ui.setRandomFlags(1,true, 'TgtN1','TgtN2','TgtN3','TgtN4')` sets one user flag from `'TgtN1'`,`'TgtN2'`,`'TgtN3'`, and `'TgtN4'` to `true`

### Simplified comms callbacks
`helms.ui.combo.commsCallback` simplifies the addition of items to the HeLMS comms submenus (mainly aimed at scripting in the mission editor)

Usage: `helms.ui.combo.commsCallback(<side>,<menuLabel>,<optionLabel>, <callback>, ...)`

Where
* `<side>` Side receiving the menu option (`coalition.side`) or nil to create comms options for all
* `<menuLabel>` Label of the submenu of the F10 'Other' comms menu
* `<optionLabel>` Label of the comms option
* `<callback>` Function fo call when comms menu item is pressed
* `...` arguments for the called function

**Example:**  `helms.ui.combo.commsCallback (nil,'Games','North', helms.dynamic.setRandomFlags, 1,true, 'TgtN1','TgtN2','TgtN3','TgtN4')` Adds comms option `Other > Games > North` for all players. When selected, one random user flag from `'TgtN1'`,`'TgtN2'`,`'TgtN3'`, and `'TgtN4'` is set to to `true`


