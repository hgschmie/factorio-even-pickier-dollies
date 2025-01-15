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

---@return boolean
function mod_settings.get_transporter_mode()
    return settings.startup['dolly-transporter-mode'].value or false --[[@as boolean]]
end

---@param player LuaPlayer
---@return boolean
function mod_settings.get_clear_entity(player)
    return player.mod_settings['dolly-clear-entity'].value or false --[[@as boolean]]
end

return mod_settings
