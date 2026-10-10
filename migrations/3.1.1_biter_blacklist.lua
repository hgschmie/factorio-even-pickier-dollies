-- The old table did not distinguish this default from API registrations. Clear
-- the legacy entry once; future API bans survive startup-setting changes because
-- the setting now has a separate blacklist.
if storage.blacklist_names then
    storage.blacklist_names['captive-biter-spawner'] = nil
end
