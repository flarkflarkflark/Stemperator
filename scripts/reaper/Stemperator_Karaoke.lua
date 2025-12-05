-- @description Stemperator - Quick Karaoke (Remove Vocals)
-- @author flarkAUDIO
-- @version 1.0.0
-- @changelog
--   Initial release
-- @link Repository https://github.com/flarkflarkflark/Stemperator
-- @about
--   Quick action: Separates stems and creates karaoke version (no vocals).
--   Perfect for toolbar button - one click to remove vocals.

local SCRIPT_NAME = "Stemperator: Quick Karaoke"

-- Find the main script
local function findMainScript()
    local scriptPath = debug.getinfo(1, "S").source:match("@(.+[/\\])")
    local mainScript = scriptPath .. "Stemperator_AI_Separate.lua"

    local f = io.open(mainScript, "r")
    if f then
        f:close()
        return mainScript
    end

    -- Try REAPER resource path
    local resourcePath = reaper.GetResourcePath()
    local paths = {
        resourcePath .. "/Scripts/Stemperator/Stemperator_AI_Separate.lua",
        resourcePath .. "/Scripts/Stemperator_AI_Separate.lua",
    }

    for _, path in ipairs(paths) do
        f = io.open(path, "r")
        if f then
            f:close()
            return path
        end
    end

    return nil
end

-- Set preset and run main script
local function main()
    -- Set karaoke preset in ExtState (main script will read this)
    reaper.SetExtState("Stemperator", "quick_preset", "karaoke", false)
    reaper.SetExtState("Stemperator", "quick_run", "1", false)

    local mainScript = findMainScript()
    if mainScript then
        dofile(mainScript)
    else
        reaper.MB("Could not find Stemperator_AI_Separate.lua\n\nPlease ensure it's installed in the same folder.", SCRIPT_NAME, 0)
    end
end

main()
