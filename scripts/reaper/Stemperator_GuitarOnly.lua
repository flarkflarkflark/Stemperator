-- @description STEMperator: Guitar Only (6-stem model)
-- @author flarkAUDIO
-- @version 2.0.0
-- @about Quick action to extract only the Guitar stem using the 6-stem model

-- Load the main script's functions
local info = debug.getinfo(1, "S")
local script_path = info.source:match("@?(.*[/\\])")
if not script_path then script_path = "" end

-- Set 6-stem model and guitar only
reaper.SetExtState("Stemperator", "model", "htdemucs_6s", false)
reaper.SetExtState("Stemperator", "stem_Vocals", "0", false)
reaper.SetExtState("Stemperator", "stem_Drums", "0", false)
reaper.SetExtState("Stemperator", "stem_Bass", "0", false)
reaper.SetExtState("Stemperator", "stem_Other", "0", false)
reaper.SetExtState("Stemperator", "stem_Guitar", "1", false)
reaper.SetExtState("Stemperator", "stem_Piano", "0", false)
reaper.SetExtState("Stemperator", "quickAction", "1", false)

-- Run the main script
dofile(script_path .. "Stemperator_AI_Separate.lua")
