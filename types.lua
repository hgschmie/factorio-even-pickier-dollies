---@meta
----------------------------------------------------------------------------------------------------
--- class definitions
----------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------
--- interface.lua
----------------------------------------------------------------------------------------------------

--- @class EventData.PickerDollies.dolly_moved_event: EventData
--- @field player_index uint
--- @field moved_entity LuaEntity
--- @field start_pos MapPosition

--- @class EvenPickierDolliesRemoteInterface
--- @field dolly_moved_entity_id fun(): uint
--- @field add_oblong_name fun(entity_name: string): boolean
--- @field remove_oblong_name fun(entity_name: string): boolean
--- @field get_oblong_names fun(): {[string]: true}
--- @field add_blacklist_name fun(entity_name: string): boolean
--- @field remove_blacklist_name fun(entity_name: string): boolean
--- @field get_blacklist_names fun(): {[string]: true}

----------------------------------------------------------------------------------------------------
--- control.lua
----------------------------------------------------------------------------------------------------

--- @class PickerDollies.storage
--- @field players {[uint]: PickerDollies.pdata}
--- @field blacklist_names {[string]: true}
--- @field oblong_names {[string]: true}

--- @class PickerDollies.pdata
--- @field dolly_tick uint
--- @field dolly LuaEntity?

--- @class EventData.PickerDollies.CustomInputEvent: EventData.CustomInputEvent
--- @field direction defines.direction
--- @field distance number
--- @field tiles_away uint
--- @field start_pos MapPosition
--- @field start_direction? defines.direction
--- @field target_direction? defines.direction
--- @field save_time? uint
