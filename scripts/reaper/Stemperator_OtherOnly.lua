-- @description STEMperator: Other Only (guitars/synths/keys)
-- @author flarkAUDIO
-- @version 1.0.0
-- @about Quick action to extract only the "Other" stem (guitars, synths, keys, etc.)

-- Load the main script's functions
local info = debug.getinfo(1, "S")
local script_path = info.source:match("@?(.*[/\\])")
if not script_path then script_path = "" end

-- Set preset before loading main script
reaper.SetExtState("Stemperator", "stem_Vocals", "0", false)
reaper.SetExtState("Stemperator", "stem_Drums", "0", false)
reaper.SetExtState("Stemperator", "stem_Bass", "0", false)
reaper.SetExtState("Stemperator", "stem_Other", "1", false)
reaper.SetExtState("Stemperator", "stem_Guitar", "0", false)
reaper.SetExtState("Stemperator", "stem_Piano", "0", false)
reaper.SetExtState("Stemperator", "quickAction", "1", false)

-- Run the main script
dofile(script_path .. "Stemperator_AI_Separate.lua")
