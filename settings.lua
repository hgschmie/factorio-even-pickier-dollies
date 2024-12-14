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
        name = "dolly-transporter-mode",
        setting_type = 'startup',
        type = "bool-setting",
        default_value = false,
        order = 'ca',
    },
}
