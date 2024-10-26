--
-- runtime code
--

local util = require('util')
local tools = require('scripts.tools')
local const = require ('scripts.constants')

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

--- @param event EventData.PickerDollies.CustomInputEvent
function epd:move_entity(event)
    --- @type LuaPlayer?, EvenPickierDolliesPlayerData
    local player, pdata = game.get_player(event.player_index), tools.pdata(event.player_index)
    if not player then return end

    local save_time = event.save_time or player.mod_settings["dolly-save-entity"].value --[[@as uint]]
    local entity = tools.get_saved_entity(player, pdata, event.tick, save_time)
    if not entity then return end

    local cheat_mode = player.cheat_mode

    --- Check non cheat_mode player in range.
    if not (cheat_mode or player.can_reach_entity(entity)) then
        return tools.flying_text(player, { "cant-reach" }, entity.position)
    end

    --- Check if entity is blacklisted, cheat_mode allows moving more entities.
    if not tools.allow_moving(entity, cheat_mode) then
        local text = { "picker-dollies.cant-be-teleported", entity.localised_name }
        return tools.flying_text(player, text, entity.position)
    end

    --- Only move entities of the same force unless cheat_mode is enabled.
    local entity_force = entity.force --[[@as LuaForce]]
    if not (cheat_mode or entity_force == player.force) then
        local text = { "picker-dollies.wrong-force", entity.localised_name }
        return tools.flying_text(player, text, entity.position)
    end

    local surface = entity.surface
    local start_pos = event.start_pos or entity.position -- Where we started from in case we have to return it

    --- Make sure there is not a rocket present.
    --- @todo Move the rocket-silo-rocket to the correct spot.
    if surface.find_entity("rocket-silo-rocket", start_pos) then
        return tools.flying_text(player, { "picker-dollies.rocket-present", entity.localised_name }, start_pos)
    end

    local prototype = entity.prototype
    local direction = event.direction or const.input_to_direction[event.input_name] -- Direction to move the source
    if not direction then return end

    local distance = (event.distance or 1) * prototype.building_grid_bit_shift   -- Distance to move the source, defaults to 1
    local target_direction = event.target_direction or entity.direction
    local target_pos = tools.position_translate(start_pos, direction, distance)        -- Where we want to go too
    local target_box = tools.area_translate(entity.selection_box, direction, distance) -- Target selection box location
    local out_of_the_way = tools.position_translate(start_pos, util.oppositedirection(direction), event.tiles_away or 20)
    local final_teleportation = false                                            -- Handling teleportion after an entity has been moved into place and checked again

    ---  Try retries times to teleport the entity out of the way.
    --- @api LuaEntity:can_be_teleported
    local retries = 5
    while not entity.teleport(out_of_the_way) do
        if retries <= 1 then
            return tools.flying_text(player, { "picker-dollies.cant-be-teleported", entity.localised_name }, entity.position)
        end
        retries = retries - 1
        out_of_the_way = tools.position_add(out_of_the_way, { x = retries, y = retries })
    end

    --- Entity was teleportable and is out of the way, Check to see if it fits in the new spot.
    if target_direction then entity.direction = target_direction end -- Rotation for oblong
    tools.save_entity(pdata, entity, event.tick, save_time)

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

        if not raise then return tools.flying_text(player, reason, pos) end

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
        local updateable_entities = surface.find_entities_filtered { area = tools.area_expand(target_box, 32), force = entity_force }
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
        if not tools.can_wires_reach(entity) then return teleport_and_update(start_pos, false, { "picker-dollies.wires-maxed" }) end
    end

    --- mining-drill check if there is ore in the area.
    if entity.type == "mining-drill" then
        if not final_teleportation then entity.teleport(target_pos) end
        final_teleportation = true
        local area = tools.position_expand_to_area(target_pos, prototype.mining_drill_radius) --[[@as BoundingBox]]
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
    epd:move_entity(event_data) --[[@as EventData.PickerDollies.CustomInputEvent]]
end)

--- @param event EventData.PickerDollies.CustomInputEvent
function epd:try_rotate_oblong_entity(event)
    --- @type LuaPlayer?, EvenPickierDolliesPlayerData
    local player, pdata = game.get_player(event.player_index), tools.pdata(event.player_index)
    if not player then return end
    if player.cursor_stack.valid_for_read or player.cursor_ghost then return end

    local save_time = player.mod_settings["dolly-save-entity"].value --[[@as uint]]
    local entity = tools.get_saved_entity(player, pdata, event.tick, save_time)
    if not entity then return end
    if not (storage.oblong_names[entity.name] and tools.allow_moving(entity, player.cheat_mode)) then return end
    if not (player.cheat_mode or player.can_reach_entity(entity)) then return end

    tools.save_entity(pdata, entity, event.tick, save_time)
    event.save_time = save_time
    event.start_pos = entity.position
    event.start_direction = entity
        .direction -- store the direction for later failed teleportation will need to restore it.
    event.target_direction = tools.direction_next(entity.direction)
    event.distance = .5
    event.direction = const.oblong_diags[event.target_direction] -- Set the translation direction to a diagonal.
    self:move_entity(event)
end

script.on_event("dolly-rotate-rectangle", function (event_data) epd:try_rotate_oblong_entity(event_data) end)

--- @param event EventData.CustomInputEvent
function epd:rotate_saved_dolly(event)
    --- @type LuaPlayer?, EvenPickierDolliesPlayerData
    local player, pdata = game.get_player(event.player_index), tools.pdata(event.player_index)
    if not player then return end
    if player.cursor_stack.valid_for_read or player.cursor_ghost or player.selected then return end

    local save_time = player.mod_settings["dolly-save-entity"].value --[[@as uint]]
    local entity = tools.get_saved_entity(player, pdata, event.tick, save_time)
    if entity and entity.supports_direction then
        tools.save_entity(pdata, entity, event.tick, save_time)
        entity.rotate { reverse = event.input_name == "dolly-rotate-saved-reverse", by_player = player }
    end
end

script.on_event({ "dolly-rotate-saved", "dolly-rotate-saved-reverse" },
    function (event_data) epd:rotate_saved_dolly(event_data) end)

local function on_init()
    storage.blacklist_names = util.copy(const.blacklist_names)
    storage.oblong_names = util.copy(const.oblong_names)
end
script.on_init(on_init)

local function on_configuration_changed()
    --- Make sure the blacklists exist.
    storage.blacklist_names = storage.blacklist_names or util.copy(const.blacklist_names)
    storage.oblong_names = storage.oblong_names or util.copy(const.oblong_names)

    --- Remove any invalid prototypes from the blacklists.
    for name in pairs(storage.blacklist_names) do
        if not prototypes.entity[name] then storage.blacklist_names[name] = nil end
    end
    for name in pairs(storage.oblong_names) do
        if not prototypes.entity[name] then storage.oblong_names[name] = nil end
    end
end

script.on_configuration_changed(on_configuration_changed)
