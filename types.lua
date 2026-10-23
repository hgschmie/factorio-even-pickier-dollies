---@meta
----------------------------------------------------------------------------------------------------
--- class definitions
----------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------
--- prototypes
----------------------------------------------------------------------------------------------------

---@class epd.ModData : table<string, AnyBasic>
---@field blacklist_names table<string, boolean>

----------------------------------------------------------------------------------------------------
--- constants.lua
----------------------------------------------------------------------------------------------------

---@class epd.TransporterControl
---@field control_fields string[]?
---@field control_objects string[]?
---@field fields string[]?
---@field filters boolean?

----------------------------------------------------------------------------------------------------
--- interface.lua
----------------------------------------------------------------------------------------------------

---@class EvenPickierDolliesRemoteInterfaceDollyMovedEvent: EventData
---@field player_index uint32
---@field moved_entity LuaEntity
---@field start_pos MapPosition.struct
---@field start_direction defines.direction
---@field start_unit_number uint64?

----------------------------------------------------------------------------------------------------
--- control.lua
----------------------------------------------------------------------------------------------------

---@class EvenPickierDolliesStorage
---@field players {[uint]: EvenPickierDolliesPlayerData}
---@field blacklist_names {[string]: true}
---@field oblong_names {[string]: number}

---@class EvenPickierDolliesPlayerData
---@field dolly_tick uint
---@field dolly LuaEntity?

---@class EvenPickierDolliesMoveEvent
---@field player LuaPlayer
---@field pdata EvenPickierDolliesPlayerData
---@field tick integer
---@field entity LuaEntity
---@field save_time uint
---@field direction defines.direction?
---@field rotate defines.direction?
---@field distance number
