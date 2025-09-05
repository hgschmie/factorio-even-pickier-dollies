--
-- constants
--

---@generic K
---@param t {[uint]: K}
---@return {[K]: true}
local function array_to_dict(t)
    local t2 = {}
    for _, v in pairs(t) do t2[v] = true end
    return t2
end

return {
    array_to_dict = array_to_dict,

    api_name = 'PickerDollies',

    -- extension area in which to repair connections for loaders, beacons, cliffs and mining drills.
    grid_size = 32,

    -- Entity types that can not be moved even in cheat_mode.
    blacklist_types = array_to_dict {
        -- rails and train stuff
        'straight-rail', 'half-diagonal-rail', 'curved-rail-a', 'curved-rail-b', 'legacy-straight-rail', 'legacy-curved-rail',
        'elevated-curved-rail-a', 'elevated-curved-rail-b', 'elevated-half-diagonal-rail', 'elevated-straight-rail',
        'rail-ramp', 'rail-support', 'train-stop', 'rail-signal', 'rail-chain-signal', 'rail-remnants',
        'locomotive', 'cargo-wagon', 'artillery-wagon', 'fluid-wagon',
        -- robots
        'construction-robot', 'logistic-robot', 'combat-robot',
        -- rockets and space stuff
        'rocket-silo-rocket', 'rocket-silo-rocket-shadow', 'cargo-landing-pad', 'cargo-pod',
        -- belts and containers
        'linked-belt', 'underground-belt', 'temporary-container',
        -- environment
        'cliff', 'tree', 'resource', 'explosion', 'particle-source', 'fire', 'sticker', 'stream', 'beam', 'artillery-flare', 'projectile',
        -- internal stuff
        'item-request-proxy', 'tile-ghost', 'item-entity', 'deconstructible-tile-proxy', 'arrow', 'highlight-box', 'speech-bubble', 'smoke-with-trigger',
        -- misc
        'spider-leg',
    },

    -- Entity types that can only be moved in cheat_mode.
    whitelist_cheat_types = array_to_dict { 'character', 'unit', 'unit-spawner', 'car', 'spider-vehicle', 'simple-entity', 'corpse', 'character-corpse' },

    -- Default entity names to blacklist from moving. Stored in global and can be modified by the user via interface.
    blacklist_names = array_to_dict { 'pumpjack' },

    -- Entities where "transporter mode" is supported.

    --- currently only 1x1 sized types. Underground belt is its own can of worms...
    ---@type table<string, epd.TransporterControl>
    whitelist_transporter_mode_types = {
        ['loader-1x1'] = {
            control_fields = { 'circuit_set_filters', 'circuit_read_transfers', 'circuit_enable_disable', 'connect_to_logistic_network', },
            control_objects = { 'circuit_condition', 'logistic_condition', },
            fields = { 'loader_type', 'loader_filter_mode', },
            filters = true,
        },
        ['transport-belt'] = {
            control_fields = { 'read_contents', 'read_contents_mode', 'circuit_enable_disable', 'connect_to_logistic_network', },
            control_objects = { 'circuit_condition', 'logistic_condition', },
        },
    },

    --- Default entity names with none-square bounding boxes. Stored in global and can be modified by the user via interface.
    oblong_names = {
        ['pump'] = 0.5,
        ['arithmetic-combinator'] = 0.5,
        ['decider-combinator'] = 0.5,
        ['selector-combinator'] = 0.5,
        -- ['recycler'] = 1 -- see https://forums.factorio.com/viewtopic.php?f=7&t=122949
    },

    input_to_direction = {
        ['dolly-move-north'] = defines.direction.north,
        ['dolly-move-east']  = defines.direction.east,
        ['dolly-move-south'] = defines.direction.south,
        ['dolly-move-west']  = defines.direction.west
    },

    oblong_diags = {
        [defines.direction.north] = defines.direction.northeast,
        [defines.direction.south] = defines.direction.northeast,
        [defines.direction.west]  = defines.direction.southwest,
        [defines.direction.east]  = defines.direction.southwest
    },

    belt_types = array_to_dict {
        'lane-splitter', 'linked-belt', 'loader', 'loader-1x1', 'splitter', 'transport-belt', 'underground-belt',
    },
}
