--This script causes the pinned track to become unpinned (used in conjunction with Dialogue Pin Track.lua)


init_proj = reaper.EnumProjects(-1) --store the initial project

ext_key = "is_continue_" .. tostring(init_proj)

if reaper.HasExtState("pin_track", ext_key) then reaper.DeleteExtState("pin_track", ext_key, true) end