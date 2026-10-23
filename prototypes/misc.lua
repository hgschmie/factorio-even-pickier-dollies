--
-- add a mod-data object to manage the blacklist
--

local const = require('scripts.constants')

data:extend({
    {
        type = 'mod-data',
        name = 'even-pickier-dollies',
        data_type = 'even-pickier-dollies',
        data = {
            blacklist_names = {},
        },
    },
})

data:extend({
    {
        type = 'custom-event',
        name = const.event_name,
        hidden = true,
    },
})
