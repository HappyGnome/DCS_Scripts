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

At any point in the mission after initialization, activate a training aid with the trigger `DO SCRIPT -> "training_aids.toggleFeature(<featureName>,<modeName>, <enableCommsControl>)"` 

Where
* `<featureName>` is the name of the feature as documented.
* `<modeName>` is the name of the mode (case-sensitive) to set for the training aid
* `<enableCommsControl>` is `true` or `false` to show/hide the comms menu options to enable/disable the aid.

#### Example

|Trigger|Action|Action Detail|
|---|---|---|
|MISSION START|DO SCRIPT FILE|helms.lua|
|MISSION START|DO SCRIPT FILE|training_aids.lua|
|MISSION START|DO SCRIPT|`training_aids.toggleFeature("missileDefeatHints","DISABLED",true)`|

Allows users to activate the missile defeat hints aid, but does not enable it.

### Features

#### missileDefeatHints

When active, this feature displays messages to either the shooter, or the target of shots. The following information is included:
* Range to target (nm)
* Missile mach
* Estimated time to pitbull range ("A") or to impact ("T") - Note that the same pitbull range is used for this estimate. Currently all missiles behave the same, not just Fox-3 missiles.
* Antenna Train Angle of target from the missile "(OUT OF SEEKER)" also displays if ATA > 75°
* Mach difference missile to target. "(DEFEATED)" is displayed when less than a set threshold (default threshold is 0.2M).

##### Configuration 
* Change the defeat mach threshold by setting `training_aids.missile_defeat_mach_diff`. Default is 0.2.
* Change the defeat ATA by setting `training_aids.missile_defeat_ATA`. Default is 75.
* Change the expected pitbull range by setting `training_aids.missile_pitbull_range_nm`. Default is 8.

##### Modes

* `IN_RAIL` - Show target players information about incoming missiles shortly after the shot (missile has left the rails).
* `IN_ACT` - Show target players information about incoming missiles at the time the missile gets within "pitbull range" (approx)
* `OUT` - Shows players information about their own shots.
* `DISABLED` - No players receive any missile defeat information.

##### Example
`training_aids.toggleFeature("missileDefeatHints","IN_RAIL",true)`
