-- @description STEMperator - Explode Stems to Tracks
-- @author flarkAUDIO
-- @version 2.0.0
-- @changelog
--   Initial release
-- @link Repository https://github.com/flarkflarkflark/Stemperator
-- @about
--   # STEMperator - Explode Stems to Tracks
--
--   Creates 4 new tracks (Vocals, Drums, Bass, Other) and routes
--   STEMperator VST3 plugin's multi-outputs to them.
--
--   ## Usage
--   1. Select the track containing STEMperator VST3
--   2. Run this script (Actions > STEMperator: Explode Stems)
--   3. 4 new tracks will be created with proper routing
--
--   Alternative: If no track is selected, you can import pre-exported
--   stem files (vocals.wav, drums.wav, bass.wav, other.wav) from a folder.
--
--   ## License
--   MIT License - https://opensource.org/licenses/MIT

local SCRIPT_NAME = "STEMperator: Explode Stems to Tracks"

-- Stem configuration: name, color (RGB), output channel pair (0-indexed)
local STEMS = {
    { name = "Vocals", color = {255, 100, 100}, outputChan = 0 },   -- Output 1-2
    { name = "Drums",  color = {100, 200, 255}, outputChan = 2 },   -- Output 3-4
    { name = "Bass",   color = {150, 100, 255}, outputChan = 4 },   -- Output 5-6
    { name = "Other",  color = {100, 255, 150}, outputChan = 6 },   -- Output 7-8
}

-- Convert RGB to Reaper color format (native OS color)
local function rgbToReaperColor(r, g, b)
    return reaper.ColorToNative(r, g, b) | 0x1000000
end

-- Find Stemperator plugin on a track
local function findStemperatorFX(track)
    local fxCount = reaper.TrackFX_GetCount(track)
    for i = 0, fxCount - 1 do
        local _, fxName = reaper.TrackFX_GetFXName(track, i, "")
        if fxName:lower():find("stemperator") then
            return i
        end
    end
    return nil
end

-- Check if track has multi-output plugin
local function hasMultiOutput(track)
    local fxIdx = findStemperatorFX(track)
    if not fxIdx then return false end

    -- Stemperator has 4 stereo outputs (8 channels total)
    -- Check by looking at the plugin's output configuration
    return true  -- Assume Stemperator always has multi-outputs
end

-- Create stem tracks with routing from source track
local function createStemTracks(sourceTrack, sourceTrackIdx)
    local trackName = ({reaper.GetSetMediaTrackInfo_String(sourceTrack, "P_NAME", "", false)})[2]
    if trackName == "" then
        trackName = "Track " .. (sourceTrackIdx + 1)
    end

    reaper.Undo_BeginBlock()

    -- Create a folder track for organization (optional)
    local createFolder = reaper.MB(
        "Create a folder track to organize stems?\n\n" ..
        "Yes = Create folder with stem tracks inside\n" ..
        "No = Create stem tracks at same level",
        SCRIPT_NAME, 4)

    local insertIdx = sourceTrackIdx + 1
    local folderTrack = nil

    if createFolder == 6 then  -- Yes
        reaper.InsertTrackAtIndex(insertIdx, true)
        folderTrack = reaper.GetTrack(0, insertIdx)
        reaper.GetSetMediaTrackInfo_String(folderTrack, "P_NAME", trackName .. " - Stems", true)
        reaper.SetMediaTrackInfo_Value(folderTrack, "I_FOLDERDEPTH", 1)  -- Start folder
        reaper.SetMediaTrackInfo_Value(folderTrack, "I_FOLDERCOMPACT", 0)  -- Expanded
        insertIdx = insertIdx + 1
    end

    -- Create stem tracks
    local stemTracks = {}
    for i, stem in ipairs(STEMS) do
        reaper.InsertTrackAtIndex(insertIdx + i - 1, true)
        local newTrack = reaper.GetTrack(0, insertIdx + i - 1)

        -- Set track name
        local stemTrackName = trackName .. " - " .. stem.name
        reaper.GetSetMediaTrackInfo_String(newTrack, "P_NAME", stemTrackName, true)

        -- Set track color
        local color = rgbToReaperColor(stem.color[1], stem.color[2], stem.color[3])
        reaper.SetMediaTrackInfo_Value(newTrack, "I_CUSTOMCOLOR", color)

        -- Store for routing setup
        stemTracks[i] = { track = newTrack, outputChan = stem.outputChan }
    end

    -- Close folder if created
    if folderTrack then
        local lastStemTrack = stemTracks[#stemTracks].track
        reaper.SetMediaTrackInfo_Value(lastStemTrack, "I_FOLDERDEPTH", -1)  -- End folder
    end

    -- Setup routing: source track outputs -> stem track inputs
    -- First, mute the source track's master send (we don't want double audio)
    reaper.SetMediaTrackInfo_Value(sourceTrack, "B_MAINSEND", 0)

    -- Create sends from source to each stem track
    for i, stemInfo in ipairs(stemTracks) do
        local sendIdx = reaper.CreateTrackSend(sourceTrack, stemInfo.track)

        -- Configure send: source channel = Stemperator output pair
        -- I_SRCCHAN: source channel (0=stereo pair 1-2, 2=pair 3-4, etc.)
        -- I_DSTCHAN: destination channel (0=track input 1-2)
        reaper.SetTrackSendInfo_Value(sourceTrack, 0, sendIdx, "I_SRCCHAN", stemInfo.outputChan)
        reaper.SetTrackSendInfo_Value(sourceTrack, 0, sendIdx, "I_DSTCHAN", 0)

        -- Set send to post-fader
        reaper.SetTrackSendInfo_Value(sourceTrack, 0, sendIdx, "I_SENDMODE", 0)

        -- Enable send
        reaper.SetTrackSendInfo_Value(sourceTrack, 0, sendIdx, "B_MUTE", 0)
    end

    reaper.Undo_EndBlock(SCRIPT_NAME, -1)

    return #stemTracks
end

-- Alternative: Import stem files from folder
local function importStemFiles()
    local retval, folder = reaper.JS_Dialog_BrowseForFolder("Select Stemperator output folder", "")
    if not retval or folder == "" then return 0 end

    local stemFiles = {
        { name = "Vocals", pattern = "vocals" },
        { name = "Drums",  pattern = "drums" },
        { name = "Bass",   pattern = "bass" },
        { name = "Other",  pattern = "other" },
    }

    reaper.Undo_BeginBlock()

    local cursorPos = reaper.GetCursorPosition()
    local imported = 0

    for i, stem in ipairs(stemFiles) do
        -- Try to find stem file
        local filePath = nil
        for _, ext in ipairs({".wav", ".flac", ".mp3"}) do
            local testPath = folder .. "/" .. stem.pattern .. ext
            if reaper.file_exists(testPath) then
                filePath = testPath
                break
            end
            -- Also try with underscore prefix (e.g., songname_vocals.wav)
            local files = io.popen('ls "' .. folder .. '"/*' .. stem.pattern .. '*' .. ext .. ' 2>/dev/null')
            if files then
                local found = files:read("*l")
                files:close()
                if found then
                    filePath = found
                    break
                end
            end
        end

        if filePath then
            -- Insert new track
            reaper.InsertTrackAtIndex(reaper.CountTracks(0), true)
            local newTrack = reaper.GetTrack(0, reaper.CountTracks(0) - 1)

            -- Set track name and color
            reaper.GetSetMediaTrackInfo_String(newTrack, "P_NAME", stem.name, true)
            local color = rgbToReaperColor(STEMS[i].color[1], STEMS[i].color[2], STEMS[i].color[3])
            reaper.SetMediaTrackInfo_Value(newTrack, "I_CUSTOMCOLOR", color)

            -- Insert media item
            reaper.InsertMedia(filePath, 0)  -- Insert on selected track at cursor

            imported = imported + 1
        end
    end

    reaper.Undo_EndBlock("Stemperator: Import Stem Files", -1)

    return imported
end

-- Main function
local function main()
    -- Check if a track is selected
    local track = reaper.GetSelectedTrack(0, 0)

    if not track then
        -- No track selected - offer to import stem files instead
        local response = reaper.MB(
            "No track selected.\n\n" ..
            "Would you like to import stem files from a folder instead?\n\n" ..
            "(Select a folder containing vocals.wav, drums.wav, bass.wav, other.wav)",
            SCRIPT_NAME, 4)

        if response == 6 then  -- Yes
            local imported = importStemFiles()
            if imported > 0 then
                reaper.MB("Imported " .. imported .. " stem files.", SCRIPT_NAME, 0)
            else
                reaper.MB("No stem files found in the selected folder.", SCRIPT_NAME, 0)
            end
        end
        return
    end

    local trackIdx = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") - 1
    local _, trackName = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)

    -- Check if STEMperator is on this track
    local fxIdx = findStemperatorFX(track)

    if not fxIdx then
        -- STEMperator not found - offer options
        local response = reaper.MB(
            "STEMperator VST3 not found on selected track '" .. trackName .. "'.\n\n" ..
            "Options:\n" ..
            "1. Add STEMperator to this track first, then run again\n" ..
            "2. Import stem files from a folder\n\n" ..
            "Would you like to import stem files instead?",
            SCRIPT_NAME, 4)

        if response == 6 then  -- Yes
            local imported = importStemFiles()
            if imported > 0 then
                reaper.MB("Imported " .. imported .. " stem files.", SCRIPT_NAME, 0)
            else
                reaper.MB("No stem files found in the selected folder.", SCRIPT_NAME, 0)
            end
        end
        return
    end

    -- STEMperator found - create stem tracks
    local created = createStemTracks(track, trackIdx)

    if created > 0 then
        reaper.MB(
            "Created " .. created .. " stem tracks with routing from STEMperator.\n\n" ..
            "The source track's master send has been disabled.\n" ..
            "Each stem track receives one stereo output from STEMperator.",
            SCRIPT_NAME, 0)
    end

    -- Update arrange view
    reaper.TrackList_AdjustWindows(false)
    reaper.UpdateArrange()
end

-- Run
main()
