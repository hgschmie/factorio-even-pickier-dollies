---@meta

--
-- settings code
--

---@class EvenPickierDolliesSettings
local mod_settings = {}

---@param player LuaPlayer
---@return integer
function mod_settings.get_save_entity(player)
    return player.mod_settings['dolly-save-entity'].value or 4 --[[@as uint]]
end

---@param player LuaPlayer
---@return boolean
function mod_settings.get_fluid_careful(player)
    return player.mod_settings['dolly-fluid-careful'].value --[[@as boolean]]
end

---@param player LuaPlayer
---@return boolean
function mod_settings.get_ignore_collisions(player)
    return player.mod_settings['dolly-ignore-collisions'].value --[[@as boolean]]
end

---@return boolean
function mod_settings.get_allow_ignore_collisions()
    return settings.global['dolly-allow-ignore-collisions'].value --[[@as boolean ]]
end

---@param player LuaPlayer
---@return boolean
function mod_settings.get_debug(player)
    return player.mod_settings['dolly-debug'].value or false --[[@as boolean]]
end

---@param player LuaPlayer
---@return integer
function mod_settings.get_attempts(player)
    return (mod_settings.get_debug(player) and player.mod_settings['dolly-attempts'].value) or 5 --[[@as integer]]
end

---@param player LuaPlayer
---@return integer
function mod_settings.get_spacing(player)
    return player.mod_settings['dolly-spacing'].value or 20 --[[@as integer]]
end

---@param player LuaPlayer
---@return defines.direction
function mod_settings.get_direction(player)
    return player.mod_settings['dolly-direction'].value or defines.direction.southeast --[[@as defines.direction]]
end

return mod_settings
