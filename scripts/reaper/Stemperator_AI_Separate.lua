-- @description Stemperator - AI Stem Separation
-- @author flarkAUDIO
-- @version 1.5.0
-- @changelog
--   v1.5.0: Improved cross-platform support
--   - Better Python detection (Homebrew, Windows venvs, user paths)
--   - Added ~/.stemperator/.venv support for global installation
--   - macOS: Added /opt/homebrew paths for Apple Silicon
--   - Windows: Better AppData Python detection
--   - Run "Stemperator: Setup AI Backend" to verify installation
--   v1.4.0: Time selection support
--   - Can now separate time selections (not just media items)
--   - If no item selected, uses time selection instead
--   - Stems are placed at the time selection position
--   v1.3.0: 6-stem model support with Guitar/Piano
--   - Guitar and Piano checkboxes appear when 6-stem model selected
--   - Keys 5/6 toggle Guitar/Piano stems
--   v1.2.0: Scalable/resizable GUI
--   - Window is now resizable (drag edges/corners)
--   - All elements scale proportionally with window size
--   v1.1.0: Major update
--   - Persist settings between sessions (REAPER ExtState)
--   - Keyboard shortcuts: 1-4 toggle stems, K=Karaoke, I=Instrumental
--   v1.0.0: Initial release
-- @provides
--   [main] .
--   [nomain] audio_separator_process.py
-- @link Repository https://github.com/flarkflarkflark/Stemperator
-- @about
--   # Stemperator - AI Stem Separation
--
--   High-quality AI-powered stem separation using Demucs/audio-separator.
--   Separates the selected media item (or time selection) into stems:
--   Vocals, Drums, Bass, Other (and optionally Guitar, Piano with 6-stem model).
--
--   ## Features
--   - Processes ONLY the selected item portion (respects splits!)
--   - Choose which stems to extract via checkboxes or presets
--   - Quick presets: Karaoke, Instrumental, Drums Only
--   - Keyboard shortcuts for fast workflow
--   - Settings persist between sessions
--   - Option to create new tracks or replace in-place (as takes)
--   - GPU acceleration support (NVIDIA CUDA, AMD ROCm)
--
--   ## Keyboard Shortcuts (in dialog)
--   - 1-4: Toggle Vocals/Drums/Bass/Other
--   - K: Karaoke preset (instrumental only)
--   - I: Instrumental preset (no vocals)
--   - D: Drums Only preset
--   - Enter: Start separation
--   - Escape: Cancel
--
--   ## Requirements
--   - Python 3.9+ with audio-separator:
--     `pip install audio-separator[gpu]`
--   - ffmpeg installed and in PATH
--
--   ## License
--   MIT License - https://opensource.org/licenses/MIT

local SCRIPT_NAME = "Stemperator"
local EXT_SECTION = "Stemperator"  -- For ExtState persistence

-- Debug mode - set to true to enable debug logging
local DEBUG_MODE = true
local DEBUG_LOG_PATH = nil  -- Set during init

local function debugLog(msg)
    if not DEBUG_MODE then return end
    if not DEBUG_LOG_PATH then
        local tempDir = os.getenv("TEMP") or os.getenv("TMP") or os.getenv("TMPDIR") or "/tmp"
        DEBUG_LOG_PATH = tempDir .. (package.config:sub(1,1) == "\\" and "\\" or "/") .. "stemperator_debug.log"
    end
    local f = io.open(DEBUG_LOG_PATH, "a")
    if f then
        f:write(os.date("[%Y-%m-%d %H:%M:%S] ") .. tostring(msg) .. "\n")
        f:close()
    end
end

-- Clear debug log on script start
local function clearDebugLog()
    if not DEBUG_MODE then return end
    local tempDir = os.getenv("TEMP") or os.getenv("TMP") or os.getenv("TMPDIR") or "/tmp"
    DEBUG_LOG_PATH = tempDir .. (package.config:sub(1,1) == "\\" and "\\" or "/") .. "stemperator_debug.log"
    local f = io.open(DEBUG_LOG_PATH, "w")
    if f then
        f:write("=== Stemperator Debug Log ===\n")
        f:write("Started: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n\n")
        f:close()
    end
end

clearDebugLog()
debugLog("Script loaded")

-- Get script path for finding audio_separator_process.py
local info = debug.getinfo(1, "S")
local script_path = info.source:match("@?(.*[/\\])")
if not script_path then script_path = "" end

-- Detect OS
local function getOS()
    local sep = package.config:sub(1,1)
    if sep == "\\" then return "Windows"
    elseif reaper.GetOS():match("OSX") or reaper.GetOS():match("macOS") then return "macOS"
    else return "Linux"
    end
end

local OS = getOS()
local PATH_SEP = OS == "Windows" and "\\" or "/"

-- Get home directory (cross-platform)
local function getHome()
    if OS == "Windows" then
        return os.getenv("USERPROFILE") or "C:\\Users\\Default"
    else
        return os.getenv("HOME") or "/tmp"
    end
end

-- Configuration - Auto-detect paths (cross-platform)
local function findPython()
    local paths = {}
    local home = getHome()

    if OS == "Windows" then
        -- Windows paths - check venvs first
        table.insert(paths, script_path .. ".venv\\Scripts\\python.exe")
        table.insert(paths, home .. "\\Documents\\Stemperator\\.venv\\Scripts\\python.exe")
        table.insert(paths, "C:\\Users\\Administrator\\Documents\\Stemperator\\.venv\\Scripts\\python.exe")
        table.insert(paths, home .. "\\.stemperator\\.venv\\Scripts\\python.exe")
        table.insert(paths, script_path .. "..\\..\\..\\venv\\Scripts\\python.exe")
        -- Standard Python locations
        local localAppData = os.getenv("LOCALAPPDATA") or ""
        table.insert(paths, localAppData .. "\\Programs\\Python\\Python312\\python.exe")
        table.insert(paths, localAppData .. "\\Programs\\Python\\Python311\\python.exe")
        table.insert(paths, localAppData .. "\\Programs\\Python\\Python310\\python.exe")
        table.insert(paths, "python")
    else
        -- Linux/macOS paths - check venvs first
        table.insert(paths, script_path .. ".venv/bin/python")
        table.insert(paths, home .. "/.stemperator/.venv/bin/python")
        table.insert(paths, script_path .. "../.venv/bin/python")
        -- Homebrew on macOS
        if OS == "macOS" then
            table.insert(paths, "/opt/homebrew/bin/python3")
            table.insert(paths, "/usr/local/opt/python@3.12/bin/python3")
        end
        -- User local and system paths
        table.insert(paths, home .. "/.local/bin/python3")
        table.insert(paths, "/usr/local/bin/python3")
        table.insert(paths, "/usr/bin/python3")
        table.insert(paths, "python3")
        table.insert(paths, "python")
    end

    for _, p in ipairs(paths) do
        local f = io.open(p, "r")
        if f then f:close(); return p end
    end
    return OS == "Windows" and "python" or "python3"
end

local function findSeparatorScript()
    local home = getHome()
    local paths = {
        script_path .. "audio_separator_process.py",
        script_path .. ".." .. PATH_SEP .. "AI" .. PATH_SEP .. "audio_separator_process.py",
        script_path .. ".." .. PATH_SEP .. ".." .. PATH_SEP .. "Source" .. PATH_SEP .. "AI" .. PATH_SEP .. "audio_separator_process.py",
        home .. PATH_SEP .. "Documents" .. PATH_SEP .. "Stemperator" .. PATH_SEP .. "scripts" .. PATH_SEP .. "reaper" .. PATH_SEP .. "audio_separator_process.py",
        home .. PATH_SEP .. "Documents" .. PATH_SEP .. "Stemperator" .. PATH_SEP .. "Source" .. PATH_SEP .. "AI" .. PATH_SEP .. "audio_separator_process.py",
    }
    for _, p in ipairs(paths) do
        local f = io.open(p, "r")
        if f then f:close(); return p end
    end
    return script_path .. "audio_separator_process.py"
end

local PYTHON_PATH = findPython()
local SEPARATOR_SCRIPT = findSeparatorScript()

-- Stem configuration (with selection state)
-- First 4 are always shown, Guitar/Piano only for 6-stem model
local STEMS = {
    { name = "Vocals", color = {255, 100, 100}, file = "vocals.wav", selected = true, key = "1", sixStemOnly = false },
    { name = "Drums",  color = {100, 200, 255}, file = "drums.wav", selected = true, key = "2", sixStemOnly = false },
    { name = "Bass",   color = {150, 100, 255}, file = "bass.wav", selected = true, key = "3", sixStemOnly = false },
    { name = "Other",  color = {100, 255, 150}, file = "other.wav", selected = true, key = "4", sixStemOnly = false },
    { name = "Guitar", color = {255, 180, 80},  file = "guitar.wav", selected = true, key = "5", sixStemOnly = true },
    { name = "Piano",  color = {255, 120, 200}, file = "piano.wav", selected = true, key = "6", sixStemOnly = true },
}

-- Available models
local MODELS = {
    { id = "htdemucs", name = "Fast", desc = "htdemucs - Fastest model, good quality (4 stems)" },
    { id = "htdemucs_ft", name = "Quality", desc = "htdemucs_ft - Best quality, slower (4 stems)" },
    { id = "htdemucs_6s", name = "6-Stem", desc = "htdemucs_6s - Adds Guitar & Piano separation" },
}

-- Settings (persist between runs)
local SETTINGS = {
    model = "htdemucs",
    createNewTracks = true,
    createFolder = false,
    muteOriginal = false,      -- Mute original item(s) after separation
    muteSelection = false,     -- Mute only the selection portion (splits item)
    deleteOriginal = false,
    deleteSelection = false,   -- Delete only the selection portion (splits item)
    deleteOriginalTrack = false,
    darkMode = true,           -- Dark/Light theme toggle
    parallelProcessing = true, -- Process multiple tracks in parallel (uses more GPU memory)
}

-- Theme colors (will be set based on darkMode)
local THEME = {}

local function updateTheme()
    if SETTINGS.darkMode then
        -- Dark theme
        THEME = {
            bg = {0.18, 0.18, 0.20},
            bgGradientTop = {0.10, 0.10, 0.12},
            bgGradientBottom = {0.18, 0.18, 0.20},
            inputBg = {0.12, 0.12, 0.14},
            text = {1, 1, 1},
            textDim = {0.7, 0.7, 0.7},
            textHint = {0.5, 0.5, 0.5},
            accent = {0.3, 0.5, 0.8},
            accentHover = {0.4, 0.6, 0.9},
            checkbox = {0.3, 0.3, 0.3},
            checkboxChecked = {0.3, 0.5, 0.7},
            button = {0.2, 0.4, 0.7},
            buttonHover = {0.3, 0.5, 0.8},
            buttonPrimary = {0.2, 0.5, 0.3},
            buttonPrimaryHover = {0.3, 0.6, 0.4},
            border = {0.6, 0.6, 0.6},
        }
    else
        -- Light theme
        THEME = {
            bg = {0.92, 0.92, 0.94},
            bgGradientTop = {0.96, 0.96, 0.98},
            bgGradientBottom = {0.88, 0.88, 0.90},
            inputBg = {0.85, 0.85, 0.87},
            text = {0.1, 0.1, 0.1},
            textDim = {0.3, 0.3, 0.3},
            textHint = {0.5, 0.5, 0.5},
            accent = {0.2, 0.4, 0.7},
            accentHover = {0.3, 0.5, 0.8},
            checkbox = {0.8, 0.8, 0.8},
            checkboxChecked = {0.3, 0.5, 0.7},
            button = {0.3, 0.5, 0.75},
            buttonHover = {0.4, 0.6, 0.85},
            buttonPrimary = {0.25, 0.55, 0.35},
            buttonPrimaryHover = {0.35, 0.65, 0.45},
            border = {0.4, 0.4, 0.4},
        }
    end
end

-- Initialize theme
updateTheme()

-- GUI state
local GUI = {
    running = false,
    result = nil,
    wasMouseDown = false,
    logoWasClicked = false,
    -- Scaling
    baseW = 340,
    baseH = 346,
    minW = 340,
    minH = 346,
    maxW = 1360,  -- Up to 4x scale
    maxH = 1384,
    scale = 1.0,
    -- Tooltip
    tooltip = nil,
    tooltipX = 0,
    tooltipY = 0,
}

-- Store last dialog position for subsequent windows (progress, result, messages)
local lastDialogX, lastDialogY, lastDialogW, lastDialogH = nil, nil, 380, 340

-- Track auto-selected items and tracks for restore on cancel
local autoSelectedItems = {}
local autoSelectionTracks = {}  -- Tracks that were selected when we auto-selected items

-- Store playback state to restore after processing
local savedPlaybackState = 0  -- 0=stopped, 1=playing, 2=paused, 5=recording, 6=record paused

-- Load settings from ExtState
local function loadSettings()
    local model = reaper.GetExtState(EXT_SECTION, "model")
    if model ~= "" then SETTINGS.model = model end

    local createNewTracks = reaper.GetExtState(EXT_SECTION, "createNewTracks")
    if createNewTracks ~= "" then SETTINGS.createNewTracks = (createNewTracks == "1") end

    local createFolder = reaper.GetExtState(EXT_SECTION, "createFolder")
    if createFolder ~= "" then SETTINGS.createFolder = (createFolder == "1") end

    local muteOriginal = reaper.GetExtState(EXT_SECTION, "muteOriginal")
    if muteOriginal ~= "" then SETTINGS.muteOriginal = (muteOriginal == "1") end

    local muteSelection = reaper.GetExtState(EXT_SECTION, "muteSelection")
    if muteSelection ~= "" then SETTINGS.muteSelection = (muteSelection == "1") end

    local deleteOriginal = reaper.GetExtState(EXT_SECTION, "deleteOriginal")
    if deleteOriginal ~= "" then SETTINGS.deleteOriginal = (deleteOriginal == "1") end

    local deleteSelection = reaper.GetExtState(EXT_SECTION, "deleteSelection")
    if deleteSelection ~= "" then SETTINGS.deleteSelection = (deleteSelection == "1") end

    local deleteOriginalTrack = reaper.GetExtState(EXT_SECTION, "deleteOriginalTrack")
    if deleteOriginalTrack ~= "" then SETTINGS.deleteOriginalTrack = (deleteOriginalTrack == "1") end

    local darkMode = reaper.GetExtState(EXT_SECTION, "darkMode")
    if darkMode ~= "" then SETTINGS.darkMode = (darkMode == "1") end
    updateTheme()

    local parallelProcessing = reaper.GetExtState(EXT_SECTION, "parallelProcessing")
    if parallelProcessing ~= "" then SETTINGS.parallelProcessing = (parallelProcessing == "1") end

    -- Load stem selections
    for i, stem in ipairs(STEMS) do
        local sel = reaper.GetExtState(EXT_SECTION, "stem_" .. stem.name)
        if sel ~= "" then STEMS[i].selected = (sel == "1") end
    end

    -- Load window size and position
    local winW = reaper.GetExtState(EXT_SECTION, "windowWidth")
    local winH = reaper.GetExtState(EXT_SECTION, "windowHeight")
    local winX = reaper.GetExtState(EXT_SECTION, "windowX")
    local winY = reaper.GetExtState(EXT_SECTION, "windowY")
    if winW ~= "" then
        GUI.savedW = tonumber(winW)
        lastDialogW = GUI.savedW
    end
    if winH ~= "" then
        GUI.savedH = tonumber(winH)
        lastDialogH = GUI.savedH
    end
    if winX ~= "" then
        GUI.savedX = tonumber(winX)
        lastDialogX = GUI.savedX
    end
    if winY ~= "" then
        GUI.savedY = tonumber(winY)
        lastDialogY = GUI.savedY
    end
end

-- Save settings to ExtState
local function saveSettings()
    reaper.SetExtState(EXT_SECTION, "model", SETTINGS.model, true)
    reaper.SetExtState(EXT_SECTION, "createNewTracks", SETTINGS.createNewTracks and "1" or "0", true)
    reaper.SetExtState(EXT_SECTION, "createFolder", SETTINGS.createFolder and "1" or "0", true)
    reaper.SetExtState(EXT_SECTION, "muteOriginal", SETTINGS.muteOriginal and "1" or "0", true)
    reaper.SetExtState(EXT_SECTION, "muteSelection", SETTINGS.muteSelection and "1" or "0", true)
    reaper.SetExtState(EXT_SECTION, "deleteOriginal", SETTINGS.deleteOriginal and "1" or "0", true)
    reaper.SetExtState(EXT_SECTION, "deleteSelection", SETTINGS.deleteSelection and "1" or "0", true)
    reaper.SetExtState(EXT_SECTION, "deleteOriginalTrack", SETTINGS.deleteOriginalTrack and "1" or "0", true)
    reaper.SetExtState(EXT_SECTION, "darkMode", SETTINGS.darkMode and "1" or "0", true)
    reaper.SetExtState(EXT_SECTION, "parallelProcessing", SETTINGS.parallelProcessing and "1" or "0", true)

    for _, stem in ipairs(STEMS) do
        reaper.SetExtState(EXT_SECTION, "stem_" .. stem.name, stem.selected and "1" or "0", true)
    end

    -- Save window size and position
    if gfx.w > 0 and gfx.h > 0 then
        reaper.SetExtState(EXT_SECTION, "windowWidth", tostring(gfx.w), true)
        reaper.SetExtState(EXT_SECTION, "windowHeight", tostring(gfx.h), true)
    end
    -- Save position from lastDialogX/Y (updated when dialog closes)
    if lastDialogX and lastDialogY then
        reaper.SetExtState(EXT_SECTION, "windowX", tostring(math.floor(lastDialogX)), true)
        reaper.SetExtState(EXT_SECTION, "windowY", tostring(math.floor(lastDialogY)), true)
    end
end

-- Preset functions
local function applyPresetKaraoke()
    -- Instrumental only (no vocals) - includes Guitar+Piano in 6-stem mode
    STEMS[1].selected = false  -- Vocals OFF
    STEMS[2].selected = true   -- Drums
    STEMS[3].selected = true   -- Bass
    STEMS[4].selected = true   -- Other
    if STEMS[5] then STEMS[5].selected = true end   -- Guitar (6-stem)
    if STEMS[6] then STEMS[6].selected = true end   -- Piano (6-stem)
end

local function applyPresetInstrumental()
    -- Same as karaoke but clearer name
    applyPresetKaraoke()
end

local function applyPresetDrumsOnly()
    STEMS[1].selected = false  -- Vocals
    STEMS[2].selected = true   -- Drums ONLY
    STEMS[3].selected = false  -- Bass
    STEMS[4].selected = false  -- Other
    if STEMS[5] then STEMS[5].selected = false end  -- Guitar
    if STEMS[6] then STEMS[6].selected = false end  -- Piano
end

local function applyPresetVocalsOnly()
    STEMS[1].selected = true   -- Vocals ONLY
    STEMS[2].selected = false  -- Drums
    STEMS[3].selected = false  -- Bass
    STEMS[4].selected = false  -- Other
    if STEMS[5] then STEMS[5].selected = false end  -- Guitar
    if STEMS[6] then STEMS[6].selected = false end  -- Piano
end

local function applyPresetBassOnly()
    STEMS[1].selected = false  -- Vocals
    STEMS[2].selected = false  -- Drums
    STEMS[3].selected = true   -- Bass ONLY
    STEMS[4].selected = false  -- Other
    if STEMS[5] then STEMS[5].selected = false end  -- Guitar
    if STEMS[6] then STEMS[6].selected = false end  -- Piano
end

local function applyPresetOtherOnly()
    STEMS[1].selected = false  -- Vocals
    STEMS[2].selected = false  -- Drums
    STEMS[3].selected = false  -- Bass
    STEMS[4].selected = true   -- Other ONLY
    if STEMS[5] then STEMS[5].selected = false end  -- Guitar
    if STEMS[6] then STEMS[6].selected = false end  -- Piano
end

local function applyPresetGuitarOnly()
    -- Only works with 6-stem model
    STEMS[1].selected = false  -- Vocals
    STEMS[2].selected = false  -- Drums
    STEMS[3].selected = false  -- Bass
    STEMS[4].selected = false  -- Other
    STEMS[5].selected = true   -- Guitar ONLY
    STEMS[6].selected = false  -- Piano
end

local function applyPresetPianoOnly()
    -- Only works with 6-stem model
    STEMS[1].selected = false  -- Vocals
    STEMS[2].selected = false  -- Drums
    STEMS[3].selected = false  -- Bass
    STEMS[4].selected = false  -- Other
    STEMS[5].selected = false  -- Guitar
    STEMS[6].selected = true   -- Piano ONLY
end

local function applyPresetAll()
    for i = 1, #STEMS do
        STEMS[i].selected = true
    end
end

local function rgbToReaperColor(r, g, b)
    return reaper.ColorToNative(r, g, b) | 0x1000000
end

-- Get monitor bounds at a specific screen position (for multi-monitor support)
-- Returns screenLeft, screenTop, screenRight, screenBottom
local function getMonitorBoundsAt(x, y)
    local screenLeft, screenTop, screenRight, screenBottom = nil, nil, nil, nil

    -- Ensure integer coordinates
    x = math.floor(x)
    y = math.floor(y)

    -- Method 1: SWS BR_Win32_GetMonitorRectFromRect (most reliable for multi-monitor)
    if reaper.BR_Win32_GetMonitorRectFromRect then
        local retval, mLeft, mTop, mRight, mBottom = reaper.BR_Win32_GetMonitorRectFromRect(true, x, y, x+1, y+1)
        if retval and mLeft and mTop and mRight and mBottom and mRight > mLeft and mBottom > mTop then
            return mLeft, mTop, mRight, mBottom
        end
    end

    -- Method 2: JS_Window API to find monitor from point
    if reaper.JS_Window_GetRect then
        local mainHwnd = reaper.GetMainHwnd()
        if mainHwnd then
            local retval, left, top, right, bottom = reaper.JS_Window_GetRect(mainHwnd)
            if retval and left and top and right and bottom then
                -- Check if mouse is within REAPER main window area
                if x >= left and x <= right and y >= top and y <= bottom then
                    screenLeft, screenTop = left, top
                    screenRight, screenBottom = right, bottom
                else
                    -- Mouse is on a different monitor - estimate based on mouse position
                    -- Assume standard monitor size around the mouse position
                    local monitorW, monitorH = 1920, 1080
                    screenLeft = math.floor(x / monitorW) * monitorW
                    screenTop = math.floor(y / monitorH) * monitorH
                    screenRight = screenLeft + monitorW
                    screenBottom = screenTop + monitorH
                end
            end
        end
    end

    -- Fallback: estimate monitor based on mouse position
    if not screenLeft then
        local monitorW, monitorH = 1920, 1080
        -- Handle negative coordinates (monitors to the left/above primary)
        if x >= 0 then
            screenLeft = math.floor(x / monitorW) * monitorW
        else
            screenLeft = math.floor((x + 1) / monitorW) * monitorW - monitorW
        end
        if y >= 0 then
            screenTop = math.floor(y / monitorH) * monitorH
        else
            screenTop = math.floor((y + 1) / monitorH) * monitorH - monitorH
        end
        screenRight = screenLeft + monitorW
        screenBottom = screenTop + monitorH
    end

    return screenLeft, screenTop, screenRight, screenBottom
end

-- Clamp window position to stay fully on screen
local function clampToScreen(winX, winY, winW, winH, refX, refY)
    local screenLeft, screenTop, screenRight, screenBottom = getMonitorBoundsAt(refX, refY)
    local margin = 20

    winX = math.max(screenLeft + margin, winX)
    winY = math.max(screenTop + margin, winY)
    winX = math.min(screenRight - winW - margin, winX)
    winY = math.min(screenBottom - winH - margin, winY)

    return winX, winY
end

-- Check if there's a valid time selection
local function hasTimeSelection()
    local startTime, endTime = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
    return endTime > startTime
end

-- Message window state (for errors, warnings, info)
local messageWindowState = {
    title = "",
    message = "",
    icon = "info",  -- "info", "warning", "error"
    wasMouseDown = false,
    startTime = 0,
    monitorSelection = false,  -- When true, auto-close and open main dialog on selection
}

-- STEM colors for window borders (used by all windows)
local STEM_BORDER_COLORS = {
    {255, 100, 100},  -- Red (Vocals)
    {100, 200, 255},  -- Blue (Drums)
    {150, 100, 255},  -- Purple (Bass)
    {100, 255, 150},  -- Green (Other)
}

-- Draw colored STEM gradient border at top of window
local function drawStemBorder(x, y, w, thickness)
    thickness = thickness or 3
    for i = 0, w - 1 do
        local colorIdx = math.floor(i / w * 4) + 1
        colorIdx = math.min(4, math.max(1, colorIdx))
        local c = STEM_BORDER_COLORS[colorIdx]
        gfx.set(c[1]/255, c[2]/255, c[3]/255, 0.9)
        gfx.line(x + i, y, x + i, y + thickness - 1)
    end
end

-- Art Gallery state
local artGalleryState = {
    currentArt = 1,
    wasMouseDown = false,
    startTime = 0,
    -- Camera controls for flying through gallery
    zoom = 1.0,
    panX = 0,
    panY = 0,
    targetZoom = 1.0,
    targetPanX = 0,
    targetPanY = 0,
    isDragging = false,
    dragStartX = 0,
    dragStartY = 0,
    dragStartPanX = 0,
    dragStartPanY = 0,
    lastMouseWheel = 0,
}

-- STEMperator Art Gallery - Spectacular animated visualizations
-- Each piece is a fully animated graphical artwork
local stemperatorArt = {
    {
        title = "The Prism of Sound",
        subtitle = "White light becomes a spectrum of music",
        description = "Audio enters as one, emerges as four distinct colors of sound",
    },
    {
        title = "Neural Separation",
        subtitle = "Deep learning dissects the mix",
        description = "Watch as AI neurons fire and separate the tangled waveforms",
    },
    {
        title = "The Four Elements",
        subtitle = "Voice, Rhythm, Bass, Harmony",
        description = "Like earth, water, fire and air - four essences of music",
    },
    {
        title = "Waveform Surgery",
        subtitle = "Precision extraction in real-time",
        description = "Surgical separation of intertwined frequencies",
    },
    {
        title = "The Sound Galaxy",
        subtitle = "Stars of audio in cosmic dance",
        description = "Each stem orbits the central mix like planets around a sun",
    },
    {
        title = "Frequency Waterfall",
        subtitle = "Cascading layers of sound",
        description = "High frequencies fall through mid and low, each finding its home",
    },
    {
        title = "The DNA Helix",
        subtitle = "Unraveling the genetic code of music",
        description = "Double helix of sound splits into its component strands",
    },
    {
        title = "Particle Storm",
        subtitle = "Audio atoms in motion",
        description = "Millions of sound particles sorting themselves by type",
    },
    {
        title = "The Mixing Desk",
        subtitle = "Faders of the universe",
        description = "Four channels rising from chaos into clarity",
    },
    {
        title = "Stem Constellation",
        subtitle = "Navigate by the stars of sound",
        description = "Connect the dots to reveal the hidden patterns in music",
    },
}

-- Forward declaration for showMessage
local showMessage

-- Draw Art Gallery window - SPECTACULAR GRAPHICAL ANIMATIONS
local function drawArtGallery()
    local w, h = gfx.w, gfx.h

    -- Calculate scale for large window
    local scale = math.min(w / 800, h / 600)
    scale = math.max(0.5, math.min(4.0, scale))
    local function PS(val) return math.floor(val * scale + 0.5) end

    local mx, my = gfx.mouse_x, gfx.mouse_y
    local mouseDown = gfx.mouse_cap & 1 == 1
    local middleMouseDown = gfx.mouse_cap & 64 == 64  -- Middle mouse button
    local time = os.clock() - artGalleryState.startTime

    -- === CAMERA CONTROLS ===
    -- Mouse wheel zoom (zoom towards mouse position)
    local mouseWheel = gfx.mouse_wheel
    if mouseWheel ~= artGalleryState.lastMouseWheel then
        local delta = (mouseWheel - artGalleryState.lastMouseWheel) / 120
        local zoomFactor = 1.15
        if delta > 0 then
            artGalleryState.targetZoom = math.min(5.0, artGalleryState.targetZoom * zoomFactor)
        elseif delta < 0 then
            artGalleryState.targetZoom = math.max(0.5, artGalleryState.targetZoom / zoomFactor)
        end
        -- Zoom towards mouse position
        local zoomCenterX = mx - w/2
        local zoomCenterY = my - h/2
        if delta > 0 then
            artGalleryState.targetPanX = artGalleryState.targetPanX - zoomCenterX * 0.15
            artGalleryState.targetPanY = artGalleryState.targetPanY - zoomCenterY * 0.15
        else
            artGalleryState.targetPanX = artGalleryState.targetPanX + zoomCenterX * 0.1
            artGalleryState.targetPanY = artGalleryState.targetPanY + zoomCenterY * 0.1
        end
        artGalleryState.lastMouseWheel = mouseWheel
    end

    -- Pan with right mouse button or middle mouse button
    local rightMouseDown = gfx.mouse_cap & 2 == 2
    if (rightMouseDown or middleMouseDown) and not artGalleryState.isDragging then
        artGalleryState.isDragging = true
        artGalleryState.dragStartX = mx
        artGalleryState.dragStartY = my
        artGalleryState.dragStartPanX = artGalleryState.targetPanX
        artGalleryState.dragStartPanY = artGalleryState.targetPanY
    elseif (rightMouseDown or middleMouseDown) and artGalleryState.isDragging then
        artGalleryState.targetPanX = artGalleryState.dragStartPanX + (mx - artGalleryState.dragStartX)
        artGalleryState.targetPanY = artGalleryState.dragStartPanY + (my - artGalleryState.dragStartY)
    elseif not rightMouseDown and not middleMouseDown then
        artGalleryState.isDragging = false
    end

    -- Smooth interpolation for camera movement
    local smoothing = 0.15
    artGalleryState.zoom = artGalleryState.zoom + (artGalleryState.targetZoom - artGalleryState.zoom) * smoothing
    artGalleryState.panX = artGalleryState.panX + (artGalleryState.targetPanX - artGalleryState.panX) * smoothing
    artGalleryState.panY = artGalleryState.panY + (artGalleryState.targetPanY - artGalleryState.panY) * smoothing

    -- Double-click to reset camera
    if mouseDown and not artGalleryState.wasMouseDown then
        local now = os.clock()
        if artGalleryState.lastClickTime and now - artGalleryState.lastClickTime < 0.3 then
            -- Double click - reset camera
            artGalleryState.targetZoom = 1.0
            artGalleryState.targetPanX = 0
            artGalleryState.targetPanY = 0
        end
        artGalleryState.lastClickTime = now
    end

    -- Apply zoom and pan to get effective center
    local zoom = artGalleryState.zoom
    local panX = artGalleryState.panX
    local panY = artGalleryState.panY

    -- Transform function: applies zoom and pan to coordinates relative to center
    local function transform(x, y)
        local cx, cy = w/2, h/2
        local tx = cx + (x - cx) * zoom + panX
        local ty = cy + (y - cy) * zoom + panY
        return tx, ty
    end

    -- Scaled size with zoom
    local function ZS(val)
        return PS(val) * zoom
    end

    -- STEM colors
    local stemColors = {
        {1.0, 0.4, 0.4},   -- S = Vocals (red)
        {0.4, 0.8, 1.0},   -- T = Drums (blue)
        {0.6, 0.4, 1.0},   -- E = Bass (purple)
        {0.4, 1.0, 0.6},   -- M = Other (green)
    }

    -- Background - subtle gradient effect
    for y = 0, h do
        local gradient = 0.08 + (y / h) * 0.04
        if not SETTINGS.darkMode then gradient = 0.92 - (y / h) * 0.04 end
        gfx.set(gradient, gradient, gradient + 0.02, 1)
        gfx.line(0, y, w, y)
    end

    -- Colored STEM border at top
    drawStemBorder(0, 0, w, 3)

    -- Current art piece
    local art = stemperatorArt[artGalleryState.currentArt]
    -- Apply camera transform to center point
    local centerX = w / 2 + panX
    local centerY = h / 2 - PS(30) + panY

    -- ============================================
    -- DRAW THE SPECTACULAR ANIMATION FOR EACH ART
    -- ============================================

    if artGalleryState.currentArt == 1 then
        -- === THE PRISM OF SOUND ===
        -- White light enters a prism and splits into 4 colored beams

        local prismX, prismY = centerX, centerY
        local prismSize = PS(80)

        -- Incoming white beam (animated)
        local beamPulse = 0.7 + math.sin(time * 3) * 0.3
        gfx.set(1, 1, 1, beamPulse)
        for i = -2, 2 do
            gfx.line(PS(50), prismY + i, prismX - prismSize/2, prismY + i)
        end

        -- Draw prism (triangle)
        gfx.set(0.3, 0.3, 0.4, 0.8)
        local p1x, p1y = prismX - prismSize/2, prismY + prismSize/2
        local p2x, p2y = prismX + prismSize/2, prismY + prismSize/2
        local p3x, p3y = prismX, prismY - prismSize/2
        -- Fill prism
        for y = p3y, p1y do
            local progress = (y - p3y) / (p1y - p3y)
            local halfWidth = progress * prismSize / 2
            gfx.line(prismX - halfWidth, y, prismX + halfWidth, y)
        end
        -- Prism outline
        gfx.set(0.5, 0.5, 0.6, 1)
        gfx.line(p1x, p1y, p2x, p2y)
        gfx.line(p2x, p2y, p3x, p3y)
        gfx.line(p3x, p3y, p1x, p1y)

        -- Outgoing colored beams (spreading)
        local beamStartX = prismX + prismSize/2
        local beamEndX = w - PS(50)
        for i, color in ipairs(stemColors) do
            local angle = (i - 2.5) * 0.15
            local waveOffset = math.sin(time * 4 + i) * PS(5)
            local alpha = 0.6 + math.sin(time * 3 + i * 0.5) * 0.4

            gfx.set(color[1], color[2], color[3], alpha)
            local endY = prismY + (beamEndX - beamStartX) * math.tan(angle) + waveOffset
            for j = -2, 2 do
                gfx.line(beamStartX, prismY + j, beamEndX, endY + j)
            end

            -- Stem label at end
            gfx.setfont(1, "Arial", PS(14), string.byte('b'))
            local labels = {"V", "D", "B", "O"}
            local lw = gfx.measurestr(labels[i])
            gfx.x = beamEndX + PS(10)
            gfx.y = endY - PS(7)
            gfx.drawstr(labels[i])
        end

    elseif artGalleryState.currentArt == 2 then
        -- === NEURAL SEPARATION ===
        -- Neural network nodes firing and processing

        local layers = {3, 6, 8, 6, 4}  -- neurons per layer
        local layerSpacing = (w - PS(150)) / (#layers - 1)
        local nodes = {}

        -- Create and draw nodes
        for l, count in ipairs(layers) do
            nodes[l] = {}
            local layerX = PS(75) + (l - 1) * layerSpacing
            local startY = centerY - (count - 1) * PS(25)

            for n = 1, count do
                local nodeY = startY + (n - 1) * PS(50)
                nodes[l][n] = {x = layerX, y = nodeY}

                -- Node pulse animation
                local pulsePhase = time * 3 + l * 0.5 + n * 0.3
                local pulse = 0.5 + math.sin(pulsePhase) * 0.5
                local radius = PS(12) + pulse * PS(5)

                -- Glow effect
                if l == #layers then
                    local color = stemColors[n] or stemColors[1]
                    gfx.set(color[1], color[2], color[3], 0.3 * pulse)
                    gfx.circle(layerX, nodeY, radius + PS(8), 1, 1)
                    gfx.set(color[1], color[2], color[3], 0.8)
                else
                    gfx.set(0.5, 0.6, 0.8, 0.3 * pulse)
                    gfx.circle(layerX, nodeY, radius + PS(5), 1, 1)
                    gfx.set(0.4, 0.5, 0.7, 0.8)
                end
                gfx.circle(layerX, nodeY, radius, 1, 1)

                -- Draw connections to previous layer
                if l > 1 then
                    for pn = 1, #nodes[l-1] do
                        local prevNode = nodes[l-1][pn]
                        local connPulse = math.sin(time * 5 + l + n + pn) * 0.5 + 0.5
                        gfx.set(0.3, 0.4, 0.6, 0.15 + connPulse * 0.2)
                        gfx.line(prevNode.x, prevNode.y, layerX, nodeY)
                    end
                end
            end
        end

        -- Draw labels for output
        local labels = {"Vocals", "Drums", "Bass", "Other"}
        gfx.setfont(1, "Arial", PS(11))
        for i = 1, 4 do
            gfx.set(stemColors[i][1], stemColors[i][2], stemColors[i][3], 1)
            local node = nodes[#layers][i]
            gfx.x = node.x + PS(20)
            gfx.y = node.y - PS(5)
            gfx.drawstr(labels[i])
        end

    elseif artGalleryState.currentArt == 3 then
        -- === THE FOUR ELEMENTS ===
        -- Four orbiting elemental spheres

        local orbitRadius = PS(120)
        local sphereRadius = PS(40)

        -- Central mix sphere
        local centralPulse = 0.8 + math.sin(time * 2) * 0.2
        gfx.set(0.9, 0.9, 0.9, centralPulse * 0.5)
        gfx.circle(centerX, centerY, PS(50), 1, 1)
        gfx.set(1, 1, 1, 0.8)
        gfx.circle(centerX, centerY, PS(45), 0, 1)
        gfx.setfont(1, "Arial", PS(12), string.byte('b'))
        gfx.set(0.3, 0.3, 0.3, 1)
        local mixW = gfx.measurestr("MIX")
        gfx.x = centerX - mixW/2
        gfx.y = centerY - PS(6)
        gfx.drawstr("MIX")

        -- Four orbiting elements
        local elements = {"Vocals", "Drums", "Bass", "Other"}
        local symbols = {"~", "#", "=", "*"}
        for i = 1, 4 do
            local angle = time * 0.5 + (i - 1) * math.pi / 2
            local wobble = math.sin(time * 3 + i) * PS(10)
            local ex = centerX + math.cos(angle) * (orbitRadius + wobble)
            local ey = centerY + math.sin(angle) * (orbitRadius + wobble)

            -- Element glow
            gfx.set(stemColors[i][1], stemColors[i][2], stemColors[i][3], 0.3)
            gfx.circle(ex, ey, sphereRadius + PS(15), 1, 1)

            -- Element sphere
            gfx.set(stemColors[i][1], stemColors[i][2], stemColors[i][3], 0.9)
            gfx.circle(ex, ey, sphereRadius, 1, 1)

            -- Element symbol
            gfx.set(1, 1, 1, 1)
            gfx.setfont(1, "Arial", PS(24), string.byte('b'))
            local symW = gfx.measurestr(symbols[i])
            gfx.x = ex - symW/2
            gfx.y = ey - PS(10)
            gfx.drawstr(symbols[i])

            -- Element name
            gfx.setfont(1, "Arial", PS(10))
            local nameW = gfx.measurestr(elements[i])
            gfx.x = ex - nameW/2
            gfx.y = ey + PS(12)
            gfx.drawstr(elements[i])

            -- Connection line to center
            gfx.set(stemColors[i][1], stemColors[i][2], stemColors[i][3], 0.3)
            gfx.line(centerX, centerY, ex, ey)
        end

    elseif artGalleryState.currentArt == 4 then
        -- === WAVEFORM SURGERY ===
        -- Scalpel cutting through waveform, separating colors

        local waveW = w - PS(100)
        local waveH = PS(150)
        local waveStartX = PS(50)
        local waveY = centerY

        -- Draw mixed waveform (before cut)
        local cutX = waveStartX + (time * 50) % waveW

        -- Before cut - mixed gray
        for x = waveStartX, math.min(cutX, waveStartX + waveW) do
            local t = (x - waveStartX) / waveW * math.pi * 8
            local amp = waveH/2 * (0.5 + math.sin(t * 0.5) * 0.3)
            local y = waveY + math.sin(t + time * 2) * amp
            gfx.set(0.5, 0.5, 0.5, 0.6)
            gfx.line(x, waveY, x, y)
        end

        -- After cut - separated colored stems
        if cutX > waveStartX then
            for i, color in ipairs(stemColors) do
                local offset = (i - 2.5) * PS(35)
                gfx.set(color[1], color[2], color[3], 0.7)
                for x = cutX, waveStartX + waveW do
                    local t = (x - waveStartX) / waveW * math.pi * 8
                    local amp = waveH/4 * (0.3 + math.sin(t * 0.3 + i) * 0.2)
                    local separation = math.min(1, (x - cutX) / PS(100))
                    local y = waveY + offset * separation + math.sin(t + time * 2 + i) * amp
                    gfx.line(x, waveY + offset * separation, x, y)
                end
            end
        end

        -- Draw scalpel
        local scalpelY = waveY - waveH/2 - PS(30) + math.sin(time * 8) * PS(5)
        gfx.set(0.8, 0.8, 0.9, 1)
        -- Blade
        gfx.line(cutX - PS(5), scalpelY, cutX, scalpelY + PS(60))
        gfx.line(cutX, scalpelY + PS(60), cutX + PS(5), scalpelY)
        -- Handle
        gfx.set(0.4, 0.3, 0.2, 1)
        gfx.rect(cutX - PS(8), scalpelY - PS(25), PS(16), PS(25), 1)

    elseif artGalleryState.currentArt == 5 then
        -- === THE SOUND GALAXY ===
        -- Stars orbiting a central sun, particles everywhere

        -- Draw background stars
        math.randomseed(42)  -- Fixed seed for consistent stars
        for i = 1, 100 do
            local sx = math.random() * w
            local sy = math.random() * h
            local twinkle = 0.3 + math.sin(time * 5 + i) * 0.3
            gfx.set(1, 1, 1, twinkle)
            gfx.circle(sx, sy, PS(1), 1, 1)
        end

        -- Central sun (the mix)
        local sunPulse = 1 + math.sin(time * 2) * 0.1
        -- Sun glow
        for r = PS(60), PS(30), -PS(5) do
            local alpha = (PS(60) - r) / PS(30) * 0.3
            gfx.set(1, 0.9, 0.5, alpha)
            gfx.circle(centerX, centerY, r * sunPulse, 1, 1)
        end
        gfx.set(1, 0.95, 0.7, 1)
        gfx.circle(centerX, centerY, PS(30) * sunPulse, 1, 1)

        -- Orbiting stem planets
        local orbits = {PS(100), PS(150), PS(200), PS(250)}
        local speeds = {0.8, 0.6, 0.4, 0.3}
        local labels = {"V", "D", "B", "O"}
        for i = 1, 4 do
            local angle = time * speeds[i] + (i - 1) * math.pi / 2
            local px = centerX + math.cos(angle) * orbits[i]
            local py = centerY + math.sin(angle) * orbits[i] * 0.6  -- Elliptical

            -- Orbit path
            gfx.set(stemColors[i][1], stemColors[i][2], stemColors[i][3], 0.15)
            for a = 0, math.pi * 2, 0.1 do
                local ox = centerX + math.cos(a) * orbits[i]
                local oy = centerY + math.sin(a) * orbits[i] * 0.6
                gfx.circle(ox, oy, PS(1), 1, 1)
            end

            -- Planet glow
            gfx.set(stemColors[i][1], stemColors[i][2], stemColors[i][3], 0.4)
            gfx.circle(px, py, PS(25), 1, 1)
            -- Planet
            gfx.set(stemColors[i][1], stemColors[i][2], stemColors[i][3], 1)
            gfx.circle(px, py, PS(18), 1, 1)
            -- Label
            gfx.set(1, 1, 1, 1)
            gfx.setfont(1, "Arial", PS(14), string.byte('b'))
            local lw = gfx.measurestr(labels[i])
            gfx.x = px - lw/2
            gfx.y = py - PS(6)
            gfx.drawstr(labels[i])
        end

    elseif artGalleryState.currentArt == 6 then
        -- === FREQUENCY WATERFALL ===
        -- Cascading frequency bands falling and separating

        local bandH = PS(30)
        local bandW = w - PS(100)
        local startX = PS(50)
        local labels = {"HIGH - Vocals", "MID-HIGH - Drums", "MID-LOW - Bass", "LOW - Other"}

        for i = 1, 4 do
            local baseY = PS(80) + (i - 1) * PS(100)
            local flowOffset = (time * 100 + i * 50) % bandW

            -- Draw flowing frequency band
            for x = 0, bandW do
                local xPos = startX + x
                local wavePhase = x / bandW * math.pi * 6 + time * 3
                local amp = bandH/2 * (0.5 + math.sin(wavePhase + i) * 0.3)
                local alpha = 0.3 + math.sin(wavePhase) * 0.2

                -- Waterfall effect - brighter at "current" position
                local distFromFlow = math.abs(x - flowOffset)
                if distFromFlow < PS(50) then
                    alpha = alpha + (1 - distFromFlow / PS(50)) * 0.5
                end

                gfx.set(stemColors[i][1], stemColors[i][2], stemColors[i][3], alpha)
                gfx.line(xPos, baseY - amp, xPos, baseY + amp)
            end

            -- Frequency label
            gfx.set(stemColors[i][1], stemColors[i][2], stemColors[i][3], 1)
            gfx.setfont(1, "Arial", PS(11), string.byte('b'))
            gfx.x = startX + bandW + PS(10)
            gfx.y = baseY - PS(5)
            gfx.drawstr(labels[i])

            -- Droplets falling
            for d = 1, 5 do
                local dropX = startX + ((time * 80 + d * 100 + i * 30) % bandW)
                local dropY = baseY + (time * 50 + d * 20) % PS(80)
                local dropAlpha = 1 - (dropY - baseY) / PS(80)
                gfx.set(stemColors[i][1], stemColors[i][2], stemColors[i][3], dropAlpha * 0.6)
                gfx.circle(dropX, dropY, PS(3), 1, 1)
            end
        end

    elseif artGalleryState.currentArt == 7 then
        -- === THE DNA HELIX ===
        -- Double helix unraveling into 4 strands

        local helixLength = w - PS(150)
        local helixStartX = PS(75)
        local helixRadius = PS(40)

        -- Draw the double helix splitting into 4
        for x = 0, helixLength do
            local progress = x / helixLength
            local phase = x / PS(30) + time * 2
            local splitFactor = math.min(1, progress * 2)  -- Start splitting at 50%

            if progress < 0.5 then
                -- Before split - double helix
                local y1 = centerY + math.sin(phase) * helixRadius
                local y2 = centerY - math.sin(phase) * helixRadius
                local alpha = 0.5 + math.cos(phase) * 0.3

                gfx.set(0.8, 0.8, 0.8, alpha)
                gfx.circle(helixStartX + x, y1, PS(4), 1, 1)
                gfx.circle(helixStartX + x, y2, PS(4), 1, 1)

                -- Connection bars
                if math.floor(phase) % 2 == 0 then
                    gfx.set(0.6, 0.6, 0.6, 0.4)
                    gfx.line(helixStartX + x, y1, helixStartX + x, y2)
                end
            else
                -- After split - 4 strands separating
                for i = 1, 4 do
                    local separation = (progress - 0.5) * 2  -- 0 to 1
                    local targetOffset = (i - 2.5) * PS(50)
                    local yOffset = targetOffset * separation
                    local y = centerY + yOffset + math.sin(phase + i * 0.5) * helixRadius * (1 - separation * 0.5)
                    local alpha = 0.5 + math.cos(phase + i) * 0.3

                    gfx.set(stemColors[i][1], stemColors[i][2], stemColors[i][3], alpha)
                    gfx.circle(helixStartX + x, y, PS(4), 1, 1)
                end
            end
        end

        -- Labels at the end
        local labels = {"Vocals", "Drums", "Bass", "Other"}
        gfx.setfont(1, "Arial", PS(12), string.byte('b'))
        for i = 1, 4 do
            local yOffset = (i - 2.5) * PS(50)
            gfx.set(stemColors[i][1], stemColors[i][2], stemColors[i][3], 1)
            gfx.x = helixStartX + helixLength + PS(15)
            gfx.y = centerY + yOffset - PS(6)
            gfx.drawstr(labels[i])
        end

    elseif artGalleryState.currentArt == 8 then
        -- === PARTICLE STORM ===
        -- Thousands of particles sorting by color

        -- Particle system with sorting animation
        math.randomseed(12345)
        local numParticles = 200

        for p = 1, numParticles do
            local colorIdx = ((p - 1) % 4) + 1
            local baseX = math.random() * w
            local baseY = math.random() * h

            -- Calculate target position (sorted by stem)
            local targetX = PS(100) + (colorIdx - 1) * (w - PS(200)) / 3
            local targetY = PS(100) + math.random() * (h - PS(250))

            -- Interpolate based on time (cycling)
            local sortPhase = (math.sin(time * 0.5) + 1) / 2  -- 0 to 1 cycling
            local px = baseX + (targetX - baseX) * sortPhase
            local py = baseY + (targetY - baseY) * sortPhase

            -- Add some turbulence
            px = px + math.sin(time * 3 + p) * PS(10) * (1 - sortPhase)
            py = py + math.cos(time * 3 + p * 0.7) * PS(10) * (1 - sortPhase)

            -- Draw particle
            local alpha = 0.4 + math.sin(time * 5 + p) * 0.2
            gfx.set(stemColors[colorIdx][1], stemColors[colorIdx][2], stemColors[colorIdx][3], alpha)
            gfx.circle(px, py, PS(3), 1, 1)
        end

        -- Labels when sorted
        local labels = {"Vocals", "Drums", "Bass", "Other"}
        gfx.setfont(1, "Arial", PS(14), string.byte('b'))
        for i = 1, 4 do
            local labelX = PS(100) + (i - 1) * (w - PS(200)) / 3
            gfx.set(stemColors[i][1], stemColors[i][2], stemColors[i][3], 1)
            local lw = gfx.measurestr(labels[i])
            gfx.x = labelX - lw/2
            gfx.y = h - PS(100)
            gfx.drawstr(labels[i])
        end

    elseif artGalleryState.currentArt == 9 then
        -- === THE MIXING DESK ===
        -- Four animated faders rising from darkness

        local faderW = PS(60)
        local faderH = PS(250)
        local faderSpacing = (w - PS(200) - faderW * 4) / 3
        local startX = PS(100)
        local baseY = h - PS(120)

        local labels = {"VOC", "DRM", "BAS", "OTH"}
        local fullLabels = {"Vocals", "Drums", "Bass", "Other"}

        for i = 1, 4 do
            local faderX = startX + (i - 1) * (faderW + faderSpacing)

            -- Fader channel strip background
            gfx.set(0.15, 0.15, 0.18, 1)
            gfx.rect(faderX - PS(10), baseY - faderH - PS(40), faderW + PS(20), faderH + PS(80), 1)

            -- Fader track
            gfx.set(0.1, 0.1, 0.12, 1)
            gfx.rect(faderX + faderW/2 - PS(4), baseY - faderH, PS(8), faderH, 1)

            -- Animated fader level
            local level = 0.3 + math.sin(time * 2 + i * 0.8) * 0.3 + math.sin(time * 5 + i * 1.5) * 0.15
            local faderY = baseY - level * faderH

            -- Level meter (behind fader)
            local meterLevel = level + math.sin(time * 8 + i) * 0.1
            for y = baseY, baseY - meterLevel * faderH, -PS(3) do
                local meterProgress = (baseY - y) / faderH
                local r = stemColors[i][1] * (0.3 + meterProgress * 0.7)
                local g = stemColors[i][2] * (0.3 + meterProgress * 0.7)
                local b = stemColors[i][3] * (0.3 + meterProgress * 0.7)
                gfx.set(r, g, b, 0.8)
                gfx.rect(faderX + PS(5), y, faderW - PS(10), PS(2), 1)
            end

            -- Fader knob
            gfx.set(stemColors[i][1], stemColors[i][2], stemColors[i][3], 1)
            gfx.rect(faderX, faderY - PS(10), faderW, PS(20), 1)
            gfx.set(1, 1, 1, 0.5)
            gfx.line(faderX + PS(5), faderY, faderX + faderW - PS(5), faderY)

            -- Channel label
            gfx.set(stemColors[i][1], stemColors[i][2], stemColors[i][3], 1)
            gfx.setfont(1, "Arial", PS(12), string.byte('b'))
            local labelW = gfx.measurestr(labels[i])
            gfx.x = faderX + faderW/2 - labelW/2
            gfx.y = baseY + PS(15)
            gfx.drawstr(labels[i])
        end

    elseif artGalleryState.currentArt == 10 then
        -- === STEM CONSTELLATION ===
        -- Stars connected forming STEM pattern

        -- Draw constellation background
        math.randomseed(999)
        for i = 1, 80 do
            local sx = math.random() * w
            local sy = math.random() * h
            local twinkle = 0.2 + math.sin(time * 4 + i * 0.5) * 0.2
            gfx.set(1, 1, 1, twinkle)
            gfx.circle(sx, sy, PS(1), 1, 1)
        end

        -- STEM constellation points
        local constellations = {
            -- S shape
            {points = {{0.15, 0.3}, {0.25, 0.25}, {0.15, 0.4}, {0.25, 0.55}, {0.15, 0.5}}, color = 1},
            -- T shape
            {points = {{0.35, 0.25}, {0.45, 0.25}, {0.55, 0.25}, {0.45, 0.35}, {0.45, 0.55}}, color = 2},
            -- E shape
            {points = {{0.65, 0.25}, {0.75, 0.25}, {0.65, 0.4}, {0.72, 0.4}, {0.65, 0.55}, {0.75, 0.55}}, color = 3},
            -- M shape
            {points = {{0.8, 0.55}, {0.8, 0.25}, {0.87, 0.4}, {0.94, 0.25}, {0.94, 0.55}}, color = 4},
        }

        for _, const in ipairs(constellations) do
            local color = stemColors[const.color]
            local points = const.points

            -- Draw connections
            gfx.set(color[1], color[2], color[3], 0.4)
            for i = 1, #points - 1 do
                local x1 = points[i][1] * w
                local y1 = points[i][2] * h
                local x2 = points[i+1][1] * w
                local y2 = points[i+1][2] * h
                gfx.line(x1, y1, x2, y2)
            end

            -- Draw stars with pulse
            for i, point in ipairs(points) do
                local px = point[1] * w
                local py = point[2] * h
                local pulse = 1 + math.sin(time * 3 + i + const.color) * 0.3

                -- Star glow
                gfx.set(color[1], color[2], color[3], 0.3 * pulse)
                gfx.circle(px, py, PS(12) * pulse, 1, 1)

                -- Star core
                gfx.set(color[1], color[2], color[3], 0.9)
                gfx.circle(px, py, PS(5) * pulse, 1, 1)

                -- Star center
                gfx.set(1, 1, 1, 1)
                gfx.circle(px, py, PS(2), 1, 1)
            end
        end

        -- Legend
        local labels = {"Vocals", "Drums", "Bass", "Other"}
        gfx.setfont(1, "Arial", PS(10))
        for i = 1, 4 do
            gfx.set(stemColors[i][1], stemColors[i][2], stemColors[i][3], 1)
            gfx.circle(PS(30), h - PS(90) + (i-1) * PS(18), PS(5), 1, 1)
            gfx.x = PS(45)
            gfx.y = h - PS(95) + (i-1) * PS(18)
            gfx.drawstr(labels[i])
        end
    end

    -- ============================================
    -- UI ELEMENTS (title, navigation, etc.)
    -- ============================================

    -- Title bar background
    gfx.set(0, 0, 0, 0.5)
    gfx.rect(0, 0, w, PS(50), 1)

    -- flarkAUDIO logo (top left)
    gfx.setfont(1, "Arial", PS(11))
    local flarkPart = "flark"
    local flarkPartW = gfx.measurestr(flarkPart)
    gfx.setfont(1, "Arial", PS(11), string.byte('b'))
    local audioPart = "AUDIO"
    gfx.set(1.0, 0.5, 0.1, 0.7)
    gfx.setfont(1, "Arial", PS(11))
    gfx.x = PS(15)
    gfx.y = PS(15)
    gfx.drawstr(flarkPart)
    gfx.setfont(1, "Arial", PS(11), string.byte('b'))
    gfx.x = PS(15) + flarkPartW
    gfx.y = PS(15)
    gfx.drawstr(audioPart)

    -- Art title (center top)
    gfx.setfont(1, "Arial", PS(18), string.byte('b'))
    local titlePulse = 0.8 + math.sin(time * 2) * 0.2
    gfx.set(1, 1, 1, titlePulse)
    local titleW = gfx.measurestr(art.title)
    gfx.x = (w - titleW) / 2
    gfx.y = PS(12)
    gfx.drawstr(art.title)

    -- Subtitle
    if art.subtitle then
        gfx.setfont(1, "Arial", PS(11))
        gfx.set(0.7, 0.7, 0.7, 1)
        local subW = gfx.measurestr(art.subtitle)
        gfx.x = (w - subW) / 2
        gfx.y = PS(35)
        gfx.drawstr(art.subtitle)
    end

    -- Navigation dots
    local dotSpacing = PS(15)
    local dotsStartX = (w - (#stemperatorArt - 1) * dotSpacing) / 2
    for i = 1, #stemperatorArt do
        local dotX = dotsStartX + (i - 1) * dotSpacing
        local dotY = h - PS(45)
        if i == artGalleryState.currentArt then
            local dotPulse = 1 + math.sin(time * 4) * 0.3
            gfx.set(1.0, 0.5, 0.1, 1)
            gfx.circle(dotX, dotY, PS(5) * dotPulse, 1, 1)
        else
            gfx.set(0.5, 0.5, 0.5, 0.6)
            gfx.circle(dotX, dotY, PS(4), 1, 1)
        end
    end

    -- Navigation arrows
    local arrowY = h - PS(45)
    local prevX = PS(50)
    local nextX = w - PS(50)
    local arrowSize = PS(15)

    local prevHover = math.abs(mx - prevX) < arrowSize * 2 and math.abs(my - arrowY) < arrowSize * 2
    local nextHover = math.abs(mx - nextX) < arrowSize * 2 and math.abs(my - arrowY) < arrowSize * 2

    -- Left arrow
    gfx.set(stemColors[1][1], stemColors[1][2], stemColors[1][3], prevHover and 1 or 0.6)
    gfx.line(prevX + arrowSize, arrowY - arrowSize, prevX - arrowSize, arrowY)
    gfx.line(prevX - arrowSize, arrowY, prevX + arrowSize, arrowY + arrowSize)

    -- Right arrow
    gfx.set(stemColors[4][1], stemColors[4][2], stemColors[4][3], nextHover and 1 or 0.6)
    gfx.line(nextX - arrowSize, arrowY - arrowSize, nextX + arrowSize, arrowY)
    gfx.line(nextX + arrowSize, arrowY, nextX - arrowSize, arrowY + arrowSize)

    -- Close button (bottom center)
    local btnW = PS(80)
    local btnH = PS(26)
    local btnX = (w - btnW) / 2
    local btnY = h - PS(80)
    local closeHover = mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH

    if closeHover then
        gfx.set(0.9, 0.3, 0.3, 1)
    else
        gfx.set(0.6, 0.2, 0.2, 0.9)
    end
    -- Rounded button
    for i = 0, btnH - 1 do
        local radius = btnH / 2
        local inset = 0
        if i < radius then
            inset = radius - math.sqrt(math.max(0, radius * radius - (radius - i) * (radius - i)))
        elseif i > btnH - radius then
            inset = radius - math.sqrt(math.max(0, radius * radius - (i - (btnH - radius)) * (i - (btnH - radius))))
        end
        gfx.line(btnX + inset, btnY + i, btnX + btnW - inset, btnY + i)
    end
    gfx.set(1, 1, 1, 1)
    gfx.setfont(1, "Arial", PS(12), string.byte('b'))
    local closeText = "Back"
    local closeTextW = gfx.measurestr(closeText)
    gfx.x = btnX + (btnW - closeTextW) / 2
    gfx.y = btnY + (btnH - PS(12)) / 2
    gfx.drawstr(closeText)

    -- Zoom indicator (top right)
    if zoom ~= 1.0 or panX ~= 0 or panY ~= 0 then
        gfx.set(1, 1, 1, 0.7)
        gfx.setfont(1, "Arial", PS(10))
        local zoomText = string.format("%.0f%%", zoom * 100)
        local zoomTextW = gfx.measurestr(zoomText)
        gfx.x = w - zoomTextW - PS(15)
        gfx.y = PS(15)
        gfx.drawstr(zoomText)

        -- Reset hint
        gfx.set(0.7, 0.7, 0.7, 0.8)
        gfx.setfont(1, "Arial", PS(8))
        local resetHint = "Double-click to reset"
        local resetHintW = gfx.measurestr(resetHint)
        gfx.x = w - resetHintW - PS(15)
        gfx.y = PS(28)
        gfx.drawstr(resetHint)
    end

    -- Hint (updated with camera controls)
    gfx.set(0.5, 0.5, 0.5, 0.8)
    gfx.setfont(1, "Arial", PS(9))
    local hint = "< > Navigate | Scroll to zoom | Right-drag to pan | ESC to close"
    local hintW = gfx.measurestr(hint)
    gfx.x = (w - hintW) / 2
    gfx.y = h - PS(15)
    gfx.drawstr(hint)

    gfx.update()

    -- Helper to reset camera when changing art
    local function resetCamera()
        artGalleryState.targetZoom = 1.0
        artGalleryState.targetPanX = 0
        artGalleryState.targetPanY = 0
    end

    -- Handle clicks
    if mouseDown and not artGalleryState.wasMouseDown then
        if prevHover then
            artGalleryState.currentArt = artGalleryState.currentArt - 1
            if artGalleryState.currentArt < 1 then artGalleryState.currentArt = #stemperatorArt end
            resetCamera()
        elseif nextHover then
            artGalleryState.currentArt = artGalleryState.currentArt + 1
            if artGalleryState.currentArt > #stemperatorArt then artGalleryState.currentArt = 1 end
            resetCamera()
        elseif closeHover then
            return "close"
        end
    end
    artGalleryState.wasMouseDown = mouseDown

    -- Keyboard navigation
    local char = gfx.getchar()
    if char == -1 or char == 27 then
        return "close"
    elseif char == 1818584692 or char == 44 or char == 60 then
        artGalleryState.currentArt = artGalleryState.currentArt - 1
        if artGalleryState.currentArt < 1 then artGalleryState.currentArt = #stemperatorArt end
        resetCamera()
    elseif char == 1919379572 or char == 46 or char == 62 then
        artGalleryState.currentArt = artGalleryState.currentArt + 1
        if artGalleryState.currentArt > #stemperatorArt then artGalleryState.currentArt = 1 end
        resetCamera()
    elseif char == 114 or char == 82 then  -- R key to reset camera
        resetCamera()
    end

    return nil
end

-- Art Gallery window loop
local function artGalleryLoop()
    local result = drawArtGallery()
    if result == "close" then
        gfx.quit()
        -- Reopen Start message
        showMessage("Start", "Please select a media item, track, or make a time selection to separate.", "info", true)
        return
    end
    reaper.defer(artGalleryLoop)
end

-- Show Art Gallery
local function showArtGallery()
    loadSettings()
    updateTheme()

    artGalleryState.currentArt = 1
    artGalleryState.wasMouseDown = false
    artGalleryState.startTime = os.clock()
    -- Reset camera
    artGalleryState.zoom = 1.0
    artGalleryState.panX = 0
    artGalleryState.panY = 0
    artGalleryState.targetZoom = 1.0
    artGalleryState.targetPanX = 0
    artGalleryState.targetPanY = 0
    artGalleryState.isDragging = false
    artGalleryState.lastMouseWheel = 0

    -- Use same size and position as last dialog
    local winW = lastDialogW or 380
    local winH = lastDialogH or 340
    local winX, winY

    if lastDialogX and lastDialogY then
        winX = lastDialogX
        winY = lastDialogY
    else
        -- Fallback to mouse position
        local mouseX, mouseY = reaper.GetMousePosition()
        winX = mouseX - winW / 2
        winY = mouseY - winH / 2
    end

    gfx.init("STEMperator Art Gallery", winW, winH, 0, winX, winY)
    reaper.defer(artGalleryLoop)
end

-- Draw message window (replaces reaper.MB for proper positioning)
-- Styled to match main app window
local function drawMessageWindow()
    local w, h = gfx.w, gfx.h

    -- Calculate scale based on window size
    local scale = math.min(w / 380, h / 340)
    scale = math.max(0.5, math.min(4.0, scale))
    local function PS(val) return math.floor(val * scale + 0.5) end

    local mx, my = gfx.mouse_x, gfx.mouse_y
    local mouseDown = gfx.mouse_cap & 1 == 1

    -- STEM colors
    local stemColors = {
        {255/255, 100/255, 100/255},  -- S = Vocals (red)
        {100/255, 200/255, 255/255},  -- T = Drums (blue)
        {150/255, 100/255, 255/255},  -- E = Bass (purple)
        {100/255, 255/255, 150/255},  -- M = Other (green)
    }

    -- Solid background
    gfx.set(THEME.bg[1], THEME.bg[2], THEME.bg[3], 1)
    gfx.rect(0, 0, w, h, 1)

    -- Colored STEM border at top
    drawStemBorder(0, 0, w, 3)

    -- Theme toggle button (sun/moon icon, top right)
    local themeSize = PS(20)
    local themeX = w - themeSize - PS(10)
    local themeY = PS(8)
    local themeHover = mx >= themeX and mx <= themeX + themeSize and my >= themeY and my <= themeY + themeSize

    if SETTINGS.darkMode then
        gfx.set(0.7, 0.7, 0.5, themeHover and 1 or 0.6)
        gfx.circle(themeX + themeSize/2, themeY + themeSize/2, themeSize/2 - 2, 1, 1)
        gfx.set(THEME.bg[1], THEME.bg[2], THEME.bg[3], 1)
        gfx.circle(themeX + themeSize/2 + 4, themeY + themeSize/2 - 3, themeSize/2 - 3, 1, 1)
    else
        gfx.set(0.9, 0.7, 0.2, themeHover and 1 or 0.8)
        gfx.circle(themeX + themeSize/2, themeY + themeSize/2, themeSize/3, 1, 1)
        for i = 0, 7 do
            local angle = i * math.pi / 4
            local x1 = themeX + themeSize/2 + math.cos(angle) * (themeSize/3 + 2)
            local y1 = themeY + themeSize/2 + math.sin(angle) * (themeSize/3 + 2)
            local x2 = themeX + themeSize/2 + math.cos(angle) * (themeSize/2 - 1)
            local y2 = themeY + themeSize/2 + math.sin(angle) * (themeSize/2 - 1)
            gfx.line(x1, y1, x2, y2)
        end
    end

    if themeHover and mouseDown and not messageWindowState.wasMouseDown then
        SETTINGS.darkMode = not SETTINGS.darkMode
        updateTheme()
        saveSettings()
    end

    -- Track tooltip
    local tooltipText = nil
    local tooltipX, tooltipY = 0, 0

    if themeHover then
        tooltipText = SETTINGS.darkMode and "Switch to light mode" or "Switch to dark mode"
        tooltipX = mx + PS(10)
        tooltipY = my + PS(15)
    end

    local time = os.clock() - messageWindowState.startTime

    -- === STEMperator Logo (large, centered, ABOVE waveform) ===
    gfx.setfont(1, "Arial", PS(28), string.byte('b'))
    local logoY = PS(35)

    local logoLetters = {"S", "T", "E", "M", "p", "e", "r", "a", "t", "o", "r"}
    local logoWidths = {}
    local logoTotalWidth = 0
    for i, letter in ipairs(logoLetters) do
        local lw = gfx.measurestr(letter)
        logoWidths[i] = lw
        logoTotalWidth = logoTotalWidth + lw
    end
    local logoX = (w - logoTotalWidth) / 2

    -- Draw each letter with subtle animation
    for i, letter in ipairs(logoLetters) do
        local yOffset = math.sin(time * 3 + i * 0.5) * PS(2)
        if i <= 4 then
            gfx.set(stemColors[i][1], stemColors[i][2], stemColors[i][3], 1)
        else
            gfx.set(THEME.text[1], THEME.text[2], THEME.text[3], 0.9)
        end
        gfx.x = logoX
        gfx.y = logoY + yOffset
        gfx.drawstr(letter)
        logoX = logoX + logoWidths[i]
    end

    -- === Tagline (ABOVE waveform) ===
    gfx.setfont(1, "Arial", PS(11))
    gfx.set(THEME.textDim[1], THEME.textDim[2], THEME.textDim[3], 1)
    local tagline = "AI-Powered Stem Separation"
    local tagW = gfx.measurestr(tagline)
    gfx.x = (w - tagW) / 2
    gfx.y = PS(68)
    gfx.drawstr(tagline)

    -- === Animated waveform visualization (BELOW tagline) ===
    local waveY = PS(95)
    local waveH = PS(50)
    local waveW = w - PS(60)
    local waveX = PS(30)

    -- Draw 4 layered waveforms (one for each stem color)
    for stemIdx = 1, 4 do
        local color = stemColors[stemIdx]
        gfx.set(color[1], color[2], color[3], 0.4)

        local freq = 2 + stemIdx * 0.7
        local amp = waveH / 4 * (1 - (stemIdx - 1) * 0.15)
        local phase = time * 2 + stemIdx * 1.5

        local prevX, prevY
        for i = 0, waveW do
            local x = waveX + i
            local t = i / waveW * math.pi * freq + phase
            local y = waveY + waveH/2 + math.sin(t) * amp * math.sin(i / waveW * math.pi)

            if prevX then
                gfx.line(prevX, prevY, x, y)
            end
            prevX, prevY = x, y
        end
    end

    -- === Four stem icons ===
    local iconY = PS(170)
    local iconSpacing = PS(70)
    local iconStartX = (w - iconSpacing * 3) / 2
    local stemNames = {"Vocals", "Drums", "Bass", "Other"}
    local stemSymbols = {"V", "D", "B", "O"}

    for i = 1, 4 do
        local ix = iconStartX + (i-1) * iconSpacing
        local pulseScale = 1 + math.sin(time * 4 + i) * 0.1

        -- Colored circle
        gfx.set(stemColors[i][1], stemColors[i][2], stemColors[i][3], 0.8)
        gfx.circle(ix, iconY, PS(16) * pulseScale, 1, 1)

        -- Letter
        gfx.set(1, 1, 1, 1)
        gfx.setfont(1, "Arial", PS(14), string.byte('b'))
        local symW = gfx.measurestr(stemSymbols[i])
        gfx.x = ix - symW/2
        gfx.y = iconY - PS(6)
        gfx.drawstr(stemSymbols[i])

        -- Label
        gfx.setfont(1, "Arial", PS(9))
        gfx.set(stemColors[i][1], stemColors[i][2], stemColors[i][3], 1)
        local nameW = gfx.measurestr(stemNames[i])
        gfx.x = ix - nameW/2
        gfx.y = iconY + PS(20)
        gfx.drawstr(stemNames[i])
    end

    -- === Message (animated, bold, pulsing) ===
    gfx.setfont(1, "Arial", PS(14), string.byte('b'))

    -- Pulsing effect: oscillate between dim and bright
    local pulseAlpha = 0.6 + math.sin(time * 3) * 0.4

    -- Gradient through STEM colors
    local colorPhase = (time * 0.5) % 4
    local colorIdx = math.floor(colorPhase) + 1
    local nextColorIdx = (colorIdx % 4) + 1
    local colorBlend = colorPhase % 1

    local r = stemColors[colorIdx][1] * (1 - colorBlend) + stemColors[nextColorIdx][1] * colorBlend
    local g = stemColors[colorIdx][2] * (1 - colorBlend) + stemColors[nextColorIdx][2] * colorBlend
    local b = stemColors[colorIdx][3] * (1 - colorBlend) + stemColors[nextColorIdx][3] * colorBlend

    gfx.set(r, g, b, pulseAlpha)

    local msg = "Select audio to begin separation"
    local msgW = gfx.measurestr(msg)
    gfx.x = (w - msgW) / 2
    gfx.y = PS(240)
    gfx.drawstr(msg)

    -- Subtle underline animation (growing/shrinking)
    local underlineW = msgW * (0.5 + math.sin(time * 2) * 0.3)
    local underlineX = (w - underlineW) / 2
    gfx.set(r, g, b, pulseAlpha * 0.5)
    gfx.line(underlineX, PS(258), underlineX + underlineW, PS(258))

    -- Art Gallery link (clickable text)
    local artLinkY = h - PS(70)
    gfx.setfont(1, "Arial", PS(10))
    local artLinkText = "View Art Gallery"
    local artLinkW = gfx.measurestr(artLinkText)
    local artLinkX = (w - artLinkW) / 2
    local artLinkHover = mx >= artLinkX and mx <= artLinkX + artLinkW and my >= artLinkY and my <= artLinkY + PS(14)

    if artLinkHover then
        gfx.set(1.0, 0.6, 0.2, 1)  -- Brighter orange on hover
    else
        gfx.set(1.0, 0.5, 0.1, 0.8)  -- Orange
    end
    gfx.x = artLinkX
    gfx.y = artLinkY
    gfx.drawstr(artLinkText)
    -- Underline
    gfx.line(artLinkX, artLinkY + PS(12), artLinkX + artLinkW, artLinkY + PS(12))

    -- Art link tooltip
    if artLinkHover and not tooltipText then
        tooltipText = "10 spectacular animated visualizations of STEMperator"
        tooltipX = mx + PS(10)
        tooltipY = my + PS(15)
    end

    -- Close button (red, rounded pill style)
    local btnW = PS(70)
    local btnH = PS(20)
    local btnX = (w - btnW) / 2
    local btnY = h - PS(40)

    local hover = mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH

    -- Red button color
    if hover then
        gfx.set(0.9, 0.3, 0.3, 1)
    else
        gfx.set(0.7, 0.2, 0.2, 1)
    end
    -- Draw rounded (pill-shaped) button
    for i = 0, btnH - 1 do
        local radius = btnH / 2
        local inset = 0
        if i < radius then
            inset = radius - math.sqrt(radius * radius - (radius - i) * (radius - i))
        elseif i > btnH - radius then
            inset = radius - math.sqrt(radius * radius - (i - (btnH - radius)) * (i - (btnH - radius)))
        end
        gfx.line(btnX + inset, btnY + i, btnX + btnW - inset, btnY + i)
    end

    gfx.set(1, 1, 1, 1)
    gfx.setfont(1, "Arial", PS(13), string.byte('b'))
    local closeText = "Close"
    local closeW = gfx.measurestr(closeText)
    gfx.x = btnX + (btnW - closeW) / 2
    gfx.y = btnY + (btnH - PS(13)) / 2
    gfx.drawstr(closeText)

    -- Close button tooltip
    if hover and not tooltipText then
        tooltipText = "Exit STEMperator"
        tooltipX = mx + PS(10)
        tooltipY = my + PS(15)
    end

    -- Hint at very bottom edge
    gfx.set(THEME.textHint[1], THEME.textHint[2], THEME.textHint[3], 1)
    gfx.setfont(1, "Arial", PS(9))
    local hint = "Enter / Space / ESC"
    local hintW = gfx.measurestr(hint)
    gfx.x = (w - hintW) / 2
    gfx.y = h - PS(12)
    gfx.drawstr(hint)

    -- flarkAUDIO logo at top (translucent) - "flark" regular, "AUDIO" bold
    gfx.setfont(1, "Arial", PS(10))
    local flarkPart = "flark"
    local flarkPartW = gfx.measurestr(flarkPart)
    gfx.setfont(1, "Arial", PS(10), string.byte('b'))
    local audioPart = "AUDIO"
    local audioPartW = gfx.measurestr(audioPart)
    local totalLogoW = flarkPartW + audioPartW
    local logoStartX = (w - totalLogoW) / 2
    -- Orange text, 50% translucent
    gfx.set(1.0, 0.5, 0.1, 0.5)
    gfx.setfont(1, "Arial", PS(10))
    gfx.x = logoStartX
    gfx.y = PS(3)
    gfx.drawstr(flarkPart)
    gfx.setfont(1, "Arial", PS(10), string.byte('b'))
    gfx.x = logoStartX + flarkPartW
    gfx.y = PS(3)
    gfx.drawstr(audioPart)

    -- Draw tooltip if active
    if tooltipText then
        gfx.setfont(1, "Arial", PS(11))
        local padding = PS(6)
        local tw = gfx.measurestr(tooltipText)
        local th = PS(14)
        local tx = tooltipX
        local ty = tooltipY

        -- Keep tooltip on screen
        if tx + tw + padding * 2 > w then
            tx = w - tw - padding * 2 - PS(5)
        end
        if ty + th + padding * 2 > h then
            ty = tooltipY - th - padding * 2 - PS(20)
        end

        -- Background
        gfx.set(0.15, 0.15, 0.18, 0.95)
        gfx.rect(tx, ty, tw + padding * 2, th + padding * 2, 1)
        -- Border
        gfx.set(0.4, 0.4, 0.45, 1)
        gfx.rect(tx, ty, tw + padding * 2, th + padding * 2, 0)
        -- Text
        gfx.set(0.9, 0.9, 0.9, 1)
        gfx.x = tx + padding
        gfx.y = ty + padding
        gfx.drawstr(tooltipText)
    end

    gfx.update()

    -- Handle clicks
    if mouseDown and not messageWindowState.wasMouseDown then
        if artLinkHover then
            return "artgallery"
        elseif hover then
            return "close"
        end
    end

    messageWindowState.wasMouseDown = mouseDown

    local char = gfx.getchar()
    if char == -1 or char == 27 or char == 13 or char == 32 then
        return "close"
    end

    return nil
end

-- Check if there's any valid selection for processing
local function hasAnySelection()
    -- Check for time selection
    if hasTimeSelection() then return true end
    -- Check for selected items
    if reaper.CountSelectedMediaItems(0) > 0 then return true end
    -- Check for selected tracks with items
    local selTrackCount = reaper.CountSelectedTracks(0)
    if selTrackCount > 0 then
        for t = 0, selTrackCount - 1 do
            local track = reaper.GetSelectedTrack(0, t)
            if reaper.CountTrackMediaItems(track) > 0 then
                return true
            end
        end
    end
    return false
end

-- Forward declaration for main (defined later)
local main

-- Message window loop
local function messageWindowLoop()
    -- Save window position for next time
    if reaper.JS_Window_Find then
        local hwnd = reaper.JS_Window_Find("Stemperator", true)
        if hwnd then
            local retval, left, top, right, bottom = reaper.JS_Window_GetRect(hwnd)
            if retval then
                lastDialogX = left
                lastDialogY = top
                lastDialogW = right - left
                lastDialogH = bottom - top
            end
        end
    end

    -- If monitoring for selection, check if user made a selection
    if messageWindowState.monitorSelection and hasAnySelection() then
        gfx.quit()
        messageWindowState.monitorSelection = false
        -- Re-run main to open the dialog with the new selection
        reaper.defer(function() main() end)
        return
    end

    local result = drawMessageWindow()
    if result == "close" then
        gfx.quit()
        messageWindowState.monitorSelection = false
        -- Return focus to REAPER main window
        local mainHwnd = reaper.GetMainHwnd()
        if mainHwnd then
            reaper.JS_Window_SetFocus(mainHwnd)
        end
        return
    elseif result == "artgallery" then
        gfx.quit()
        messageWindowState.monitorSelection = false
        -- Open Art Gallery
        showArtGallery()
        return
    end
    reaper.defer(messageWindowLoop)
end

-- Show a styled message window (replacement for reaper.MB)
-- icon: "info", "warning", "error"
-- monitorSelection: if true, window will auto-close and open main dialog when user makes a selection
showMessage = function(title, message, icon, monitorSelection)
    -- Load settings to get current theme
    loadSettings()
    updateTheme()

    messageWindowState.title = title or "Stemperator"
    messageWindowState.message = message or ""
    messageWindowState.icon = icon or "info"
    messageWindowState.wasMouseDown = false
    messageWindowState.startTime = os.clock()
    messageWindowState.monitorSelection = monitorSelection or false

    -- Use same size as main dialog
    local winW = lastDialogW or 380
    local winH = lastDialogH or 340
    local winX, winY

    -- Use last dialog position if available (exact position, no clamping)
    if lastDialogX and lastDialogY then
        winX = lastDialogX
        winY = lastDialogY
    else
        -- Fallback to mouse position with clamping
        local mouseX, mouseY = reaper.GetMousePosition()
        winX = mouseX - winW / 2
        winY = mouseY - winH / 2
        winX, winY = clampToScreen(winX, winY, winW, winH, mouseX, mouseY)
    end

    gfx.init("Stemperator", winW, winH, 0, winX, winY)
    reaper.defer(messageWindowLoop)
end

-- Scaling helper: converts base coordinates to current scale
local function S(val)
    return math.floor(val * GUI.scale + 0.5)
end

-- Calculate current scale based on window size
local function updateScale()
    local scaleW = gfx.w / GUI.baseW
    local scaleH = gfx.h / GUI.baseH
    GUI.scale = math.min(scaleW, scaleH)
    -- Clamp scale (1.0 to 4.0)
    GUI.scale = math.max(1.0, math.min(4.0, GUI.scale))
end

-- Track if we've made window resizable
local windowResizableSet = false

-- Make window resizable using JS_ReaScriptAPI (if available)
local function makeWindowResizable()
    if windowResizableSet then return true end
    if not reaper.JS_Window_Find then return false end

    -- Find the gfx window
    local hwnd = reaper.JS_Window_Find(SCRIPT_NAME, true)
    if not hwnd then return false end

    -- On Linux/X11, use different approach - set window hints
    if OS == "Linux" then
        -- For Linux, we need to modify GDK window properties
        -- js_ReaScriptAPI doesn't directly support this, but we can try
        local style = reaper.JS_Window_GetLong(hwnd, "STYLE")
        if style then
            -- Try to add resize style bits
            reaper.JS_Window_SetLong(hwnd, "STYLE", style | 0x00040000 | 0x00010000)
        end
    else
        -- Windows: add WS_THICKFRAME and WS_MAXIMIZEBOX
        local style = reaper.JS_Window_GetLong(hwnd, "STYLE")
        local WS_THICKFRAME = 0x00040000
        local WS_MAXIMIZEBOX = 0x00010000
        reaper.JS_Window_SetLong(hwnd, "STYLE", style | WS_THICKFRAME | WS_MAXIMIZEBOX)
    end

    windowResizableSet = true
    return true
end

-- Tooltip helper: set tooltip if mouse is in area
local function setTooltip(x, y, w, h, text)
    local mx, my = gfx.mouse_x, gfx.mouse_y
    if mx >= x and mx <= x + w and my >= y and my <= y + h then
        GUI.tooltip = text
        GUI.tooltipX = mx + S(10)
        GUI.tooltipY = my + S(15)
    end
end

-- Set a rich tooltip for STEMperate button with colored output stems and target
local function setRichTooltip(x, y, w, h)
    local mx, my = gfx.mouse_x, gfx.mouse_y
    if mx >= x and mx <= x + w and my >= y and my <= y + h then
        GUI.richTooltip = true
        GUI.tooltipX = mx + S(10)
        GUI.tooltipY = my + S(15)
    end
end

-- Set a tooltip with keyboard shortcut highlighted in color
-- shortcut: the key (e.g. "K", "V", "1")
-- color: RGB table for the shortcut color (e.g. {255, 100, 100})
local function setTooltipWithShortcut(x, y, w, h, text, shortcut, color)
    local mx, my = gfx.mouse_x, gfx.mouse_y
    if mx >= x and mx <= x + w and my >= y and my <= y + h then
        GUI.shortcutTooltip = {
            text = text,
            shortcut = shortcut,
            color = color or {255, 200, 100}  -- Default orange/yellow
        }
        GUI.tooltipX = mx + S(10)
        GUI.tooltipY = my + S(15)
    end
end

-- Draw the current tooltip (call at end of frame)
local function drawTooltip()
    -- Rich tooltip for STEMperate button
    if GUI.richTooltip then
        gfx.setfont(1, "Arial", S(10))
        local padding = S(8)
        local lineH = S(14)

        -- Use global STEM border colors
        local titleColors = STEM_BORDER_COLORS

        -- Build selected stems list (use actual STEMS data)
        local selectedStems = {}
        for i, stem in ipairs(STEMS) do
            if stem.selected and (not stem.sixStemOnly or SETTINGS.model == "htdemucs_6s") then
                table.insert(selectedStems, {name = stem.name, color = stem.color})
            end
        end

        -- Get target info
        local targetText = "New tracks"
        if SETTINGS.deleteOriginal then targetText = "Delete original"
        elseif SETTINGS.deleteSelection then targetText = "Delete selection"
        elseif SETTINGS.muteOriginal then targetText = "Mute original"
        elseif SETTINGS.muteSelection then targetText = "Mute selection"
        end
        if SETTINGS.createFolder then targetText = targetText .. " + folder" end

        -- Count selection info
        local selTrackCount = reaper.CountSelectedTracks(0)
        local selItemCount = 0
        for i = 0, selTrackCount - 1 do
            local track = reaper.GetSelectedTrack(0, i)
            selItemCount = selItemCount + reaper.CountTrackMediaItems(track)
        end

        -- Calculate tooltip size (5 lines: header, stems, selection, takes, target)
        local th = padding * 2 + lineH * 5 + S(10)

        -- Fixed label column width
        local labelColW = S(65)

        -- Measure line widths (value column only)
        gfx.setfont(1, "Arial", S(10), string.byte('b'))
        local stemsValueW = 0
        for i, stem in ipairs(selectedStems) do
            stemsValueW = stemsValueW + gfx.measurestr(stem.name)
            if i < #selectedStems then stemsValueW = stemsValueW + gfx.measurestr(" ") end
        end

        gfx.setfont(1, "Arial", S(10))
        local selectionText = string.format("%d track%s, %d item%s",
            selTrackCount, selTrackCount == 1 and "" or "s",
            selItemCount, selItemCount == 1 and "" or "s")
        local selValueW = gfx.measurestr(selectionText)
        local takesText = SETTINGS.createTakes and "Yes" or "No"
        local takesValueW = gfx.measurestr(takesText)
        local targetValueW = gfx.measurestr(targetText)

        -- Measure header
        gfx.setfont(1, "Arial", S(11), string.byte('b'))
        local headerText = "Click to STEMperate"
        local headerLineW = gfx.measurestr(headerText)

        -- Calculate max value width needed
        local maxValueW = math.max(stemsValueW, selValueW, takesValueW, targetValueW)
        -- Total width = padding + label column + value column + padding
        local tw = math.max(headerLineW + padding * 2, padding + labelColW + maxValueW + padding)

        local tx = GUI.tooltipX
        local ty = GUI.tooltipY

        -- Keep tooltip on screen
        if tx + tw > gfx.w then tx = gfx.w - tw - S(5) end
        if ty + th > gfx.h then ty = GUI.tooltipY - th - S(20) end

        -- Background (theme-aware)
        gfx.set(THEME.inputBg[1], THEME.inputBg[2], THEME.inputBg[3], 0.98)
        gfx.rect(tx, ty, tw, th, 1)

        -- Colored top border (stem colors gradient)
        for i = 0, tw - 1 do
            local colorIdx = math.floor(i / tw * 4) + 1
            colorIdx = math.min(4, math.max(1, colorIdx))
            local c = titleColors[colorIdx]
            gfx.set(c[1]/255, c[2]/255, c[3]/255, 0.9)
            gfx.line(tx + i, ty, tx + i, ty + 2)
        end

        -- Border (theme-aware)
        gfx.set(THEME.border[1], THEME.border[2], THEME.border[3], 1)
        gfx.rect(tx, ty, tw, th, 0)

        local labelX = tx + padding
        local valueX = tx + padding + labelColW
        local currentY = ty + padding + S(2)

        -- Header: Click to STEMperate (centered, colored letters)
        gfx.setfont(1, "Arial", S(11), string.byte('b'))
        local headerW = gfx.measurestr(headerText)
        local headerX = tx + (tw - headerW) / 2
        gfx.x = headerX
        gfx.y = currentY

        -- Draw "Click to " in theme text color
        gfx.set(THEME.text[1], THEME.text[2], THEME.text[3], 1)
        gfx.drawstr("Click to ")
        -- Draw "STEM" with colored letters
        local stemLetters = {"S", "T", "E", "M"}
        for i, letter in ipairs(stemLetters) do
            local c = titleColors[i]
            gfx.set(c[1]/255, c[2]/255, c[3]/255, 1)
            gfx.drawstr(letter)
        end
        -- Draw "perate" in theme text color
        gfx.set(THEME.text[1], THEME.text[2], THEME.text[3], 1)
        gfx.drawstr("perate")
        currentY = currentY + lineH + S(4)

        -- Line 1: Stems (colored)
        gfx.setfont(1, "Arial", S(10))
        gfx.set(THEME.textHint[1], THEME.textHint[2], THEME.textHint[3], 1)
        gfx.x = labelX
        gfx.y = currentY
        gfx.drawstr("Stems")

        gfx.setfont(1, "Arial", S(10), string.byte('b'))
        local stemX = valueX
        for i, stem in ipairs(selectedStems) do
            gfx.set(stem.color[1]/255, stem.color[2]/255, stem.color[3]/255, 1)
            gfx.x = stemX
            gfx.y = currentY
            gfx.drawstr(stem.name)
            stemX = stemX + gfx.measurestr(stem.name)
            if i < #selectedStems then
                gfx.set(THEME.textHint[1], THEME.textHint[2], THEME.textHint[3], 1)
                gfx.x = stemX
                gfx.drawstr(" ")
                stemX = stemX + gfx.measurestr(" ")
            end
        end
        currentY = currentY + lineH

        -- Line 2: Selection
        gfx.setfont(1, "Arial", S(10))
        gfx.set(THEME.textHint[1], THEME.textHint[2], THEME.textHint[3], 1)
        gfx.x = labelX
        gfx.y = currentY
        gfx.drawstr("Selection")
        gfx.set(THEME.text[1], THEME.text[2], THEME.text[3], 1)
        gfx.x = valueX
        gfx.drawstr(selectionText)
        currentY = currentY + lineH

        -- Line 3: Takes
        gfx.set(THEME.textHint[1], THEME.textHint[2], THEME.textHint[3], 1)
        gfx.x = labelX
        gfx.y = currentY
        gfx.drawstr("Takes")
        if SETTINGS.createTakes then
            gfx.set(0.4, 0.9, 0.5, 1)  -- Green for yes
        else
            gfx.set(THEME.textDim[1], THEME.textDim[2], THEME.textDim[3], 1)  -- Dim for no
        end
        gfx.x = valueX
        gfx.drawstr(takesText)
        currentY = currentY + lineH

        -- Line 4: Target
        gfx.set(THEME.textHint[1], THEME.textHint[2], THEME.textHint[3], 1)
        gfx.x = labelX
        gfx.y = currentY
        gfx.drawstr("Target")
        gfx.set(1.0, 0.6, 0.2, 1)  -- Orange for target (stays colored)
        gfx.x = valueX
        gfx.drawstr(targetText)

        GUI.richTooltip = nil
    elseif GUI.tooltip then
        -- Use global STEM border colors
        local tooltipColors = STEM_BORDER_COLORS

        gfx.setfont(1, "Arial", S(11))
        local padding = S(8)
        local tw = gfx.measurestr(GUI.tooltip) + padding * 2
        local th = S(18) + padding * 2
        local tx = GUI.tooltipX
        local ty = GUI.tooltipY

        -- Keep tooltip on screen
        if tx + tw > gfx.w then
            tx = gfx.w - tw - S(5)
        end
        if ty + th > gfx.h then
            ty = GUI.tooltipY - th - S(20)
        end

        -- Background (theme-aware)
        gfx.set(THEME.inputBg[1], THEME.inputBg[2], THEME.inputBg[3], 0.98)
        gfx.rect(tx, ty, tw, th, 1)

        -- Colored top border (stem colors gradient)
        for i = 0, tw - 1 do
            local colorIdx = math.floor(i / tw * 4) + 1
            colorIdx = math.min(4, math.max(1, colorIdx))
            local c = tooltipColors[colorIdx]
            gfx.set(c[1]/255, c[2]/255, c[3]/255, 0.9)
            gfx.line(tx + i, ty, tx + i, ty + 2)
        end

        -- Border (theme-aware)
        gfx.set(THEME.border[1], THEME.border[2], THEME.border[3], 1)
        gfx.rect(tx, ty, tw, th, 0)

        -- Text (theme-aware)
        gfx.set(THEME.text[1], THEME.text[2], THEME.text[3], 1)
        gfx.x = tx + padding
        gfx.y = ty + padding + S(2)
        gfx.drawstr(GUI.tooltip)

        -- Clear tooltip for next frame
        GUI.tooltip = nil
    elseif GUI.shortcutTooltip then
        -- Tooltip with colored keyboard shortcut
        local tooltipColors = STEM_BORDER_COLORS
        local st = GUI.shortcutTooltip

        gfx.setfont(1, "Arial", S(11))
        local padding = S(8)
        local textW = gfx.measurestr(st.text)
        local shortcutW = gfx.measurestr(" [" .. st.shortcut .. "]")
        local tw = textW + shortcutW + padding * 2
        local th = S(18) + padding * 2
        local tx = GUI.tooltipX
        local ty = GUI.tooltipY

        -- Keep tooltip on screen
        if tx + tw > gfx.w then
            tx = gfx.w - tw - S(5)
        end
        if ty + th > gfx.h then
            ty = GUI.tooltipY - th - S(20)
        end

        -- Background (theme-aware)
        gfx.set(THEME.inputBg[1], THEME.inputBg[2], THEME.inputBg[3], 0.98)
        gfx.rect(tx, ty, tw, th, 1)

        -- Colored top border (stem colors gradient)
        for i = 0, tw - 1 do
            local colorIdx = math.floor(i / tw * 4) + 1
            colorIdx = math.min(4, math.max(1, colorIdx))
            local c = tooltipColors[colorIdx]
            gfx.set(c[1]/255, c[2]/255, c[3]/255, 0.9)
            gfx.line(tx + i, ty, tx + i, ty + 2)
        end

        -- Border (theme-aware)
        gfx.set(THEME.border[1], THEME.border[2], THEME.border[3], 1)
        gfx.rect(tx, ty, tw, th, 0)

        -- Text (theme-aware)
        gfx.set(THEME.text[1], THEME.text[2], THEME.text[3], 1)
        gfx.x = tx + padding
        gfx.y = ty + padding + S(2)
        gfx.drawstr(st.text .. " ")

        -- Shortcut in color
        gfx.set(st.color[1]/255, st.color[2]/255, st.color[3]/255, 1)
        gfx.drawstr("[" .. st.shortcut .. "]")

        -- Clear tooltip for next frame
        GUI.shortcutTooltip = nil
    end
end

-- Draw a checkbox as a toggle box (like stems/presets) and return if it was clicked (scaled)
-- Optional fixedW parameter to set a fixed width for all boxes
local function drawCheckbox(x, y, checked, label, r, g, b, fixedW)
    local clicked = false
    local labelWidth = gfx.measurestr(label)
    local boxW = fixedW or (labelWidth + S(16))
    local boxH = S(20)
    local mx, my = gfx.mouse_x, gfx.mouse_y
    local mouseDown = gfx.mouse_cap & 1 == 1
    local hover = mx >= x and mx <= x + boxW and my >= y and my <= y + boxH

    if mouseDown and hover then
        if not GUI.wasMouseDown then clicked = true end
    end

    -- Background color based on checked state
    if checked then
        local mult = hover and 1.2 or 1.0
        gfx.set(r/255 * mult, g/255 * mult, b/255 * mult, 1)
    else
        local brightness = hover and 0.35 or 0.25
        gfx.set(brightness, brightness, brightness, 1)
    end
    gfx.rect(x, y, boxW, boxH, 1)

    -- Border
    gfx.set(THEME.border[1], THEME.border[2], THEME.border[3], 1)
    gfx.rect(x, y, boxW, boxH, 0)

    -- Text - white for contrast
    gfx.set(1, 1, 1, 1)
    local tw = gfx.measurestr(label)
    gfx.x = x + (boxW - tw) / 2
    gfx.y = y + (boxH - S(14)) / 2
    gfx.drawstr(label)

    return clicked, boxW
end

-- Draw a radio button as a toggle box (like stems/presets) and return if it was clicked (scaled)
-- Optional fixedW parameter to set a fixed width for all boxes
local function drawRadio(x, y, selected, label, color, fixedW)
    local clicked = false
    local labelWidth = gfx.measurestr(label)
    local boxW = fixedW or (labelWidth + S(16))
    local boxH = S(20)
    local mx, my = gfx.mouse_x, gfx.mouse_y
    local mouseDown = gfx.mouse_cap & 1 == 1
    local hover = mx >= x and mx <= x + boxW and my >= y and my <= y + boxH

    if mouseDown and hover then
        if not GUI.wasMouseDown then clicked = true end
    end

    -- Use provided color or default accent color
    local r, g, b = THEME.accent[1] * 255, THEME.accent[2] * 255, THEME.accent[3] * 255
    if color then
        r, g, b = color[1], color[2], color[3]
    end

    -- Background color based on selected state
    if selected then
        local mult = hover and 1.2 or 1.0
        gfx.set(r/255 * mult, g/255 * mult, b/255 * mult, 1)
    else
        local brightness = hover and 0.35 or 0.25
        gfx.set(brightness, brightness, brightness, 1)
    end
    gfx.rect(x, y, boxW, boxH, 1)

    -- Border
    gfx.set(THEME.border[1], THEME.border[2], THEME.border[3], 1)
    gfx.rect(x, y, boxW, boxH, 0)

    -- Text - white for contrast
    gfx.set(1, 1, 1, 1)
    local tw = gfx.measurestr(label)
    gfx.x = x + (boxW - tw) / 2
    gfx.y = y + (boxH - S(14)) / 2
    gfx.drawstr(label)

    return clicked, boxW
end

-- Draw a toggle button (like stems) with selected state
local function drawToggleButton(x, y, w, h, label, selected, color)
    local clicked = false
    local mx, my = gfx.mouse_x, gfx.mouse_y
    local mouseDown = gfx.mouse_cap & 1 == 1
    local hover = mx >= x and mx <= x + w and my >= y and my <= y + h

    if mouseDown and hover then
        if not GUI.wasMouseDown then clicked = true end
    end

    -- Background color based on selected state
    if selected then
        -- Selected: use the stem color
        local mult = hover and 1.2 or 1.0
        gfx.set(color[1]/255 * mult, color[2]/255 * mult, color[3]/255 * mult, 1)
    else
        -- Not selected: dim gray
        local brightness = hover and 0.35 or 0.25
        gfx.set(brightness, brightness, brightness, 1)
    end
    gfx.rect(x, y, w, h, 1)

    -- Border - brighter when selected
    if selected then
        gfx.set(1, 1, 1, 0.5)
    else
        gfx.set(THEME.border[1], THEME.border[2], THEME.border[3], 1)
    end
    gfx.rect(x, y, w, h, 0)

    -- Button text
    if selected then
        gfx.set(1, 1, 1, 1)
    else
        gfx.set(0.6, 0.6, 0.6, 1)
    end
    local tw = gfx.measurestr(label)
    gfx.x = x + (w - tw) / 2
    gfx.y = y + (h - S(14)) / 2
    gfx.drawstr(label)

    return clicked
end

-- Draw a small button and return if it was clicked (scaled)
local function drawButton(x, y, w, h, label, isDefault, color)
    local clicked = false
    local mx, my = gfx.mouse_x, gfx.mouse_y
    local mouseDown = gfx.mouse_cap & 1 == 1
    local hover = mx >= x and mx <= x + w and my >= y and my <= y + h

    if mouseDown and hover then
        if not GUI.wasMouseDown then clicked = true end
    end

    if color then
        -- Custom color provided (e.g., preset buttons)
        local mult = hover and 1.2 or 1.0
        gfx.set(color[1]/255 * mult, color[2]/255 * mult, color[3]/255 * mult, 1)
    else
        -- Use theme colors
        if isDefault then
            if hover then
                gfx.set(THEME.buttonPrimaryHover[1], THEME.buttonPrimaryHover[2], THEME.buttonPrimaryHover[3], 1)
            else
                gfx.set(THEME.buttonPrimary[1], THEME.buttonPrimary[2], THEME.buttonPrimary[3], 1)
            end
        else
            if hover then
                gfx.set(THEME.buttonHover[1], THEME.buttonHover[2], THEME.buttonHover[3], 1)
            else
                gfx.set(THEME.button[1], THEME.button[2], THEME.button[3], 1)
            end
        end
    end

    -- Draw rounded (pill-shaped) button background
    for i = 0, h - 1 do
        local radius = h / 2
        local inset = 0
        if i < radius then
            inset = radius - math.sqrt(radius * radius - (radius - i) * (radius - i))
        elseif i > h - radius then
            inset = radius - math.sqrt(radius * radius - (i - (h - radius)) * (i - (h - radius)))
        end
        gfx.line(x + inset, y + i, x + w - inset, y + i)
    end

    -- Button text - always white for good contrast on colored buttons
    gfx.set(1, 1, 1, 1)
    local tw = gfx.measurestr(label)
    gfx.x = x + (w - tw) / 2
    gfx.y = y + (h - S(14)) / 2
    gfx.drawstr(label)

    return clicked
end

-- Main dialog loop
local function dialogLoop()
    -- Try to make window resizable (needs to be called after window is visible)
    makeWindowResizable()

    -- Save window position continuously (for when window loses focus)
    if reaper.JS_Window_GetRect then
        local hwnd = reaper.JS_Window_Find(SCRIPT_NAME, true)
        if hwnd then
            local retval, left, top, right, bottom = reaper.JS_Window_GetRect(hwnd)
            if retval then
                lastDialogX = left
                lastDialogY = top
                lastDialogW = right - left
                lastDialogH = bottom - top
            end
        end
    end

    -- Check if settings changed and save periodically (throttled to avoid excessive writes)
    if not GUI.lastSaveTime then GUI.lastSaveTime = 0 end
    local now = os.clock()
    if now - GUI.lastSaveTime > 0.5 then  -- Save at most every 0.5 seconds
        saveSettings()
        GUI.lastSaveTime = now
    end

    -- Update scale based on current window size
    updateScale()

    -- Check if selection was lost - switch to "Start" message
    if not hasAnySelection() then
        gfx.quit()
        -- Clear auto-selection tracking (user already deselected everything)
        autoSelectedItems = {}
        autoSelectionTracks = {}
        -- Show "Start" with monitoring enabled
        showMessage("Start", "Please select a media item, track, or make a time selection to separate.", "info", true)
        return
    end

    -- Background
    gfx.set(THEME.bg[1], THEME.bg[2], THEME.bg[3], 1)
    gfx.rect(0, 0, gfx.w, gfx.h, 1)

    -- Colored STEM border at top
    drawStemBorder(0, 0, gfx.w, 3)

    -- Theme toggle button (sun/moon icon, aligned with column 4)
    local themeSize = S(20)
    local themeX = S(260) + S(70) - themeSize  -- col4X + outBoxW - themeSize (right-aligned)
    local themeY = S(8)
    local mx, my = gfx.mouse_x, gfx.mouse_y
    local themeHover = mx >= themeX and mx <= themeX + themeSize and my >= themeY and my <= themeY + themeSize
    local mouseDown = gfx.mouse_cap & 1 == 1

    -- Draw theme toggle (circle with rays for sun, crescent for moon)
    if SETTINGS.darkMode then
        -- Moon icon (crescent)
        gfx.set(0.7, 0.7, 0.5, themeHover and 1 or 0.6)
        gfx.circle(themeX + themeSize/2, themeY + themeSize/2, themeSize/2 - 2, 1, 1)
        gfx.set(THEME.bg[1], THEME.bg[2], THEME.bg[3], 1)
        gfx.circle(themeX + themeSize/2 + 4, themeY + themeSize/2 - 3, themeSize/2 - 3, 1, 1)
    else
        -- Sun icon
        gfx.set(0.9, 0.7, 0.2, themeHover and 1 or 0.8)
        gfx.circle(themeX + themeSize/2, themeY + themeSize/2, themeSize/3, 1, 1)
        -- Rays
        for i = 0, 7 do
            local angle = i * math.pi / 4
            local x1 = themeX + themeSize/2 + math.cos(angle) * (themeSize/3 + 2)
            local y1 = themeY + themeSize/2 + math.sin(angle) * (themeSize/3 + 2)
            local x2 = themeX + themeSize/2 + math.cos(angle) * (themeSize/2 - 1)
            local y2 = themeY + themeSize/2 + math.sin(angle) * (themeSize/2 - 1)
            gfx.line(x1, y1, x2, y2)
        end
    end

    -- Handle theme toggle click and tooltip
    if themeHover then
        local themeTip = SETTINGS.darkMode and "Switch to light mode" or "Switch to dark mode"
        setTooltip(themeX, themeY, themeSize, themeSize, themeTip)
        if mouseDown and not GUI.wasMouseDown then
            SETTINGS.darkMode = not SETTINGS.darkMode
            updateTheme()
            saveSettings()  -- Persist theme change
        end
    end

    -- === LOGO: Centered "STEMperator" at top ===
    gfx.setfont(1, "Arial", S(24), string.byte('b'))  -- Bold, large font
    local logoY = S(12)

    -- Calculate total width of logo text to center it
    local logoLetters = {"S", "T", "E", "M", "p", "e", "r", "a", "t", "o", "r"}
    local logoWidths = {}
    local logoTotalWidth = 0
    for i, letter in ipairs(logoLetters) do
        local w, _ = gfx.measurestr(letter)
        logoWidths[i] = w
        logoTotalWidth = logoTotalWidth + w
    end
    local logoX = (gfx.w - logoTotalWidth) / 2

    -- STEM colors (Vocals red, Drums blue, Bass purple, Other green)
    local logoColors = {
        {255/255, 100/255, 100/255},  -- S = Vocals (red)
        {100/255, 200/255, 255/255},  -- T = Drums (blue)
        {150/255, 100/255, 255/255},  -- E = Bass (purple)
        {100/255, 255/255, 150/255},  -- M = Other (green)
    }

    -- Store logo start position for click detection
    local logoStartX = logoX

    -- Draw each letter
    for i, letter in ipairs(logoLetters) do
        if i <= 4 then
            -- Colored STEM letters
            gfx.set(logoColors[i][1], logoColors[i][2], logoColors[i][3], 1)
        else
            -- White/gray "perator"
            gfx.set(THEME.text[1], THEME.text[2], THEME.text[3], 0.9)
        end
        gfx.x = logoX
        gfx.y = logoY
        gfx.drawstr(letter)
        logoX = logoX + logoWidths[i]
    end

    -- Logo click detection and tooltip
    local logoH = S(28)
    local mx, my = gfx.mouse_x, gfx.mouse_y
    local logoHover = mx >= logoStartX and mx <= logoStartX + logoTotalWidth and my >= logoY and my <= logoY + logoH
    if logoHover then
        setTooltip(logoStartX, logoY, logoTotalWidth, logoH, "Click for help - Select tracks/items, choose stems, click STEMperate!")
        -- Check for click
        if gfx.mouse_cap & 1 == 1 and not GUI.logoWasClicked then
            GUI.logoWasClicked = true
        elseif gfx.mouse_cap & 1 == 0 and GUI.logoWasClicked then
            GUI.logoWasClicked = false
            -- Set flag to show help (handled after dialog loop exits)
            GUI.result = "help"
        end
    end

    -- Content starts below logo
    local contentTop = S(45)

    gfx.setfont(1, "Arial", S(13))

    -- Determine 6-stem mode early (needed for stem display)
    local is6Stem = (SETTINGS.model == "htdemucs_6s")

    -- Column positions (4 columns)
    local col1X = S(10)   -- Presets
    local col2X = S(90)   -- Stems
    local col3X = S(175)  -- Model
    local col4X = S(260)  -- Output
    local colW = S(70)
    local btnH = S(20)

    -- === COLUMN 1: Presets ===
    gfx.set(THEME.textDim[1], THEME.textDim[2], THEME.textDim[3], 1)
    gfx.x = col1X
    gfx.y = contentTop
    gfx.drawstr("Presets:")

    local presetY = contentTop + S(20)

    -- Combo presets first (most common use cases)
    if drawButton(col1X, presetY, colW, btnH, "Karaoke (K)", false, {80, 80, 90}) then applyPresetKaraoke() end
    setTooltipWithShortcut(col1X, presetY, colW, btnH, "Everything except vocals", "K", {255, 200, 100})
    presetY = presetY + S(22)
    if drawButton(col1X, presetY, colW, btnH, "All (A)", false, {80, 80, 90}) then applyPresetAll() end
    setTooltipWithShortcut(col1X, presetY, colW, btnH, "Select all available stems", "A", {255, 200, 100})

    -- Separator
    presetY = presetY + S(28)

    -- Stem presets (colored by stem)
    if drawButton(col1X, presetY, colW, btnH, "Vocals (V)", false, {255, 100, 100}) then applyPresetVocalsOnly() end
    setTooltipWithShortcut(col1X, presetY, colW, btnH, "Select only Vocals stem", "V", {255, 100, 100})
    presetY = presetY + S(22)
    if drawButton(col1X, presetY, colW, btnH, "Drums (D)", false, {100, 200, 255}) then applyPresetDrumsOnly() end
    setTooltipWithShortcut(col1X, presetY, colW, btnH, "Select only Drums stem", "D", {100, 200, 255})
    presetY = presetY + S(22)
    if drawButton(col1X, presetY, colW, btnH, "Bass (B)", false, {150, 100, 255}) then applyPresetBassOnly() end
    setTooltipWithShortcut(col1X, presetY, colW, btnH, "Select only Bass stem", "B", {150, 100, 255})
    presetY = presetY + S(22)
    if drawButton(col1X, presetY, colW, btnH, "Other (O)", false, {100, 255, 150}) then applyPresetOtherOnly() end
    setTooltipWithShortcut(col1X, presetY, colW, btnH, "Select only Other stem", "O", {100, 255, 150})
    presetY = presetY + S(22)

    -- Piano and Guitar only show for 6-stem model
    if is6Stem then
        if drawButton(col1X, presetY, colW, btnH, "Piano (P)", false, {255, 120, 200}) then applyPresetPianoOnly() end
        setTooltipWithShortcut(col1X, presetY, colW, btnH, "Select only Piano stem", "P", {255, 120, 200})
        presetY = presetY + S(22)
        if drawButton(col1X, presetY, colW, btnH, "Guitar (G)", false, {255, 180, 100}) then applyPresetGuitarOnly() end
        setTooltipWithShortcut(col1X, presetY, colW, btnH, "Select only Guitar stem", "G", {255, 180, 100})
        presetY = presetY + S(22)
    end

    -- === COLUMN 2: Stems ===
    gfx.set(THEME.textDim[1], THEME.textDim[2], THEME.textDim[3], 1)
    gfx.x = col2X
    gfx.y = contentTop
    gfx.drawstr(is6Stem and "Stems (1-6):" or "Stems (1-4):")

    local stemY = contentTop + S(20)
    local stemTooltips = {
        Vocals = "Voice, lead vocals, backing vocals",
        Drums = "Drums, percussion, cymbals",
        Bass = "Bass guitar, synth bass",
        Other = "Synths, strings, keys, effects",
        Guitar = "Electric and acoustic guitars",
        Piano = "Piano, keys, Rhodes"
    }
    for i, stem in ipairs(STEMS) do
        if not stem.sixStemOnly or is6Stem then
            local label = stem.name .. " (" .. stem.key .. ")"
            if drawToggleButton(col2X, stemY, colW, btnH, label, stem.selected, stem.color) then
                STEMS[i].selected = not STEMS[i].selected
            end
            setTooltipWithShortcut(col2X, stemY, colW, btnH, stemTooltips[stem.name] or stem.name, stem.key, stem.color)
            stemY = stemY + S(22)
        end
    end

    -- === COLUMN 3: Model ===
    gfx.set(THEME.textDim[1], THEME.textDim[2], THEME.textDim[3], 1)
    gfx.x = col3X
    gfx.y = contentTop
    gfx.drawstr("Model:")

    -- Fixed width for all Model column boxes
    local modelBoxW = S(70)

    local modelY = contentTop + S(20)
    for _, model in ipairs(MODELS) do
        if drawRadio(col3X, modelY, SETTINGS.model == model.id, model.name, nil, modelBoxW) then
            SETTINGS.model = model.id
        end
        setTooltip(col3X, modelY, modelBoxW, btnH, model.desc)
        modelY = modelY + S(22)
    end

    -- Processing mode
    modelY = modelY + S(8)
    local parallelColor = SETTINGS.parallelProcessing and {100, 180, 255} or {160, 160, 160}
    local parallelLabel = SETTINGS.parallelProcessing and "Parallel" or "Sequential"
    if drawCheckbox(col3X, modelY, SETTINGS.parallelProcessing, parallelLabel, parallelColor[1], parallelColor[2], parallelColor[3], modelBoxW) then
        SETTINGS.parallelProcessing = not SETTINGS.parallelProcessing
    end
    local parallelTip = SETTINGS.parallelProcessing
        and "Process all tracks at once (12GB+ VRAM)"
        or "Process one track at a time (4-8GB VRAM)"
    setTooltip(col3X, modelY, modelBoxW, btnH, parallelTip)

    -- === COLUMN 4: Output ===
    gfx.set(THEME.textDim[1], THEME.textDim[2], THEME.textDim[3], 1)
    gfx.x = col4X
    gfx.y = contentTop
    gfx.drawstr("Output:")

    -- Fixed width for all Output column boxes
    local outBoxW = S(70)

    -- Count selected stems for plural labels
    local stemCount = 0
    for _, stem in ipairs(STEMS) do
        if stem.selected and (not stem.sixStemOnly or is6Stem) then
            stemCount = stemCount + 1
        end
    end
    local stemPlural = stemCount ~= 1
    local newTracksLabel = stemPlural and "New tracks" or "New track"
    local inPlaceLabel = "In-place"

    local outY = contentTop + S(20)
    if drawRadio(col4X, outY, SETTINGS.createNewTracks, newTracksLabel, nil, outBoxW) then
        SETTINGS.createNewTracks = true
    end
    setTooltip(col4X, outY, outBoxW, btnH, "Create separate tracks for each stem")
    outY = outY + S(22)
    if drawRadio(col4X, outY, not SETTINGS.createNewTracks, inPlaceLabel, nil, outBoxW) then
        SETTINGS.createNewTracks = false
    end
    setTooltip(col4X, outY, outBoxW, btnH, "Replace original with stems as takes")

    -- Options (only when creating new tracks)
    if SETTINGS.createNewTracks then
        outY = outY + S(28)
        gfx.set(THEME.textDim[1], THEME.textDim[2], THEME.textDim[3], 1)
        gfx.x = col4X
        gfx.y = outY
        gfx.drawstr("After:")

        outY = outY + S(20)
        if drawCheckbox(col4X, outY, SETTINGS.createFolder, "Folder", 160, 160, 160, outBoxW) then
            SETTINGS.createFolder = not SETTINGS.createFolder
        end
        setTooltip(col4X, outY, outBoxW, btnH, "Group stem tracks in a folder track")

        outY = outY + S(22)
        if drawCheckbox(col4X, outY, SETTINGS.muteOriginal, "Mute orig", 160, 160, 160, outBoxW) then
            SETTINGS.muteOriginal = not SETTINGS.muteOriginal
            if SETTINGS.muteOriginal then
                SETTINGS.deleteOriginal = false; SETTINGS.deleteOriginalTrack = false
                SETTINGS.muteSelection = false; SETTINGS.deleteSelection = false
            end
        end
        setTooltip(col4X, outY, outBoxW, btnH, "Mute original items after separation")

        outY = outY + S(22)
        local delItemColor = SETTINGS.deleteOriginal and {255, 120, 120} or {160, 160, 160}
        if drawCheckbox(col4X, outY, SETTINGS.deleteOriginal, "Delete orig", delItemColor[1], delItemColor[2], delItemColor[3], outBoxW) then
            SETTINGS.deleteOriginal = not SETTINGS.deleteOriginal
            if SETTINGS.deleteOriginal then
                SETTINGS.muteOriginal = false
                SETTINGS.muteSelection = false; SETTINGS.deleteSelection = false
            end
        end
        setTooltip(col4X, outY, outBoxW, btnH, "Delete original items after separation")

        outY = outY + S(22)
        local delTrackColor = SETTINGS.deleteOriginalTrack and {255, 120, 120} or {160, 160, 160}
        if drawCheckbox(col4X, outY, SETTINGS.deleteOriginalTrack, "Del track", delTrackColor[1], delTrackColor[2], delTrackColor[3], outBoxW) then
            SETTINGS.deleteOriginalTrack = not SETTINGS.deleteOriginalTrack
            if SETTINGS.deleteOriginalTrack then
                SETTINGS.deleteOriginal = true; SETTINGS.muteOriginal = false
                SETTINGS.muteSelection = false; SETTINGS.deleteSelection = false
            end
        end
        setTooltip(col4X, outY, outBoxW, btnH, "Delete original tracks after separation")

        -- Selection-level options (only if time selection exists)
        local hasTimeSel = hasTimeSelection()
        if hasTimeSel then
            outY = outY + S(22)
            if drawCheckbox(col4X, outY, SETTINGS.muteSelection, "Mute sel", 160, 160, 160, outBoxW) then
                SETTINGS.muteSelection = not SETTINGS.muteSelection
                if SETTINGS.muteSelection then
                    SETTINGS.muteOriginal = false; SETTINGS.deleteOriginal = false; SETTINGS.deleteOriginalTrack = false
                    SETTINGS.deleteSelection = false
                end
            end
            setTooltip(col4X, outY, outBoxW, btnH, "Mute only the time selection part")

            outY = outY + S(22)
            local delSelColor = SETTINGS.deleteSelection and {255, 120, 120} or {160, 160, 160}
            if drawCheckbox(col4X, outY, SETTINGS.deleteSelection, "Del sel", delSelColor[1], delSelColor[2], delSelColor[3], outBoxW) then
                SETTINGS.deleteSelection = not SETTINGS.deleteSelection
                if SETTINGS.deleteSelection then
                    SETTINGS.muteOriginal = false; SETTINGS.deleteOriginal = false; SETTINGS.deleteOriginalTrack = false
                    SETTINGS.muteSelection = false
                end
            end
            setTooltip(col4X, outY, outBoxW, btnH, "Delete only the time selection part")
        end
    end


    -- Buttons
    gfx.setfont(1, "Arial", S(13))
    local btnY = gfx.h - S(32)
    local btnW = S(80)
    local btnH = S(20)
    local stemBtnW = S(70)  -- Same width as Cancel button

    -- Footer layout: 2 rows
    -- Row 1: Selected info (col1-2) + Output info (col3-4)
    -- Row 2: Target info (col1-4)
    -- Row 3: STEMperate button (col3) + Cancel button (col4)
    local footerRow1Y = btnY - S(32)
    local footerRow2Y = btnY - S(16)
    local footerRow3Y = btnY

    local selTrackCount = reaper.CountSelectedTracks(0)
    local selItemCount = reaper.CountSelectedMediaItems(0)
    local trackLabel = selTrackCount == 1 and "track" or "tracks"
    local itemLabel = selItemCount == 1 and "item" or "items"

    -- Count selected stems for output calculation
    local selectedStemCount = 0
    for _, stem in ipairs(STEMS) do
        if stem.selected and (not stem.sixStemOnly or is6Stem) then
            selectedStemCount = selectedStemCount + 1
        end
    end

    -- Calculate expected output
    local outTrackCount = SETTINGS.createNewTracks and (selTrackCount * selectedStemCount) or 0
    local outItemCount = selItemCount * selectedStemCount
    local outTrackLabel = outTrackCount == 1 and "track" or "tracks"
    local outItemLabel = outItemCount == 1 and "item" or "items"

    gfx.set(THEME.textDim[1], THEME.textDim[2], THEME.textDim[3], 1)
    gfx.setfont(1, "Arial", S(11))

    -- Row 1, Col 1: Selected label
    gfx.x = col1X
    gfx.y = footerRow1Y
    gfx.drawstr("Selected:")

    -- Row 1, Col 2: Selection values
    local selInfoText = string.format("%d %s, %d %s", selTrackCount, trackLabel, selItemCount, itemLabel)
    gfx.x = col2X
    gfx.y = footerRow1Y
    gfx.drawstr(selInfoText)

    -- Row 1, Col 3: Output label
    gfx.x = col3X
    gfx.y = footerRow1Y
    gfx.drawstr("Output:")

    -- Row 1, Col 4: Output values
    local outInfoText
    if SETTINGS.createNewTracks then
        outInfoText = string.format("%d trk, %d itm", outTrackCount, outItemCount)
    else
        outInfoText = string.format("%d takes", outItemCount)
    end
    gfx.x = col4X
    gfx.y = footerRow1Y
    gfx.drawstr(outInfoText)

    setTooltip(col1X, footerRow1Y - S(2), gfx.w - col1X - S(10), S(16), "Input selection → Expected output")

    -- Row 2: Target info
    gfx.x = col1X
    gfx.y = footerRow2Y
    gfx.drawstr("Target:")

    -- Determine target description based on output mode
    local targetText
    if SETTINGS.createNewTracks then
        if SETTINGS.createFolder then
            targetText = "New folder with stem tracks"
        else
            targetText = "New tracks below source"
        end
    else
        targetText = "In-place (as takes on source)"
    end
    gfx.x = col2X
    gfx.y = footerRow2Y
    gfx.drawstr(targetText)

    -- Row 3, Col 3: STEMperate button
    local stemBtnX = col3X
    local mx, my = gfx.mouse_x, gfx.mouse_y
    local stemBtnHover = mx >= stemBtnX and mx <= stemBtnX + stemBtnW and my >= footerRow3Y and my <= footerRow3Y + btnH
    local stemBtnColor = stemBtnHover and THEME.buttonPrimaryHover or THEME.buttonPrimary

    -- Draw button background
    gfx.set(stemBtnColor[1], stemBtnColor[2], stemBtnColor[3], 1)
    for i = 0, btnH - 1 do
        local radius = btnH / 2
        local inset = 0
        if i < radius then
            inset = radius - math.sqrt(radius * radius - (radius - i) * (radius - i))
        elseif i > btnH - radius then
            inset = radius - math.sqrt(radius * radius - (i - (btnH - radius)) * (i - (btnH - radius)))
        end
        gfx.line(stemBtnX + inset, footerRow3Y + i, stemBtnX + stemBtnW - inset, footerRow3Y + i)
    end

    -- Draw "STEMperate" with colored STEM letters
    gfx.setfont(1, "Arial", S(13), string.byte('b'))
    local textY = footerRow3Y + (btnH - gfx.texth) / 2

    -- Calculate total width to center
    local letters = {"S", "T", "E", "M", "p", "e", "r", "a", "t", "e"}
    local letterWidths = {}
    local totalWidth = 0
    for i, letter in ipairs(letters) do
        local w, _ = gfx.measurestr(letter)
        letterWidths[i] = w
        totalWidth = totalWidth + w
    end
    local textX = stemBtnX + (stemBtnW - totalWidth) / 2

    -- STEM colors (Vocals, Drums, Bass, Other)
    local stemColors = {
        {255/255, 100/255, 100/255},  -- S = Vocals (red)
        {100/255, 200/255, 255/255},  -- T = Drums (blue)
        {150/255, 100/255, 255/255},  -- E = Bass (purple)
        {100/255, 255/255, 150/255},  -- M = Other (green)
    }

    for i, letter in ipairs(letters) do
        if i <= 4 then
            -- Colored STEM letters
            gfx.set(stemColors[i][1], stemColors[i][2], stemColors[i][3], 1)
        else
            -- White "perate"
            gfx.set(1, 1, 1, 1)
        end
        gfx.x = textX
        gfx.y = textY
        gfx.drawstr(letter)
        textX = textX + letterWidths[i]
    end

    -- Rich tooltip for STEMperate button (shows output stems + target with colors)
    setRichTooltip(stemBtnX, footerRow3Y, stemBtnW, btnH)

    -- Handle STEMperate click
    if stemBtnHover and GUI.wasMouseDown and (gfx.mouse_cap & 1 == 0) then
        local anySelected = false
        for _, stem in ipairs(STEMS) do
            if stem.selected then anySelected = true; break end
        end
        if anySelected then
            saveSettings()
            GUI.result = true
        else
            showMessage("No Stems Selected", "Please select at least one stem.", "warning")
        end
    end

    -- Row 3, Col 4: Close button (red, like Start window)
    local closeBtnX = col4X
    local closeBtnW = outBoxW
    local closeBtnHover = mx >= closeBtnX and mx <= closeBtnX + closeBtnW and my >= footerRow3Y and my <= footerRow3Y + btnH

    -- Red button color
    if closeBtnHover then
        gfx.set(0.9, 0.3, 0.3, 1)
    else
        gfx.set(0.7, 0.2, 0.2, 1)
    end
    -- Draw rounded (pill-shaped) button
    for i = 0, btnH - 1 do
        local radius = btnH / 2
        local inset = 0
        if i < radius then
            inset = radius - math.sqrt(radius * radius - (radius - i) * (radius - i))
        elseif i > btnH - radius then
            inset = radius - math.sqrt(radius * radius - (i - (btnH - radius)) * (i - (btnH - radius)))
        end
        gfx.line(closeBtnX + inset, footerRow3Y + i, closeBtnX + closeBtnW - inset, footerRow3Y + i)
    end

    gfx.set(1, 1, 1, 1)
    gfx.setfont(1, "Arial", S(13), string.byte('b'))
    local closeText = "Close"
    local closeTextW = gfx.measurestr(closeText)
    gfx.x = closeBtnX + (closeBtnW - closeTextW) / 2
    gfx.y = footerRow3Y + (btnH - S(13)) / 2
    gfx.drawstr(closeText)

    -- Handle Close button click
    if closeBtnHover and GUI.wasMouseDown and (gfx.mouse_cap & 1 == 0) then
        GUI.result = false
    end
    setTooltip(closeBtnX, footerRow3Y, closeBtnW, btnH, "Close STEMperator (ESC)")

    GUI.wasMouseDown = (gfx.mouse_cap & 1 == 1)

    -- Handle keyboard
    local char = gfx.getchar()
    if char == 27 then  -- ESC
        GUI.result = false
    elseif char == 13 or char == 32 then  -- Enter or Space
        local anySelected = false
        for _, stem in ipairs(STEMS) do
            if stem.selected then anySelected = true; break end
        end
        if anySelected then
            GUI.result = true
        end
    elseif char == 49 then STEMS[1].selected = not STEMS[1].selected  -- 1: Vocals
    elseif char == 50 then STEMS[2].selected = not STEMS[2].selected  -- 2: Drums
    elseif char == 51 then STEMS[3].selected = not STEMS[3].selected  -- 3: Bass
    elseif char == 52 then STEMS[4].selected = not STEMS[4].selected  -- 4: Other
    elseif char == 53 and SETTINGS.model == "htdemucs_6s" then STEMS[5].selected = not STEMS[5].selected  -- 5: Guitar (6-stem only)
    elseif char == 54 and SETTINGS.model == "htdemucs_6s" then STEMS[6].selected = not STEMS[6].selected  -- 6: Piano (6-stem only)
    -- Preset shortcuts: first letter of preset name
    elseif char == 118 or char == 86 then applyPresetVocalsOnly()  -- V: Vocals
    elseif char == 100 or char == 68 then applyPresetDrumsOnly()  -- D: Drums
    elseif char == 98 or char == 66 then applyPresetBassOnly()  -- B: Bass
    elseif char == 111 or char == 79 then applyPresetOtherOnly()  -- O: Other
    elseif char == 112 or char == 80 then applyPresetPianoOnly()  -- P: Piano (6-stem only)
    elseif char == 103 or char == 71 then applyPresetGuitarOnly()  -- G: Guitar (6-stem only)
    elseif char == 107 or char == 75 then applyPresetKaraoke()  -- K: Karaoke
    elseif char == 105 or char == 73 then applyPresetKaraoke()  -- I: Instrumental (alias for Karaoke)
    elseif char == 97 or char == 65 then applyPresetAll()  -- A: All
    -- Model shortcuts: F=Fast, Q=Quality, S=6-stem
    elseif char == 102 or char == 70 then SETTINGS.model = "htdemucs"  -- F: Fast
    elseif char == 113 or char == 81 then SETTINGS.model = "htdemucs_ft"  -- Q: Quality
    elseif char == 115 or char == 83 then SETTINGS.model = "htdemucs_6s"  -- S: 6-stem
    elseif char == 43 or char == 61 then  -- + or = to grow window
        local newW = math.min(GUI.maxW, gfx.w + 76)
        local newH = math.min(GUI.maxH, gfx.h + 68)
        gfx.init(SCRIPT_NAME, newW, newH)
    elseif char == 45 then  -- - to shrink window
        local newW = math.max(GUI.minW, gfx.w - 76)
        local newH = math.max(GUI.minH, gfx.h - 68)
        gfx.init(SCRIPT_NAME, newW, newH)
    end

    -- flarkAUDIO logo at top (translucent) - "flark" regular, "AUDIO" bold
    gfx.setfont(1, "Arial", S(10))
    local flarkPart = "flark"
    local flarkPartW = gfx.measurestr(flarkPart)
    gfx.setfont(1, "Arial", S(10), string.byte('b'))
    local audioPart = "AUDIO"
    local audioPartW = gfx.measurestr(audioPart)
    local totalLogoW = flarkPartW + audioPartW
    local logoStartX = (gfx.w - totalLogoW) / 2
    -- Orange text, 50% translucent
    gfx.set(1.0, 0.5, 0.1, 0.5)
    gfx.setfont(1, "Arial", S(10))
    gfx.x = logoStartX
    gfx.y = S(3)
    gfx.drawstr(flarkPart)
    gfx.setfont(1, "Arial", S(10), string.byte('b'))
    gfx.x = logoStartX + flarkPartW
    gfx.y = S(3)
    gfx.drawstr(audioPart)

    -- Draw tooltip on top of everything
    drawTooltip()

    gfx.update()

    if GUI.result == nil and char ~= -1 then
        reaper.defer(dialogLoop)
    else
        -- Save dialog position before closing for progress window positioning
        if reaper.JS_Window_GetRect then
            local hwnd = reaper.JS_Window_Find(SCRIPT_NAME, true)
            if hwnd then
                local retval, left, top, right, bottom = reaper.JS_Window_GetRect(hwnd)
                if retval then
                    lastDialogX = left
                    lastDialogY = top
                    lastDialogW = right - left
                    lastDialogH = bottom - top
                end
            end
        end
        -- Fallback: keep existing lastDialogX/Y, just update size
        if not lastDialogX then
            -- Use initial position that was set in showStemSelectionDialog
            lastDialogW = gfx.w
            lastDialogH = gfx.h
        end
        -- Always save settings (including position) when dialog closes
        saveSettings()
        gfx.quit()
        if GUI.result == "help" then
            -- Show help window, then return to main dialog
            local helpText = [[STEMperator - AI Stem Separation for REAPER

BASIC WORKFLOW:
1. Select one or more tracks with audio items
2. Optionally make a time selection to process only that part
3. Choose which stems you want (or use a preset)
4. Select a model (Fast, Quality, or 6-Stem)
5. Click STEMperate to start separation

KEYBOARD SHORTCUTS:
1-4: Toggle Vocals/Drums/Bass/Other stems
5-6: Toggle Guitar/Piano (6-stem model only)
K: Karaoke preset (instrumental)
V: Vocals only    D: Drums only
B: Bass only      O: Other only
A: All stems
Enter: Start separation
Escape: Cancel

MODELS:
- Fast: Quick processing, good quality (4 stems)
- Quality: Best results, slower (4 stems)
- 6-Stem: Adds Guitar and Piano separation

OUTPUT OPTIONS:
- New tracks: Creates separate tracks for each stem
- In-place: Replaces original with stems as takes
- Folder: Groups stem tracks in a folder
- Mute/Delete: Handle original after separation

TIPS:
- Use Parallel mode for 12GB+ VRAM GPUs
- Use Sequential mode for 4-8GB VRAM GPUs
- Time selection lets you process just a section
- Undo (Ctrl+Z) to restore if needed]]
            showMessage("STEMperator Help", helpText, "info")
        elseif GUI.result then
            reaper.defer(runSeparationWorkflow)
        else
            -- User cancelled: restore original selection state if items were auto-selected
            if #autoSelectedItems > 0 then
                for _, item in ipairs(autoSelectedItems) do
                    if reaper.ValidatePtr(item, "MediaItem*") then
                        reaper.SetMediaItemSelected(item, false)
                    end
                end
                autoSelectedItems = {}
            end
            -- Also deselect the tracks that triggered auto-selection
            if #autoSelectionTracks > 0 then
                for _, track in ipairs(autoSelectionTracks) do
                    if reaper.ValidatePtr(track, "MediaTrack*") then
                        reaper.SetTrackSelected(track, false)
                    end
                end
                autoSelectionTracks = {}
            end
            reaper.UpdateArrange()
        end
    end
end

-- Show stem selection dialog
local function showStemSelectionDialog()
    loadSettings()
    GUI.result = nil
    GUI.wasMouseDown = false

    -- Use saved size if available, otherwise use default
    local dialogW = GUI.savedW or GUI.baseW
    local dialogH = GUI.savedH or GUI.baseH
    -- Clamp to min/max
    dialogW = math.max(GUI.minW, math.min(GUI.maxW, dialogW))
    dialogH = math.max(GUI.minH, math.min(GUI.maxH, dialogH))

    local posX, posY

    -- Use saved position if available, otherwise center on mouse
    if GUI.savedX and GUI.savedY then
        -- Use exact saved position (user placed it there intentionally)
        posX = GUI.savedX
        posY = GUI.savedY
    else
        -- No saved position - center on mouse and clamp to screen
        local mouseX, mouseY = reaper.GetMousePosition()
        posX = mouseX - dialogW / 2
        posY = mouseY - dialogH / 2
        posX, posY = clampToScreen(posX, posY, dialogW, dialogH, mouseX, mouseY)
    end

    -- Save initial position for progress window
    lastDialogX = posX
    lastDialogY = posY
    lastDialogW = dialogW
    lastDialogH = dialogH

    gfx.init(SCRIPT_NAME, dialogW, dialogH, 0, posX, posY)

    -- Make window resizable (requires js_ReaScriptAPI extension)
    makeWindowResizable()

    gfx.setfont(1, "Arial", S(13))
    dialogLoop()
end

-- Get temp directory (cross-platform)
local function getTempDir()
    if OS == "Windows" then
        return os.getenv("TEMP") or os.getenv("TMP") or "C:\\Temp"
    else
        return os.getenv("TMPDIR") or "/tmp"
    end
end

-- Create directory (cross-platform)
local function makeDir(path)
    if OS == "Windows" then
        os.execute('mkdir "' .. path .. '" 2>nul')
    else
        os.execute('mkdir -p "' .. path .. '"')
    end
end

-- Suppress stderr (cross-platform)
local function suppressStderr()
    return OS == "Windows" and " 2>nul" or " 2>/dev/null"
end

-- Execute command without showing a window (Windows-specific)
-- On Windows, os.execute() shows a brief CMD flash. This avoids that.
local function execHidden(cmd)
    debugLog("execHidden called")
    debugLog("  Command: " .. cmd:sub(1, 200) .. (cmd:len() > 200 and "..." or ""))
    if OS == "Windows" then
        -- Use a temporary VBS file to run the command hidden
        local tempDir = os.getenv("TEMP") or os.getenv("TMP") or "."
        local vbsPath = tempDir .. "\\stemperator_exec_" .. os.time() .. ".vbs"
        debugLog("  VBS path: " .. vbsPath)
        local vbsFile = io.open(vbsPath, "w")
        if vbsFile then
            -- Window style 0 = hidden, True = wait for completion
            local vbsContent = 'CreateObject("WScript.Shell").Run "cmd /c ' .. cmd:gsub('"', '""') .. '", 0, True\n'
            vbsFile:write(vbsContent)
            vbsFile:close()
            debugLog("  VBS file created")

            if reaper.ExecProcess then
                debugLog("  Using reaper.ExecProcess")
                reaper.ExecProcess('wscript "' .. vbsPath .. '"', 0)  -- 0 = wait for completion
            else
                debugLog("  Using os.execute")
                os.execute('wscript "' .. vbsPath .. '"')
            end
            debugLog("  Command completed")

            -- Clean up VBS file
            os.remove(vbsPath)
            debugLog("  VBS file cleaned up")
        else
            -- Fallback to os.execute if VBS creation fails
            debugLog("  VBS creation failed, falling back to os.execute")
            os.execute(cmd)
        end
    else
        debugLog("  Non-Windows, using os.execute")
        os.execute(cmd)
    end
    debugLog("execHidden done")
end

-- Render selected item to a temporary WAV file
-- If time selection exists and overlaps item, only render that portion
local function renderItemToWav(item, outputPath)
    local take = reaper.GetActiveTake(item)
    if not take then return nil, "No active take" end

    local source = reaper.GetMediaItemTake_Source(take)
    if not source then return nil, "No source" end

    local sourceFile = reaper.GetMediaSourceFileName(source, "")
    if not sourceFile or sourceFile == "" then return nil, "No source file" end

    local itemPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local itemLen = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local itemEnd = itemPos + itemLen
    local takeOffset = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
    local playrate = reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")

    -- Check for time selection that overlaps the item
    local timeSelStart, timeSelEnd = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
    local hasTimeSel = timeSelEnd > timeSelStart

    local renderStart = itemPos
    local renderEnd = itemEnd

    if hasTimeSel then
        -- Clamp time selection to item bounds
        if timeSelStart > itemPos and timeSelStart < itemEnd then
            renderStart = timeSelStart
        end
        if timeSelEnd > itemPos and timeSelEnd < itemEnd then
            renderEnd = timeSelEnd
        end
        -- Only use time selection if it actually overlaps
        if timeSelStart >= itemEnd or timeSelEnd <= itemPos then
            -- No overlap, render whole item
            renderStart = itemPos
            renderEnd = itemEnd
        end
    end

    -- Calculate source file offset and duration
    local renderOffset = takeOffset + (renderStart - itemPos) * playrate
    local renderDuration = (renderEnd - renderStart) * playrate

    local ffmpegCmd = string.format(
        'ffmpeg -y -i "%s" -ss %.6f -t %.6f -ar 44100 -ac 2 "%s"' .. suppressStderr(),
        sourceFile, renderOffset, renderDuration, outputPath
    )

    execHidden(ffmpegCmd)

    local f = io.open(outputPath, "r")
    if f then f:close(); return outputPath, nil, renderStart, renderEnd - renderStart
    else return nil, "Failed to extract audio" end
end

-- Render time selection to a temporary WAV file
local function renderTimeSelectionToWav(outputPath)
    local startTime, endTime = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
    if startTime >= endTime then return nil, "No time selection" end

    -- Find all selected items overlapping the time selection
    local numTracks = reaper.CountTracks(0)
    if numTracks == 0 then return nil, "No tracks in project" end

    local selectedItems = {}
    local foundItem = nil  -- First found item for return value

    for t = 0, numTracks - 1 do
        local track = reaper.GetTrack(0, t)
        local numItems = reaper.CountTrackMediaItems(track)
        for i = 0, numItems - 1 do
            local item = reaper.GetTrackMediaItem(track, i)
            local iPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
            local iLen = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
            local iEnd = iPos + iLen
            -- Check if item overlaps time selection AND is selected
            if iPos < endTime and iEnd > startTime then
                if reaper.IsMediaItemSelected(item) then
                    table.insert(selectedItems, {item = item, track = track})
                    if not foundItem then foundItem = item end
                end
            end
        end
    end

    -- If no items selected but tracks are selected and In-place mode is on,
    -- find items on those tracks that overlap the time selection
    if #selectedItems == 0 then
        local selTrackCount = reaper.CountSelectedTracks(0)
        local selItemCount = reaper.CountSelectedMediaItems(0)

        -- In-place mode with track selected: auto-find overlapping items on selected tracks
        if selTrackCount > 0 and selItemCount == 0 and not SETTINGS.createNewTracks then
            debugLog("In-place mode: finding items on selected tracks overlapping time selection")
            for t = 0, selTrackCount - 1 do
                local track = reaper.GetSelectedTrack(0, t)
                local numItems = reaper.CountTrackMediaItems(track)
                for i = 0, numItems - 1 do
                    local item = reaper.GetTrackMediaItem(track, i)
                    local iPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
                    local iLen = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
                    local iEnd = iPos + iLen
                    -- Check if item overlaps time selection
                    if iPos < endTime and iEnd > startTime then
                        table.insert(selectedItems, {item = item, track = track})
                        if not foundItem then foundItem = item end
                        debugLog("Found overlapping item on selected track at pos " .. iPos)
                    end
                end
            end
        end

        -- Still no items found - show appropriate error
        if #selectedItems == 0 then
            if selTrackCount == 0 and selItemCount == 0 then
                return nil, "No tracks or items selected"
            elseif selTrackCount == 0 then
                return nil, "No tracks selected (select tracks with items)"
            elseif selItemCount == 0 and not SETTINGS.createNewTracks then
                return nil, "No items on selected tracks overlap time selection"
            elseif selItemCount == 0 then
                return nil, "No items selected on tracks"
            else
                return nil, "No selected items overlap the time selection"
            end
        end
    end

    -- If only one item, use simple ffmpeg extraction (faster)
    if #selectedItems == 1 then
        local take = reaper.GetActiveTake(selectedItems[1].item)
        if not take then return nil, "No active take" end

        local source = reaper.GetMediaItemTake_Source(take)
        if not source then return nil, "No source" end

        local sourceFile = reaper.GetMediaSourceFileName(source, "")
        if not sourceFile or sourceFile == "" then return nil, "No source file" end

        local itemPos = reaper.GetMediaItemInfo_Value(selectedItems[1].item, "D_POSITION")
        local takeOffset = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
        local playrate = reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")

        local selStartInItem = math.max(0, startTime - itemPos)
        local selEndInItem = math.min(endTime - itemPos, reaper.GetMediaItemInfo_Value(selectedItems[1].item, "D_LENGTH"))
        local duration = (selEndInItem - selStartInItem) * playrate
        local sourceOffset = takeOffset + (selStartInItem * playrate)

        local ffmpegCmd = string.format(
            'ffmpeg -y -i "%s" -ss %.6f -t %.6f -ar 44100 -ac 2 "%s"' .. suppressStderr(),
            sourceFile, sourceOffset, duration, outputPath
        )

        execHidden(ffmpegCmd)

        local f = io.open(outputPath, "r")
        if f then f:close(); return outputPath, nil, foundItem
        else return nil, "Failed to extract audio from time selection", nil end
    end

    -- Multiple items selected - group by track
    local trackItems = {}  -- track -> list of items
    for _, itemData in ipairs(selectedItems) do
        if not trackItems[itemData.track] then
            trackItems[itemData.track] = {}
        end
        table.insert(trackItems[itemData.track], itemData.item)
    end

    -- Count tracks
    local trackCount = 0
    local trackList = {}
    for track in pairs(trackItems) do
        trackCount = trackCount + 1
        table.insert(trackList, track)
    end

    if trackCount > 1 then
        -- Multiple tracks - return special marker to indicate multi-track mode
        return nil, "MULTI_TRACK", nil, trackList, trackItems
    end

    -- All items are on the same track - use the first one
    local take = reaper.GetActiveTake(foundItem)
    if not take then return nil, "No active take" end

    local source = reaper.GetMediaItemTake_Source(take)
    if not source then return nil, "No source" end

    local sourceFile = reaper.GetMediaSourceFileName(source, "")
    if not sourceFile or sourceFile == "" then return nil, "No source file" end

    local itemPos = reaper.GetMediaItemInfo_Value(foundItem, "D_POSITION")
    local takeOffset = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
    local playrate = reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")

    local selStartInItem = math.max(0, startTime - itemPos)
    local selEndInItem = math.min(endTime - itemPos, reaper.GetMediaItemInfo_Value(foundItem, "D_LENGTH"))
    local duration = (selEndInItem - selStartInItem) * playrate
    local sourceOffset = takeOffset + (selStartInItem * playrate)

    local ffmpegCmd = string.format(
        'ffmpeg -y -i "%s" -ss %.6f -t %.6f -ar 44100 -ac 2 "%s"' .. suppressStderr(),
        sourceFile, sourceOffset, duration, outputPath
    )

    execHidden(ffmpegCmd)

    local f = io.open(outputPath, "r")
    if f then f:close(); return outputPath, nil, foundItem
    else return nil, "Failed to extract audio from time selection", nil end
end

-- Extract audio for a specific track within time selection
local function renderTrackTimeSelectionToWav(track, outputPath)
    local startTime, endTime = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
    if startTime >= endTime then return nil, "No time selection" end

    -- Find ALL selected items on this track overlapping time selection
    local numItems = reaper.CountTrackMediaItems(track)
    local foundItem = nil
    local allFoundItems = {}

    for i = 0, numItems - 1 do
        local item = reaper.GetTrackMediaItem(track, i)
        local iPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local iLen = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        local iEnd = iPos + iLen
        if iPos < endTime and iEnd > startTime and reaper.IsMediaItemSelected(item) then
            if not foundItem then
                foundItem = item  -- Keep first for audio extraction
            end
            table.insert(allFoundItems, item)  -- Collect all for mute/delete
        end
    end

    if not foundItem then return nil, "No selected items on track" end

    local take = reaper.GetActiveTake(foundItem)
    if not take then return nil, "No active take" end

    local source = reaper.GetMediaItemTake_Source(take)
    if not source then return nil, "No source" end

    local sourceFile = reaper.GetMediaSourceFileName(source, "")
    if not sourceFile or sourceFile == "" then return nil, "No source file" end

    local itemPos = reaper.GetMediaItemInfo_Value(foundItem, "D_POSITION")
    local takeOffset = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
    local playrate = reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")

    local selStartInItem = math.max(0, startTime - itemPos)
    local selEndInItem = math.min(endTime - itemPos, reaper.GetMediaItemInfo_Value(foundItem, "D_LENGTH"))
    local duration = (selEndInItem - selStartInItem) * playrate
    local sourceOffset = takeOffset + (selStartInItem * playrate)

    local ffmpegCmd = string.format(
        'ffmpeg -y -i "%s" -ss %.6f -t %.6f -ar 44100 -ac 2 "%s"' .. suppressStderr(),
        sourceFile, sourceOffset, duration, outputPath
    )

    execHidden(ffmpegCmd)

    local f = io.open(outputPath, "r")
    if f then f:close(); return outputPath, nil, foundItem, allFoundItems
    else return nil, "Failed to extract audio", nil, nil end
end

-- Render selected items on a track to WAV (no time selection needed)
-- Used when items are selected but no time selection exists
local function renderTrackSelectedItemsToWav(track, outputPath)
    -- Find ALL selected items on this track
    local numItems = reaper.CountTrackMediaItems(track)
    local foundItem = nil
    local allFoundItems = {}
    local minPos = math.huge
    local maxEnd = 0

    for i = 0, numItems - 1 do
        local item = reaper.GetTrackMediaItem(track, i)
        if reaper.IsMediaItemSelected(item) then
            local iPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
            local iLen = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
            local iEnd = iPos + iLen
            if not foundItem then
                foundItem = item  -- Keep first for audio extraction
            end
            table.insert(allFoundItems, item)
            minPos = math.min(minPos, iPos)
            maxEnd = math.max(maxEnd, iEnd)
        end
    end

    if not foundItem then return nil, "No selected items on track" end

    local take = reaper.GetActiveTake(foundItem)
    if not take then return nil, "No active take" end

    local source = reaper.GetMediaItemTake_Source(take)
    if not source then return nil, "No source" end

    local sourceFile = reaper.GetMediaSourceFileName(source, "")
    if not sourceFile or sourceFile == "" then return nil, "No source file" end

    local itemPos = reaper.GetMediaItemInfo_Value(foundItem, "D_POSITION")
    local itemLen = reaper.GetMediaItemInfo_Value(foundItem, "D_LENGTH")
    local takeOffset = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
    local playrate = reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")

    -- Extract the full item (not a sub-selection)
    local duration = itemLen * playrate
    local sourceOffset = takeOffset

    local ffmpegCmd = string.format(
        'ffmpeg -y -i "%s" -ss %.6f -t %.6f -ar 44100 -ac 2 "%s"' .. suppressStderr(),
        sourceFile, sourceOffset, duration, outputPath
    )

    execHidden(ffmpegCmd)

    local f = io.open(outputPath, "r")
    if f then f:close(); return outputPath, nil, foundItem, allFoundItems
    else return nil, "Failed to extract audio", nil, nil end
end

-- Render a single item to WAV (for in-place multi-item processing)
local function renderSingleItemToWav(item, outputPath)
    if not item or not reaper.ValidatePtr(item, "MediaItem*") then
        return nil, "Invalid item"
    end

    local take = reaper.GetActiveTake(item)
    if not take then return nil, "No active take" end

    local source = reaper.GetMediaItemTake_Source(take)
    if not source then return nil, "No source" end

    local sourceFile = reaper.GetMediaSourceFileName(source, "")
    if not sourceFile or sourceFile == "" then return nil, "No source file" end

    local itemPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local itemLen = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local takeOffset = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
    local playrate = reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")

    local duration = itemLen * playrate
    local sourceOffset = takeOffset

    local ffmpegCmd = string.format(
        'ffmpeg -y -i "%s" -ss %.6f -t %.6f -ar 44100 -ac 2 "%s"' .. suppressStderr(),
        sourceFile, sourceOffset, duration, outputPath
    )

    execHidden(ffmpegCmd)

    local f = io.open(outputPath, "r")
    if f then f:close(); return outputPath, nil
    else return nil, "Failed to extract audio" end
end

-- Progress window state
local progressState = {
    running = false,
    outputDir = nil,
    stdoutFile = nil,
    logFile = nil,
    percent = 0,
    stage = "Starting...",
    startTime = 0,
}

-- Multi-track queue state (declared early for access in drawProgressWindow)
local multiTrackQueue = {
    tracks = {},           -- List of tracks to process
    currentIndex = 0,      -- Current track being processed
    totalTracks = 0,       -- Total number of tracks
    active = false,        -- Is multi-track mode active
    currentTrackName = "", -- Name of current track being processed
    currentSourceTrack = nil, -- Track to place stems under
}

-- Forward declarations for multi-track processing
local runSingleTrackSeparation
local startSeparationProcessForJob
local updateAllJobsProgress
local allJobsDone
local getOverallProgress
local showMultiTrackProgressWindow
local processAllStemsResult

-- Progress window base dimensions for scaling
local PROGRESS_BASE_W = 480
local PROGRESS_BASE_H = 210

-- Progress window resizable flag
local progressWindowResizableSet = false

-- Make progress window resizable
local function makeProgressWindowResizable()
    if progressWindowResizableSet then return true end
    if not reaper.JS_Window_Find then return false end

    local hwnd = reaper.JS_Window_Find("Stemperator - Processing...", true)
    if not hwnd then return false end

    local style = reaper.JS_Window_GetLong(hwnd, "STYLE")
    if style then
        local WS_THICKFRAME = 0x00040000
        local WS_MAXIMIZEBOX = 0x00010000
        reaper.JS_Window_SetLong(hwnd, "STYLE", style | WS_THICKFRAME | WS_MAXIMIZEBOX)
    end

    progressWindowResizableSet = true
    return true
end

-- Animated waveform data for eye candy
local waveformState = {
    bars = {},
    particles = {},
    lastUpdate = 0,
    pulsePhase = 0,
}

-- Initialize waveform bars
local function initWaveformBars(count)
    waveformState.bars = {}
    for i = 1, count do
        waveformState.bars[i] = {
            height = math.random() * 0.5 + 0.2,
            targetHeight = math.random() * 0.8 + 0.2,
            velocity = 0,
            phase = math.random() * math.pi * 2,
        }
    end
end

-- Draw progress window with stem colors and eye candy (scalable)
local function drawProgressWindow()
    local w, h = gfx.w, gfx.h

    -- Calculate scale based on window size
    local scaleW = w / PROGRESS_BASE_W
    local scaleH = h / PROGRESS_BASE_H
    local scale = math.min(scaleW, scaleH)
    scale = math.max(0.5, math.min(4.0, scale))  -- Clamp scale

    -- Scaling helper
    local function PS(val) return math.floor(val * scale + 0.5) end

    -- Try to make window resizable
    makeProgressWindowResizable()

    -- Solid background (matching main app)
    gfx.set(THEME.bg[1], THEME.bg[2], THEME.bg[3], 1)
    gfx.rect(0, 0, w, h, 1)

    -- Colored STEM border at top
    drawStemBorder(0, 0, w, 3)

    -- Get selected stems for colors
    local selectedStems = {}
    for _, stem in ipairs(STEMS) do
        if stem.selected and (not stem.sixStemOnly or SETTINGS.model == "htdemucs_6s") then
            table.insert(selectedStems, stem)
        end
    end

    -- Model badge (top right)
    local modelText = SETTINGS.model or "htdemucs"
    gfx.setfont(1, "Arial", PS(11))
    local modelW = gfx.measurestr(modelText) + PS(16)
    local badgeX = w - modelW - PS(20)
    local badgeY = PS(18)
    gfx.set(THEME.inputBg[1], THEME.inputBg[2], THEME.inputBg[3], 1)
    gfx.rect(badgeX, badgeY, modelW, PS(22), 1)
    gfx.set(THEME.border[1], THEME.border[2], THEME.border[3], 1)
    gfx.rect(badgeX, badgeY, modelW, PS(22), 0)
    gfx.set(THEME.accent[1], THEME.accent[2], THEME.accent[3], 1)
    gfx.x = badgeX + PS(8)
    gfx.y = PS(22)
    gfx.drawstr(modelText)

    -- Title
    gfx.setfont(1, "Arial", PS(18), string.byte('b'))
    local title = "AI Stem Separation"
    -- In multi-track mode, show which track
    if multiTrackQueue.active then
        title = "Track " .. multiTrackQueue.currentIndex .. "/" .. multiTrackQueue.totalTracks .. ": " .. (multiTrackQueue.currentTrackName or "")
    end
    gfx.set(THEME.text[1], THEME.text[2], THEME.text[3], 1)
    gfx.x = PS(25)
    gfx.y = PS(20)
    gfx.drawstr(title)

    -- Stem indicators (simple colored boxes)
    local stemX = PS(25)
    local stemY = PS(55)
    local stemBoxSize = PS(14)
    gfx.setfont(1, "Arial", PS(11))
    for _, stem in ipairs(STEMS) do
        if stem.selected and (not stem.sixStemOnly or SETTINGS.model == "htdemucs_6s") then
            -- Stem color box
            gfx.set(stem.color[1]/255, stem.color[2]/255, stem.color[3]/255, 1)
            gfx.rect(stemX, stemY, stemBoxSize, stemBoxSize, 1)
            -- Stem name
            gfx.set(THEME.textDim[1], THEME.textDim[2], THEME.textDim[3], 1)
            gfx.x = stemX + stemBoxSize + PS(6)
            gfx.y = stemY + PS(1)
            gfx.drawstr(stem.name)
            stemX = stemX + stemBoxSize + gfx.measurestr(stem.name) + PS(20)
        end
    end

    -- Progress bar
    local barX = PS(25)
    local barY = PS(90)
    local barW = w - PS(50)
    local barH = PS(28)

    -- Progress bar background
    gfx.set(THEME.inputBg[1], THEME.inputBg[2], THEME.inputBg[3], 1)
    gfx.rect(barX, barY, barW, barH, 1)
    gfx.set(THEME.border[1], THEME.border[2], THEME.border[3], 1)
    gfx.rect(barX, barY, barW, barH, 0)

    -- Progress bar fill with stem color gradient
    local fillWidth = math.floor(barW * progressState.percent / 100)
    if fillWidth > 0 and #selectedStems > 0 then
        for x = 0, fillWidth - 1 do
            local pos = x / math.max(1, fillWidth - 1)
            local idx = math.floor(pos * (#selectedStems - 1)) + 1
            local nextIdx = math.min(idx + 1, #selectedStems)
            local blend = (pos * (#selectedStems - 1)) % 1

            idx = math.max(1, math.min(idx, #selectedStems))
            nextIdx = math.max(1, math.min(nextIdx, #selectedStems))

            local r = (selectedStems[idx].color[1] * (1 - blend) + selectedStems[nextIdx].color[1] * blend) / 255
            local g = (selectedStems[idx].color[2] * (1 - blend) + selectedStems[nextIdx].color[2] * blend) / 255
            local b = (selectedStems[idx].color[3] * (1 - blend) + selectedStems[nextIdx].color[3] * blend) / 255

            gfx.set(r, g, b, 1)
            gfx.rect(barX + x, barY + 1, 1, barH - 2, 1)
        end
    end

    -- Progress percentage in center of bar
    gfx.setfont(1, "Arial", PS(14), string.byte('b'))
    local percentText = string.format("%d%%", progressState.percent)
    local tw = gfx.measurestr(percentText)
    gfx.set(1, 1, 1, 1)
    gfx.x = barX + (barW - tw) / 2
    gfx.y = barY + (barH - PS(14)) / 2
    gfx.drawstr(percentText)

    -- Stage text
    gfx.setfont(1, "Arial", PS(11))
    gfx.set(THEME.textDim[1], THEME.textDim[2], THEME.textDim[3], 1)
    gfx.x = PS(25)
    gfx.y = PS(130)
    local stageDisplay = progressState.stage or "Starting..."
    local maxStageLen = math.floor(70 * scale)
    if #stageDisplay > maxStageLen then stageDisplay = stageDisplay:sub(1, maxStageLen - 3) .. "..." end
    gfx.drawstr(stageDisplay)

    -- Info boxes row
    local infoY = PS(155)
    local infoH = PS(22)
    local infoGap = PS(8)

    -- Time info box
    local elapsed = os.time() - progressState.startTime
    local mins = math.floor(elapsed / 60)
    local secs = elapsed % 60

    gfx.set(THEME.inputBg[1], THEME.inputBg[2], THEME.inputBg[3], 1)
    gfx.rect(PS(25), infoY, PS(95), infoH, 1)
    gfx.set(THEME.border[1], THEME.border[2], THEME.border[3], 1)
    gfx.rect(PS(25), infoY, PS(95), infoH, 0)
    gfx.set(THEME.text[1], THEME.text[2], THEME.text[3], 1)
    gfx.x = PS(32)
    gfx.y = infoY + PS(4)
    gfx.drawstr(string.format("Elapsed: %d:%02d", mins, secs))

    -- ETA box (if available)
    local eta = progressState.stage:match("ETA ([%d:]+)")
    if eta then
        gfx.set(THEME.inputBg[1], THEME.inputBg[2], THEME.inputBg[3], 1)
        gfx.rect(PS(128), infoY, PS(75), infoH, 1)
        gfx.set(THEME.border[1], THEME.border[2], THEME.border[3], 1)
        gfx.rect(PS(128), infoY, PS(75), infoH, 0)
        gfx.set(0.3, 0.75, 0.45, 1)
        gfx.x = PS(135)
        gfx.y = infoY + PS(4)
        gfx.drawstr("ETA: " .. eta)
    end

    -- Segment size indicator
    gfx.set(THEME.inputBg[1], THEME.inputBg[2], THEME.inputBg[3], 1)
    gfx.rect(w - PS(190), infoY, PS(60), infoH, 1)
    gfx.set(THEME.border[1], THEME.border[2], THEME.border[3], 1)
    gfx.rect(w - PS(190), infoY, PS(60), infoH, 0)
    gfx.set(THEME.textDim[1], THEME.textDim[2], THEME.textDim[3], 1)
    gfx.x = w - PS(183)
    gfx.y = infoY + PS(4)
    gfx.drawstr("Seg: 30")

    -- GPU indicator
    gfx.set(THEME.inputBg[1], THEME.inputBg[2], THEME.inputBg[3], 1)
    gfx.rect(w - PS(122), infoY, PS(97), infoH, 1)
    gfx.set(THEME.border[1], THEME.border[2], THEME.border[3], 1)
    gfx.rect(w - PS(122), infoY, PS(97), infoH, 0)
    gfx.set(0.3, 0.75, 0.45, 1)
    gfx.x = w - PS(115)
    gfx.y = infoY + PS(4)
    gfx.drawstr("GPU: DirectML")

    -- Cancel hint
    gfx.set(THEME.textHint[1], THEME.textHint[2], THEME.textHint[3], 1)
    gfx.setfont(1, "Arial", PS(9))
    local hintText = "Press ESC or close window to cancel"
    local hintW = gfx.measurestr(hintText)
    gfx.x = (w - hintW) / 2
    gfx.y = h - PS(32)
    gfx.drawstr(hintText)

    -- flarkAUDIO logo at top (translucent) - "flark" regular, "AUDIO" bold
    gfx.setfont(1, "Arial", PS(10))
    local flarkPart = "flark"
    local flarkPartW = gfx.measurestr(flarkPart)
    gfx.setfont(1, "Arial", PS(10), string.byte('b'))
    local audioPart = "AUDIO"
    local audioPartW = gfx.measurestr(audioPart)
    local totalLogoW = flarkPartW + audioPartW
    local logoStartX = (w - totalLogoW) / 2
    -- Orange text, 50% translucent
    gfx.set(1.0, 0.5, 0.1, 0.5)
    gfx.setfont(1, "Arial", PS(10))
    gfx.x = logoStartX
    gfx.y = PS(3)
    gfx.drawstr(flarkPart)
    gfx.setfont(1, "Arial", PS(10), string.byte('b'))
    gfx.x = logoStartX + flarkPartW
    gfx.y = PS(3)
    gfx.drawstr(audioPart)

    gfx.update()
end

-- Read latest progress from stdout file
local function updateProgressFromFile()
    local f = io.open(progressState.stdoutFile, "r")
    if not f then return end

    local lastProgress = nil
    for line in f:lines() do
        local percent, stage = line:match("PROGRESS:(%d+):(.+)")
        if percent then
            lastProgress = { percent = tonumber(percent), stage = stage }
        end
    end
    f:close()

    if lastProgress then
        progressState.percent = lastProgress.percent
        progressState.stage = lastProgress.stage
    end
end

-- Check if separation process is done (check for done.txt marker file)
local function checkSeparationDone()
    -- Check for done marker file
    local doneFile = io.open(progressState.outputDir .. PATH_SEP .. "done.txt", "r")
    if doneFile then
        doneFile:close()
        return true
    end
    -- Also check if progress hit 100%
    return progressState.percent >= 100
end

-- Background process handle
local bgProcess = nil

-- Start separation process in background (Windows)
local function startSeparationProcess(inputFile, outputDir, model)
    local logFile = outputDir .. PATH_SEP .. "separation_log.txt"
    local stdoutFile = outputDir .. PATH_SEP .. "stdout.txt"
    local doneFile = outputDir .. PATH_SEP .. "done.txt"

    -- Store for progress tracking
    progressState.outputDir = outputDir
    progressState.stdoutFile = stdoutFile
    progressState.logFile = logFile
    progressState.percent = 0
    progressState.stage = "Starting..."
    progressState.startTime = os.time()

    if OS == "Windows" then
        -- Create batch file to run Python with output redirection
        -- Single-track mode uses larger segment size (40) for better GPU utilization
        local batPath = outputDir .. PATH_SEP .. "run_separation.bat"
        local batFile = io.open(batPath, "w")
        if batFile then
            batFile:write('@echo off\n')
            batFile:write('"' .. PYTHON_PATH .. '" -u "' .. SEPARATOR_SCRIPT .. '" ')
            batFile:write('"' .. inputFile .. '" "' .. outputDir .. '" --model ' .. model .. ' --segment-size 30 ')
            batFile:write('>"' .. stdoutFile .. '" 2>"' .. logFile .. '"\n')
            batFile:write('echo DONE >"' .. doneFile .. '"\n')
            batFile:close()
        end

        -- Create VBS to run batch file hidden (window style 0)
        local vbsPath = outputDir .. PATH_SEP .. "run_hidden.vbs"
        local vbsFile = io.open(vbsPath, "w")
        if vbsFile then
            vbsFile:write('CreateObject("WScript.Shell").Run """' .. batPath .. '""", 0, False\n')
            vbsFile:close()
        end

        -- Try reaper.ExecProcess first (no CMD window), fallback to os.execute
        if reaper.ExecProcess then
            reaper.ExecProcess('wscript "' .. vbsPath .. '"', -1)
        else
            -- Use io.popen instead of os.execute to avoid CMD flash
            local handle = io.popen('wscript "' .. vbsPath .. '"')
            if handle then handle:close() end
        end
    else
        -- Unix: run in background
        -- Single-track mode uses larger segment size (40) for better GPU utilization
        local cmd = string.format(
            '"%s" -u "%s" "%s" "%s" --model %s --segment-size 30 >"%s" 2>"%s" && echo DONE > "%s/done.txt" &',
            PYTHON_PATH, SEPARATOR_SCRIPT, inputFile, outputDir, model, stdoutFile, logFile, outputDir
        )
        os.execute(cmd)
    end
end

-- Progress loop with UI
local function progressLoop()
    updateProgressFromFile()
    drawProgressWindow()

    local char = gfx.getchar()
    if char == -1 or char == 27 then  -- Window closed or ESC pressed
        -- Window closed by user
        progressState.running = false
        gfx.quit()
        showMessage("Cancelled", "Separation cancelled.", "info")
        return
    end

    if checkSeparationDone() then
        -- Done!
        progressState.running = false
        gfx.quit()
        finishSeparation()
        return
    end

    -- Check timeout (10 minutes max)
    if os.time() - progressState.startTime > 600 then
        progressState.running = false
        gfx.quit()
        showMessage("Timeout", "Separation timed out after 10 minutes.", "error")
        return
    end

    reaper.defer(progressLoop)
end

-- Finish separation after progress completes
local function finishSeparationCallback()
    -- Small delay to ensure files are written
    local checkCount = 0
    local function checkFiles()
        checkCount = checkCount + 1
        local stems = {}
        for _, stem in ipairs(STEMS) do
            if stem.selected then
                local stemPath = progressState.outputDir .. PATH_SEP .. stem.file
                local f = io.open(stemPath, "r")
                if f then f:close(); stems[stem.name:lower()] = stemPath end
            end
        end

        if next(stems) then
            -- Success - process stems
            processStemsResult(stems)
        elseif checkCount < 10 then
            -- Retry
            reaper.defer(checkFiles)
        else
            -- Failed
            local errLog = io.open(progressState.logFile, "r")
            local errMsg = "No stems created"
            if errLog then
                local content = errLog:read("*a")
                errLog:close()
                if content and content ~= "" then
                    errMsg = errMsg .. "\n\nLog:\n" .. content:sub(1, 500)
                end
            end
            showMessage("Separation Failed", errMsg, "error")
        end
    end
    checkFiles()
end

-- Store callback reference
finishSeparation = finishSeparationCallback

-- Run AI separation with progress UI
local function runSeparationWithProgress(inputFile, outputDir, model)
    -- Load settings to get current theme
    loadSettings()
    updateTheme()

    -- Start the process
    startSeparationProcess(inputFile, outputDir, model)

    -- Use same size as main dialog (scaled proportionally for progress content)
    local winW = lastDialogW or 380
    local winH = lastDialogH or 340
    local winX, winY

    -- Use last dialog position if available, otherwise use mouse position
    local refX, refY  -- reference point for screen detection
    if lastDialogX and lastDialogY then
        winX = lastDialogX
        winY = lastDialogY
        refX = lastDialogX + winW / 2
        refY = lastDialogY + winH / 2
    else
        -- Fallback to mouse position
        local mouseX, mouseY = reaper.GetMousePosition()
        winX = mouseX - winW / 2
        winY = mouseY - winH / 2
        refX, refY = mouseX, mouseY
    end

    -- Clamp to current monitor
    winX, winY = clampToScreen(winX, winY, winW, winH, refX, refY)

    -- Open progress window
    gfx.init("Stemperator - Processing...", winW, winH, 0, winX, winY)
    progressWindowResizableSet = false  -- Reset so we try to make it resizable
    progressState.running = true

    -- Start progress loop
    reaper.defer(progressLoop)
end

-- Legacy synchronous separation (fallback)
local function runSeparation(inputFile, outputDir, model)
    local logFile = outputDir .. PATH_SEP .. "separation_log.txt"
    local stdoutFile = outputDir .. PATH_SEP .. "stdout.txt"

    local cmd
    if OS == "Windows" then
        local vbsPath = outputDir .. PATH_SEP .. "run_hidden.vbs"
        local vbsFile = io.open(vbsPath, "w")
        if vbsFile then
            local pythonCmd = string.format(
                '"%s" -u "%s" "%s" "%s" --model %s',
                PYTHON_PATH, SEPARATOR_SCRIPT, inputFile, outputDir, model
            )
            pythonCmd = pythonCmd:gsub('"', '""')
            vbsFile:write('Set WshShell = CreateObject("WScript.Shell")\n')
            vbsFile:write('WshShell.Run "cmd /c ' .. pythonCmd .. ' >""' .. stdoutFile .. '"" 2>""' .. logFile .. '""", 0, True\n')
            vbsFile:close()
            cmd = 'cscript //nologo "' .. vbsPath .. '"'
        end
    else
        cmd = string.format(
            '"%s" -u "%s" "%s" "%s" --model %s >"%s" 2>"%s"',
            PYTHON_PATH, SEPARATOR_SCRIPT, inputFile, outputDir, model, stdoutFile, logFile
        )
    end

    os.execute(cmd)

    local stems = {}
    for _, stem in ipairs(STEMS) do
        if stem.selected then
            local stemPath = outputDir .. PATH_SEP .. stem.file
            local f = io.open(stemPath, "r")
            if f then f:close(); stems[stem.name:lower()] = stemPath end
        end
    end

    if next(stems) == nil then
        local errLog = io.open(logFile, "r")
        local errMsg = "No stems created"
        if errLog then
            local content = errLog:read("*a")
            errLog:close()
            if content and content ~= "" then
                errMsg = errMsg .. "\n\nLog:\n" .. content:sub(1, 500)
            end
        end
        return nil, errMsg
    end
    return stems
end

-- Replace only a portion of an item with stems (for time selection mode)
-- Splits the item at selection boundaries and replaces only the selected portion
local function replaceInPlacePartial(item, stemPaths, selStart, selEnd)
    local track = reaper.GetMediaItem_Track(item)
    local origItemPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local origItemEnd = origItemPos + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

    reaper.Undo_BeginBlock()

    -- We need to split the item at selection boundaries
    -- First, deselect all items and select only our target item
    reaper.SelectAllMediaItems(0, false)
    reaper.SetMediaItemSelected(item, true)

    local leftItem = nil   -- Part before selection (if any)
    local middleItem = item -- Part to replace
    local rightItem = nil  -- Part after selection (if any)

    -- Split at selection start if it's inside the item
    if selStart > origItemPos and selStart < origItemEnd then
        middleItem = reaper.SplitMediaItem(item, selStart)
        leftItem = item
        if middleItem then
            reaper.SetMediaItemSelected(leftItem, false)
            reaper.SetMediaItemSelected(middleItem, true)
        else
            -- Split failed, middle is still the original item
            middleItem = item
            leftItem = nil
        end
    end

    -- Split at selection end if it's inside what remains
    if middleItem then
        local midPos = reaper.GetMediaItemInfo_Value(middleItem, "D_POSITION")
        local midEnd = midPos + reaper.GetMediaItemInfo_Value(middleItem, "D_LENGTH")

        if selEnd > midPos and selEnd < midEnd then
            rightItem = reaper.SplitMediaItem(middleItem, selEnd)
            if rightItem then
                reaper.SetMediaItemSelected(rightItem, false)
            end
        end
    end

    -- Now delete the middle item and insert stems in its place
    local selLen = selEnd - selStart
    if middleItem then
        reaper.DeleteTrackMediaItem(track, middleItem)
    end

    -- Create stem items at the selection position
    local items = {}
    local stemColors = {}  -- Store colors for later take coloring
    for _, stem in ipairs(STEMS) do
        if stem.selected then
            local stemPath = stemPaths[stem.name:lower()]
            if stemPath then
                local newItem = reaper.AddMediaItemToTrack(track)
                reaper.SetMediaItemInfo_Value(newItem, "D_POSITION", selStart)
                reaper.SetMediaItemInfo_Value(newItem, "D_LENGTH", selLen)

                local take = reaper.AddTakeToMediaItem(newItem)
                local source = reaper.PCM_Source_CreateFromFile(stemPath)
                reaper.SetMediaItemTake_Source(take, source)
                reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", stem.name, true)

                local stemColor = rgbToReaperColor(stem.color[1], stem.color[2], stem.color[3])
                reaper.SetMediaItemInfo_Value(newItem, "I_CUSTOMCOLOR", stemColor)

                items[#items + 1] = { item = newItem, take = take, color = stemColor, name = stem.name }
            end
        end
    end

    -- Merge into takes on the first item
    if #items > 1 then
        local mainItem = items[1].item
        -- Set main item color to first stem color
        reaper.SetMediaItemInfo_Value(mainItem, "I_CUSTOMCOLOR", items[1].color)

        for i = 2, #items do
            local srcTake = reaper.GetActiveTake(items[i].item)
            if srcTake then
                local newTake = reaper.AddTakeToMediaItem(mainItem)
                reaper.SetMediaItemTake_Source(newTake, reaper.GetMediaItemTake_Source(srcTake))
                reaper.GetSetMediaItemTakeInfo_String(newTake, "P_NAME", items[i].name, true)
            end
            reaper.DeleteTrackMediaItem(track, items[i].item)
        end

        -- Now set the color for each take based on its stem
        -- Iterate through all takes and set their colors
        local numTakes = reaper.CountTakes(mainItem)
        for t = 0, numTakes - 1 do
            local take = reaper.GetTake(mainItem, t)
            if take then
                local _, takeName = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
                -- Find the matching stem color
                for _, stemData in ipairs(items) do
                    if stemData.name == takeName then
                        -- Set take color (I_CUSTOMCOLOR on the take)
                        reaper.SetMediaItemTakeInfo_Value(take, "I_CUSTOMCOLOR", stemData.color)
                        break
                    end
                end
            end
        end
    end

    reaper.Undo_EndBlock("Stemperator: Replace selection in-place", -1)
    return #items
end

-- Replace item in-place with stems as takes
local function replaceInPlace(item, stemPaths, itemPos, itemLen)
    local track = reaper.GetMediaItem_Track(item)
    reaper.Undo_BeginBlock()
    reaper.DeleteTrackMediaItem(track, item)

    local items = {}
    for _, stem in ipairs(STEMS) do
        if stem.selected then
            local stemPath = stemPaths[stem.name:lower()]
            if stemPath then
                local newItem = reaper.AddMediaItemToTrack(track)
                reaper.SetMediaItemInfo_Value(newItem, "D_POSITION", itemPos)
                reaper.SetMediaItemInfo_Value(newItem, "D_LENGTH", itemLen)

                local take = reaper.AddTakeToMediaItem(newItem)
                local source = reaper.PCM_Source_CreateFromFile(stemPath)
                reaper.SetMediaItemTake_Source(take, source)
                reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", stem.name, true)

                local stemColor = rgbToReaperColor(stem.color[1], stem.color[2], stem.color[3])
                reaper.SetMediaItemInfo_Value(newItem, "I_CUSTOMCOLOR", stemColor)

                items[#items + 1] = { item = newItem, take = take, color = stemColor, name = stem.name }
            end
        end
    end

    -- Merge into takes
    if #items > 1 then
        local mainItem = items[1].item
        -- Set main item color to first stem color
        reaper.SetMediaItemInfo_Value(mainItem, "I_CUSTOMCOLOR", items[1].color)

        for i = 2, #items do
            local srcTake = reaper.GetActiveTake(items[i].item)
            if srcTake then
                local newTake = reaper.AddTakeToMediaItem(mainItem)
                reaper.SetMediaItemTake_Source(newTake, reaper.GetMediaItemTake_Source(srcTake))
                reaper.GetSetMediaItemTakeInfo_String(newTake, "P_NAME", items[i].name, true)
            end
            reaper.DeleteTrackMediaItem(track, items[i].item)
        end

        -- Now set the color for each take based on its stem
        local numTakes = reaper.CountTakes(mainItem)
        for t = 0, numTakes - 1 do
            local take = reaper.GetTake(mainItem, t)
            if take then
                local _, takeName = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
                -- Find the matching stem color
                for _, stemData in ipairs(items) do
                    if stemData.name == takeName then
                        reaper.SetMediaItemTakeInfo_Value(take, "I_CUSTOMCOLOR", stemData.color)
                        break
                    end
                end
            end
        end
    end

    reaper.Undo_EndBlock("Stemperator: Replace in-place", -1)
    return #items
end

-- Create new tracks for each selected stem
local function createStemTracks(item, stemPaths, itemPos, itemLen)
    local track = reaper.GetMediaItem_Track(item)
    local trackIdx = math.floor(reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER"))
    local _, trackName = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    if trackName == "" then trackName = "Item" end

    local take = reaper.GetActiveTake(item)
    local sourceName = trackName
    if take then
        local _, takeName = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
        if takeName and takeName ~= "" then
            sourceName = takeName:match("([^/\\]+)%.[^.]*$") or takeName
        end
    end

    reaper.Undo_BeginBlock()

    local selectedCount = 0
    for _, stem in ipairs(STEMS) do
        if stem.selected and stemPaths[stem.name:lower()] then selectedCount = selectedCount + 1 end
    end

    local folderTrack = nil
    if SETTINGS.createFolder then
        reaper.InsertTrackAtIndex(trackIdx, true)
        folderTrack = reaper.GetTrack(0, trackIdx)
        reaper.GetSetMediaTrackInfo_String(folderTrack, "P_NAME", sourceName .. " - Stems", true)
        reaper.SetMediaTrackInfo_Value(folderTrack, "I_FOLDERDEPTH", 1)
        reaper.SetMediaTrackInfo_Value(folderTrack, "I_CUSTOMCOLOR", rgbToReaperColor(180, 140, 200))
        trackIdx = trackIdx + 1
    end

    local importedCount = 0
    for _, stem in ipairs(STEMS) do
        if stem.selected then
            local stemPath = stemPaths[stem.name:lower()]
            if stemPath then
                reaper.InsertTrackAtIndex(trackIdx + importedCount, true)
                local newTrack = reaper.GetTrack(0, trackIdx + importedCount)

                local newTrackName = selectedCount == 1 and (stem.name .. " - " .. sourceName) or (sourceName .. " - " .. stem.name)
                reaper.GetSetMediaTrackInfo_String(newTrack, "P_NAME", newTrackName, true)

                local color = rgbToReaperColor(stem.color[1], stem.color[2], stem.color[3])
                reaper.SetMediaTrackInfo_Value(newTrack, "I_CUSTOMCOLOR", color)

                local newItem = reaper.AddMediaItemToTrack(newTrack)
                reaper.SetMediaItemInfo_Value(newItem, "D_POSITION", itemPos)
                reaper.SetMediaItemInfo_Value(newItem, "D_LENGTH", itemLen)

                local newTake = reaper.AddTakeToMediaItem(newItem)
                reaper.SetMediaItemTake_Source(newTake, reaper.PCM_Source_CreateFromFile(stemPath))
                reaper.GetSetMediaItemTakeInfo_String(newTake, "P_NAME", stem.name, true)
                reaper.SetMediaItemInfo_Value(newItem, "I_CUSTOMCOLOR", color)

                importedCount = importedCount + 1
            end
        end
    end

    if folderTrack and importedCount > 0 then
        reaper.SetMediaTrackInfo_Value(reaper.GetTrack(0, trackIdx + importedCount - 1), "I_FOLDERDEPTH", -1)
    end

    if SETTINGS.deleteOriginalTrack then
        reaper.DeleteTrack(track)
    elseif SETTINGS.deleteOriginal then
        reaper.DeleteTrackMediaItem(track, item)
    elseif SETTINGS.muteOriginal then
        reaper.SetMediaItemInfo_Value(item, "B_MUTE", 1)
    elseif SETTINGS.muteSelection then
        -- Mute only the selection portion by splitting and muting that part
        local selStart, selEnd = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
        local origItemPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local origItemEnd = origItemPos + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

        -- Check if there's a valid time selection overlapping the item
        if selEnd > selStart and selStart < origItemEnd and selEnd > origItemPos then
            -- Clamp selection to item bounds
            local muteStart = math.max(selStart, origItemPos)
            local muteEnd = math.min(selEnd, origItemEnd)

            -- Split at selection start (if inside item)
            local middleItem = item
            if muteStart > origItemPos then
                middleItem = reaper.SplitMediaItem(item, muteStart)
            end

            -- Split at selection end (if inside remaining item)
            if middleItem then
                local midPos = reaper.GetMediaItemInfo_Value(middleItem, "D_POSITION")
                local midEnd = midPos + reaper.GetMediaItemInfo_Value(middleItem, "D_LENGTH")
                if muteEnd < midEnd then
                    reaper.SplitMediaItem(middleItem, muteEnd)
                end
                -- Mute the middle section
                reaper.SetMediaItemInfo_Value(middleItem, "B_MUTE", 1)
            end
        else
            -- No valid selection, mute entire item
            reaper.SetMediaItemInfo_Value(item, "B_MUTE", 1)
        end
    elseif SETTINGS.deleteSelection then
        -- Delete only the selection portion by splitting and deleting that part
        local selStart, selEnd = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
        local origItemPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local origItemEnd = origItemPos + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

        -- Check if there's a valid time selection overlapping the item
        if selEnd > selStart and selStart < origItemEnd and selEnd > origItemPos then
            -- Clamp selection to item bounds
            local delStart = math.max(selStart, origItemPos)
            local delEnd = math.min(selEnd, origItemEnd)

            -- Split at selection start (if inside item)
            local middleItem = item
            if delStart > origItemPos then
                middleItem = reaper.SplitMediaItem(item, delStart)
            end

            -- Split at selection end (if inside remaining item)
            if middleItem then
                local midPos = reaper.GetMediaItemInfo_Value(middleItem, "D_POSITION")
                local midEnd = midPos + reaper.GetMediaItemInfo_Value(middleItem, "D_LENGTH")
                if delEnd < midEnd then
                    reaper.SplitMediaItem(middleItem, delEnd)
                end
                -- Delete the middle section
                reaper.DeleteTrackMediaItem(track, middleItem)
            end
        else
            -- No valid selection, delete entire item
            reaper.DeleteTrackMediaItem(track, item)
        end
    end
    -- If none of the above, leave item as-is

    reaper.Undo_EndBlock("Stemperator: Create stem tracks", -1)
    return importedCount
end

-- Store item reference for async workflow
local selectedItem = nil
local itemPos = 0
local itemLen = 0
local timeSelectionMode = false  -- true when processing time selection instead of item
local timeSelectionStart = 0
local timeSelectionEnd = 0
local timeSelectionSourceItem = nil  -- The item found in time selection (for in-place replacement)
local itemSubSelection = false  -- true when we rendered only a portion of the selected item
local itemSubSelStart = 0
local itemSubSelEnd = 0

-- Get all items that overlap with a time range
-- If selectedOnly is true, only returns items that are also selected
local function getItemsInTimeRange(startTime, endTime, selectedOnly)
    local items = {}
    local numTracks = reaper.CountTracks(0)
    for t = 0, numTracks - 1 do
        local track = reaper.GetTrack(0, t)
        local numItems = reaper.CountTrackMediaItems(track)
        for i = 0, numItems - 1 do
            local item = reaper.GetTrackMediaItem(track, i)
            local itemStart = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
            local itemEnd = itemStart + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
            -- Check if item overlaps with time range
            if itemStart < endTime and itemEnd > startTime then
                -- If selectedOnly, check if item is selected
                if selectedOnly then
                    if reaper.IsMediaItemSelected(item) then
                        table.insert(items, item)
                    end
                else
                    table.insert(items, item)
                end
            end
        end
    end
    return items
end

-- Mute the selection portion of selected items within a time range
local function muteSelectionInItems(startTime, endTime)
    local items = getItemsInTimeRange(startTime, endTime, true)  -- selectedOnly = true
    for _, item in ipairs(items) do
        local track = reaper.GetMediaItem_Track(item)
        local origItemPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local origItemEnd = origItemPos + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        local muteStart = math.max(startTime, origItemPos)
        local muteEnd = math.min(endTime, origItemEnd)

        local middleItem = item
        if muteStart > origItemPos then
            middleItem = reaper.SplitMediaItem(item, muteStart)
        end
        if middleItem then
            local midEnd = reaper.GetMediaItemInfo_Value(middleItem, "D_POSITION") + reaper.GetMediaItemInfo_Value(middleItem, "D_LENGTH")
            if muteEnd < midEnd then
                reaper.SplitMediaItem(middleItem, muteEnd)
            end
            reaper.SetMediaItemInfo_Value(middleItem, "B_MUTE", 1)
        end
    end
    return #items
end

-- Delete the selection portion of selected items within a time range
local function deleteSelectionInItems(startTime, endTime)
    local items = getItemsInTimeRange(startTime, endTime, true)  -- selectedOnly = true
    -- Process in reverse order to avoid index shifting issues
    for i = #items, 1, -1 do
        local item = items[i]
        local track = reaper.GetMediaItem_Track(item)
        local origItemPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local origItemEnd = origItemPos + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        local delStart = math.max(startTime, origItemPos)
        local delEnd = math.min(endTime, origItemEnd)

        local middleItem = item
        if delStart > origItemPos then
            middleItem = reaper.SplitMediaItem(item, delStart)
        end
        if middleItem then
            local midEnd = reaper.GetMediaItemInfo_Value(middleItem, "D_POSITION") + reaper.GetMediaItemInfo_Value(middleItem, "D_LENGTH")
            if delEnd < midEnd then
                reaper.SplitMediaItem(middleItem, delEnd)
            end
            reaper.DeleteTrackMediaItem(track, middleItem)
        end
    end
    return #items
end

-- Create new tracks for stems from time selection (no original item)
local function createStemTracksForSelection(stemPaths, selPos, selLen, sourceTrack)
    reaper.Undo_BeginBlock()

    -- Get reference track: use provided sourceTrack, or first selected track, or track 0
    local refTrack = sourceTrack or reaper.GetSelectedTrack(0, 0) or reaper.GetTrack(0, 0)
    local trackIdx = 0
    if refTrack then
        trackIdx = math.floor(reaper.GetMediaTrackInfo_Value(refTrack, "IP_TRACKNUMBER"))
    end

    local selectedCount = 0
    for _, stem in ipairs(STEMS) do
        if stem.selected and stemPaths[stem.name:lower()] then selectedCount = selectedCount + 1 end
    end

    -- Get source track name for stem naming
    local folderTrack = nil
    local sourceName = "Selection"
    if refTrack then
        local _, trackName = reaper.GetTrackName(refTrack)
        if trackName and trackName ~= "" then
            sourceName = trackName
        end
    end
    if SETTINGS.createFolder then
        reaper.InsertTrackAtIndex(trackIdx, true)
        folderTrack = reaper.GetTrack(0, trackIdx)
        reaper.GetSetMediaTrackInfo_String(folderTrack, "P_NAME", sourceName .. " - Stems", true)
        reaper.SetMediaTrackInfo_Value(folderTrack, "I_FOLDERDEPTH", 1)
        reaper.SetMediaTrackInfo_Value(folderTrack, "I_CUSTOMCOLOR", rgbToReaperColor(180, 140, 200))
        trackIdx = trackIdx + 1
    end

    local importedCount = 0
    for _, stem in ipairs(STEMS) do
        if stem.selected then
            local stemPath = stemPaths[stem.name:lower()]
            if stemPath then
                reaper.InsertTrackAtIndex(trackIdx + importedCount, true)
                local newTrack = reaper.GetTrack(0, trackIdx + importedCount)

                local newTrackName = selectedCount == 1 and (stem.name .. " - " .. sourceName) or (sourceName .. " - " .. stem.name)
                reaper.GetSetMediaTrackInfo_String(newTrack, "P_NAME", newTrackName, true)

                local color = rgbToReaperColor(stem.color[1], stem.color[2], stem.color[3])
                reaper.SetMediaTrackInfo_Value(newTrack, "I_CUSTOMCOLOR", color)

                local newItem = reaper.AddMediaItemToTrack(newTrack)
                reaper.SetMediaItemInfo_Value(newItem, "D_POSITION", selPos)
                reaper.SetMediaItemInfo_Value(newItem, "D_LENGTH", selLen)

                local newTake = reaper.AddTakeToMediaItem(newItem)
                reaper.SetMediaItemTake_Source(newTake, reaper.PCM_Source_CreateFromFile(stemPath))
                reaper.GetSetMediaItemTakeInfo_String(newTake, "P_NAME", stem.name, true)
                reaper.SetMediaItemInfo_Value(newItem, "I_CUSTOMCOLOR", color)

                importedCount = importedCount + 1
            end
        end
    end

    if folderTrack and importedCount > 0 then
        reaper.SetMediaTrackInfo_Value(reaper.GetTrack(0, trackIdx + importedCount - 1), "I_FOLDERDEPTH", -1)
    end

    reaper.Undo_EndBlock("Stemperator: Create stem tracks from selection", -1)
    return importedCount
end

-- Store temp directory for async workflow
local workflowTempDir = nil
local workflowTempInput = nil

-- Process stems after separation completes (called from progress UI)
function processStemsResult(stems)
    local count
    local resultMsg

    if timeSelectionMode then
        -- Time selection mode: respect user's setting
        if SETTINGS.createNewTracks then
            -- Handle mute/delete options BEFORE creating stems (so new stems aren't affected)
            local actionMsg = ""
            if SETTINGS.muteOriginal then
                -- Mute only SELECTED items that overlap with time selection
                local items = getItemsInTimeRange(timeSelectionStart, timeSelectionEnd, true)
                for _, item in ipairs(items) do
                    reaper.SetMediaItemInfo_Value(item, "B_MUTE", 1)
                end
                local itemWord = #items == 1 and "item" or "items"
                actionMsg = "\n" .. #items .. " " .. itemWord .. " muted."
            elseif SETTINGS.muteSelection then
                -- Mute selection portion of SELECTED items
                local itemCount = muteSelectionInItems(timeSelectionStart, timeSelectionEnd)
                local itemWord = itemCount == 1 and "item" or "items"
                actionMsg = "\nSelection muted in " .. itemCount .. " " .. itemWord .. "."
            elseif SETTINGS.deleteOriginal then
                -- Delete only SELECTED items that overlap with time selection
                local items = getItemsInTimeRange(timeSelectionStart, timeSelectionEnd, true)
                for i = #items, 1, -1 do
                    local item = items[i]
                    reaper.DeleteTrackMediaItem(reaper.GetMediaItem_Track(item), item)
                end
                local itemWord = #items == 1 and "item" or "items"
                actionMsg = "\n" .. #items .. " " .. itemWord .. " deleted."
            elseif SETTINGS.deleteSelection then
                -- Delete selection portion of SELECTED items
                local itemCount = deleteSelectionInItems(timeSelectionStart, timeSelectionEnd)
                local itemWord = itemCount == 1 and "item" or "items"
                actionMsg = "\nSelection deleted from " .. itemCount .. " " .. itemWord .. "."
            end
            -- Now create stems (after mute/delete so they're not affected)
            -- In multi-track mode, use the source track from the queue
            local sourceTrack = multiTrackQueue.active and multiTrackQueue.currentSourceTrack or nil
            count = createStemTracksForSelection(stems, itemPos, itemLen, sourceTrack)
            local trackWord = count == 1 and "track" or "tracks"
            -- In multi-track mode, show which track we're on
            local trackInfo = ""
            if multiTrackQueue.active then
                trackInfo = " [Track " .. multiTrackQueue.currentIndex .. "/" .. multiTrackQueue.totalTracks .. ": " .. (multiTrackQueue.currentTrackName or "?") .. "]"
            end
            resultMsg = count .. " stem " .. trackWord .. " created from time selection." .. actionMsg .. trackInfo
        else
            -- In-place mode: replace only the selected portion of the item
            if timeSelectionSourceItem then
                -- Use partial replacement - splits the item and replaces only the selected part
                count = replaceInPlacePartial(timeSelectionSourceItem, stems, timeSelectionStart, timeSelectionEnd)
                resultMsg = count == 1 and "Selection replaced with stem." or "Selection replaced with stems as takes (press T to switch)."
            else
                -- Fallback: create new tracks if no source item
                local sourceTrack = multiTrackQueue.active and multiTrackQueue.currentSourceTrack or nil
                count = createStemTracksForSelection(stems, itemPos, itemLen, sourceTrack)
                local trackWord = count == 1 and "track" or "tracks"
                resultMsg = count .. " stem " .. trackWord .. " created from time selection."
            end
        end
    elseif SETTINGS.createNewTracks then
        count = createStemTracks(selectedItem, stems, itemPos, itemLen)
        local action = SETTINGS.deleteOriginalTrack and "Track deleted." or
                       (SETTINGS.deleteOriginal and "Item deleted." or
                       (SETTINGS.deleteSelection and "Selection deleted." or
                       (SETTINGS.muteOriginal and "Item muted." or
                       (SETTINGS.muteSelection and "Selection muted." or ""))))
        local trackWord = count == 1 and "track" or "tracks"
        resultMsg = count .. " stem " .. trackWord .. " created."
        if action ~= "" then resultMsg = resultMsg .. "\n" .. action end
    else
        -- Check if we processed a sub-selection of the item
        if itemSubSelection then
            -- Use partial replacement - splits the item and replaces only the selected part
            count = replaceInPlacePartial(selectedItem, stems, itemSubSelStart, itemSubSelEnd)
            resultMsg = count == 1 and "Selection replaced with stem." or "Selection replaced with stems as takes (press T to switch)."
        else
            count = replaceInPlace(selectedItem, stems, itemPos, itemLen)
            resultMsg = count == 1 and "Stem replaced." or "Stems added as takes (press T to switch)."
        end
    end

    local selectedNames = {}
    local selectedStemData = {}
    local is6Stem = (SETTINGS.model == "htdemucs_6s")
    for _, stem in ipairs(STEMS) do
        -- Only include stems that were actually processed (respect sixStemOnly flag)
        if stem.selected and (not stem.sixStemOnly or is6Stem) then
            selectedNames[#selectedNames + 1] = stem.name
            selectedStemData[#selectedStemData + 1] = stem
        end
    end

    -- Calculate and add timing info
    local totalTime = os.time() - (progressState.startTime or os.time())
    local totalMins = math.floor(totalTime / 60)
    local totalSecs = totalTime % 60
    local timeStr = string.format("%d:%02d", totalMins, totalSecs)
    resultMsg = resultMsg .. "\nTime: " .. timeStr

    reaper.UpdateArrange()

    -- Show custom result window
    showResultWindow(selectedStemData, resultMsg)
end

-- Result window state
local resultWindowState = {
    selectedStems = {},
    message = "",
    running = false,
    startTime = 0,
    confetti = {},
    rings = {},
}

-- Initialize celebration effects
local function initCelebration()
    resultWindowState.startTime = os.clock()
    resultWindowState.confetti = {}
    resultWindowState.rings = {}

    -- Create confetti particles
    for i = 1, 50 do
        table.insert(resultWindowState.confetti, {
            x = math.random() * 400 + 100,
            y = -math.random() * 100,
            vx = (math.random() - 0.5) * 4,
            vy = math.random() * 2 + 1,
            rotation = math.random() * math.pi * 2,
            rotSpeed = (math.random() - 0.5) * 0.3,
            size = math.random() * 8 + 4,
            colorIdx = math.random(1, 6),
            delay = math.random() * 0.5,
        })
    end

    -- Create expanding rings
    for i = 1, 3 do
        table.insert(resultWindowState.rings, {
            radius = 0,
            alpha = 1,
            delay = i * 0.15,
        })
    end
end

-- Draw result window (clean style matching main app)
local function drawResultWindow()
    local w, h = gfx.w, gfx.h

    -- Calculate scale
    local scale = math.min(w / 380, h / 340)
    scale = math.max(0.5, math.min(4.0, scale))
    local function PS(val) return math.floor(val * scale + 0.5) end

    -- Solid background (matching main app)
    gfx.set(THEME.bg[1], THEME.bg[2], THEME.bg[3], 1)
    gfx.rect(0, 0, w, h, 1)

    -- Colored STEM border at top
    drawStemBorder(0, 0, w, 3)

    -- Theme toggle button (sun/moon icon, top right)
    local themeSize = PS(20)
    local themeX = w - themeSize - PS(10)
    local themeY = PS(8)
    local mx, my = gfx.mouse_x, gfx.mouse_y
    local themeHover = mx >= themeX and mx <= themeX + themeSize and my >= themeY and my <= themeY + themeSize
    local mouseDown = gfx.mouse_cap & 1 == 1

    -- Draw theme toggle (circle with rays for sun, crescent for moon)
    if SETTINGS.darkMode then
        -- Moon icon (crescent)
        gfx.set(0.7, 0.7, 0.5, themeHover and 1 or 0.6)
        gfx.circle(themeX + themeSize/2, themeY + themeSize/2, themeSize/2 - 2, 1, 1)
        gfx.set(THEME.bg[1], THEME.bg[2], THEME.bg[3], 1)
        gfx.circle(themeX + themeSize/2 + 4, themeY + themeSize/2 - 3, themeSize/2 - 3, 1, 1)
    else
        -- Sun icon
        gfx.set(0.9, 0.7, 0.2, themeHover and 1 or 0.8)
        gfx.circle(themeX + themeSize/2, themeY + themeSize/2, themeSize/3, 1, 1)
        -- Rays
        for i = 0, 7 do
            local angle = i * math.pi / 4
            local x1 = themeX + themeSize/2 + math.cos(angle) * (themeSize/3 + 2)
            local y1 = themeY + themeSize/2 + math.sin(angle) * (themeSize/3 + 2)
            local x2 = themeX + themeSize/2 + math.cos(angle) * (themeSize/2 - 1)
            local y2 = themeY + themeSize/2 + math.sin(angle) * (themeSize/2 - 1)
            gfx.line(x1, y1, x2, y2)
        end
    end

    -- Handle theme toggle click
    if themeHover and mouseDown and not resultWindowState.wasMouseDown then
        SETTINGS.darkMode = not SETTINGS.darkMode
        updateTheme()
        saveSettings()  -- Persist theme change
    end

    -- Success icon (simple green circle with checkmark)
    local iconX = w / 2
    local iconY = PS(50)
    local iconR = PS(28)

    -- Green circle
    gfx.set(0.2, 0.65, 0.35, 1)
    gfx.circle(iconX, iconY, iconR, 1, 1)

    -- White checkmark
    gfx.set(1, 1, 1, 1)
    local cx, cy = iconX, iconY
    -- First part of checkmark
    local x1, y1 = cx - PS(10), cy
    local x2, y2 = cx - PS(3), cy + PS(8)
    gfx.line(x1, y1, x2, y2)
    gfx.line(x1, y1+1, x2, y2+1)
    -- Second part of checkmark
    local x3, y3 = cx + PS(10), cy - PS(7)
    gfx.line(x2, y2, x3, y3)
    gfx.line(x2, y2+1, x3, y3+1)

    -- Title with colored STEM letters: "STEMperation Complete!"
    gfx.setfont(1, "Arial", PS(18), string.byte('b'))

    -- STEM colors (same as STEMperate button)
    local stemLetterColors = {
        {255, 100, 100},  -- S = Vocals (red)
        {100, 200, 255},  -- T = Drums (blue)
        {150, 100, 255},  -- E = Bass (purple)
        {100, 255, 150},  -- M = Other (green)
    }

    local stemPart = "STEM"
    local restPart = "peration Complete!"
    local stemW = gfx.measurestr(stemPart)
    local restW = gfx.measurestr(restPart)
    local totalW = stemW + restW
    local titleX = (w - totalW) / 2
    local titleY = PS(90)

    -- Draw STEM with individual colored letters
    local charX = titleX
    for i = 1, 4 do
        local char = stemPart:sub(i, i)
        local color = stemLetterColors[i]
        gfx.set(color[1]/255, color[2]/255, color[3]/255, 1)
        gfx.x = charX
        gfx.y = titleY
        gfx.drawstr(char)
        charX = charX + gfx.measurestr(char)
    end

    -- Draw rest of title in normal text color
    gfx.set(THEME.text[1], THEME.text[2], THEME.text[3], 1)
    gfx.x = charX
    gfx.y = titleY
    gfx.drawstr(restPart)

    -- Stem indicators (simple colored boxes)
    local stemY = PS(125)
    local stemBoxSize = PS(14)
    gfx.setfont(1, "Arial", PS(11))

    -- Calculate total width to center
    local totalStemWidth = 0
    for _, stem in ipairs(resultWindowState.selectedStems) do
        totalStemWidth = totalStemWidth + stemBoxSize + gfx.measurestr(stem.name) + PS(16)
    end
    local stemX = (w - totalStemWidth) / 2

    for _, stem in ipairs(resultWindowState.selectedStems) do
        -- Stem color box
        gfx.set(stem.color[1]/255, stem.color[2]/255, stem.color[3]/255, 1)
        gfx.rect(stemX, stemY, stemBoxSize, stemBoxSize, 1)

        -- Stem name
        gfx.set(THEME.textDim[1], THEME.textDim[2], THEME.textDim[3], 1)
        gfx.x = stemX + stemBoxSize + PS(5)
        gfx.y = stemY + PS(1)
        gfx.drawstr(stem.name)
        stemX = stemX + stemBoxSize + gfx.measurestr(stem.name) + PS(16)
    end

    -- Target info (output mode)
    local targetY = PS(150)
    gfx.setfont(1, "Arial", PS(10))
    gfx.set(THEME.textDim[1], THEME.textDim[2], THEME.textDim[3], 1)
    local targetText = "Target: "
    if SETTINGS.createNewTracks then
        targetText = targetText .. "New tracks"
        if SETTINGS.createFolder then targetText = targetText .. " (folder)" end
    else
        targetText = targetText .. "In-place (as takes)"
    end
    -- Add action info
    if SETTINGS.muteOriginal then
        targetText = targetText .. " | Mute original"
    elseif SETTINGS.muteSelection then
        targetText = targetText .. " | Mute selection"
    elseif SETTINGS.deleteOriginal then
        targetText = targetText .. " | Delete original"
    elseif SETTINGS.deleteSelection then
        targetText = targetText .. " | Delete selection"
    elseif SETTINGS.deleteOriginalTrack then
        targetText = targetText .. " | Delete track"
    end
    local targetW = gfx.measurestr(targetText)
    gfx.x = (w - targetW) / 2
    gfx.y = targetY
    gfx.drawstr(targetText)

    -- Result message box
    local msgBoxY = PS(170)
    local msgBoxH = PS(70)
    gfx.set(THEME.inputBg[1], THEME.inputBg[2], THEME.inputBg[3], 1)
    gfx.rect(PS(20), msgBoxY, w - PS(40), msgBoxH, 1)
    gfx.set(THEME.border[1], THEME.border[2], THEME.border[3], 1)
    gfx.rect(PS(20), msgBoxY, w - PS(40), msgBoxH, 0)

    -- Result message text
    gfx.set(THEME.text[1], THEME.text[2], THEME.text[3], 1)
    gfx.setfont(1, "Arial", PS(11))
    local msgLines = {}
    for line in (resultWindowState.message .. "\n"):gmatch("([^\n]*)\n") do
        table.insert(msgLines, line)
    end
    local msgY = msgBoxY + PS(8)
    for _, line in ipairs(msgLines) do
        local lineW = gfx.measurestr(line)
        gfx.x = (w - lineW) / 2
        gfx.y = msgY
        gfx.drawstr(line)
        msgY = msgY + PS(13)
    end

    -- OK button (rounded pill style like main app)
    local btnW = PS(70)
    local btnH = PS(20)
    local btnX = (w - btnW) / 2
    local btnY = h - PS(40)

    local hover = mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH

    -- Button background
    if hover then
        gfx.set(THEME.buttonPrimaryHover[1], THEME.buttonPrimaryHover[2], THEME.buttonPrimaryHover[3], 1)
    else
        gfx.set(THEME.buttonPrimary[1], THEME.buttonPrimary[2], THEME.buttonPrimary[3], 1)
    end
    -- Draw rounded (pill-shaped) button
    for i = 0, btnH - 1 do
        local radius = btnH / 2
        local inset = 0
        if i < radius then
            inset = radius - math.sqrt(radius * radius - (radius - i) * (radius - i))
        elseif i > btnH - radius then
            inset = radius - math.sqrt(radius * radius - (i - (btnH - radius)) * (i - (btnH - radius)))
        end
        gfx.line(btnX + inset, btnY + i, btnX + btnW - inset, btnY + i)
    end

    -- Button text
    gfx.set(1, 1, 1, 1)
    gfx.setfont(1, "Arial", PS(13), string.byte('b'))
    local okText = "OK"
    local okW = gfx.measurestr(okText)
    gfx.x = btnX + (btnW - okW) / 2
    gfx.y = btnY + (btnH - PS(13)) / 2
    gfx.drawstr(okText)

    -- Hint at very bottom edge
    gfx.set(THEME.textHint[1], THEME.textHint[2], THEME.textHint[3], 1)
    gfx.setfont(1, "Arial", PS(9))
    local hint = "Enter / Space / ESC"
    local hintW = gfx.measurestr(hint)
    gfx.x = (w - hintW) / 2
    gfx.y = h - PS(12)
    gfx.drawstr(hint)

    -- flarkAUDIO logo at top (translucent) - "flark" regular, "AUDIO" bold
    gfx.setfont(1, "Arial", PS(10))
    local flarkPart = "flark"
    local flarkPartW = gfx.measurestr(flarkPart)
    gfx.setfont(1, "Arial", PS(10), string.byte('b'))
    local audioPart = "AUDIO"
    local audioPartW = gfx.measurestr(audioPart)
    local totalLogoW = flarkPartW + audioPartW
    local logoStartX = (w - totalLogoW) / 2
    -- Orange text, 50% translucent
    gfx.set(1.0, 0.5, 0.1, 0.5)
    gfx.setfont(1, "Arial", PS(10))
    gfx.x = logoStartX
    gfx.y = PS(3)
    gfx.drawstr(flarkPart)
    gfx.setfont(1, "Arial", PS(10), string.byte('b'))
    gfx.x = logoStartX + flarkPartW
    gfx.y = PS(3)
    gfx.drawstr(audioPart)

    gfx.update()

    -- Check for click on OK button
    if hover and mouseDown and not resultWindowState.wasMouseDown then
        return true  -- Close
    end

    resultWindowState.wasMouseDown = mouseDown

    local char = gfx.getchar()
    if char == -1 or char == 27 or char == 13 or char == 32 then  -- Window closed, ESC, Enter, or Space
        return true  -- Close
    end

    return false  -- Keep open
end

-- Result window loop
local function resultWindowLoop()
    -- Save window position for next time
    if reaper.JS_Window_GetRect then
        local hwnd = reaper.JS_Window_Find("Stemperator - Complete", true)
        if hwnd then
            local retval, left, top, right, bottom = reaper.JS_Window_GetRect(hwnd)
            if retval then
                lastDialogX = left
                lastDialogY = top
                lastDialogW = right - left
                lastDialogH = bottom - top
            end

            -- Check if window lost focus - close and reopen main dialog
            if reaper.JS_Window_GetFocus then
                local focusedHwnd = reaper.JS_Window_GetFocus()
                if focusedHwnd and focusedHwnd ~= hwnd then
                    -- Window lost focus, close and reopen main app
                    gfx.quit()
                    reaper.defer(function() main() end)
                    return
                end
            end
        end
    end

    if drawResultWindow() then
        gfx.quit()
        -- Reopen main dialog (if there's still a selection)
        reaper.defer(function() main() end)
        return
    end
    reaper.defer(resultWindowLoop)
end

-- Show result window
function showResultWindow(selectedStems, message)
    -- Load settings to get current theme
    loadSettings()
    updateTheme()

    resultWindowState.selectedStems = selectedStems
    resultWindowState.message = message
    resultWindowState.wasMouseDown = false

    -- Initialize celebration effects
    initCelebration()

    -- Restore playback state if it was playing before processing
    if savedPlaybackState == 1 then
        -- Was playing, resume playback
        reaper.OnPlayButton()
    elseif savedPlaybackState == 2 then
        -- Was paused, start and pause (to restore paused state)
        reaper.OnPlayButton()
        reaper.OnPauseButton()
    end

    -- Return focus to REAPER main window so user can interact
    local mainHwnd = reaper.GetMainHwnd()
    if mainHwnd and reaper.JS_Window_SetFocus then
        reaper.JS_Window_SetFocus(mainHwnd)
    end

    -- Use same size as main dialog
    local winW = lastDialogW or 380
    local winH = lastDialogH or 340
    local winX, winY

    -- Use last dialog position if available (exact position, no clamping)
    if lastDialogX and lastDialogY then
        winX = lastDialogX
        winY = lastDialogY
    else
        -- Fallback to mouse position with clamping
        local mouseX, mouseY = reaper.GetMousePosition()
        winX = mouseX - winW / 2
        winY = mouseY - winH / 2
        winX, winY = clampToScreen(winX, winY, winW, winH, mouseX, mouseY)
    end

    gfx.init("Stemperator - Complete", winW, winH, 0, winX, winY)
    reaper.defer(resultWindowLoop)
end

-- Run multi-track separation (parallel or sequential based on setting)
runSingleTrackSeparation = function(trackList)
    local baseTempDir = getTempDir() .. PATH_SEP .. "stemperator_" .. os.time()
    makeDir(baseTempDir)

    -- Check if we have a time selection
    local hasTimeSel = hasTimeSelection()

    -- In-place mode with no time selection: process each item separately
    -- This ensures each item gets its own stems as takes
    local inPlaceMultiItem = not SETTINGS.createNewTracks and not hasTimeSel

    -- Prepare all tracks: extract audio
    local trackJobs = {}
    local jobIndex = 0

    for i, track in ipairs(trackList) do
        local _, trackName = reaper.GetTrackName(track)
        if trackName == "" then trackName = "Track " .. math.floor(reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")) end

        if inPlaceMultiItem then
            -- In-place mode: create a separate job for EACH selected item on the track
            local numItems = reaper.CountTrackMediaItems(track)
            local selectedItems = {}
            for j = 0, numItems - 1 do
                local item = reaper.GetTrackMediaItem(track, j)
                if reaper.IsMediaItemSelected(item) then
                    table.insert(selectedItems, item)
                end
            end

            for itemIdx, item in ipairs(selectedItems) do
                jobIndex = jobIndex + 1
                local itemDir = baseTempDir .. PATH_SEP .. "item_" .. jobIndex
                makeDir(itemDir)
                local inputFile = itemDir .. PATH_SEP .. "input.wav"

                local extracted, err = renderSingleItemToWav(item, inputFile)
                if extracted then
                    -- Get item name for display
                    local itemName = "Unknown"
                    local take = reaper.GetActiveTake(item)
                    if take then
                        local _, takeName = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
                        if takeName and takeName ~= "" then
                            itemName = takeName
                        else
                            local source = reaper.GetMediaItemTake_Source(take)
                            if source then
                                local sourcePath = reaper.GetMediaSourceFileName(source, "")
                                if sourcePath and sourcePath ~= "" then
                                    itemName = sourcePath:match("([^/\\]+)$") or sourcePath
                                end
                            end
                        end
                    end

                    -- Get audio duration
                    local audioDuration = 0
                    local f = io.popen('ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "' .. inputFile .. '" 2>nul')
                    if f then
                        local dur = f:read("*a")
                        f:close()
                        audioDuration = tonumber(dur) or 0
                    end

                    table.insert(trackJobs, {
                        track = track,
                        trackName = trackName .. " [" .. itemIdx .. "/" .. #selectedItems .. "]",
                        trackDir = itemDir,
                        inputFile = inputFile,
                        sourceItem = item,
                        sourceItems = {item},  -- Only this one item
                        itemNames = itemName,
                        itemCount = 1,
                        index = jobIndex,
                        audioDuration = audioDuration,
                    })
                end
            end
        else
            -- Original behavior: one job per track (combines items or uses time selection)
            jobIndex = jobIndex + 1
            local trackDir = baseTempDir .. PATH_SEP .. "track_" .. jobIndex
            makeDir(trackDir)
            local inputFile = trackDir .. PATH_SEP .. "input.wav"

            -- Use appropriate render function based on whether time selection exists
            local extracted, err, sourceItem, allSourceItems
            if hasTimeSel then
                extracted, err, sourceItem, allSourceItems = renderTrackTimeSelectionToWav(track, inputFile)
            else
                extracted, err, sourceItem, allSourceItems = renderTrackSelectedItemsToWav(track, inputFile)
            end
            if extracted then
                -- Get media item name(s) for display
                local itemNames = {}
                local items = allSourceItems or {sourceItem}
                for _, item in ipairs(items) do
                    if item and reaper.ValidatePtr(item, "MediaItem*") then
                        local take = reaper.GetActiveTake(item)
                        if take then
                            local _, takeName = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
                            if takeName and takeName ~= "" then
                                table.insert(itemNames, takeName)
                            else
                                -- Try to get source filename
                                local source = reaper.GetMediaItemTake_Source(take)
                                if source then
                                    local sourcePath = reaper.GetMediaSourceFileName(source, "")
                                    if sourcePath and sourcePath ~= "" then
                                        local fileName = sourcePath:match("([^/\\]+)$") or sourcePath
                                        table.insert(itemNames, fileName)
                                    end
                                end
                            end
                        end
                    end
                end
                local itemNamesStr = #itemNames > 0 and table.concat(itemNames, ", ") or "Unknown"

                -- Get audio duration from the input file
                local audioDuration = 0
                local f = io.popen('ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "' .. inputFile .. '" 2>nul')
                if f then
                    local dur = f:read("*a")
                    f:close()
                    audioDuration = tonumber(dur) or 0
                end

                table.insert(trackJobs, {
                    track = track,
                    trackName = trackName,
                    trackDir = trackDir,
                    inputFile = inputFile,
                    sourceItem = sourceItem,
                    sourceItems = allSourceItems or {sourceItem},  -- All items for mute/delete
                    itemNames = itemNamesStr,
                    itemCount = #items,
                    index = jobIndex,
                    audioDuration = audioDuration,  -- Duration in seconds
                })
            end
        end
    end

    if #trackJobs == 0 then
        showMessage("Error", "Failed to extract audio from any tracks.", "error")
        return
    end

    -- Store jobs in queue for progress tracking
    multiTrackQueue.jobs = trackJobs
    multiTrackQueue.totalTracks = #trackJobs
    multiTrackQueue.completedCount = 0
    multiTrackQueue.baseTempDir = baseTempDir
    multiTrackQueue.active = true
    multiTrackQueue.sequentialMode = not SETTINGS.parallelProcessing
    multiTrackQueue.currentJobIndex = 0
    multiTrackQueue.globalStartTime = os.time()  -- Track total elapsed time
    multiTrackQueue.totalAudioDuration = 0  -- Will be updated when jobs start

    if SETTINGS.parallelProcessing then
        -- Start all separation processes in parallel (uses more VRAM)
        for _, job in ipairs(trackJobs) do
            startSeparationProcessForJob(job, 25)  -- Smaller segments for parallel
        end
    else
        -- Sequential mode: start only the first job (uses less VRAM)
        startSeparationProcessForJob(trackJobs[1], 40)  -- Larger segments for sequential
        multiTrackQueue.currentJobIndex = 1
    end

    -- Show progress window that monitors all jobs
    showMultiTrackProgressWindow()
end

-- Start a separation process for one job (no window, just background process)
-- segmentSize: optional, defaults to 25 for parallel, 40 for sequential
startSeparationProcessForJob = function(job, segmentSize)
    segmentSize = segmentSize or 25
    local logFile = job.trackDir .. PATH_SEP .. "separation_log.txt"
    local stdoutFile = job.trackDir .. PATH_SEP .. "stdout.txt"
    local doneFile = job.trackDir .. PATH_SEP .. "done.txt"

    job.stdoutFile = stdoutFile
    job.doneFile = doneFile
    job.logFile = logFile
    job.percent = 0
    job.stage = "Starting..."
    job.startTime = os.time()

    if OS == "Windows" then
        -- Create batch file to run Python with output redirection
        local batPath = job.trackDir .. PATH_SEP .. "run_separation.bat"
        local batFile = io.open(batPath, "w")
        if batFile then
            batFile:write('@echo off\n')
            batFile:write('"' .. PYTHON_PATH .. '" -u "' .. SEPARATOR_SCRIPT .. '" ')
            batFile:write('"' .. job.inputFile .. '" "' .. job.trackDir .. '" --model ' .. SETTINGS.model .. ' --segment-size ' .. segmentSize .. ' ')
            batFile:write('>"' .. stdoutFile .. '" 2>"' .. logFile .. '"\n')
            batFile:write('echo DONE >"' .. doneFile .. '"\n')
            batFile:close()
        end

        -- Create VBS to run batch file hidden
        local vbsPath = job.trackDir .. PATH_SEP .. "run_hidden.vbs"
        local vbsFile = io.open(vbsPath, "w")
        if vbsFile then
            vbsFile:write('CreateObject("WScript.Shell").Run """' .. batPath .. '""", 0, False\n')
            vbsFile:close()
        end

        -- Start the process
        if reaper.ExecProcess then
            reaper.ExecProcess('wscript "' .. vbsPath .. '"', -1)
        else
            local handle = io.popen('wscript "' .. vbsPath .. '"')
            if handle then handle:close() end
        end
    else
        -- macOS/Linux
        local cmd = '"' .. PYTHON_PATH .. '" -u "' .. SEPARATOR_SCRIPT .. '" '
        cmd = cmd .. '"' .. job.inputFile .. '" "' .. job.trackDir .. '" --model ' .. SETTINGS.model .. ' --segment-size ' .. segmentSize
        cmd = cmd .. ' >"' .. stdoutFile .. '" 2>"' .. logFile .. '" && echo DONE >"' .. doneFile .. '" &'
        os.execute(cmd)
    end
end

-- Update progress for all jobs from their stdout files
updateAllJobsProgress = function()
    for _, job in ipairs(multiTrackQueue.jobs) do
        -- Only check progress for jobs that have been started
        if job.startTime then
            local f = io.open(job.stdoutFile, "r")
            if f then
                local lastProgress = nil
                for line in f:lines() do
                    local percent, stage = line:match("PROGRESS:(%d+):(.+)")
                    if percent then
                        lastProgress = { percent = tonumber(percent), stage = stage }
                    end
                end
                f:close()
                if lastProgress then
                    job.percent = lastProgress.percent
                    job.stage = lastProgress.stage
                end
            end

            -- Check if done
            local doneFile = io.open(job.doneFile, "r")
            if doneFile then
                doneFile:close()
                if not job.done then
                    job.done = true
                    -- In sequential mode, start the next job when this one completes
                    if multiTrackQueue.sequentialMode then
                        local nextIndex = multiTrackQueue.currentJobIndex + 1
                        if nextIndex <= #multiTrackQueue.jobs then
                            local nextJob = multiTrackQueue.jobs[nextIndex]
                            startSeparationProcessForJob(nextJob, 40)  -- Larger segments for sequential
                            multiTrackQueue.currentJobIndex = nextIndex
                        end
                    end
                end
            end
        else
            -- Job not yet started (sequential mode)
            job.percent = 0
            job.stage = "Waiting..."
        end
    end
end

-- Check if all jobs are done
allJobsDone = function()
    for _, job in ipairs(multiTrackQueue.jobs) do
        if not job.done then return false end
    end
    return true
end

-- Calculate overall progress
getOverallProgress = function()
    local total = 0
    for _, job in ipairs(multiTrackQueue.jobs) do
        total = total + (job.percent or 0)
    end
    return math.floor(total / #multiTrackQueue.jobs)
end

-- Draw multi-track progress window
local function drawMultiTrackProgressWindow()
    local w, h = gfx.w, gfx.h

    -- Scale
    local scale = math.min(w / 480, h / 280)
    scale = math.max(0.5, math.min(4.0, scale))
    local function PS(val) return math.floor(val * scale + 0.5) end

    -- Solid background (matching main app)
    gfx.set(THEME.bg[1], THEME.bg[2], THEME.bg[3], 1)
    gfx.rect(0, 0, w, h, 1)

    -- Colored STEM border at top
    drawStemBorder(0, 0, w, 3)

    -- Title
    gfx.setfont(1, "Arial", PS(16), string.byte('b'))
    local modeStr = multiTrackQueue.sequentialMode and "Sequential" or "Parallel"
    local title = string.format("Multi-Track Separation - %s (%d tracks)", modeStr, #multiTrackQueue.jobs)
    gfx.set(THEME.text[1], THEME.text[2], THEME.text[3], 1)
    gfx.x = PS(20)
    gfx.y = PS(15)
    gfx.drawstr(title)

    -- Overall progress bar
    local barX = PS(20)
    local barY = PS(45)
    local barW = w - PS(40)
    local barH = PS(20)
    local overallProgress = getOverallProgress()

    -- Progress bar background
    gfx.set(THEME.inputBg[1], THEME.inputBg[2], THEME.inputBg[3], 1)
    gfx.rect(barX, barY, barW, barH, 1)
    gfx.set(THEME.border[1], THEME.border[2], THEME.border[3], 1)
    gfx.rect(barX, barY, barW, barH, 0)

    -- Progress fill
    local fillW = math.floor(barW * overallProgress / 100)
    if fillW > 0 then
        gfx.set(0.3, 0.65, 0.4, 1)
        gfx.rect(barX + 1, barY + 1, fillW - 2, barH - 2, 1)
    end

    -- Progress text
    gfx.setfont(1, "Arial", PS(11))
    gfx.set(1, 1, 1, 1)
    local progText = string.format("%d%%", overallProgress)
    local progW = gfx.measurestr(progText)
    gfx.x = barX + (barW - progW) / 2
    gfx.y = barY + PS(3)
    gfx.drawstr(progText)

    -- Individual track progress
    local trackY = PS(80)
    local trackSpacing = PS(30)

    gfx.setfont(1, "Arial", PS(10))
    for i, job in ipairs(multiTrackQueue.jobs) do
        local yPos = trackY + (i - 1) * trackSpacing

        -- Track name
        gfx.set(THEME.textDim[1], THEME.textDim[2], THEME.textDim[3], 1)
        gfx.x = barX
        gfx.y = yPos
        local displayName = job.trackName
        if #displayName > 20 then displayName = displayName:sub(1, 17) .. "..." end
        gfx.drawstr(displayName)

        -- Track progress bar
        local tBarX = barX + PS(120)
        local tBarW = barW - PS(150)
        local tBarH = PS(18)

        -- Progress bar background
        gfx.set(THEME.inputBg[1], THEME.inputBg[2], THEME.inputBg[3], 1)
        gfx.rect(tBarX, yPos, tBarW, tBarH, 1)
        gfx.set(THEME.border[1], THEME.border[2], THEME.border[3], 1)
        gfx.rect(tBarX, yPos, tBarW, tBarH, 0)

        -- Fill
        local tFillW = math.floor(tBarW * (job.percent or 0) / 100)
        if tFillW > 0 then
            -- Color based on stem being processed
            local stemIdx = (i - 1) % #STEMS + 1
            local stemColor = STEMS[stemIdx].color
            gfx.set(stemColor[1]/255, stemColor[2]/255, stemColor[3]/255, 0.85)
            gfx.rect(tBarX + 1, yPos + 1, tFillW - 2, tBarH - 2, 1)
        end

        -- Stage text inside progress bar
        if not job.done and job.stage and job.stage ~= "" then
            gfx.setfont(1, "Arial", PS(9))
            gfx.set(1, 1, 1, 0.95)
            local stageText = job.stage
            if #stageText > 35 then stageText = stageText:sub(1, 32) .. "..." end
            gfx.x = tBarX + PS(5)
            gfx.y = yPos + PS(3)
            gfx.drawstr(stageText)
        end

        -- Done checkmark or percentage
        gfx.setfont(1, "Arial", PS(10))
        if job.done then
            gfx.set(0.3, 0.75, 0.4, 1)
            gfx.x = tBarX + tBarW + PS(8)
            gfx.y = yPos + PS(2)
            gfx.drawstr("Done")
        else
            gfx.set(THEME.textDim[1], THEME.textDim[2], THEME.textDim[3], 1)
            gfx.x = tBarX + tBarW + PS(8)
            gfx.y = yPos + PS(2)
            gfx.drawstr(string.format("%d%%", job.percent or 0))
        end
    end

    -- Current processing info (positioned below progress bars)
    local numJobs = #multiTrackQueue.jobs
    local infoY = trackY + numJobs * trackSpacing + PS(8)  -- Below last progress bar

    -- Calculate stats
    local globalElapsed = os.time() - (multiTrackQueue.globalStartTime or os.time())
    local completedJobs = 0
    local activeJobs = 0
    local totalAudioDur = 0
    local completedAudioDur = 0
    local activeJob = nil

    -- Get system CPU, GPU, and Memory usage (Windows) - cached to avoid overhead
    local cpuUsage = nil
    local gpuUsage = nil
    local memUsage = nil
    if not multiTrackQueue.lastCpuCheck or (os.time() - multiTrackQueue.lastCpuCheck) >= 2 then
        local tempDir = os.getenv("TEMP")
        -- Query CPU via WMIC
        local cpuFile = tempDir .. "\\stemperator_cpu.txt"
        execHidden('wmic cpu get loadpercentage /value > "' .. cpuFile .. '"')
        local f = io.open(cpuFile, "r")
        if f then
            local content = f:read("*a")
            f:close()
            local load = content:match("LoadPercentage=(%d+)")
            if load then
                multiTrackQueue.cachedCpuUsage = tonumber(load)
            end
        end

        -- Query GPU usage via PowerShell (works for AMD and NVIDIA)
        local gpuFile = tempDir .. "\\stemperator_gpu.txt"
        local gpuCmd = 'powershell -NoProfile -Command "(Get-Counter \'\\GPU Engine(*engtype_3D)\\Utilization Percentage\' -ErrorAction SilentlyContinue).CounterSamples | Measure-Object -Property CookedValue -Sum | Select-Object -ExpandProperty Sum" > "' .. gpuFile .. '"'
        execHidden(gpuCmd)
        local gf = io.open(gpuFile, "r")
        if gf then
            local gpuContent = gf:read("*a")
            gf:close()
            local gpuLoad = gpuContent:match("(%d+)")
            if gpuLoad then
                multiTrackQueue.cachedGpuUsage = tonumber(gpuLoad)
            end
        end

        -- Query Memory usage via WMIC
        local memFile = tempDir .. "\\stemperator_mem.txt"
        execHidden('wmic OS get FreePhysicalMemory,TotalVisibleMemorySize /value > "' .. memFile .. '"')
        local mf = io.open(memFile, "r")
        if mf then
            local memContent = mf:read("*a")
            mf:close()
            local freeMem = memContent:match("FreePhysicalMemory=(%d+)")
            local totalMem = memContent:match("TotalVisibleMemorySize=(%d+)")
            if freeMem and totalMem then
                local freeKB = tonumber(freeMem)
                local totalKB = tonumber(totalMem)
                local usedKB = totalKB - freeKB
                multiTrackQueue.cachedMemUsage = math.floor(usedKB / totalKB * 100)
                multiTrackQueue.cachedMemUsedGB = usedKB / 1024 / 1024
                multiTrackQueue.cachedMemTotalGB = totalKB / 1024 / 1024
            end
        end

        multiTrackQueue.lastCpuCheck = os.time()
    end
    cpuUsage = multiTrackQueue.cachedCpuUsage
    gpuUsage = multiTrackQueue.cachedGpuUsage
    memUsage = multiTrackQueue.cachedMemUsage
    local memUsedGB = multiTrackQueue.cachedMemUsedGB
    local memTotalGB = multiTrackQueue.cachedMemTotalGB

    for _, job in ipairs(multiTrackQueue.jobs) do
        totalAudioDur = totalAudioDur + (job.audioDuration or 0)
        if job.done then
            completedJobs = completedJobs + 1
            completedAudioDur = completedAudioDur + (job.audioDuration or 0)
        elseif job.startTime then
            activeJobs = activeJobs + 1
            if not activeJob then activeJob = job end
            -- Estimate completed audio based on progress %
            completedAudioDur = completedAudioDur + (job.audioDuration or 0) * (job.percent or 0) / 100
        end
    end

    -- Calculate processing speed (realtime factor)
    local realtimeFactor = 0
    if globalElapsed > 5 and completedAudioDur > 0 then
        realtimeFactor = completedAudioDur / globalElapsed
    end

    -- Estimate ETA
    local eta = 0
    local remainingAudio = totalAudioDur - completedAudioDur
    if realtimeFactor > 0 then
        eta = remainingAudio / realtimeFactor
    elseif globalElapsed > 0 and overallProgress > 5 then
        -- Fallback: estimate from progress %
        local totalEstimate = globalElapsed * 100 / overallProgress
        eta = totalEstimate - globalElapsed
    end

    gfx.setfont(1, "Arial", PS(11))
    gfx.set(THEME.textDim[1], THEME.textDim[2], THEME.textDim[3], 1)

    -- Count expected stems
    local stemsPerTrack = SETTINGS.model == "htdemucs_6s" and 6 or 4
    local selectedStemCount = 0
    for _, stem in ipairs(STEMS) do
        if stem.selected then selectedStemCount = selectedStemCount + 1 end
    end
    local expectedStems = numJobs * selectedStemCount

    -- Line 1: Status overview
    local statusText = string.format("Tracks: %d/%d | Audio: %.1fs/%.1fs | Stems: %d expected",
        completedJobs, numJobs, completedAudioDur, totalAudioDur, expectedStems)
    gfx.x = barX
    gfx.y = infoY
    gfx.drawstr(statusText)

    -- Line 2: Speed and ETA
    local speedText = ""
    if realtimeFactor > 0 then
        speedText = string.format("Speed: %.2fx realtime", realtimeFactor)
    else
        speedText = "Speed: calculating..."
    end
    local etaText = ""
    if eta > 0 then
        local etaMins = math.floor(eta / 60)
        local etaSecs = math.floor(eta % 60)
        etaText = string.format(" | ETA: %d:%02d remaining", etaMins, etaSecs)
    end
    gfx.x = barX
    gfx.y = infoY + PS(16)
    gfx.drawstr(speedText .. etaText)

    -- Line 3: System resources (CPU, GPU, RAM)
    local sysText = "System: "
    if cpuUsage then
        sysText = sysText .. string.format("CPU %d%%", cpuUsage)
    end
    if gpuUsage then
        sysText = sysText .. string.format(" | GPU %d%%", gpuUsage)
    end
    if memUsedGB and memTotalGB then
        sysText = sysText .. string.format(" | RAM %.1f/%.1fGB", memUsedGB, memTotalGB)
    end
    gfx.x = barX
    gfx.y = infoY + PS(32)
    gfx.drawstr(sysText)

    -- Line 4: Current job info (if active)
    if activeJob then
        local jobElapsed = os.time() - (activeJob.startTime or os.time())
        local jobMins = math.floor(jobElapsed / 60)
        local jobSecs = jobElapsed % 60
        local audioDurStr = activeJob.audioDuration and string.format("%.1fs", activeJob.audioDuration) or "?"
        local infoText = string.format("Current: %s (%s) | %d:%02d elapsed",
            activeJob.trackName or "?",
            audioDurStr,
            jobMins, jobSecs)
        gfx.x = barX
        gfx.y = infoY + PS(48)
        gfx.drawstr(infoText)

        -- Line 5: Media item info
        local itemInfo = activeJob.itemNames or "Unknown"
        if #itemInfo > 55 then itemInfo = itemInfo:sub(1, 52) .. "..." end
        gfx.set(THEME.textHint[1], THEME.textHint[2], THEME.textHint[3], 1)
        gfx.x = barX
        gfx.y = infoY + PS(64)
        gfx.drawstr("Media: " .. itemInfo)
    end

    -- Bottom line: Total elapsed, model, segment and cancel hint
    local totalMins = math.floor(globalElapsed / 60)
    local totalSecs = globalElapsed % 60
    gfx.set(THEME.textHint[1], THEME.textHint[2], THEME.textHint[3], 1)
    gfx.setfont(1, "Arial", PS(10))
    gfx.x = PS(20)
    gfx.y = h - PS(20)
    local segSize = multiTrackQueue.sequentialMode and "40" or "25"
    local modeStr = multiTrackQueue.sequentialMode and "Seq" or "Par"
    gfx.drawstr(string.format("Time: %d:%02d | %s | Seg:%s | %s | ESC=cancel",
        totalMins, totalSecs, SETTINGS.model or "?", segSize, modeStr))

    -- flarkAUDIO logo at top (translucent) - "flark" regular, "AUDIO" bold
    gfx.setfont(1, "Arial", PS(10))
    local flarkPart = "flark"
    local flarkPartW = gfx.measurestr(flarkPart)
    gfx.setfont(1, "Arial", PS(10), string.byte('b'))
    local audioPart = "AUDIO"
    local audioPartW = gfx.measurestr(audioPart)
    local totalLogoW = flarkPartW + audioPartW
    local logoStartX = (w - totalLogoW) / 2
    -- Orange text, 50% translucent
    gfx.set(1.0, 0.5, 0.1, 0.5)
    gfx.setfont(1, "Arial", PS(10))
    gfx.x = logoStartX
    gfx.y = PS(3)
    gfx.drawstr(flarkPart)
    gfx.setfont(1, "Arial", PS(10), string.byte('b'))
    gfx.x = logoStartX + flarkPartW
    gfx.y = PS(3)
    gfx.drawstr(audioPart)

    gfx.update()

    -- Check for cancel
    local char = gfx.getchar()
    if char == -1 or char == 27 then
        return "cancel"
    end

    return nil
end

-- Multi-track progress window loop
local function multiTrackProgressLoop()
    -- Update all job progress
    updateAllJobsProgress()

    local result = drawMultiTrackProgressWindow()

    if result == "cancel" then
        gfx.quit()
        multiTrackQueue.active = false
        local mainHwnd = reaper.GetMainHwnd()
        if mainHwnd then reaper.JS_Window_SetFocus(mainHwnd) end
        showMessage("Cancelled", "Multi-track separation was cancelled.", "info")
        return
    end

    if allJobsDone() then
        gfx.quit()
        -- Process all results
        processAllStemsResult()
        return
    end

    reaper.defer(multiTrackProgressLoop)
end

-- Show multi-track progress window
showMultiTrackProgressWindow = function()
    -- Load settings to get current theme
    loadSettings()
    updateTheme()

    -- Use saved dialog size/position like other windows
    -- Increased height for stats display (5 lines of info + track bars)
    local winW = lastDialogW or 480
    local winH = lastDialogH or 460

    local winX, winY
    if lastDialogX and lastDialogY then
        winX = lastDialogX
        winY = lastDialogY
    else
        local mouseX, mouseY = reaper.GetMousePosition()
        winX = mouseX - winW / 2
        winY = mouseY - winH / 2
        winX, winY = clampToScreen(winX, winY, winW, winH, mouseX, mouseY)
    end

    gfx.init("Stemperator - Multi-Track Progress", winW, winH, 0, winX, winY)
    reaper.defer(multiTrackProgressLoop)
end

-- Process all stems after parallel jobs complete
processAllStemsResult = function()
    reaper.Undo_BeginBlock()

    -- Handle mute/delete options FIRST (before creating stems)
    local actionMsg = ""
    local actionCount = 0

    -- Collect all source items from all jobs
    local allItems = {}
    for _, job in ipairs(multiTrackQueue.jobs) do
        if job.sourceItems then
            for _, item in ipairs(job.sourceItems) do
                table.insert(allItems, item)
            end
        elseif job.sourceItem then
            table.insert(allItems, job.sourceItem)
        end
    end

    -- Skip item-level processing if deleteOriginalTrack is set (tracks will be deleted after stems created)
    if SETTINGS.deleteOriginalTrack then
        -- Do nothing here - track deletion happens after stems are created
    elseif SETTINGS.muteOriginal then
        -- Mute all source items from all jobs
        for _, item in ipairs(allItems) do
            if reaper.ValidatePtr(item, "MediaItem*") then
                reaper.SetMediaItemInfo_Value(item, "B_MUTE", 1)
                actionCount = actionCount + 1
            end
        end
        local itemWord = actionCount == 1 and "item" or "items"
        actionMsg = "\n" .. actionCount .. " " .. itemWord .. " muted."
    elseif SETTINGS.muteSelection then
        -- Mute selection portion of all source items
        -- Process in reverse order to avoid item index shifting issues
        for i = #allItems, 1, -1 do
            local item = allItems[i]
            if reaper.ValidatePtr(item, "MediaItem*") then
                local itemTrack = reaper.GetMediaItem_Track(item)
                if itemTrack then
                    local itemPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
                    local itemLen = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
                    local itemEnd = itemPos + itemLen

                    -- Only process if item overlaps time selection
                    if itemPos < timeSelectionEnd and itemEnd > timeSelectionStart then
                        -- Split at selection boundaries if needed
                        local splitStart = math.max(itemPos, timeSelectionStart)
                        local splitEnd = math.min(itemEnd, timeSelectionEnd)

                        -- Split at start of selection (if not at item start)
                        local middleItem = item
                        if splitStart > itemPos + 0.001 then
                            middleItem = reaper.SplitMediaItem(item, splitStart)
                        end

                        -- Split at end of selection (if not at item end)
                        if middleItem then
                            -- Get middleItem's actual end position after first split
                            local middlePos = reaper.GetMediaItemInfo_Value(middleItem, "D_POSITION")
                            local middleLen = reaper.GetMediaItemInfo_Value(middleItem, "D_LENGTH")
                            local middleEnd = middlePos + middleLen

                            if splitEnd < middleEnd - 0.001 then
                                reaper.SplitMediaItem(middleItem, splitEnd)
                            end
                        end

                        -- Mute the middle part (now 'middleItem' is the selection portion)
                        if middleItem then
                            reaper.SetMediaItemInfo_Value(middleItem, "B_MUTE", 1)
                            actionCount = actionCount + 1
                        end
                    end
                end
            end
        end
        local itemWord = actionCount == 1 and "item" or "items"
        actionMsg = "\nSelection muted in " .. actionCount .. " " .. itemWord .. "."
    elseif SETTINGS.deleteOriginal then
        -- Delete all source items from all jobs
        -- Process in reverse order to avoid index shifting issues
        for i = #allItems, 1, -1 do
            local item = allItems[i]
            if reaper.ValidatePtr(item, "MediaItem*") then
                local itemTrack = reaper.GetMediaItem_Track(item)
                if itemTrack then
                    reaper.DeleteTrackMediaItem(itemTrack, item)
                    actionCount = actionCount + 1
                end
            end
        end
        local itemWord = actionCount == 1 and "item" or "items"
        actionMsg = "\n" .. actionCount .. " " .. itemWord .. " deleted."
    elseif SETTINGS.deleteSelection then
        -- Delete selection portion of all source items
        -- Process in reverse order to avoid item index shifting issues
        for i = #allItems, 1, -1 do
            local item = allItems[i]
            if reaper.ValidatePtr(item, "MediaItem*") then
                local itemTrack = reaper.GetMediaItem_Track(item)
                if itemTrack then
                    local itemPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
                    local itemLen = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
                    local itemEnd = itemPos + itemLen

                    -- Only process if item overlaps time selection
                    if itemPos < timeSelectionEnd and itemEnd > timeSelectionStart then
                        local splitStart = math.max(itemPos, timeSelectionStart)
                        local splitEnd = math.min(itemEnd, timeSelectionEnd)

                        -- Split at start of selection (if not at item start)
                        local middleItem = item
                        if splitStart > itemPos + 0.001 then
                            middleItem = reaper.SplitMediaItem(item, splitStart)
                        end

                        -- Split at end of selection (if not at item end)
                        if middleItem then
                            -- Get middleItem's actual end position after first split
                            local middlePos = reaper.GetMediaItemInfo_Value(middleItem, "D_POSITION")
                            local middleLen = reaper.GetMediaItemInfo_Value(middleItem, "D_LENGTH")
                            local middleEnd = middlePos + middleLen

                            if splitEnd < middleEnd - 0.001 then
                                reaper.SplitMediaItem(middleItem, splitEnd)
                            end
                        end

                        -- Delete the middle part
                        if middleItem then
                            local middleTrack = reaper.GetMediaItem_Track(middleItem)
                            if middleTrack then
                                reaper.DeleteTrackMediaItem(middleTrack, middleItem)
                                actionCount = actionCount + 1
                            end
                        end
                    end
                end
            end
        end
        local itemWord = actionCount == 1 and "item" or "items"
        actionMsg = "\nSelection deleted from " .. actionCount .. " " .. itemWord .. "."
    end

    -- Now create stems for each job
    local totalStemsCreated = 0
    local trackNames = {}

    debugLog("=== processAllStemsResult: Creating stem tracks ===")
    debugLog("Number of jobs: " .. #multiTrackQueue.jobs)
    debugLog("itemPos: " .. tostring(itemPos) .. ", itemLen: " .. tostring(itemLen))
    debugLog("createNewTracks: " .. tostring(SETTINGS.createNewTracks))

    local is6Stem = (SETTINGS.model == "htdemucs_6s")

    for jobIdx, job in ipairs(multiTrackQueue.jobs) do
        debugLog("Job " .. jobIdx .. ": trackDir=" .. tostring(job.trackDir))
        -- Find stem files in job directory
        local stems = {}
        local selectedCount = 0
        local foundCount = 0
        for _, stem in ipairs(STEMS) do
            -- Skip 6-stem-only stems if not using 6-stem model
            local stemApplies = stem.selected and (not stem.sixStemOnly or is6Stem)
            if stemApplies then
                selectedCount = selectedCount + 1
                local stemPath = job.trackDir .. PATH_SEP .. stem.name:lower() .. ".wav"
                local f = io.open(stemPath, "r")
                if f then
                    f:close()
                    stems[stem.name:lower()] = stemPath
                    foundCount = foundCount + 1
                    debugLog("  Found stem: " .. stem.name:lower() .. " at " .. stemPath)
                else
                    debugLog("  MISSING stem: " .. stem.name:lower() .. " at " .. stemPath)
                end
            end
        end
        debugLog("  Selected stems: " .. selectedCount .. ", Found: " .. foundCount)

        -- Create stems based on output mode
        if next(stems) then
            if SETTINGS.createNewTracks then
                -- New tracks mode: create separate tracks for each stem
                debugLog("  Calling createStemTracksForSelection...")
                local count = createStemTracksForSelection(stems, itemPos, itemLen, job.track)
                debugLog("  Created " .. count .. " stem tracks")
                totalStemsCreated = totalStemsCreated + count
            else
                -- In-place mode: replace source item with stems as takes
                -- Note: We only replace the primary source item (job.sourceItem) because
                -- the stems were extracted from that item's audio. Other items in sourceItems
                -- are tracked for mute/delete operations but not for in-place replacement.
                debugLog("  In-place mode: processing source item...")
                local sourceItem = job.sourceItem
                if sourceItem and reaper.ValidatePtr(sourceItem, "MediaItem*") then
                    local srcItemPos = reaper.GetMediaItemInfo_Value(sourceItem, "D_POSITION")
                    local srcItemLen = reaper.GetMediaItemInfo_Value(sourceItem, "D_LENGTH")
                    debugLog("  Replacing item at pos=" .. srcItemPos .. ", len=" .. srcItemLen)
                    local count = replaceInPlace(sourceItem, stems, srcItemPos, srcItemLen)
                    debugLog("  Replaced with " .. count .. " stems as takes")
                    totalStemsCreated = totalStemsCreated + count
                else
                    debugLog("  ERROR: No valid source item for in-place replacement")
                end
            end
            table.insert(trackNames, job.trackName)
        else
            debugLog("  No stems found, skipping")
        end
    end
    debugLog("Total stems created: " .. totalStemsCreated)

    -- Handle deleteOriginalTrack AFTER stems are created (deletes entire source tracks)
    if SETTINGS.deleteOriginalTrack then
        -- Collect unique tracks from jobs (delete in reverse order to avoid index issues)
        local tracksToDelete = {}
        for _, job in ipairs(multiTrackQueue.jobs) do
            if job.track and reaper.ValidatePtr(job.track, "MediaTrack*") then
                -- Check if track is not already in list
                local found = false
                for _, t in ipairs(tracksToDelete) do
                    if t == job.track then found = true; break end
                end
                if not found then
                    table.insert(tracksToDelete, job.track)
                end
            end
        end
        -- Delete tracks in reverse order (higher indices first)
        for i = #tracksToDelete, 1, -1 do
            local track = tracksToDelete[i]
            if reaper.ValidatePtr(track, "MediaTrack*") then
                reaper.DeleteTrack(track)
                actionCount = actionCount + 1
            end
        end
        local trackWord = actionCount == 1 and "track" or "tracks"
        actionMsg = "\n" .. actionCount .. " source " .. trackWord .. " deleted."
    end

    reaper.Undo_EndBlock("Stemperator: Multi-track stem separation", -1)
    reaper.UpdateArrange()

    -- Calculate total processing time
    local totalTime = os.time() - (multiTrackQueue.globalStartTime or os.time())
    local totalMins = math.floor(totalTime / 60)
    local totalSecs = totalTime % 60

    -- Calculate total audio duration processed
    local totalAudioDur = 0
    for _, job in ipairs(multiTrackQueue.jobs) do
        totalAudioDur = totalAudioDur + (job.audioDuration or 0)
    end

    -- Calculate realtime factor
    local realtimeFactor = totalAudioDur > 0 and (totalAudioDur / totalTime) or 0

    -- Log benchmark result
    local modeStr = multiTrackQueue.sequentialMode and "Sequential" or "Parallel"
    local segSize = multiTrackQueue.sequentialMode and "40" or "25"
    local benchmarkLog = os.getenv("TEMP") .. "\\stemperator_benchmark.txt"
    local bf = io.open(benchmarkLog, "a")
    if bf then
        bf:write(string.format("\n=== Benchmark Result ===\n"))
        bf:write(string.format("Date: %s\n", os.date("%Y-%m-%d %H:%M:%S")))
        bf:write(string.format("Mode: %s (segment size: %s)\n", modeStr, segSize))
        bf:write(string.format("Model: %s\n", SETTINGS.model or "?"))
        bf:write(string.format("Tracks: %d\n", #multiTrackQueue.jobs))
        bf:write(string.format("Audio duration: %.1fs\n", totalAudioDur))
        bf:write(string.format("Processing time: %d:%02d (%ds)\n", totalMins, totalSecs, totalTime))
        bf:write(string.format("Speed: %.2fx realtime\n", realtimeFactor))
        bf:write(string.format("Stems created: %d\n", totalStemsCreated))
        bf:write("========================\n")
        bf:close()
    end

    multiTrackQueue.active = false

    -- Show result
    local selectedStemData = {}
    local is6Stem = (SETTINGS.model == "htdemucs_6s")
    for _, stem in ipairs(STEMS) do
        if stem.selected and (not stem.sixStemOnly or is6Stem) then
            table.insert(selectedStemData, stem)
        end
    end

    local timeStr = string.format("%d:%02d", totalMins, totalSecs)
    local speedStr = string.format("%.2fx", realtimeFactor)
    local resultMsg
    if SETTINGS.createNewTracks then
        local trackWord = totalStemsCreated == 1 and "track" or "tracks"
        resultMsg = string.format("%d stem %s created from %d source tracks.\nTime: %s | Speed: %s realtime | Mode: %s%s",
            totalStemsCreated, trackWord, #multiTrackQueue.jobs, timeStr, speedStr, modeStr, actionMsg)
    else
        local itemWord = #multiTrackQueue.jobs == 1 and "item" or "items"
        resultMsg = string.format("%d %s replaced with stems as takes.\nTime: %s | Speed: %s realtime | Mode: %s%s",
            #multiTrackQueue.jobs, itemWord, timeStr, speedStr, modeStr, actionMsg)
    end
    showResultWindow(selectedStemData, resultMsg)
end

-- Separation workflow
function runSeparationWorkflow()
    debugLog("=== runSeparationWorkflow started ===")

    -- Save playback state to restore after processing
    savedPlaybackState = reaper.GetPlayState()
    debugLog("Saved playback state: " .. savedPlaybackState)

    -- Re-fetch the current selection at processing time (user may have changed it)
    selectedItem = reaper.GetSelectedMediaItem(0, 0)
    timeSelectionMode = false
    debugLog("Selected item: " .. tostring(selectedItem))

    -- If no items selected but tracks are selected (and no time selection),
    -- auto-select all items on those tracks
    if not selectedItem and not hasTimeSelection() and reaper.CountSelectedTracks(0) > 0 then
        debugLog("No items/time selection, but tracks selected - auto-selecting items on tracks")
        for t = 0, reaper.CountSelectedTracks(0) - 1 do
            local track = reaper.GetSelectedTrack(0, t)
            local numItems = reaper.CountTrackMediaItems(track)
            for i = 0, numItems - 1 do
                local item = reaper.GetTrackMediaItem(track, i)
                reaper.SetMediaItemSelected(item, true)
            end
        end
        reaper.UpdateArrange()
        selectedItem = reaper.GetSelectedMediaItem(0, 0)
        debugLog("After auto-select, selected item: " .. tostring(selectedItem))
    end

    -- Time selection takes priority over item selection
    -- This allows processing a specific region regardless of which item is selected
    if hasTimeSelection() then
        timeSelectionMode = true
        timeSelectionStart, timeSelectionEnd = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
        itemPos = timeSelectionStart
        itemLen = timeSelectionEnd - timeSelectionStart
        debugLog("Time selection mode: " .. timeSelectionStart .. " to " .. timeSelectionEnd)
    elseif selectedItem then
        -- No time selection, use selected item
        itemPos = reaper.GetMediaItemInfo_Value(selectedItem, "D_POSITION")
        itemLen = reaper.GetMediaItemInfo_Value(selectedItem, "D_LENGTH")
    else
        -- No time selection and no item selected (and no track with items)
        showMessage("Start", "Please select a media item, track, or make a time selection to separate.", "info")
        return
    end

    workflowTempDir = getTempDir() .. PATH_SEP .. "stemperator_" .. os.time()
    makeDir(workflowTempDir)
    workflowTempInput = workflowTempDir .. PATH_SEP .. "input.wav"
    debugLog("Temp dir: " .. workflowTempDir)
    debugLog("Temp input: " .. workflowTempInput)

    local extracted, err, sourceItem, trackList, trackItems
    if timeSelectionMode then
        debugLog("Rendering time selection to WAV...")
        extracted, err, sourceItem, trackList, trackItems = renderTimeSelectionToWav(workflowTempInput)
        debugLog("Render result: extracted=" .. tostring(extracted) .. ", err=" .. tostring(err))

        -- Check for multi-track mode
        if err == "MULTI_TRACK" and trackList and #trackList > 1 then
            -- Multi-track mode: process all tracks in parallel
            debugLog("Multi-track mode: " .. #trackList .. " tracks")
            runSingleTrackSeparation(trackList)
            return
        end

        timeSelectionSourceItem = sourceItem  -- Store for later use
    else
        -- No time selection - check if we have multiple items selected (multi-track mode)
        local selItemCount = reaper.CountSelectedMediaItems(0)
        debugLog("No time selection, selected items: " .. selItemCount)

        if selItemCount > 1 then
            -- Multiple items selected - group by track and use multi-track mode
            local trackItems = {}  -- track -> list of items
            for i = 0, selItemCount - 1 do
                local item = reaper.GetSelectedMediaItem(0, i)
                local track = reaper.GetMediaItem_Track(item)
                if not trackItems[track] then
                    trackItems[track] = {}
                end
                table.insert(trackItems[track], item)
            end

            -- Build track list
            local trackList = {}
            for track in pairs(trackItems) do
                table.insert(trackList, track)
            end

            debugLog("Multi-item mode: " .. #trackList .. " tracks with items")
            runSingleTrackSeparation(trackList)
            return
        end

        -- Single item mode
        local origItemPos = reaper.GetMediaItemInfo_Value(selectedItem, "D_POSITION")
        local origItemLen = reaper.GetMediaItemInfo_Value(selectedItem, "D_LENGTH")

        extracted, err = renderItemToWav(selectedItem, workflowTempInput)
        -- Check if we rendered a sub-selection (not the whole item)
        local renderPos, renderLen = nil, nil  -- These would come from renderItemToWav if supported
        if renderPos and renderLen then
            itemPos = renderPos
            itemLen = renderLen
            -- Detect if this is a sub-selection
            if math.abs(renderPos - origItemPos) > 0.001 or math.abs(renderLen - origItemLen) > 0.001 then
                itemSubSelection = true
                itemSubSelStart = renderPos
                itemSubSelEnd = renderPos + renderLen
            else
                itemSubSelection = false
            end
        end
    end

    if not extracted then
        debugLog("Extraction FAILED: " .. (err or "Unknown"))
        showMessage("Extraction Failed", "Failed to extract audio: " .. (err or "Unknown"), "error")
        return
    end

    debugLog("Extraction successful, starting separation...")
    debugLog("Model: " .. SETTINGS.model)
    -- Start separation with progress UI (async)
    runSeparationWithProgress(workflowTempInput, workflowTempDir, SETTINGS.model)
    debugLog("runSeparationWithProgress called")
end

-- Check for quick preset mode (called from toolbar scripts)
local function checkQuickPreset()
    local quickRun = reaper.GetExtState(EXT_SECTION, "quick_run")
    if quickRun == "1" then
        -- Clear the flag
        reaper.DeleteExtState(EXT_SECTION, "quick_run", false)

        -- Apply preset based on quick_preset
        local preset = reaper.GetExtState(EXT_SECTION, "quick_preset")
        reaper.DeleteExtState(EXT_SECTION, "quick_preset", false)

        if preset == "karaoke" or preset == "instrumental" then
            applyPresetKaraoke()
        elseif preset == "vocals" then
            applyPresetVocalsOnly()
        elseif preset == "drums" then
            applyPresetDrumsOnly()
        elseif preset == "bass" then
            STEMS[1].selected = false
            STEMS[2].selected = false
            STEMS[3].selected = true
            STEMS[4].selected = false
        elseif preset == "all" then
            applyPresetAll()
        end

        return true  -- Quick mode, skip dialog
    end
    return false
end

-- Main
main = function()
    -- Load settings first (needed for window position in error messages)
    loadSettings()

    selectedItem = reaper.GetSelectedMediaItem(0, 0)
    timeSelectionMode = false
    autoSelectedItems = {}  -- Reset auto-selected items tracking
    autoSelectionTracks = {}  -- Reset auto-selection tracks tracking

    -- If no items selected but tracks are selected (and no time selection),
    -- auto-select all items on those tracks
    if not selectedItem and not hasTimeSelection() and reaper.CountSelectedTracks(0) > 0 then
        for t = 0, reaper.CountSelectedTracks(0) - 1 do
            local track = reaper.GetSelectedTrack(0, t)
            table.insert(autoSelectionTracks, track)  -- Track this track for potential restore
            local numItems = reaper.CountTrackMediaItems(track)
            for i = 0, numItems - 1 do
                local item = reaper.GetTrackMediaItem(track, i)
                reaper.SetMediaItemSelected(item, true)
                table.insert(autoSelectedItems, item)  -- Track this item for potential restore
            end
        end
        reaper.UpdateArrange()
        selectedItem = reaper.GetSelectedMediaItem(0, 0)
    end

    -- Time selection takes priority over item selection
    -- This allows processing a specific region regardless of which item is selected
    if hasTimeSelection() then
        timeSelectionMode = true
        timeSelectionStart, timeSelectionEnd = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
        itemPos = timeSelectionStart
        itemLen = timeSelectionEnd - timeSelectionStart
    elseif selectedItem then
        -- No time selection, use selected item
        itemPos = reaper.GetMediaItemInfo_Value(selectedItem, "D_POSITION")
        itemLen = reaper.GetMediaItemInfo_Value(selectedItem, "D_LENGTH")
    else
        -- No time selection, no item selected, no track with items
        -- Enable selection monitoring so dialog auto-opens when user makes a selection
        showMessage("Start", "Please select a media item, track, or make a time selection to separate.", "info", true)
        return
    end

    -- Check for quick preset mode (from toolbar scripts)
    if checkQuickPreset() then
        -- Quick mode: run immediately without dialog
        saveSettings()
        reaper.defer(runSeparationWorkflow)
    else
        -- Normal mode: show dialog
        showStemSelectionDialog()
    end
end

main()
