--
-- runtime code
--

local util = require('util')
local tools = require('scripts.tools')
local const = require('scripts.constants')

local event_id = script.generate_event_name()

--- @class EvenPickierDolliesMod
--- @field event_id uint The event id registered with the main game.
--- @field remote_interface EvenPickierDolliesRemoteInterface
local epd = {
    event_id = event_id,
    remote_interface = require('scripts.remote-interface')(event_id)
}

remote.add_interface(const.api_name, epd.remote_interface)

assert(remote.interfaces[const.api_name]['dolly_moved_entity_id'])

--- @param move_event EvenPickierDolliesMoveEvent
function epd:move_entity(move_event)
    local player = move_event.player
    local entity = move_event.entity
    local cheat_mode = player.cheat_mode

    local direction = move_event.direction -- Direction to move the source
    if not direction then return end

    -- Check non cheat_mode player in range.
    if not (cheat_mode or player.can_reach_entity(entity)) then
        return tools.flying_text(player, { "cant-reach" }, entity.position)
    end

    -- Check if entity is blacklisted, cheat_mode allows moving more entities.
    if not tools.allow_moving(entity, cheat_mode) then
        return tools.flying_text(player, { "picker-dollies.cant-be-teleported", entity.localised_name }, entity.position)
    end

    -- Only move entities of the same force unless cheat_mode is enabled.
    local entity_force = entity.force --[[@as LuaForce]]
    if not (cheat_mode or entity_force == player.force) then
        return tools.flying_text(player, { "picker-dollies.wrong-force", entity.localised_name }, entity.position)
    end

    local surface = entity.surface
    local start_pos = entity.position        -- Where we started from in case we have to return it
    local start_direction = entity.direction -- Direction in which the entity currently points

    -- Make sure there is not a rocket present.
    -- @todo Move the rocket-silo-rocket to the correct spot.
    if surface.find_entity("rocket-silo-rocket", start_pos) then
        return tools.flying_text(player, { "picker-dollies.rocket-present", entity.localised_name }, start_pos)
    end

    local prototype = entity.prototype

    local distance = move_event.distance * prototype.building_grid_bit_shift           -- Distance to move the source, defaults to 1
    local target_pos = tools.position_translate(start_pos, direction, distance)        -- Where we want to go too
    local target_box = tools.area_translate(entity.selection_box, direction, distance) -- Target selection box location
    local out_of_the_way = tools.position_translate(start_pos, util.oppositedirection(direction), const.tile_offset)
    local final_teleportation = false                                                  -- Handling teleportion after an entity has been moved into place and checked again

    --  Try retries times to teleport the entity out of the way.
    local retries = const.teleport_retries
    while not tools.safe_teleport(entity, out_of_the_way) do
        if retries <= 1 then return tools.flying_text(player, { "picker-dollies.cant-be-teleported", entity.localised_name }, entity.position) end
        retries = retries - 1
        out_of_the_way = tools.position_add(out_of_the_way, { x = retries, y = retries })
    end

    -- Entity was teleportable and is out of the way, Check to see if it fits in the new spot.

    if move_event.rotate then entity.direction = move_event.rotate end -- operation was a rotate
    tools.save_entity(move_event.pdata, entity, move_event.tick, move_event.save_time)

    -- Update everything after teleporting. This includes moving rocket-silo-rocket, item-entity, item-request-proxies, fluidbox.
    --- @param final_pos MapPosition position to move to
    --- @param final_direction defines.direction direction to point to
    --- @param raise boolean Teleportation was successfull raise event
    --- @param reason? LocalisedString
    local function teleport_and_update(final_pos, final_direction, raise, reason)
        if entity.last_user then entity.last_user = player end

        -- Final teleport into position. Ignore final_teleportation if we are not raising
        if not (raise and final_teleportation) then
            if final_direction then entity.direction = final_direction end
            tools.safe_teleport(entity, final_pos)
        end

        if not raise then return tools.flying_text(player, reason, final_pos) end

        -- At this point the entity should be able to be teleported into a new position.
        -- Hoover up items, Move the proxy, Update any connections, Raise the dolly_moved event.

        -- Mine or move out of the way any items on the ground.
        local items_on_ground = surface.find_entities_filtered { type = "item-entity", area = target_box }
        for _, item_entity in pairs(items_on_ground) do
            if item_entity.valid and not player.mine_entity(item_entity) then
                -- @todo this doesn't do anything.......
                local item_pos = item_entity.position
                -- local valid_pos = surface.find_non_colliding_position("item-on-ground", item_pos, 0, .20) or item_pos
                tools.safe_teleport(item_entity, item_pos)
            end
        end

        -- Move the proxy to the correct position.
        local proxy = surface.find_entity("item-request-proxy", start_pos)
        if proxy and proxy.valid then proxy.teleport(entity.position) end

        -- @todo Move any rocket-silo-rockets instead of blocking.

        -- Update all connections.
        -- @todo Only add updateable_entities to a list.
        local updateable_entities = surface.find_entities_filtered { area = tools.area_expand(target_box, const.grid_size), force = entity_force }
        for _, updateable in pairs(updateable_entities) do updateable.update_connections() end

        --- @type EvenPickierDolliesRemoteInterfaceDollyMovedEvent
        local event_data = {
            player_index = player.index,
            moved_entity = entity,
            start_pos = start_pos
        }

        script.raise_event(self.event_id, event_data)
        player.play_sound { path = "utility/rotated_medium" }
    end

    local can_place_params = {
        name = entity.name == "entity-ghost" and entity.ghost_name or entity.name,
        position = target_pos,
        direction = move_event.rotate or entity.direction,
        force = entity_force,
        build_check_type = defines.build_check_type.manual, -- Won't allow placing on ghosts/deconstruction proxies
        inner_name = entity.name == "entity-ghost" and entity.ghost_name or nil
    }

    -- Allow collisions if the player has the setting enabled.
    local ignore_collisions = settings.global["dolly-allow-ignore-collisions"].value and player.mod_settings["dolly-ignore-collisions"].value
    if not ignore_collisions then
        if not (surface.can_place_entity(can_place_params) and not surface.find_entity("entity-ghost", target_pos)) then
            return teleport_and_update(start_pos, start_direction, false, { "picker-dollies.no-room", entity.localised_name })
        end
    end

    --  Check if all the wires can reach.
    local wire_connectors = entity.get_wire_connectors(false) or {}
    if table_size(wire_connectors) > 0 then
        if not final_teleportation then tools.safe_teleport(entity, target_pos) end
        final_teleportation = true
        if not tools.can_wires_reach(entity) then return teleport_and_update(start_pos, start_direction, false, { "picker-dollies.wires-maxed" }) end
    end

    return teleport_and_update(target_pos, move_event.rotate, true)
end

--- @param event EventData.CustomInputEvent
function epd.dolly_move(event)
    local player, pdata = game.get_player(event.player_index), tools.pdata(event.player_index)
    if not player then return end

    local save_time = tools.get_save_entity_setting(player)
    local entity = tools.get_entity_to_move(player, pdata, event.tick, save_time)
    if not entity then return end

    --- @type EvenPickierDolliesMoveEvent
    local move_event = {
        player = player,
        pdata = pdata,
        tick = event.tick,
        entity = entity,
        save_time = save_time,
        direction = const.input_to_direction[event.input_name], -- direction in which the entity is moved
        distance = 1,
    }

    epd:move_entity(move_event)
end

--- @param event EventData.CustomInputEvent
--- @param reverse boolean
function epd.rotate_oblong_entity(event, reverse)
    --- @type LuaPlayer?, EvenPickierDolliesPlayerData
    local player, pdata = game.get_player(event.player_index), tools.pdata(event.player_index)
    if not player then return end

    if player.cursor_stack.valid_for_read or player.cursor_ghost then return end

    local save_time = tools.get_save_entity_setting(player)
    local entity = tools.get_entity_to_move(player, pdata, event.tick, save_time)
    if not entity then return end

    if not (storage.oblong_names[entity.name] and tools.allow_moving(entity, player.cheat_mode)) then return end
    if not (player.cheat_mode or player.can_reach_entity(entity)) then return end

    local rotate = reverse and tools.direction_previous(entity.direction) or tools.direction_next(entity.direction)

    --- @type EvenPickierDolliesMoveEvent
    local move_event = {
        player = player,
        pdata = pdata,
        tick = event.tick,
        entity = entity,
        save_time = save_time,
        direction = const.oblong_diags[rotate],
        distance = 0.5,
        rotate = rotate,
    }

    epd:move_entity(move_event)
end

--- @param event EventData.CustomInputEvent
--- @param reverse boolean
function epd.rotate_saved_dolly(event, reverse)
    --- @type LuaPlayer?, EvenPickierDolliesPlayerData
    local player, pdata = game.get_player(event.player_index), tools.pdata(event.player_index)
    if not player then return end

    if player.cursor_stack.valid_for_read or player.cursor_ghost or player.selected then return end

    local save_time = tools.get_save_entity_setting(player)
    local entity = tools.get_entity_to_move(player, pdata, event.tick, save_time)
    if not entity or not entity.supports_direction then return end

    tools.save_entity(pdata, entity, event.tick, save_time)
    entity.rotate { reverse = reverse, by_player = player }
end

function epd.on_init()
    storage.blacklist_names = util.copy(const.blacklist_names)
    storage.oblong_names = util.copy(const.oblong_names)
end

function epd.on_configuration_changed()
    -- Make sure the blacklists exist.
    storage.blacklist_names = storage.blacklist_names or util.copy(const.blacklist_names)
    storage.oblong_names = storage.oblong_names or util.copy(const.oblong_names)

    -- Remove any invalid prototypes from the blacklists.
    for name in pairs(storage.blacklist_names) do
        if not prototypes.entity[name] then storage.blacklist_names[name] = nil end
    end
    for name in pairs(storage.oblong_names) do
        if not prototypes.entity[name] then storage.oblong_names[name] = nil end
    end
end

script.on_event({ "dolly-move-north", "dolly-move-east", "dolly-move-south", "dolly-move-west" }, epd.dolly_move)
script.on_event("dolly-rotate-rectangle", function(event) epd.rotate_oblong_entity(event, false) end)
script.on_event("dolly-rotate-rectangle-reverse", function(event) epd.rotate_oblong_entity(event, true) end)
script.on_event("dolly-rotate-saved", function (event) epd.rotate_saved_dolly(event, false) end)
script.on_event("dolly-rotate-saved-reverse", function (event) epd.rotate_saved_dolly(event, true) end)
script.on_init(epd.on_init)
script.on_configuration_changed(epd.on_configuration_changed)
