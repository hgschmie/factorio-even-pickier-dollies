--
-- runtime code
--

local event_id = script.generate_event_name()

local epd = {
    event_id = event_id,
    remote_interface = require('interface')(event_id)
}

remote.add_interface('PickerDollies', epd.remote_interface)

assert(remote.interfaces['PickerDollies']['dolly_moved_entity_id'])

--- @param t table
--- @return table
local function table_copy(t)
    local t2 = {}
    for k, v in pairs(t) do t2[k] = v end
    return t2
end

--- @generic K
--- @param t {[uint]: K}
--- @return {[K]: true}
local function array_to_dict(t)
    local t2 = {}
    for _, v in pairs(t) do t2[v] = true end
    return t2
end

--- Entity types that can not be moved even in cheat_mode.
local blacklist_types = array_to_dict {

    -- rails and train stuff
    "straight-rail", "half-diagonal-rail", "curved-rail-a", "curved-rail-b", "legacy-straight-rail", "legacy-curved-rail",
    "elevated-curved-rail-a", "elevated-curved-rail-b", "elevated-half-diagonal-rail", "elevated-straight-rail",
    "rail-ramp", "rail-support", "train-stop", "rail-signal", "rail-chain-signal", "rail-remnants",
    "locomotive", "cargo-wagon", "artillery-wagon", "fluid-wagon",
    -- robots
    "construction-robot", "logistic-robot", "combat-robot",
    -- rockets and space stuff
    "rocket-silo-rocket", "rocket-silo-rocket-shadow", "cargo-landing-pad", "cargo-pod",
    -- belts and containers
    "linked-belt", "underground-belt", "temporary-container",
    -- environment
    "cliff", "tree", "resource", "explosion", "particle-source", "fire", "sticker", "stream", "beam", "artillery-flare", "projectile",
    -- internal stuff
    "item-request-proxy", "tile-ghost", "item-entity", "deconstructible-tile-proxy", "arrow", "highlight-box", "entity-ghost", "speech-bubble", "smoke-with-trigger",
    -- misc
    "spider-leg",
}

--- Entity types that can only be moved in cheat_mode.
local blacklist_cheat_types = array_to_dict { "character", "unit", "unit-spawner", "car", "spider-vehicle", "simple-entity", "corpse", "character-corpse" }

--- Default entity names to blacklist from moving. Stored in global and can be modified by the user via interface.
local blacklist_names = array_to_dict { "pumpjack" }

--- Default entity names with none-square bounding boxes. Stored in global and can be modified by the user via interface.
local oblong_names = array_to_dict { "pump", "arithmetic-combinator", "decider-combinator", "selector-combinator", }

local input_to_direction = {
    ["dolly-move-north"] = defines.direction.north,
    ["dolly-move-east"]  = defines.direction.east,
    ["dolly-move-south"] = defines.direction.south,
    ["dolly-move-west"]  = defines.direction.west
}

local oblong_diags = {
    [defines.direction.north] = defines.direction.northeast,
    [defines.direction.south] = defines.direction.northeast,
    [defines.direction.west]  = defines.direction.southwest,
    [defines.direction.east]  = defines.direction.southwest
}

--- @param player LuaPlayer
--- @param position MapPosition
--- @param silent? boolean
local function flying_text(player, text, position, silent)
    player.create_local_flying_text { text = text, position = position }
    if not silent then player.play_sound { path = "utility/cannot_build", position = player.position, volume = 1 } end
end

--- @param entity LuaEntity
--- @param cheat_mode? boolean
--- @return boolean
local function is_blacklisted(entity, cheat_mode)
    local listed = blacklist_types[entity.type] or storage.blacklist_names[entity.name]
    if cheat_mode then return listed end
    return listed or blacklist_cheat_types[entity.type]
end

--- @param pdata PickerDollies.pdata
--- @param entity LuaEntity
--- @param tick uint
--- @param save_time uint
local function save_entity(pdata, entity, tick, save_time)
    if save_time == 0 then return end
    pdata.dolly = entity
    pdata.dolly_tick = tick
end

--- @param player LuaPlayer
--- @param pdata PickerDollies.pdata
--- @param tick uint
--- @param save_time uint
--- @return LuaEntity|nil
local function get_saved_entity(player, pdata, tick, save_time)
    if save_time == 0 then return player.selected end

    if pdata.dolly and (not pdata.dolly.valid or tick > (pdata.dolly_tick + 60 * save_time)) then pdata.dolly = nil end

    local selected = player.selected
    if selected then
        if pdata.dolly and blacklist_types[selected.type] then
            return pdata.dolly
        end
        return selected
    end
    return pdata.dolly
end

--- Returns true if the wires can reach.
--- @param entity LuaEntity
--- @return boolean
local function can_wires_reach(entity)
    local wire_connectors = entity.get_wire_connectors(false) or {}
    for _, wire_connector in pairs(wire_connectors) do
        for _, connection in pairs(wire_connector.connections) do
            if not wire_connector.can_wire_reach(connection.target) then return false end
        end
    end
    return true
end

-- ----------------------
-- stdlib stuff
-- ----------------------

local function pdata(index)
    storage.players = storage.players or {}
    if storage.players[index] then
        return storage.players[index]
    end

    local player_data = {
        index = index
    }

    storage.players[index] = player_data

    local player = game.get_player(index)
    if player then
        player_data.name = player.name
        player_data.force = player.force.name
    end

    return player_data
end

local vectors = {
    [defines.direction.north]     = { x = 0, y = -1 },
    [defines.direction.northeast] = { x = 1, y = -1 },
    [defines.direction.east]      = { x = 1, y = 0 },
    [defines.direction.southeast] = { x = 1, y = 1 },
    [defines.direction.south]     = { x = 0, y = 1 },
    [defines.direction.southwest] = { x = -1, y = 1 },
    [defines.direction.west]      = { x = -1, y = 0 },
    [defines.direction.northwest] = { x = -1, y = -1 },
}
local function direction_to_vector(direction, distance)
    local offset = vectors[direction] or { x = 0, y = 0 }
    return { x = offset.x * distance, y = offset.y * distance }
end

local function direction_opposite(direction)
    return (direction + 8) % 16
end

local function direction_next(direction, eight_way)
    return (direction + (eight_way and 2 or 4)) % 16
end

local function position_add(pos1, pos2)
    return { x = pos1.x + pos2.x, y = pos1.y + pos2.y }
end

local function position_subtract(pos1, pos2)
    return { x = pos1.x - pos2.x, y = pos1.y - pos2.y }
end

local function position_translate(pos, direction, distance)
    direction = direction or 0
    distance = distance or 1
    return position_add(pos, direction_to_vector(direction, distance))
end

local function position_expand_to_area(pos, radius)
    radius = radius or 1

    local left_top = { x = pos.x - radius, y = pos.y - radius }
    local right_bottom = { x = pos.x + radius, y = pos.y + radius }

    return { left_top = left_top, right_bottom = right_bottom }
end

local function area_translate(area, direction, distance)
    return {
        left_top = position_translate(area.left_top, direction, distance),
        right_bottom = position_translate(area.right_bottom, direction, distance),
    }
end

local function area_expand(area, amount)
    local offset = { x = amount, y = amount }
    return {
        left_top = position_subtract(area.left_top, offset ),
        right_bottom = position_add(area.right_bottom, offset),
    }
end


--- @param event EventData.CustomInputEvent
function epd:move_entity(event)
    --- @type LuaPlayer?, PickerDollies.pdata
    local player, pdata = game.get_player(event.player_index), pdata(event.player_index)
    if not player then return end

    local save_time = event.save_time or player.mod_settings["dolly-save-entity"].value --[[@as uint]]
    local entity = get_saved_entity(player, pdata, event.tick, save_time)
    if not entity then return end

    local cheat_mode = player.cheat_mode

    --- Check non cheat_mode player in range.
    if not (cheat_mode or player.can_reach_entity(entity)) then
        return flying_text(player, { "cant-reach" }, entity.position)
    end

    --- Check if entity is blacklisted, cheat_mode allows moving more entities.
    if is_blacklisted(entity, cheat_mode) then
        local text = { "picker-dollies.cant-be-teleported", entity.localised_name }
        return flying_text(player, text, entity.position)
    end

    --- Only move entities of the same force unless cheat_mode is enabled.
    local entity_force = entity.force --[[@as LuaForce]]
    if not (cheat_mode or entity_force == player.force) then
        local text = { "picker-dollies.wrong-force", entity.localised_name }
        return flying_text(player, text, entity.position)
    end

    local surface = entity.surface
    local start_pos = event.start_pos or entity.position -- Where we started from in case we have to return it

    --- Make sure there is not a rocket present.
    --- @todo Move the rocket-silo-rocket to the correct spot.
    if surface.find_entity("rocket-silo-rocket", start_pos) then
        return flying_text(player, { "picker-dollies.rocket-present", entity.localised_name }, start_pos)
    end

    local prototype = entity.prototype
    local direction = event.direction or input_to_direction[event.input_name] -- Direction to move the source
    if not direction then return end

    local distance = (event.distance or 1) * prototype.building_grid_bit_shift   -- Distance to move the source, defaults to 1
    local target_direction = event.target_direction or entity.direction
    local target_pos = position_translate(start_pos, direction, distance)        -- Where we want to go too
    local target_box = area_translate(entity.selection_box, direction, distance) -- Target selection box location
    local out_of_the_way = position_translate(start_pos, direction_opposite(direction), event.tiles_away or 20)
    local final_teleportation = false                                            -- Handling teleportion after an entity has been moved into place and checked again

    ---  Try retries times to teleport the entity out of the way.
    --- @api LuaEntity:can_be_teleported
    local retries = 5
    while not entity.teleport(out_of_the_way) do
        if retries <= 1 then
            return flying_text(player, { "picker-dollies.cant-be-teleported", entity.localised_name }, entity.position)
        end
        retries = retries - 1
        out_of_the_way = position_add(out_of_the_way, { x = retries, y = retries })
    end

    --- Entity was teleportable and is out of the way, Check to see if it fits in the new spot.
    if target_direction then entity.direction = target_direction end -- Rotation for oblong
    save_entity(pdata, entity, event.tick, save_time)

    --- Update everything after teleporting. This includes moving rocket-silo-rocket, item-entity, item-request-proxies, fluidbox.
    --- @param pos MapPosition
    --- @param raise boolean Teleportation was successfull raise event
    --- @param reason? LocalisedString
    local function teleport_and_update(pos, raise, reason)
        if entity.last_user then entity.last_user = player end

        --- Final teleport into position. Ignore final_teleportation if we are not raising
        if not (raise and final_teleportation) then
            if event.start_direction then
                entity.direction = event.start_direction
            end
            entity.teleport(pos)
        end

        if not raise then return flying_text(player, reason, pos) end

        --- At this point the entity should be able to be teleported into a new position.
        --- Hoover up items, Move the proxy, Update any connections, Raise the dolly_moved event.

        --- Mine or move out of the way any items on the ground.
        local items_on_ground = surface.find_entities_filtered { type = "item-entity", area = target_box }
        for _, item_entity in pairs(items_on_ground) do
            if item_entity.valid and not player.mine_entity(item_entity) then
                --- @todo this doesn't do anything.......
                local item_pos = item_entity.position
                -- local valid_pos = surface.find_non_colliding_position("item-on-ground", item_pos, 0, .20) or item_pos
                item_entity.teleport(item_pos)
            end
        end

        --- Move the proxy to the correct position.
        local proxy = surface.find_entity("item-request-proxy", start_pos)
        if proxy and proxy.valid then proxy.teleport(entity.position) end

        --- @todo Move any rocket-silo-rockets instead of blocking.

        --- Update all connections.
        --- @todo Only add updateable_entities to a list.
        local updateable_entities = surface.find_entities_filtered { area = area_expand(target_box, 32), force = entity_force }
        for _, updateable in pairs(updateable_entities) do updateable.update_connections() end

        --- @type EventData.PickerDollies.dolly_moved_event
        local event_data = { player_index = player.index, moved_entity = entity, start_pos = start_pos }
        script.raise_event(self.event_id, event_data)
        player.play_sound { path = "utility/rotated_medium" }
    end

    local can_place_params = {
        name = entity.name == "entity-ghost" and entity.ghost_name or entity.name,
        position = target_pos,
        direction = target_direction,
        force = entity_force,
        build_check_type = defines.build_check_type.manual, -- Won't allow placing on ghosts/deconstruction proxies
        inner_name = entity.name == "entity-ghost" and entity.ghost_name
    }

    --- Allow collisions if the player has the setting enabled.
    local ignore_collisions = settings.global["dolly-allow-ignore-collisions"].value and
        player.mod_settings["dolly-ignore-collisions"].value
    if not ignore_collisions then
        if not (surface.can_place_entity(can_place_params) and not surface.find_entity("entity-ghost", target_pos)) then
            return teleport_and_update(start_pos, false, { "picker-dollies.no-room", entity.localised_name })
        end
    end

    ---  Check if all the wires can reach.
    local wire_connectors = entity.get_wire_connectors(false) or {}
    if table_size(wire_connectors) > 0 then
        if not final_teleportation then entity.teleport(target_pos) end
        final_teleportation = true
        if not can_wires_reach(entity) then return teleport_and_update(start_pos, false, { "picker-dollies.wires-maxed" }) end
    end

    --- mining-drill check if there is ore in the area.
    if entity.type == "mining-drill" then
        if not final_teleportation then entity.teleport(target_pos) end
        final_teleportation = true
        local area = position_expand_to_area(target_pos, prototype.mining_drill_radius) --[[@as BoundingBox]]
        local resource_name = entity.mining_target and entity.mining_target.name or nil
        local count = entity.surface.count_entities_filtered { area = area, type = "resource", name = resource_name }
        if count == 0 then
            return teleport_and_update(start_pos, false,
                { "picker-dollies.off-ore-patch", entity.localised_name, resource_name })
        end
    end

    return teleport_and_update(target_pos, true)
end

script.on_event({ "dolly-move-north", "dolly-move-east", "dolly-move-south", "dolly-move-west" }, function (event_data)
    epd:move_entity(event_data)
end)

--- @param event EventData.CustomInputEvent
function epd:try_rotate_oblong_entity(event)
    --- @type LuaPlayer?, PickerDollies.pdata
    local player, pdata = game.get_player(event.player_index), pdata(event.player_index)
    if not player then return end
    if player.cursor_stack.valid_for_read or player.cursor_ghost then return end

    local save_time = player.mod_settings["dolly-save-entity"].value --[[@as uint]]
    local entity = get_saved_entity(player, pdata, event.tick, save_time)
    if not entity then return end
    if not (storage.oblong_names[entity.name] and not is_blacklisted(entity)) then return end
    if not (player.cheat_mode or player.can_reach_entity(entity)) then return end

    save_entity(pdata, entity, event.tick, save_time)
    event.save_time = save_time
    event.start_pos = entity.position
    event.start_direction = entity
        .direction -- store the direction for later failed teleportation will need to restore it.
    event.target_direction = direction_next(entity.direction)
    event.distance = .5
    event.direction = oblong_diags[event.target_direction] -- Set the translation direction to a diagonal.
    self:move_entity(event)
end

script.on_event("dolly-rotate-rectangle", function (event_data) epd:try_rotate_oblong_entity(event_data) end)

--- @param event EventData.CustomInputEvent
function epd:rotate_saved_dolly(event)
    --- @type LuaPlayer?, PickerDollies.pdata
    local player, pdata = game.get_player(event.player_index), pdata(event.player_index)
    if not player then return end
    if player.cursor_stack.valid_for_read or player.cursor_ghost or player.selected then return end

    local save_time = player.mod_settings["dolly-save-entity"].value --[[@as uint]]
    local entity = get_saved_entity(player, pdata, event.tick, save_time)
    if entity and entity.supports_direction then
        save_entity(pdata, entity, event.tick, save_time)
        entity.rotate { reverse = event.input_name == "dolly-rotate-saved-reverse", by_player = player }
    end
end

script.on_event({ "dolly-rotate-saved", "dolly-rotate-saved-reverse" },
    function (event_data) epd:rotate_saved_dolly(event_data) end)

local function on_init()
    storage.blacklist_names = table_copy(blacklist_names)
    storage.oblong_names = table_copy(oblong_names)
end
script.on_init(on_init)

local function on_configuration_changed()
    --- Make sure the blacklists exist.
    storage.blacklist_names = storage.blacklist_names or table_copy(blacklist_names)
    storage.oblong_names = storage.oblong_names or table_copy(oblong_names)

    --- Remove any invalid prototypes from the blacklists.
    for name in pairs(storage.blacklist_names) do
        if not prototypes.entity[name] then storage.blacklist_names[name] = nil end
    end
    for name in pairs(storage.oblong_names) do
        if not prototypes.entity[name] then storage.oblong_names[name] = nil end
    end
end

script.on_configuration_changed(on_configuration_changed)

--- @class PickerDollies.global
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
