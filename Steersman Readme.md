# Readme

Steersman allows automation of a carrier group to maintain a certain wind over it's angled deck, while staying within a zone and recovering downwind when players are not near

## Download
See [tagged versions](https://github.com/HappyGnome/DCS_Scripts/tags) of this repository. 

This readme is for v1.5.3a of my DCS scripts.

## General Usage

### Prerequisites
All scripts assume the use of the [mist helper library for DCS](https://github.com/mrSkortch/MissionScriptingTools/releases)

Add the trigger `MISSION START -> DO SCRIPT FILE -> mist_*_*_*.lua`
**Before** calls to any of these scripts
\* `MISSION START` can be replaced by another event, as long as it will happen before using any of these scripts

Currently tested with Mist version 4.4.90

### Initialization

Before using any of the methods detailed below trigger `DO SCRIPT FILE -> steersman.lua` in your mission. The easiest time for this is immediately after initializsing MIST.

## Steersman

### Scripting

#### Add a carrier group

At any point in the mission after initialization, a naval group can be automated within a specified zone using the trigger `DO SCRIPT -> steersman.new(<groupName>, <zoneName>)` 

Where
* `<groupName>` is the name of the group to make spawnable (in quotes). The carrier should idealy be the lead unit of the group.
* `<zoneName>` is the name of the zone to patrol (in quotes). This must be a circular zone.

**Return:** a new `steersman` instance

##### Example

In a mission with a carrier group called `CV-1`, and a circular zone called `CV-1-AO` set up the triggers:

|Trigger|Action|Action Detail|
|---|---|---|
|MISSION START|DO SCRIPT FILE|mist_4_4_90.lua|
|MISSION START|DO SCRIPT FILE|steersman.lua|
|MISSION START|DO SCRIPT|`steersman.new("CV-1", "CV-1-AO")`|

#### Additional options

The functions in the table below should can be called on an instance returned from `steersman.new`. E.g. `myCVN:setDesiredHeadwindKts(30)`
where `myCVN=steersman.new(...)`.

|Method|Args|Callback Args|Desc|Example|
|---|---|---|---|---|
|`setDesiredHeadwindKts`|`speed` - `kts`||Sets desired wind over the angled deck while in ops mode. Default is ~31kts|`myCVN:setDesiredHeadwindKts(30)`|
|`setDeckAngleCCWDeg`|`angle` - `degrees`||Sets angle of landing deck measured counter clockwise. Default is 10|`myCVN:setDeckAngleCCWDeg(10)`|
|`setMinCruiseSpeedKts`|`speed` - `kts`||Sets minimum forward speed of the boat while in ops mode. Default is ~14|`myCVN:setMinCruiseSpeedKts(8)`|



**Note** These functions return the calling instance, so they can be chained. E.g. `steersman.new(...):setMinCruiseSpeedKts(13):setDesiredHeadwindKts(25)`	

### Usage
* Once created as above, the carrier's route will periodically update. 
* If there are friendly players nearby, or on an inbound course with an ETA to within ~50nm of the carrier less than a few minutes, the carrier will enter or maintain ops mode
* When entering ops mode the carrier will start a turn to achieve the desired wind over the deck as accurately as possible. 
* Out of ops mode, the carrier will zig-zag downwind to make space to run upwind again. (Zig-zagging helps to reduce the time to turn back upwind).
* The carrier will not set waypoints outside of its allocated zone, so it will stop when reaching the edge of the zone.

