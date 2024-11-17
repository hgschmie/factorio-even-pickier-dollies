--
-- settings definitions
--

data:extend {
    {
        name = "dolly-save-entity",
        setting_type = "runtime-per-user",
        type = "int-setting",
        default_value = 4,
        minimum_value = 0,
        maximum_value = 60,
        order = 'aa',
    },
    {
        name = "dolly-fluid-careful",
        setting_type = "runtime-per-user",
        type = "bool-setting",
        default_value = true,
        order = 'ab',
    },
    {
        name = "dolly-ignore-collisions",
        setting_type = "runtime-per-user",
        type = "bool-setting",
        default_value = false,
        order = 'ac',
    },
    {
        name = "dolly-allow-ignore-collisions",
        setting_type = "runtime-global",
        type = "bool-setting",
        default_value = false,
    },
    {
        name = "dolly-debug",
        setting_type = 'runtime-per-user',
        type = "bool-setting",
        default_value = false,
        order = 'ba',
    },
    {
        name = "dolly-attempts",
        setting_type = 'runtime-per-user',
        type = "int-setting",
        default_value = 5,
        minimum_value = 1,
        maximum_value = 10,
        order = 'bb',
    },
    {
        name = "dolly-spacing",
        setting_type = 'runtime-per-user',
        type = "int-setting",
        default_value = 20,
        minimum_value = 15,
        maximum_value = 25,
        order = 'ca',
    },
    {
        name = "dolly-direction",
        setting_type = 'runtime-per-user',
        type = "int-setting",
        default_value = defines.direction.southeast,
        allowed_values = defines.direction,
        order = 'cb',
    },
}
