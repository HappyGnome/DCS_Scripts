# HeLMS Readme

HeLMS - "Helpful Library of Mission Scripts" - contains common utilities for the other scripts. A lightweight substitute for MIST (formerly a dependency)

## Download
This readme is for the [latest versions](https://github.com/HappyGnome/DCS_Scripts/releases/tag/Latest), including untagged changes. Other tagged versions are available [here](https://github.com/HappyGnome/DCS_Scripts/tags).

## General Usage

### Initialization

Before using any of the methods detailed below trigger `DO SCRIPT FILE -> helms.lua` in your mission. The easiest time for this is immediately after initializsing MIST.

## Selected Utilities - helms.ai

### Set Alarm State 
`helms.ai.setAlarmState` and `helms.ai.setAlarmStateIfNameContains` set the alarm state of a named group or groups

Usage: `helms.ai.setAlarmState(<groupName>, <alarmState>)`, or `helms.ai.setAlarmStateIfNameContains(<groupNameContains>, <alarmState>)`

Where
* `<groupName>` is the name of the group for which to set alarm state
* `<groupNameContains>` any group whose name contains this substring will have its alarm state set
* `<alarmState>` alarm state to set `AI.Option.Ground.val.ALARM_STATE` value, e.g. `AI.Option.Ground.val.ALARM_STATE.RED`,`AI.Option.Ground.val.ALARM_STATE.GREEN`, or `AI.Option.Ground.val.ALARM_STATE.AUTO`

**Example:**  `helms.ai.setAlarmStateIfNameContains("Ground Target",AI.Option.Ground.val.ALARM_STATE.RED)` puts any group with name containing `Ground Target` (e.g. `Ground Target-1`) on alert.

## Selected Utilities - helms.dynamic

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

**Example:**  `helms.dynamic.setRandomFlags(1,true, 'TgtN1','TgtN2','TgtN3','TgtN4')` sets one user flag from `'TgtN1'`,`'TgtN2'`,`'TgtN3'`, and `'TgtN4'` to `true`

### Spawn units in zone
`helms.dynamic.respawnMEGroupsInZone` spawn or respawn all groups in mission with a starting point in a circular or quad trigger zone. NOTE: Groups containing "Client" units cannot be respawned this way (but in SP missions, "Player" groups can be).

Usage: `helms.dynamic.respawnMEGroupsInZone(<zoneName>, <activate>, <coalition>, <includeStatic>)`

Where
* `<zoneName>` trigger zone name
* `<activate>` (optional - default true) activate respawned units
* `<coalition>` (optional) side of groups to respawn (e.g. `coalition.side.RED`, or `coalition.side.BLUE`). All units respawn if this is omitted.
* `<includeStatic>` (optional - default true) Also respawn static objects in the zone

**Example:**  `helms.dynamic.respawnMEGroupsInZone("zone1", true, coalition.side.RED)` respawns and activates all mission groups in zone called "zone1"

### Despawn units from zone
`helms.dynamic.despawnMEGroupsInZone` destroy all groups in mission whose spawn point is inside a circular or quad trigger zone. NOTE: Client and player groups CAN be despawned by this method.
 
 Usage: `helms.dynamic.despawnMEGroupsInZone(<zoneName>, <coalition>, <includeStatic>)`

Where
* `<zoneName>` trigger zone name
* `<coalition>` (optional) side of groups to despawn (e.g. `coalition.side.RED`, or `coalition.side.BLUE`). All units despawn if this is omitted.
* `<includeStatic>` (optional - default true) Also despawn static objects in the zone

**Example:**  `helms.dynamic.despawnMEGroupsInZone("zone2", coalition.side.RED)` despawns all red units that start inside "zone2"

## Selected Utilities - helms.mission

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

## Selected Utilities - helms.ui

### Add comms callbacks
`helms.ui.combo.commsCallback` simplifies the addition of items to the HeLMS comms submenus (mainly aimed at scripting in the mission editor)

Usage: `helms.ui.combo.commsCallback(<side>,<menuLabel>,<optionLabel>, <callback>, ...)`

Where
* `<side>` Side receiving the menu option (`coalition.side`) or nil to create comms options for all
* `<menuLabel>` Label of the submenu of the F10 'Other' comms menu
* `<optionLabel>` Label of the comms option
* `<callback>` Function fo call when comms menu item is pressed
* `...` arguments for the called function

Returns: table that can be passed to `removeCommsCallback`

**Example:**  `helms.ui.combo.commsCallback (nil,'Games','North', helms.dynamic.setRandomFlags, 1,true, 'TgtN1','TgtN2','TgtN3','TgtN4')` Adds comms option `Other > Games > North` for all players. When selected, one random user flag from `'TgtN1'`,`'TgtN2'`,`'TgtN3'`, and `'TgtN4'` is set to to `true`

### Remove comms callbacks
`helms.ui.combo.removeCommsCallback` remove a comms menu option previously added with `helms.ui.combo.commsCallback`

Usage: `helms.ui.combo.removeCommsCallback(<side>,<menuLabel>,<optionLabel>)`

Where
* `<side>` Side with the menu option (`coalition.side`) or nil to create comms options for all, as passed to `helms.ui.combo.commsCallback`
* `<menuLabel>` Label of the submenu of the F10 'Other' comms menu, as passed to `helms.ui.combo.commsCallback`
* `<optionLabel>` Label of the comms option, as passed to `helms.ui.combo.commsCallback`

**Example:**  `helms.ui.combo.removeCommsCallback(nil,'Games','North')`

### Display mission drawing
`helms.ui.showDrawing` show drawing defined in mission editor in the running mission (to groups other than those that can see it on mission load).

NOTE: This feature has some known limitations, due to limitations of the DCS scripting API. E.g.: 
* not all line styles work,
* line thickness doesn't work,
* some flickering of fill colours may be seen, and
* ovals are rendered as circles

Usage: `helms.ui.showDrawing(<drawingName>,<coalition>)`

Where
* `<drawingName>` drawing name from mission editor to add
* `<coalition>` (optional) coalition.side of side who will see the drawing (e.g. `coalition.side.RED`, or `coalition.side.BLUE`). Defaults to displaying to all players.

**Example:**  `helms.ui.showDrawing('Line-5',coalition.side.RED)` display drawing called "Line-5" to red players.

### Hide mission drawing
`helms.ui.removeDrawing` hides a drawing added with `helms.ui.showDrawing`.

Usage: `helms.ui.removeDrawing(<drawingName>)`

Where
* `<drawingName>` drawing name from mission editor to hide (must have been added with `helms.ui.showDrawing`)

**Example:**  `helms.ui.removeDrawing('Polygon-37')` hides drawing called "Polygon-37" previously shown by a call to `helms.ui.showDrawing`

## Selected Utilities - helms.effect
### Start smoke effect
`helms.effect.startSmokeOnZone` starts a smoke effect (using `trigger.action.smoke`) at a named zone centre. This effect is refreshed every 5 minutes to create a perpetual effect. See `helms.effect.stopSmokeOnZone` to cancel an effect. This method can also be called to update the colour of an existing smoke effect (note that the change only occurs the next time the smoke is re-created, which may take up to 5 minutes). 

Usage: `helms.effect.startSmokeOnZone(<zoneName>, <colour>)` where

Where
* `<zone>` Is the name of a (static) trigger zone
* `<colour>` is "Red", "Green", "Blue", "White", or "Orange"

Returns: the zone name on success.

**Example:**  `helms.effect.startSmokeOnZone("Zone-1", "Green")`

### Stop smoke effect
`helms.effect.stopSmokeOnZone` stops a smoke effect created by `helms.effect.startSmokeOnZone` from refreshing. Note that the effect is not immediately stopped. It may take up to 5 minutes for the current smoke effect to stop.

Usage: `helms.effect.stopSmokeOnZone(<zoneName>)` where

Where
* `<zone>` Is the name of a (static) trigger zone

Returns: None

**Example:**  `helms.effect.stopSmokeOnZone("Zone-1")`