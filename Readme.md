# Readme

This repository contains some lua scripts for making DCS World missions.

## Download
See [tagged versions](https://github.com/HappyGnome/DCS_Scripts/tags) of this repository. 

## General Usage

### Prerequisites
All scripts assume the use of the [mist helper library for DCS](https://github.com/mrSkortch/MissionScriptingTools/releases)

Add the trigger `MISSION START -> DO SCRIPT FILE -> mist_*_*_*.lua`
**Before** calls to any of these scripts
\* `MISSION START` can be replaced by another event, as long as it will happen before using any of these scripts

Currently tested with Mist version 4.4.90

### Installation

Copy the folder `AssetPools` into `<DCS World path>\Scripts`. These need to be in the main install location, not `<User>\Saved Games\...` because of a security feature of DCS mission scripting (which I don't want to ask users to disable).

## Respawnable On-Call Assets
Allows assets to be (re)spawned via the comms menu with timeouts applied when the unit dies or goes idle
Assets can be coalition specific or available to all
### Usage

#### Initialization

Call `DO SCRIPT FILE -> respawnable_on_call.lua`

#### Add an asset

At any point in the mission after initialization, a group can be added by calling `DO SCRIPT -> respawnable_on_call.new(<groupName>, <spawnDelay>, <delayWhenIdle>, <delayWhenDead>, <coalitionName>)`

Where
* `<groupName>` is the name of the group to make spawnable (in quotes)
**N.B.** This group should have late activation - do not activate it yourself!

* `<spawnDelay>` is the time (seconds) it takes for the group to spawn after it is requested

* `<delayWhenIdle>` is the approximate time (seconds) before the group can be requested after it finishes its mission 
(e.g. time delay after declaring RTB)

* `<delayWhenDead>` is the approximate time (seconds) before the group can be requested after it dies or is otherwise despawned

* `<coalitionName>` should be `"red"` `"blue"` or `"all"` to declare which side will be able to call in the asset (it doesn't have to match the allegience of the asset)

**Return:** a new `respawnable_on_call` instance

##### Example

In a mission with a group called `Aerial-2` set up the triggers:

|Trigger|Action|Action Detail|
|---|---|---|
|MISSION START|DO SCRIPT FILE|mist_4_4_90.lua|
|MISSION START|DO SCRIPT FILE|respawnable_on_call.lua|
|MISSION START|DO SCRIPT|`respawnable_on_call.new("Aerial-2",60,300,300,"red")`|


Then the red coalition will have a "Respawnable Assets" sub-menu in the `F10` comms menu,
from which they can request that `Aerial-2` is respawned. If available it will activate 
60 seconds after user selects this option. Once the group dies or goes RTB (it may take a minute for the script to detect this) a cooldown of 5 minutes (300 seconds) begins, during which time the group can not be respawned - players instead receive a message saying when the group will be available again.

#### Remove an asset

To remove an asset call `<respawnable_on_call instance>:delete()` where `<respawnable_on_call instance>` was returned by a call to `respawnable_on_call.new`. Active units will not be de-spawned, but no further respawns of the asset will be possible.

##### Example

In a mission with a group called `Aerial-2` set up the triggers:

|Trigger|Action|Action Detail|
|---|---|---|
|...|||
|MISSION START|DO SCRIPT|`myRemovableAsset=respawnable_on_call.new("Aerial-2",60,300,300,"red")`|
|...|||
|`<any>`|DO SCRIPT|`myRemovableAsset:delete()`|

#### Additional options

Mission creators can set a few additional options for `respawnable_on_call` instances, including setting Lua functions to be triggered when the tracked group goes idle, dies/despawns, and whenever a respawn is scheduled. 
The functions in the table below should be called on an instance returned from `respawnable_on_call.new`. E.g. `myROC:setGroupDeathCallback(myFunc)`
where `myROC=respawnable_on_call.new(...`.

|Method|Args|Callback Args|Desc|
|---|---|---|---|
|`setGroupDeathCallback`|`callback` - `function(groupName,timesCalledIn)`|`groupName` - name of the monitored group<br> `timesCalledIn` - number of times this group has been spawned |Sets `callback` to be called when the group is detected as dead or despawned |
|`setGroupIdleCallback`|`callback` - `function(groupName,timesCalledIn)`|`groupName` - name of the monitored group<br> `timesCalledIn` - number of times this group has been spawned |Sets `callback` to be called when the group is detected as idle |
|`setGroupCallInCallback`|`callback` - `function(groupName,timesCalledIn)`|`groupName` - name of the monitored group<br> `timesCalledIn` - number of times this group has been spawned (including this time)|Sets `callback` to be called when the group is scheduled to respawn. |
|`resetSpawnCount`|None|N/A|Reset the `timesCalledIn` counter that's passed to callbacks to zero|

**Note** These functions return the calling instance, so they can be chained. E.g. `respawnable_on_call.new(...):setGroupDeathCallback(myFoo):setGroupIdleCallback(myBar)`		

## Constant Pressure Set
This script is designed to help mission builders keep an area constantly busy with units for missions of indefinite duration, while allowing for some attritional effects.
 
Mission builders can define a collection of groups and how many of them should be kept constantly in play. Once a group dies or finishes its tasks, a cooldown time is set, at which a dead/idle group (possibly a different one - this prevents any spawn order building up) will become available to respawn. If the number of active groups in play falls below the target, a new one will be (re)spawned at random from the cooled down groups, and with random delay. 

### Usage

#### Initialization

Call `DO SCRIPT FILE -> constant_pressure_set.lua`

#### Add assets

At any point in the mission after initialization, a set of group can be added by calling `DO SCRIPT -> constant_pressure_set.new(<targetActive>,<reinforceStrength>,<idleCooldown>, <deathCooldown>, <minSpawnDelay>, <maxSpawnDelay>, ...)`

Where
* `<targetActive>` is the number of groups the script will try to maintain in-play

* `<reinforceStrength>` is the number of groups in excess of `<targetActive>` available for spawn at the start. 
		After this many groups despawn or go idle, further spawns will only be possible after one of the cooldowns has completed.

* `<idleCooldown>` is the length of the cooldown time (s) set when a group becomes idle
(e.g. time delay after declaring RTB)

* `<deathCooldown>` is the length of the cooldown time (s) set when a group dies/despawns


* `<minSpawnDelay>` minimum time (s) between groups in-play dropping below `targetActive` and a new group spawning

* `<maxSpawnDelay>` approximate maximum time (s) between groups in-play dropping below `targetActive` and a new group spawning

* `...` A list of group names comprising the set of assets for the maintained presence

**Return:** a new `rconstant_pressure_set` instance

##### Example

In a mission with groups called `Aerial-1` ... `Aerial-7` set up the triggers:

|Trigger|Action|Action Detail|
|---|---|---|
|MISSION START|DO SCRIPT FILE|mist_4_4_90.lua|
|MISSION START|DO SCRIPT FILE|constant_pressure_set.lua|
|MISSION START|DO SCRIPT|`constant_pressure_set.new(2,2,1800,3600,10,120, "Aerial-1","Aerial-2","Aerial-3","Aerial-4","Aerial-5","Aerial-6","Aerial-7" )`|

Then two groups from among the seven Aerial groups will spawn, as each finishs their mission/dies/despawns, it enters a cooldown and
 another one will spawn within between 10s and  ~120s afterwards. Up to two additional groups will spawn this way. But this numebr increases
each time one of the 1800s or 3600s cooldowns finishes. 
 

#### Remove pressure

To cease respawning units from this pressure set, call `<constant_pressure_set instance>:delete()` 

Where

`<constant_pressure_set instance>` was returned by a call to `constant_pressure_set.new`

#### Suggestion

To keep a roughly equal presence in the absence of attrition, set the `<idleCooldown>` to at most `(<reinforceStrength>/<targetActive>) x <minimum mission time among the groups>` 
E.g. the example above would suit groups with missions not shorter than 30 minutes (`= 2/2 x 1800s`). Otherwise, e.g. if groups typically finished their missions in 10 minutes there would be 
a loose cycle where for about 20 minutes, all 4 groups (two at a time) would finish their missions, followed by a 20 minute delay before more spawns could occur, 
(i.e. 30 minutes after the first groups finished).

#### Generating random groups
ap_utils.generateGroups=function(nameRoot,count,unitDonors,taskDonors)

`ap_utils.generateGroups` can be used to simplify creating large numbers of groups for the `constant_pressure_set.new` to make it easier to add variability to missions at runtime.

Usage: `ap_utils.generateGroups(<nameRoot>,<count>,<unitDonors>,<taskDonors>)`

Where
* `<nameRoot>` is a string used to generate names for the new groups e.g. `"EasyGroup"` to generate `EasyGroup-1,EasyGroup-2,...`. This should not clash with other groups in the mission.

* `<count>` is the number of groups to generate

* `<unitDonors>` is an array of group names specifying the groups to be copied (apart from their mission and tasks). I.e. this specifies the strength and unit type etc. **Note:** AI skill will be randomized

* `<taskDonors>` is an array of group names specifying the missions/task lists to give to generated groups

**Returns:** An unpacked list of group names added to the mission. These groups will be inactive. Each consists of the units from a random unit donor with the mission of a random task donor.

**Example:** `constant_pressure_set.new(2,2,1800,3600,10,120, ap_utils.generateGroups("Aerial",7, {"EasyUnits-1","EasyUnits-2"}, {"EasyTask-1","EasyTask-2", "EasyTask-3"}) )`