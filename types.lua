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