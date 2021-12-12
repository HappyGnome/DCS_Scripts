# Readme

Hitchtrooper provides some simple commands for respawnable ground units, aimed at making transporting troops more useful.

## Download
This readme is for the [latest versions](https://github.com/HappyGnome/DCS_Scripts/releases/tag/Latest), including untagged changes. Other tagged versions are available [here](https://github.com/HappyGnome/DCS_Scripts/tags).

## General Usage

### Prerequisites
All scripts assume the use of the [mist helper library for DCS](https://github.com/mrSkortch/MissionScriptingTools/releases)

Add the trigger `MISSION START -> DO SCRIPT FILE -> mist_*_*_*.lua`
**Before** calls to any of these scripts
\* `MISSION START` can be replaced by another event, as long as it will happen before using any of these scripts

Currently tested with Mist version 4.4.90

### Initialization

Before using any of the methods detailed below trigger `DO SCRIPT FILE -> hitch_trooper.lua` in your mission. The easiest time for this is immediately after initializsing MIST.

## HitchTrooper

### Scripting

#### Add an asset

At any point in the mission after initialization, a group made a respawnable hitchtrooper group for their corresponding coalition as follows `DO SCRIPT -> hitch_trooper.new(<groupName>, <playersCanSpawn>)`

Where
* `<groupName>` is the name of the group to make spawnable (in quotes)
* `<playersCanSpawn>` (optional, default **true**) If false, the players will not be able to (re)spawn this group, or see it as available. The group can be active at the start of the mission or spawns instead of the named group being activated.

**Return:** a new `hitch_trooper` instance

##### Example

In a mission with a group called `Squad-1` set up the triggers:

|Trigger|Action|Action Detail|
|---|---|---|
|MISSION START|DO SCRIPT FILE|mist_4_4_90.lua|
|MISSION START|DO SCRIPT FILE|hitch_trooper.lua|
|MISSION START|DO SCRIPT|`hitch_trooper.new("Squad-1")`|


#### Register units by substring name
At any point, usually mission start, any units can be made into hitchtroopers by looking for a substring in the group name as follows:
`DO SCRIPT ->hitch_trooper.newIfNameContains(<substring>)'

Usage: `DO SCRIPT ->hitch_trooper.newIfNameContains(<substring>, <playersCanSpawn>)`

Where
* `<substring>` Substring to search for in group name in ME
* `<playersCanSpawn>` (optional, default **true**) See above.
**Example:**  `hitch_trooper.newIfNameContains("%-hitch%-")` If mission contains *-hitch-1*, and *-hitch-2*, these units willbecome independent hitchtrooper units.

### Usage
* Hitchtroopers can be called in via the comms menu. Each active or available group is identified by a pair of letters (or more if there are 677+ groups used...). 
* A list of hitchtrooper groups available to spawn and approximate locations can be shown using the `Available` command from the hitchtrooper comms menu.
* Units can be commanded using their comms submenu, and map mark points.
#### Commands

|Comms Command|Description|
|---|---|
|Call in|Spawn/respawn the group|
|Evac|Switch ROE to return fire and retreat to evac point if designated. Once there the group will await transport|
|Smoke|Drop a smoke near the groups location (subject to an ammo constraint). Ammo can be replenished at bases (but not trucks).|
|Sitrep|Print info about group status and actions|
|Stand down|If a friendly base is nearby the group despawns after a delay, and will shortly be available for respawn.|

For directing a group use their digraph followed by a short command word in a mark label on the f10 map:
|Command|Example|Description|
|---|---|---|
|atk|`aa atk`|Weapons free and move to this point|
|evac|`aa evac`|Set evac location (use comms menu to begin evac)|
|rec|`aa rec`|Switch ROE to return fire and move to point (practically similar to evac for now).|

**Responding to events**
* If hit too many times the group will attempt to return to an evac point and request medevac
* If fired upon when not attacking, the group will attempt to retreat from the threat.
* If entire group is KIA, respawn will be possible only after a long delay (hence it can be worth completing the medevac if requested).

