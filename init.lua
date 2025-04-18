-- sfs/init.lua
local modpath = core.get_modpath(core.get_current_modname()) .. "/"

local sfs = dofile(modpath .. "api.lua")

dofile(modpath .. "template.lua")(sfs)