# Training Aids Readme

The Training Aids module adds some functionality specific for building training/practice missions. For example, cues to help situational awareness when training missile defense.

## Download
This readme is for the [latest versions](https://github.com/HappyGnome/DCS_Scripts/releases/tag/Latest), including untagged changes. Other tagged versions are available [here](https://github.com/HappyGnome/DCS_Scripts/tags).

## General Usage

### HeLMS
Add the trigger `MISSION START -> DO SCRIPT FILE -> helms.lua`
**Before** calls to any of these scripts

\* `MISSION START` can be replaced by another event, as long as it will happen before using any of these scripts

## Initialization

Before using any of the methods detailed below trigger `DO SCRIPT FILE -> training_aids.lua` in your mission. The easiest time for this is immediately after initializsing HeLMS.

### Toggle a training aid

At any point in the mission after initialization, activate a training aid with the trigger `DO SCRIPT -> "training_aids.toggleFeature(<featureName>,<enable>, <enableCommsControl>)"` 

Where
* `<featureName>` is the name of the feature as documented.
* `<enable>` is `true` or `false` to activate/de-activate the feature right away
* `<enableCommsControl>` is `true` or `false` to show/hide the comms menu options to enable/disable the aid.

#### Example

|Trigger|Action|Action Detail|
|---|---|---|
|MISSION START|DO SCRIPT FILE|helms.lua|
|MISSION START|DO SCRIPT FILE|training_aids.lua|
|MISSION START|DO SCRIPT|`training_aids.toggleFeature("missileDefeatHints",false,true)`|

Allows users to activate the missile defeat hints aid, but does not enable it.

### Features

#### missileDefeatHints

When active, this feature displays a message to the user when a missile fired at them is destroyed, or when the missile's mach number is less than the target's mach number plus a specified threshold (default threshold is 0.2M).

##### Configuration 
Change the defeat mach threshold by setting `training_aids.missile_defeat_mach_diff`. Default is 0.2.

##### Example
`training_aids.toggleFeature("missileDefeatHints",false,true)`
