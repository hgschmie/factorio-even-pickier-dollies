--
-- runtime code
--

local util = require('util')
local tools = require('scripts.tools')
local const = require('scripts.constants')

local event_id = script.generate_event_name()

-- everything that may connect to fluid pipes
local fluid_types = tools.array_to_dictionary({
    'assembling-machine', 'boiler', 'fluid-turret', 'fusion-generator', 'generator', 'mining-drill',
    'offshore-pump', 'pipe', 'pipe-to-ground', 'pump', 'storage-tank', 'thruster'
})

---@class EvenPickierDolliesMod
---@field event_id uint The event id registered with the main game.
---@field remote_interface EvenPickierDolliesRemoteInterface
---@field settings EvenPickierDolliesSettings
local epd = {
    event_id = event_id,
    settings = require('scripts.settings'),
    remote_interface = require('scripts.remote-interface')(event_id),
}

remote.add_interface(const.api_name, epd.remote_interface)

assert(remote.interfaces[const.api_name]['dolly_moved_entity_id'])

---@param move_event EvenPickierDolliesMoveEvent
function epd:move_entity(move_event)
    local player = move_event.player
    local cheat_mode = player.cheat_mode

    local entity = move_event.entity
    local prototype = entity.prototype

    local debug = self.settings.get_debug(player)

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

    -- save start position in case we have to unwind
    local start_pos = entity.position        -- Where we started from in case we have to return it
    local start_direction = entity.direction -- Direction in which the entity currently points

    local function undo_move(message)
        -- undo everything
        entity.direction = start_direction
        if entity.teleport(start_pos) then
            return tools.flying_text(player, { message, entity.localised_name }, start_pos)
        else
            -- error message at the original position
            return tools.flying_text(player, { 'picker-dollies.teleport-problem', entity.localised_name }, player.position)
        end
    end

    -- Make sure there is not a rocket present.
    -- @todo Move the rocket-silo-rocket to the correct spot.
    if surface.find_entity("rocket-silo-rocket", start_pos) then
        return tools.flying_text(player, { "picker-dollies.rocket-present", entity.localised_name }, start_pos)
    end

    local distance = move_event.distance * prototype.building_grid_bit_shift          -- Distance to move the source, defaults to 1
    local target_pos = tools.position_translate(start_pos, direction, distance)       -- Where we want to go too
    local target_box = tools.area_translate(entity.bounding_box, direction, distance) -- Target selection box location

    local function find_safe_position(e)
        local fluid_careful = (self.settings.get_fluid_careful(player) and fluid_types[e.type]) or false
        local dolly_attempts = self.settings.get_attempts(player)
        local dolly_spacing = self.settings.get_spacing(player)
        local dolly_direction = self.settings.get_direction(player)

        for attempts = 1, dolly_attempts, 1 do
            local offset = math.pow(dolly_spacing, (0.875 + attempts / 8)) -- 1, 1.125, 1.25, 1.375, 1.5
            local error_color = { r = 1 } -- red for placing problems

            ---@type MapPosition?
            local safe_position = tools.position_translate(target_pos, dolly_direction, offset)
            assert(safe_position)

            safe_position = surface.find_non_colliding_position(e, safe_position, 0, 2)
            assert(safe_position)

            local bbox = tools.area_center(safe_position, target_pos, target_box)

            local can_place_params = {
                name = prototype.name,
                position = safe_position,
                direction = e.direction,
                force = player.force,
                build_check_type = defines.build_check_type.ghost_revive,
            }

            local can_place = surface.can_place_entity(can_place_params)

            if fluid_careful and can_place then
                -- check the surroundings of the safe position for fluidic entities which may connect to any pipe that is sitting around.
                -- This check ensures that there is at least one space
                local safe_box = tools.area_expand(bbox, 1)
                local sb_entities = {}

                for _, sb_entity in pairs(surface.find_entities_filtered {
                    area = safe_box,
                    type = { 'character', 'entity-ghost', 'item-entity', }, -- ignore those entities
                    invert = true,
                }) do
                    if fluid_types[sb_entity.type] then table.insert(sb_entities, sb_entity) end
                end

                error_color = { r = 1, g = 0.5 } -- different error color for fluid problem
                can_place = table_size(sb_entities) == 0
            end

            if debug then
                rendering.draw_rectangle {
                    color = (can_place and { g = 1 } or error_color),
                    surface = player.surface,
                    left_top = bbox.left_top,
                    right_bottom = bbox.right_bottom,
                    time_to_live = 120,
                }

                tools.flying_text(player, { 'picker-dollies.safe-pos', attempts }, safe_position, true)
            end

            if can_place then return safe_position end
        end

        return nil
    end

    local safe_position = find_safe_position(entity)
    if not safe_position then
        return tools.flying_text(player, { "picker-dollies.factory-too-clustered", entity.localised_name }, start_pos)
    end

    -- Move entity to the safe position temporarily
    if not entity.teleport(safe_position) then
        return tools.flying_text(player, { "picker-dollies.cant-be-teleported", entity.localised_name }, start_pos)
    end

    -- Entity was teleportable and is out of the way, Check to see if it fits in the new spot.

    if move_event.rotate then entity.direction = move_event.rotate end -- operation was a rotate

    -- update the saved entity for multiple moves
    tools.save_entity(move_event.pdata, entity, move_event.tick, move_event.save_time)

    -- see if we can place the entity in the new spot
    local ignore_collisions = self.settings.get_allow_ignore_collisions() and self.settings.get_ignore_collisions(player)

    if not ignore_collisions then
        ---@type LuaSurface.can_place_entity_param
        local can_place_params = {
            name = prototype.name,
            position = target_pos,
            direction = entity.direction,
            force = player.force,
            build_check_type = defines.build_check_type.ghost_revive,
        }

        if debug then
            rendering.draw_rectangle {
                color = { r = 0.3, g = 0.3, b = 1 },
                surface = player.surface,
                left_top = target_box.left_top,
                right_bottom = target_box.right_bottom,
                time_to_live = 120,
            }
        end

        if not (surface.can_place_entity(can_place_params) and not surface.find_entity("entity-ghost", target_pos)) then
            return undo_move('picker-dollies.no-room')
        end
    end

    if not entity.teleport(target_pos) then
        -- this can happen in ignore-collisions mode
        return undo_move('picker-dollies.no-room')
    end

    --  Check if all the wires can reach.
    local wire_connectors = entity.get_wire_connectors(false) or {}
    if table_size(wire_connectors) > 0 then
        if not tools.can_wires_reach(entity) then
            return undo_move('picker-dollies.wires-maxed')
        end
    end

    -- everything seems to be fine
    if entity.last_user then entity.last_user = player end

    -- Mine or move out of the way any items on the ground.
    local items_on_ground = surface.find_entities_filtered { type = "item-entity", area = target_box }
    for _, item_entity in pairs(items_on_ground) do
        if item_entity.valid and not player.mine_entity(item_entity) then
            local item_pos = item_entity.position
            local valid_pos = surface.find_non_colliding_position(item_entity, item_pos, 50, .20) or item_pos
            item_entity.teleport(valid_pos)
        end
    end

    -- Move a proxy to the correct position...
    local proxy = surface.find_entity("item-request-proxy", start_pos)
    if proxy and proxy.valid then proxy.teleport(target_pos) end

    -- Update all connections.
    -- @todo Only add updateable_entities to a list.
    local updateable_entities = surface.find_entities_filtered { area = tools.area_expand(target_box, const.grid_size), force = entity_force }
    for _, updateable in pairs(updateable_entities) do updateable.update_connections() end

    ---@type EvenPickierDolliesRemoteInterfaceDollyMovedEvent
    local event_data = {
        player_index = player.index,
        moved_entity = entity,
        start_pos = start_pos
    }

    script.raise_event(self.event_id, event_data)
    player.play_sound { path = "utility/rotated_medium" }
end

---@param event EventData.CustomInputEvent
function epd.dolly_move(event)
    local player, pdata = game.get_player(event.player_index), tools.pdata(event.player_index)
    if not player then return end

    local save_time = epd.settings.get_save_entity(player)
    local entity = tools.get_entity_to_move(player, pdata, event.tick, save_time)
    if not entity then return end

    ---@type EvenPickierDolliesMoveEvent
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

---@param event EventData.CustomInputEvent
---@param reverse boolean
function epd.rotate_oblong_entity(event, reverse)
    ---@type LuaPlayer?
    local player = game.get_player(event.player_index)
    if not player then return end
    if player.cursor_stack.valid_for_read or player.cursor_ghost then return end

    local pdata = tools.pdata(event.player_index)

    local save_time = epd.settings.get_save_entity(player)
    local entity = tools.get_entity_to_move(player, pdata, event.tick, save_time)
    if not entity then return end

    if not (storage.oblong_names[entity.name] and tools.allow_moving(entity, player.cheat_mode)) then return end
    if not (player.cheat_mode or player.can_reach_entity(entity)) then return end

    local rotate = reverse and tools.direction_previous(entity.direction) or tools.direction_next(entity.direction)

    ---@type EvenPickierDolliesMoveEvent
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

---@param event EventData.CustomInputEvent
---@param reverse boolean
function epd.rotate_saved_dolly(event, reverse)
    ---@type LuaPlayer?
    local player = game.get_player(event.player_index)
    if not player then return end

    if player.cursor_stack.valid_for_read or player.cursor_ghost or player.selected then return end

    local pdata = tools.pdata(event.player_index)

    local save_time = epd.settings.get_save_entity(player)
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
script.on_event("dolly-rotate-rectangle", function (event) epd.rotate_oblong_entity(event, false) end)
script.on_event("dolly-rotate-rectangle-reverse", function (event) epd.rotate_oblong_entity(event, true) end)
script.on_event("dolly-rotate-saved", function (event) epd.rotate_saved_dolly(event, false) end)
script.on_event("dolly-rotate-saved-reverse", function (event) epd.rotate_saved_dolly(event, true) end)
script.on_init(epd.on_init)
script.on_configuration_changed(epd.on_configuration_changed)
