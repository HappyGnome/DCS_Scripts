# Changelog

## Latest
* Quick suppression script: Randomized reset times
* Added HeLMS effect category. Added perpetual smoke effects.
## 1.10a
* Added removeCommsCallback to HeLMS
* Added optional static object respawns/despawns to the zonal spawning methods
* Fixed undefined constant in asset_pools
* Added support for non-circular zones for HeLMS zone-based respawns
* Added `helms.ai` and `helms.ai.setAlarmState`
* KOTH 1.3: Kill detection rule improvements
* KOTH 1.3: Crown spawn zone can be a multiple of the zone of play
* KOTH 1.3: Fixed inability to create multiple games with the same name
* HeLMS: Fixed DespawnGroupByName bug
* Added quick suppression script
## 1.9a
* Improved KOTH scoreboard and added disappearing smoke workaround
* Added steersman zig-zag enable/disable function
* Added "Hold Position" / "Resume Sailing" options to manually controlled steersman groups
* Added random trigger flag and simplifed comms scripting utilities for HeLMS
* Added respawn in zone methods for HeLMS
* Added limited methods to show/hide drawings dynamically
## 1.8a
* Created common comms management logic in HeLMS
* Steersman comms control option added
* Added separate asset pool activity detection for non-air groups (CPS and ROC now compatible with these groups)
* Added filters to CPS controllable from the comms menu.
* Added king-of-the hill
## 1.7a
* Mission examples added
* Added late activation handling for unit_repairman
* Added deregistration methods for unit_repairman
* Added group aliasing and unit name normalisation in HeLMS
* Added auto-stripping of magic strings in group names. Affects names of groups created with:
    * `unit_repairman.registerRepairmanIfNameContains`
    * `ap_utils.makeRocIfNameContains`
    * `hitch_trooper.newIfNameContains`
* Fixed bug with generated group names in HeLMS
* Added ap_utils wrappers for helms methods for backwards compatibility
* Added damage dependent respawn times for unit_repairman
* Added zone reuse and direction enforcement for steersman
* Changed default deck angle to 9 degrees for steersman
* Added initial respawn for repairman groups
* Added despawning constant_pressure groups on a timer once they go idle
## 1.6a
* Replaced MIST with HeLMS
* Added idle detection for asset pools based on fuel state
## 1.5.7
* Improved steersman logic
## 1.5.6a
* Added evac for hitchtroopers without an evac point set
* Added one-time hitchtroopers that can be activated by mission triggers rather than the comms menus
* Added instruction hints in the hitchtroopers 'Available' comms item
* Added alternation of alarm state for hitchtroopers in recon mode
* Improved target intel from hitchtroopers added upon task change
* Improved target intel descriptors
##1.5.5a
* Added waypoint 1 task copying for steersman
* Added map mark generation for hitch troopers
* Added default frequencies for asset pool groups
## 1.5.4a
* Added meters for short distances in hitchtrooper sitrep
## 1.5.3a
* Added Steersman
## 1.5.2a
* Exception handling when spawning a group in a pool is improved
* Fixed error with repeated spawning of a group
* Added setDeathPredicate and setDeathPctPredicate
## 1.5.1a
* Unit repairman: added poll so that respawns are only scheduled once group is damaged/destroyed
## 1.5a
* Added HitchTroopers
## 1.4.1a
* Restriction on unit_repairman for nearby player units applies to start point as well as current position.
## 1.4a
* Added unit_repairman helper to schedule periodic respawns of named units
## v1.3.1a
* Added ap_utils.makeRocIfNameContains
* Added overflow paging for comms menus
## v1.3a
* Combined all scripts into one file
* Fixed ap_utils.generateGroups issue with airbourne spawns
* Added optional predicate for groups going idle in constant_pressure_set
* Added ap_utils.getClosestLateralPlayer to help build predicates based on distance between player and units of a group
* Idle check now checks all units in the group
## v1.2a
* Respawnable_on_call.add should be called respawnable_on_call.new -- Fixed
* Added respawnable_on_call:delete 
* Added constant_pressure_set:delete
* Added ability to create groups  with randomly selected units and missions (ap_utils.generateGroups)
* Added option to set callbacks from respawnable_on_call events

## v1.1a
* Added constant_pressure_set
* Split code across multiple lua files - installation instructions updated
* Renamed respawnable_on_call.addGroup to respawnable_on_call.new, for consistency
* Added changelog

## v1.0a
* Initial version