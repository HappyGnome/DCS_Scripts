# Games Readme

These game scripts add some game modes to DCS.

## Download
This readme is for the [latest versions](https://github.com/HappyGnome/DCS_Scripts/releases/tag/Latest), including untagged changes. Other tagged versions are available [here](https://github.com/HappyGnome/DCS_Scripts/tags).

## Include HeLMS
All game scripts below require HeLMS to be initialized first.

Add the trigger `MISSION START -> DO SCRIPT FILE -> helms.lua`
**Before** calls to any of the game scripts
\* `MISSION START` can be replaced by another event, as long as it will happen before using any of these scripts

## King Of The Hill

Before using any of the methods detailed below trigger `DO SCRIPT FILE -> king_of_the_hill.lua` in your mission. The easiest time for this is immediately after initializsing HeLMS.

### Scripting

#### Add a game

To add a game that can be started from the comms menu, add a trigger zone to be the arena for the game, then add the following trigger
`DO SCRIPT -> king_of_the_hill.AddGame(<zoneName>, <gameName>, <objectiveScore>)` 

Where
* `<zoneName>` is the name of the trigger zone. The crown spawns in this zone and the king must stay in this zone.
* `<gameName>` is the name of the game in the comms menu
* `<objectiveScore>` First team to this score wins! Optional, default 1800.

#### Rules
* The crown spawns at a random point in the arena. Marked by fire and smoke.
* Units flying over the crown become 'king'
* The king scores 1 point per second times their current multiplier for their team
* First team over a certain score (can be configured per game) wins
* If the king leaves the zone or lands the crown is lost and will respawn after a short delay
* If the king is hit by an opponent and dies or leaves the zone, the opponent that scored the kill becomes king
* If the king kills an opponent the current multiplier increases by 1. This is reset when the crown is lost.
* The current king is robed in flares and smoke

##### Example

In a mission with a trigger zone called `Zone1` set up the triggers:

|Trigger|Action|Action Detail|
|---|---|---|
|MISSION START|DO SCRIPT FILE|helms.lua|
|MISSION START|DO SCRIPT FILE|king_of_the_hill.lua|
|MISSION START|DO SCRIPT|`king_of_the_hill.AddGame('Zone1', "Game1")`|

Players can start the game via the comms menu. `Other > Games > Game1 > First to 1800`