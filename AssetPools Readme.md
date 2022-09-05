# AssetPools Readme

Scripts for spawning groups automatically to keep a mission alive, and managing resources to be spawned via the F10 menu

## Download
This readme is for the [latest versions](https://github.com/HappyGnome/DCS_Scripts/releases/tag/Latest), including untagged changes. Other tagged versions are available [here](https://github.com/HappyGnome/DCS_Scripts/tags).

## General Usage

### Prerequisites

#### HeLMS
Add the trigger `MISSION START -> DO SCRIPT FILE -> helms.lua`
**Before** calls to any of these scripts
\* `MISSION START` can be replaced by another event, as long as it will happen before using any of these scripts


### Initialization

Before using any of the methods detailed below trigger `DO SCRIPT FILE -> asset_pools.lua` in your mission. The easiest time for this is immediately after initializsing HeLMS.

## Respawnable On-Call Assets
Allows assets to be (re)spawned via the comms menu with timeouts applied when the unit dies or goes idle
Assets can be coalition specific or available to all
### Usage

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
|MISSION START|DO SCRIPT FILE|helms.lua|
|MISSION START|DO SCRIPT FILE|asset_pools.lua|
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
|MISSION START|DO SCRIPT FILE|helms.lua|
|MISSION START|DO SCRIPT FILE|asset_pools.lua|
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

#### Additional options

The functions in the table below should can be called on an instance returned from `constant_pressure_set.new`. E.g. `myCPS:setIdlePredicate(myFunc)`
where `myROC=respawnable_on_call.new(...`.

|Method|Args|Callback Args|Desc|Example|
|---|---|---|---|---|
|`setIdlePredicate`|`predicate` - `function(groupName) -> Boolean`|`groupName` - name of the monitored group<br> **Returns** true to allow group to go idle |Sets an additional condition for a group to be considered idle. E.g. check whether a player is nearby one of the units in the group (see `ap_utils.getClosestLateralPlayer`)||
|`setDeathPctPredicate`|`percent` - `number`||If a group from a constant pressure set goes idle, but the average health of units in the group (including dead ones) is less than the given percentage, then the group is subject to the death cooldown instead of the idle one.|`constant_pressure_set.new(...):setDeathPctPredicate(60)` - if a group starts with three units but at the end of its mission the two surviving units are at 100% and 50% health then the group will be treated as a dead group for cooldown (avg. health is only 50%)|


**Note** These functions return the calling instance, so they can be chained. E.g. `constant_pressure_set.new(...):setIdlePredicate(myFunc)`	

## Unit Repairman

### Register individual units

`unit_repairman.register` registers a named group to be respawned if it is damaged after a random delay.

Usage: `unit_repairman.register(<groupName>, <minDelaySeconds>, <maxDelaySeconds>, <options>)`

Where
* `<groupName>` is name of group in ME to respawn (ignored if groupData set)

* `<minDelaySeconds>` is the minimum delay for subsequent respawn

* `<maxDelaySeconds>` is the maximum delay for subsequent respawn

* `<options>` is a table containing further options

**Possible options:**

* `<options>.remainingSpawns` Maximum number of timer this unit will be respawned, including the first time triggered by this call.  Leave nil for no-limit
* `<options>.spawnUntil` (s) latest value of mission elapsed time that spawns will occur. Leave nil for no-limit
* `<options>.delaySpawnIfPlayerWithin` lateral distance from the group within which red or blue players block spawn temporarily
* `<options>.retrySpawnDelay` (s) time after which to retry spawn if it's blocked (e.g. by players nearby). Default is 600 (10 minutes)
* `<options>.perDamageRepairSeconds` respawn delay per unit destroyed (or equivalent damage accross the group - e.g. two units damaged 50%). Default is 3600 (1 hour)
* `<options>.baseRepairSeconds` minimum delay to schedule respawn after new damage occurs. Default is 600 (10 minutes)

**Example:**  `unit_repairman.register("Reaper-1",  300, 600, {delaySpawnIfPlayerWithin = 8000})` respawns the unit *Reaper-1* and will repeatedly respawn it every 5 - 10 minutes, unless there is a non-neutral player within 8km of the active unit. If there is a player nearby, the spawn will be attempted again in 10 minutes (default).


### Register units by substring name
unit_repairman.registerRepairmanIfNameContains = function(substring,  minDelaySeconds, maxDelaySeconds, options)

`unit_repairman.registerRepairmanIfNameContains` Has the effect of calling `unit_repairman.register` on each group whose name contains a certain string.

Usage: `unit_repairman.registerRepairmanIfNameContains(<substring>, <minDelaySeconds>, <maxDelaySeconds>, <options>, <replaceSubstring>, <respawnNow>)`

Where
* `<substring>` Substring to search for in group name in ME

* `<minDelaySeconds>` is the minimum randomised delay for respawn (once damage-based repair time elapsed)

* `<maxDelaySeconds>` is the maximum randomised delay for respawn (once damage-based repair time elapsed)

* `<options>` is a table containing further options

* `<replaceSubstring>` will replace the `<substring>` in the group name displayed in the mission. Default is `-`.
* `<respawnNow>` if true, respawn the group now to apply the new group name. Default is true.

**Possible options:**
See options object for `unit_repairman.register`.

**Example:**  `unit_repairman.registerRepairmanIfNameContains("%-repair%-",  300, 600, {delaySpawnIfPlayerWithin = 8000})` If mission contains *unit-repair-1*,  and *unit-repair-2*, these units will independently respawn 5 - 10 minutes after being damaged/destroyed, unless there is a non-neutral player within 8km of that active unit. If there is a player nearby, the spawn will be attempted again in 10 minutes (default). The names of the respawned units will be *unit-1* and *unit-2*.

## Utilities

### Make respawnable on-call units by group name
`ap_utils.makeRocIfNameContains` Create respawn-on-command asset pools for all groups whose name contains a certain substring.
	Add comms menu commands to trigger them.

Usage:
`ap_utils.makeRocIfNameContains (<substring>, <spawnDelay>, <delayWhenIdle>, <delayWhenDead>, <coalitionName>, <replaceSubstring>)`

Where:
* `<spawnDelay>` (s) time between request and activation/respawn

* `<delayWhenIdle>` (s) time before respawn requests allowed when unit goes idle

* `<delayWhenDead>` (s) time before respawn requests allowed when unit is dead
		
* `<coalitionName>` "red", "blue","neutral" or "all" (anything else counts as "all")
		is the coalition name that can spawn group and receive updates about them
		Note: neutral players don't seem to have a dedicated comms menu, so units added with "neutral" will not be spawnable!

* `<replaceSubstring>` will replace the `<substring>` in the group name displayed in the mission. Default is `-`.
		
**Example:**		
`ap_utils.makeRocIfNameContains("%-broc%-" , 60, 180, 600, "Blue")` Makes any group whose name contains "-broc-" respawnable for Blue. (Note that "-" needs to be escaped in lua for substring lookup.)