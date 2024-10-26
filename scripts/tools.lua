--
-- tools. Some of this code has been picked out of stdlib
--

local const = require ('scripts.constants')

--- @class EvenPickierDolliesTools
local tools = {}

--- @param player LuaPlayer
--- @param position MapPosition
--- @param silent? boolean
function tools.flying_text(player, text, position, silent)
    player.create_local_flying_text { text = text, position = position }
    if not silent then player.play_sound { path = "utility/cannot_build", position = player.position, volume = 1 } end
end

--- @param entity LuaEntity
--- @param cheat_mode boolean
--- @return boolean 
function tools.allow_moving(entity, cheat_mode)
    -- definitely blacklisted by either internal list or mod registration
    local blacklisted = const.blacklist_types[entity.type] or storage.blacklist_names[entity.name]
    if blacklisted then return false end
    
    -- if it is not in the cheat whitelist, allow moving
    local only_in_cheat = const.whitelist_cheat_types[entity.type]
    if only_in_cheat then return cheat_mode end

    -- otherwise, allow moving
    return true
end

--- @param index integer
function tools.pdata(index)
    storage.players = storage.players or {}
    storage.players[index] = storage.players[index] or {}
    return storage.players[index]
end

--- @param pdata EvenPickierDolliesPlayerData
--- @param entity LuaEntity
--- @param tick uint
--- @param save_time uint
function tools.save_entity(pdata, entity, tick, save_time)
    pdata.dolly = entity
    pdata.dolly_tick = tick
end

--- @param player LuaPlayer
--- @param pdata EvenPickierDolliesPlayerData
--- @param tick uint
--- @param save_time uint
--- @return LuaEntity|nil
function tools.get_entity_to_move(player, pdata, tick, save_time)
    -- do not remember the last moved entity. Return either the current selection or nil.
    if save_time == 0 then return player.selected end

    -- clean out current entity if it is invalid or expired
    if pdata.dolly and (not pdata.dolly.valid or tick > (pdata.dolly_tick + second * save_time)) then pdata.dolly = nil end

    -- if the player has not selected anything, return the current entity or nil
    if not player.selected then return pdata.dolly end

    -- if the selected object can not be moved and there is a current object, return that, otherwise the selected object
    if pdata.dolly and not tools.allow_moving(player.selected, player.cheat_mode) then
        return pdata.dolly
    else
        return player.selected
    end
end

--- Returns true if the wires can reach.
--- @param entity LuaEntity
--- @return boolean
function tools.can_wires_reach(entity)
    local wire_connectors = entity.get_wire_connectors(false) or {}
    for _, wire_connector in pairs(wire_connectors) do
        for _, connection in pairs(wire_connector.connections) do
            if not wire_connector.can_wire_reach(connection.target) then return false end
        end
    end
    return true
end

--- @param player LuaPlayer
--- @return uint dolly_save_entity
function tools.get_save_entity_setting(player)
    return player.mod_settings["dolly-save-entity"].value --[[@as uint]]
end

--- @param entity LuaEntity
--- @param position MapPosition
function tools.safe_teleport(entity, position)

    -- this is a workaround for https://forums.factorio.com/viewtopic.php?f=7&t=117719
    -- my suspicion is that this is a bug with the new fluid system; there is nothing in the
    -- release notes that teleporting (moving) an entity with a fluid box would clear it.

    local fluids = {}

    if #entity.fluidbox > 0 then
        for i = 1, #entity.fluidbox, 1 do
            local fluid = entity.get_fluid(i)
            table.insert(fluids, fluid)
        end
    end

    if not entity.teleport(position) then return false end

    if #fluids then
        for i = 1, #fluids, 1 do
            if fluids[i] then
                entity.set_fluid(i, fluids[i])
            end
        end
    end

    return true
end

-- ----------------------
-- stdlib stuff
-- ----------------------

--- @param direction defines.direction
--- @param distance number
--- @return MapPosition
function tools.direction_to_vector(direction, distance)
    local vector = util.direction_vectors[direction] or { 0, 0 }
    return { x = vector[1] * distance, y = vector[2] * distance }
end

--- @param direction defines.direction
--- @return defines.direction new_direction
function tools.direction_next(direction)
    return (direction + 4) % 16
end

--- @param direction defines.direction
--- @return defines.direction new_direction
function tools.direction_previous(direction)
    return (direction - 4) % 16
end

--- @param pos1 MapPosition
--- @param pos2 MapPosition
--- @return MapPosition
function tools.position_add(pos1, pos2)
    return { x = pos1.x + pos2.x, y = pos1.y + pos2.y }
end

--- @param pos1 MapPosition
--- @param pos2 MapPosition
--- @return MapPosition
function tools.position_subtract(pos1, pos2)
    return { x = pos1.x - pos2.x, y = pos1.y - pos2.y }
end

--- @param pos MapPosition
--- @param direction defines.direction
--- @param distance number
function tools.position_translate(pos, direction, distance)
    direction = direction or 0
    distance = distance or 1
    return tools.position_add(pos, tools.direction_to_vector(direction, distance))
end

--- @param pos MapPosition
--- @param radius number
--- @return BoundingBox
function tools.position_expand_to_area(pos, radius)
    radius = radius or 1

    local left_top = { x = pos.x - radius, y = pos.y - radius }
    local right_bottom = { x = pos.x + radius, y = pos.y + radius }

    return { left_top = left_top, right_bottom = right_bottom }
end

--- @param area BoundingBox
--- @param direction defines.direction
--- @param distance number
--- @return BoundingBox
function tools.area_translate(area, direction, distance)
    return {
        left_top = tools.position_translate(area.left_top, direction, distance),
        right_bottom = tools.position_translate(area.right_bottom, direction, distance),
    }
end

--- @param area BoundingBox
--- @param amount number
--- @return BoundingBox
function tools.area_expand(area, amount)
    local offset = { x = amount, y = amount }
    return {
        left_top = tools.position_subtract(area.left_top, offset ),
        right_bottom = tools.position_add(area.right_bottom, offset),
    }
end

return tools