# QuickSuppression Readme

A simple addition to ground unit AI, that causes groups attacked by an aircraft to stop moving and attacking for a time.

## Download
This readme is for the [latest versions](https://github.com/HappyGnome/DCS_Scripts/releases/tag/Latest), including untagged changes. Other tagged versions are available [here](https://github.com/HappyGnome/DCS_Scripts/tags).

## General Usage

### Prerequisites

#### HeLMS
Add the trigger `MISSION START -> DO SCRIPT FILE -> helms.lua`
**Before** calls to any of these scripts
\* `MISSION START` can be replaced by another event, as long as it will happen before using any of these scripts


### Initialization

Before using any of the methods detailed below trigger `DO SCRIPT FILE -> quick_suppression_script.lua` in your mission. The easiest time for this is immediately after initializsing HeLMS.

## Usage
No further commands are need to be called. Running `quick_suppression_script.lua` in the mission has the following key effects:

* When a ground unit is hit by weapons from an airplane or helicopter, the AI of the unit's group is deactivated. The group becomes *suppressed*.
* While suppressed, the group will not move or fire.
* The AI of the group is re-enabled after a random delay, and the group continues with it's original task.
* If the group is hit again while disabled, it MAY stay suppressed for a longer time. However, if it is hit multiple times in quick succession, the delay will only be updated once.

## Configuration options

### Suppression times
Groups are suppressed for a random time between two values. The min and max time can be set in a `DO SCRIPT` trigger by setting the following values:
`quick_suppression_script.defaultMinSuppressionSeconds`, and
`quick_suppression_script.defaultMaxSuppressionSeconds`.

E.g. `quick_suppression_script.defaultMinSuppressionSeconds = 30`
`quick_suppression_script.defaultMaxSuppressionSeconds = 300`

### Re-suppression cooldown
The re-activation time of a group is not updated more than once within a certain cooldown. E.g. with a cooldown of 30 seconds, hitting a group within 30 seconds of original suppression will have no effect, but hitting it after 30 seconds would potentially cause the group to stay inactive for longer (depending on the random suppression time).

To change this cooldown globally, update the following value in a `DO SCRIPT` trigger:
`quick_suppression_script.resuppressionCooldownSeconds`

E.g. `quick_suppression_script.resuppressionCooldownSeconds = 30`