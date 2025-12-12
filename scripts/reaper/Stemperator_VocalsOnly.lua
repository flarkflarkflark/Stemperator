-- @description STEMperator - Quick Vocals Only
-- @author flarkAUDIO
-- @version 2.0.0
-- @changelog
--   Initial release
-- @link Repository https://github.com/flarkflarkflark/Stemperator
-- @about
--   Quick action: Extracts only the vocal stem.
--   Perfect for vocal sampling or acapella creation.

local SCRIPT_NAME = "STEMperator: Quick Vocals Only"

local function findMainScript()
    local scriptPath = debug.getinfo(1, "S").source:match("@(.+[/\\])")
    local mainScript = scriptPath .. "Stemperator_AI_Separate.lua"

    local f = io.open(mainScript, "r")
    if f then
        f:close()
        return mainScript
    end

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

local function main()
    reaper.SetExtState("Stemperator", "quick_preset", "vocals", false)
    reaper.SetExtState("Stemperator", "quick_run", "1", false)

    local mainScript = findMainScript()
    if mainScript then
        dofile(mainScript)
    else
        reaper.MB("Could not find Stemperator_AI_Separate.lua", SCRIPT_NAME, 0)
    end
end

main()
