-- @description STEMperator: 6-Stem All (includes Guitar & Piano)
-- @author flarkAUDIO
-- @version 2.0.0
-- @about Quick action to extract all 6 stems including Guitar and Piano

-- Load the main script's functions
local info = debug.getinfo(1, "S")
local script_path = info.source:match("@?(.*[/\\])")
if not script_path then script_path = "" end

-- Set 6-stem model and all stems selected
reaper.SetExtState("Stemperator", "model", "htdemucs_6s", false)
reaper.SetExtState("Stemperator", "stem_Vocals", "1", false)
reaper.SetExtState("Stemperator", "stem_Drums", "1", false)
reaper.SetExtState("Stemperator", "stem_Bass", "1", false)
reaper.SetExtState("Stemperator", "stem_Other", "1", false)
reaper.SetExtState("Stemperator", "stem_Guitar", "1", false)
reaper.SetExtState("Stemperator", "stem_Piano", "1", false)
reaper.SetExtState("Stemperator", "quickAction", "1", false)

-- Run the main script
dofile(script_path .. "Stemperator_AI_Separate.lua")
