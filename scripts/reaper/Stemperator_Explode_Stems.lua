-- @description Stemperator - Explode Stems to Tracks
-- @author flarkAUDIO
-- @version 1.5.0
-- @changelog
--   v1.5.0: Rewritten for takes explode functionality
--   v1.0.0: Initial release
-- @link Repository https://github.com/flarkflarkflark/Stemperator
-- @about
--   # Stemperator - Explode Stems to Tracks
--
--   Explodes STEMperator takes (from In-place mode) to separate tracks.
--   Properly preserves volume, position, and all item properties.
--
--   ## Usage
--   1. Select item(s) containing STEMperator takes
--   2. Run this script
--   3. Each take becomes its own track
--
--   ## License
--   MIT License - https://opensource.org/licenses/MIT

local SCRIPT_NAME = "Stemperator: Explode Stems to Tracks"

-- Stem colors (matching main script)
local STEM_COLORS = {
    Vocals = {255, 100, 100},
    Drums  = {100, 200, 255},
    Bass   = {150, 100, 255},
    Other  = {100, 255, 150},
    Guitar = {255, 180, 100},
    Piano  = {255, 255, 100},
}

-- Convert RGB to Reaper color format
local function rgbToReaperColor(r, g, b)
    return reaper.ColorToNative(r, g, b) | 0x1000000
end

-- Get color for stem name
local function getStemColor(name)
    local colors = STEM_COLORS[name]
    if colors then
        return rgbToReaperColor(colors[1], colors[2], colors[3])
    end
    return rgbToReaperColor(180, 180, 180)  -- Default gray
end

-- Main function
local function main()
    local numSelectedItems = reaper.CountSelectedMediaItems(0)

    if numSelectedItems == 0 then
        reaper.MB("Please select one or more items with multiple takes to explode.", SCRIPT_NAME, 0)
        return
    end

    -- Count total takes across all selected items
    local totalTakes = 0
    local itemsWithTakes = 0
    for i = 0, numSelectedItems - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        local numTakes = reaper.CountTakes(item)
        if numTakes > 1 then
            totalTakes = totalTakes + numTakes
            itemsWithTakes = itemsWithTakes + 1
        end
    end

    if itemsWithTakes == 0 then
        reaper.MB("Selected items don't have multiple takes to explode.\n\nThis script is for exploding STEMperator takes created with 'In-place (takes)' mode.", SCRIPT_NAME, 0)
        return
    end

    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)

    local totalCreated = 0

    -- Process each selected item
    for itemIdx = 0, numSelectedItems - 1 do
        local item = reaper.GetSelectedMediaItem(0, itemIdx)
        if not item then goto continue end

        local numTakes = reaper.CountTakes(item)
        if numTakes <= 1 then goto continue end

        local track = reaper.GetMediaItem_Track(item)
        local trackIdx = math.floor(reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER"))
        local _, trackName = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
        if trackName == "" then trackName = "Track " .. trackIdx end

        local itemPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local itemLen = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        local itemVol = reaper.GetMediaItemInfo_Value(item, "D_VOL")
        local itemFadeIn = reaper.GetMediaItemInfo_Value(item, "D_FADEINLEN")
        local itemFadeOut = reaper.GetMediaItemInfo_Value(item, "D_FADEOUTLEN")

        -- Create a track for each take
        for takeIdx = 0, numTakes - 1 do
            local take = reaper.GetTake(item, takeIdx)
            if not take then goto nextTake end

            local _, takeName = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
            local takeVol = reaper.GetMediaItemTakeInfo_Value(take, "D_VOL")
            local takeOffset = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
            local takePlayrate = reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
            local source = reaper.GetMediaItemTake_Source(take)

            if not source then goto nextTake end

            -- Insert new track
            reaper.InsertTrackAtIndex(trackIdx + takeIdx, true)
            local newTrack = reaper.GetTrack(0, trackIdx + takeIdx)

            -- Set track name and color
            local newTrackName = trackName .. " - " .. takeName
            reaper.GetSetMediaTrackInfo_String(newTrack, "P_NAME", newTrackName, true)
            reaper.SetMediaTrackInfo_Value(newTrack, "I_CUSTOMCOLOR", getStemColor(takeName))

            -- Create new item on the new track
            local newItem = reaper.AddMediaItemToTrack(newTrack)
            reaper.SetMediaItemInfo_Value(newItem, "D_POSITION", itemPos)
            reaper.SetMediaItemInfo_Value(newItem, "D_LENGTH", itemLen)
            reaper.SetMediaItemInfo_Value(newItem, "D_VOL", itemVol)
            reaper.SetMediaItemInfo_Value(newItem, "D_FADEINLEN", itemFadeIn)
            reaper.SetMediaItemInfo_Value(newItem, "D_FADEOUTLEN", itemFadeOut)
            reaper.SetMediaItemInfo_Value(newItem, "I_CUSTOMCOLOR", getStemColor(takeName))

            -- Create take with same source
            local newTake = reaper.AddTakeToMediaItem(newItem)
            reaper.SetMediaItemTake_Source(newTake, source)
            reaper.GetSetMediaItemTakeInfo_String(newTake, "P_NAME", takeName, true)
            reaper.SetMediaItemTakeInfo_Value(newTake, "D_VOL", takeVol)
            reaper.SetMediaItemTakeInfo_Value(newTake, "D_STARTOFFS", takeOffset)
            reaper.SetMediaItemTakeInfo_Value(newTake, "D_PLAYRATE", takePlayrate)

            totalCreated = totalCreated + 1

            ::nextTake::
        end

        -- Delete the original item
        reaper.DeleteTrackMediaItem(track, item)

        ::continue::
    end

    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
    reaper.Undo_EndBlock(SCRIPT_NAME, -1)

    if totalCreated > 0 then
        local trackWord = totalCreated == 1 and "track" or "tracks"
        reaper.MB("Exploded " .. totalCreated .. " takes to separate " .. trackWord .. ".", SCRIPT_NAME, 0)
    end
end

main()
