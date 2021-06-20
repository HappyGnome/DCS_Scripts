# Changelog
 
## v1.3.1a
* Added ap_utils.makeRocIfNameContains
* Added overflow paging for comms menus
* Added unit_repairman helper to schedule periodic respawns of named units
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