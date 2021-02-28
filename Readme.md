# Readme

This repository contains some lua scripts for making DCS World missions.

## General Usage
All scripts assume the use of the [mist helper library for DCS](https://github.com/mrSkortch/MissionScriptingTools/releases)

Add the trigger `MISSION START -> DO SCRIPT FILE -> mist_*_*_*.lua`
**Before** calls to any of these scripts
\* `MISSION START` can be replaced by another event, as long as it will happen before using any of these scripts

Currently tested with Mist version 4.4.90

## Respawnable Assets
Allows assets to be (re)spawned via the comms menu with timeouts applied when the unit dies or goes idle
Assets can be coalition specific or available to all
### Usage

Initialization
=====
Call `DO SCRIPT FILE -> respawnable_on_call.lua`

Add an assets
====
At any point in the mission after initialization, a group can be added by calling `DO SCRIPT -> respawnable_on_call.addGroup(<groupName>, <spawnDelay>, <delayWhenIdle>, <delayWhenDead>, <coalitionName>)`

Where
`<groupName>` is the name of the group to make spawnable (in quotes)
**N.B.** This group should have late activation - do not activate it yourself!

`<spawnDelay>` is the time (seconds) it takes for the group to spawn after it is requested

`<delayWhenIdle>` is the approximate time (seconds) before the group can be requested after it finishes its mission 
(e.g. time delay after declaring RTB)

`<delayWhenDead>` is the approximate time (seconds) before the group can be requested after it dies or is otherwise despawned

`<coalitionName>` should be `"red"` `"blue"` or `"all"` to declare which side will be able to call in the asset (it doesn't have to match the allegience of the asset)

Example
=====

In a mission with a group called `Aerial-2` set up the triggers:

|Trigger|Action|Action Detail|
|=======|======|============|
|MISSION START|DO SCRIPT FILE|mist_4_4_90.lua|
|MISSION START|DO SCRIPT FILE|respawnable_on_call.lua|
|MISSION START|DO SCRIPT|respawnable_on_call.addGroup("Aerial-2",60,300,300,"red")|
|====|====|====


Then the red coalition will have a "Respawnable Assets" sub-menu in the `F10` comms menu,
from which they can request that `Aerial-2` is respawned. If available it will activate 
60 seconds after user selects this option. Once the group dies or goes RTB (it may take a minute for the script to detect this) a cooldown os 5 minutes (300 seconds) begins, during which time the group can not be respawned - players instead receive a message saying when the group will be available again.
