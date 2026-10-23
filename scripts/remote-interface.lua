--
-- Even Pickier Dollies API
---

local const = require('scripts.constants')

---@class EvenPickierDolliesRemoteInterface: table<string, function>
---@field event_id defines.events?
local RemoteInterface = {
    event_id = nil,
}

---@return defines.events event_id The event id to use when registering for dollies events.
function RemoteInterface.dolly_moved_entity_id()
    if not RemoteInterface.event_id then
        RemoteInterface.event_id = assert(prototypes.custom_event[const.event_name]).event_id
    end
    return RemoteInterface.event_id
end

---@param entity_name string
---@param distance number?
---@return boolean
function RemoteInterface.add_oblong_name(entity_name, distance)
    storage.oblong_names = storage.oblong_names or {}
    local proto = prototypes.entity[entity_name]
    if not proto then return false end

    storage.oblong_names[entity_name] = distance or 0.5
    return true
end

---@param entity_name string
---@return boolean
function RemoteInterface.remove_oblong_name(entity_name)
    storage.oblong_names = storage.oblong_names or {}
    if not storage.oblong_names[entity_name] then return false end

    storage.oblong_names[entity_name] = nil
    return true
end

---@return table<string, number>
function RemoteInterface.get_oblong_names()
    storage.oblong_names = storage.oblong_names or {}
    return storage.oblong_names
end

---@param entity_name string
---@return boolean
function RemoteInterface.add_blacklist_name(entity_name)
    storage.blacklist_names = storage.blacklist_names or {}
    local proto = prototypes.entity[entity_name]
    if not proto then return false end

    storage.blacklist_names[entity_name] = true
    return true
end

---@param entity_name string
---@return boolean
function RemoteInterface.remove_blacklist_name(entity_name)
    storage.blacklist_names = storage.blacklist_names or {}
    if not storage.blacklist_names[entity_name] then return false end

    storage.blacklist_names[entity_name] = nil
    return true
end

---@return table<string, true>
function RemoteInterface.get_blacklist_names()
    storage.blacklist_names = storage.blacklist_names or {}
    return storage.blacklist_names
end

return RemoteInterface
