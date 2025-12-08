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

local SCRIPT_NAME = "Stemperator: AI Stem Separation"
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
    { id = "htdemucs", name = "Fast (htdemucs)", desc = "4 stems, fastest" },
    { id = "htdemucs_ft", name = "Quality (htdemucs_ft)", desc = "4 stems, best quality" },
    { id = "htdemucs_6s", name = "6-Stem (guitar/piano)", desc = "6 stems, includes guitar & piano" },
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
    -- Scaling
    baseW = 380,
    baseH = 340,
    minW = 380,
    minH = 340,
    maxW = 1520,  -- Up to 4x scale
    maxH = 1360,
    scale = 1.0,
}

-- Store last dialog position for subsequent windows (progress, result, messages)
local lastDialogX, lastDialogY, lastDialogW, lastDialogH = nil, nil, 380, 340

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
    -- Instrumental only (no vocals)
    STEMS[1].selected = false  -- Vocals OFF
    STEMS[2].selected = true   -- Drums
    STEMS[3].selected = true   -- Bass
    STEMS[4].selected = true   -- Other
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
end

local function applyPresetVocalsOnly()
    STEMS[1].selected = true   -- Vocals ONLY
    STEMS[2].selected = false  -- Drums
    STEMS[3].selected = false  -- Bass
    STEMS[4].selected = false  -- Other
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
}

-- Draw message window (replaces reaper.MB for proper positioning)
local function drawMessageWindow()
    local w, h = gfx.w, gfx.h
    local time = os.clock()
    local elapsed = time - messageWindowState.startTime

    -- Calculate scale based on window size
    local scale = math.min(w / 380, h / 340)
    scale = math.max(0.5, math.min(4.0, scale))
    local function PS(val) return math.floor(val * scale + 0.5) end

    -- Determine icon colors for theming
    local iconColor, bgTint
    if messageWindowState.icon == "error" then
        iconColor = {0.8, 0.2, 0.2}
        bgTint = {0.05, 0, 0}
    elseif messageWindowState.icon == "warning" then
        iconColor = {0.9, 0.7, 0.1}
        bgTint = {0.03, 0.02, 0}
    else
        iconColor = {0.3, 0.5, 0.8}
        bgTint = {0, 0.01, 0.03}
    end

    -- Gradient background based on theme
    local bgPulse = 0.01 * math.sin(time * 0.5)
    for y = 0, h do
        local t = y / h
        local baseR = THEME.bgGradientTop[1] * (1-t) + THEME.bgGradientBottom[1] * t
        local baseG = THEME.bgGradientTop[2] * (1-t) + THEME.bgGradientBottom[2] * t
        local baseB = THEME.bgGradientTop[3] * (1-t) + THEME.bgGradientBottom[3] * t
        gfx.set(baseR + bgTint[1] + bgPulse, baseG + bgTint[2] + bgPulse, baseB + bgTint[3] + bgPulse, 1)
        gfx.line(0, y, w, y)
    end

    -- Subtle animated particles in background
    for i = 1, 8 do
        local px = (w * 0.2) + (i * w * 0.1) + math.sin(time * 0.5 + i) * 20
        local py = h * 0.3 + math.cos(time * 0.3 + i * 0.5) * 30
        local alpha = 0.05 + 0.03 * math.sin(time * 2 + i)
        gfx.set(iconColor[1], iconColor[2], iconColor[3], alpha)
        gfx.circle(px, py, PS(3 + math.sin(time + i) * 2), 1, 1)
    end

    -- Icon with animated glow
    local iconX = w / 2
    local iconY = PS(60)
    local iconR = PS(28)
    local pulseScale = 1 + 0.03 * math.sin(time * 3)
    local glowPulse = 0.2 + 0.15 * math.sin(time * 2)

    -- Outer glow
    gfx.set(iconColor[1], iconColor[2], iconColor[3], glowPulse * 0.4)
    gfx.circle(iconX, iconY, iconR * 1.4 * pulseScale, 1, 1)

    if messageWindowState.icon == "error" then
        -- Red circle with animated X
        for r = iconR, 0, -1 do
            local gradientFactor = 0.5 + 0.5 * (r / iconR)
            gfx.set(iconColor[1] * gradientFactor, iconColor[2] * gradientFactor, iconColor[3] * gradientFactor, 1)
            gfx.circle(iconX, iconY, r * pulseScale, 1, 1)
        end

        -- Animated X (shake effect on appear)
        local shake = math.max(0, (0.3 - elapsed) * 5) * math.sin(elapsed * 50)
        gfx.set(1, 1, 1, 1)
        local xOff = shake
        gfx.line(iconX - PS(10) + xOff, iconY - PS(10), iconX + PS(10) + xOff, iconY + PS(10))
        gfx.line(iconX - PS(10) + xOff, iconY + PS(10), iconX + PS(10) + xOff, iconY - PS(10))
        gfx.line(iconX - PS(9) + xOff, iconY - PS(10), iconX + PS(11) + xOff, iconY + PS(10))
        gfx.line(iconX - PS(9) + xOff, iconY + PS(10), iconX + PS(11) + xOff, iconY - PS(10))

    elseif messageWindowState.icon == "warning" then
        -- Yellow triangle with ! (animated)
        local bounce = math.max(0, (0.5 - elapsed) * 3) * math.abs(math.sin(elapsed * 8))
        local triH = PS(48)
        local triW = PS(52)
        local triY = iconY - bounce * 5

        -- Triangle glow
        gfx.set(iconColor[1], iconColor[2], iconColor[3], 0.3)
        gfx.triangle(iconX, triY - triH/2 - 3, iconX - triW/2 - 3, triY + triH/2 + 3, iconX + triW/2 + 3, triY + triH/2 + 3)

        -- Main triangle with gradient
        for i = 0, PS(4) do
            local fade = 1 - i / PS(8)
            gfx.set(iconColor[1] * fade, iconColor[2] * fade, iconColor[3] * fade, 1)
            gfx.triangle(iconX, triY - triH/2 + i, iconX - triW/2 + i, triY + triH/2, iconX + triW/2 - i, triY + triH/2)
        end

        -- Exclamation mark
        gfx.set(0.1, 0.1, 0.1, 1)
        gfx.setfont(1, "Arial", PS(26), string.byte('b'))
        local exW = gfx.measurestr("!")
        gfx.x = iconX - exW/2
        gfx.y = triY - PS(5)
        gfx.drawstr("!")

    else
        -- Info: Blue circle with i (pulsing)
        for r = iconR, 0, -1 do
            local gradientFactor = 0.4 + 0.6 * (r / iconR)
            gfx.set(iconColor[1] * gradientFactor, iconColor[2] * gradientFactor, iconColor[3] * gradientFactor, 1)
            gfx.circle(iconX, iconY, r * pulseScale, 1, 1)
        end

        gfx.set(1, 1, 1, 1)
        gfx.setfont(1, "Arial", PS(24), string.byte('b'))
        local iW = gfx.measurestr("i")
        gfx.x = iconX - iW/2
        gfx.y = iconY - PS(10)
        gfx.drawstr("i")
    end

    -- Title with glow effect
    gfx.setfont(1, "Arial", PS(18), string.byte('b'))
    local titleW = gfx.measurestr(messageWindowState.title)

    -- Title glow
    local titleGlow = 0.2 + 0.1 * math.sin(time * 2)
    gfx.set(iconColor[1], iconColor[2], iconColor[3], titleGlow)
    gfx.x = (w - titleW) / 2 + 1
    gfx.y = PS(105) + 1
    gfx.drawstr(messageWindowState.title)

    -- Main title
    gfx.set(THEME.text[1], THEME.text[2], THEME.text[3], 1)
    gfx.x = (w - titleW) / 2
    gfx.y = PS(105)
    gfx.drawstr(messageWindowState.title)

    -- Message box background
    local msgBgAlpha = SETTINGS.darkMode and 0.7 or 0.15
    gfx.set(THEME.checkbox[1], THEME.checkbox[2], THEME.checkbox[3], msgBgAlpha)
    gfx.rect(PS(25), PS(135), w - PS(50), PS(80), 1)

    -- Message (multi-line support)
    gfx.set(THEME.text[1] * 0.85, THEME.text[2] * 0.85, THEME.text[3] * 0.85, 1)
    gfx.setfont(1, "Arial", PS(12))
    local msgY = PS(150)
    local maxLineWidth = w - PS(60)

    -- Simple word wrap
    local words = {}
    for word in messageWindowState.message:gmatch("%S+") do
        table.insert(words, word)
    end

    local currentLine = ""
    local lineCount = 0
    for i, word in ipairs(words) do
        local testLine = currentLine == "" and word or (currentLine .. " " .. word)
        if gfx.measurestr(testLine) > maxLineWidth then
            local lineW = gfx.measurestr(currentLine)
            gfx.x = (w - lineW) / 2
            gfx.y = msgY
            gfx.drawstr(currentLine)
            msgY = msgY + PS(16)
            lineCount = lineCount + 1
            currentLine = word
        else
            currentLine = testLine
        end
    end
    if currentLine ~= "" then
        local lineW = gfx.measurestr(currentLine)
        gfx.x = (w - lineW) / 2
        gfx.y = msgY
        gfx.drawstr(currentLine)
    end

    -- OK button with hover effect
    local btnW = PS(100)
    local btnH = PS(32)
    local btnX = (w - btnW) / 2
    local btnY = h - PS(70)

    local mx, my = gfx.mouse_x, gfx.mouse_y
    local hover = mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH
    local mouseDown = gfx.mouse_cap & 1 == 1

    -- Button glow on hover
    if hover then
        gfx.set(iconColor[1], iconColor[2], iconColor[3], 0.3)
        gfx.rect(btnX - 3, btnY - 3, btnW + 6, btnH + 6, 1)
        gfx.set(iconColor[1] * 0.8 + 0.2, iconColor[2] * 0.8 + 0.2, iconColor[3] * 0.8 + 0.2, 1)
    else
        gfx.set(iconColor[1] * 0.6 + 0.1, iconColor[2] * 0.6 + 0.1, iconColor[3] * 0.6 + 0.1, 1)
    end
    gfx.rect(btnX, btnY, btnW, btnH, 1)

    -- Button border
    gfx.set(iconColor[1] * 0.8 + 0.2, iconColor[2] * 0.8 + 0.2, iconColor[3] * 0.8 + 0.2, 0.8)
    gfx.rect(btnX, btnY, btnW, btnH, 0)

    -- Button text
    gfx.set(1, 1, 1, 1)
    gfx.setfont(1, "Arial", PS(14), string.byte('b'))
    local okText = "OK"
    local okW = gfx.measurestr(okText)
    gfx.x = btnX + (btnW - okW) / 2
    gfx.y = btnY + (btnH - PS(14)) / 2
    gfx.drawstr(okText)

    -- Hint
    gfx.set(THEME.textHint[1], THEME.textHint[2], THEME.textHint[3], 1)
    gfx.setfont(1, "Arial", PS(9))
    local hint = "Press Enter, Space, or ESC to close"
    local hintW = gfx.measurestr(hint)
    gfx.x = (w - hintW) / 2
    gfx.y = h - PS(25)
    gfx.drawstr(hint)

    gfx.update()

    -- Check for click on OK button
    if hover and mouseDown and not messageWindowState.wasMouseDown then
        return true  -- Close
    end

    messageWindowState.wasMouseDown = mouseDown

    local char = gfx.getchar()
    if char == -1 or char == 27 or char == 13 or char == 32 then
        return true  -- Close
    end

    return false  -- Keep open
end

-- Message window loop
local function messageWindowLoop()
    if drawMessageWindow() then
        gfx.quit()
        -- Return focus to REAPER main window
        local mainHwnd = reaper.GetMainHwnd()
        if mainHwnd then
            reaper.JS_Window_SetFocus(mainHwnd)
        end
        return
    end
    reaper.defer(messageWindowLoop)
end

-- Show a styled message window (replacement for reaper.MB)
-- icon: "info", "warning", "error"
local function showMessage(title, message, icon)
    messageWindowState.title = title or "Stemperator"
    messageWindowState.message = message or ""
    messageWindowState.icon = icon or "info"
    messageWindowState.wasMouseDown = false
    messageWindowState.startTime = os.clock()

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

-- Draw a checkbox and return if it was clicked (scaled)
local function drawCheckbox(x, y, checked, label, r, g, b)
    local boxSize = S(18)
    local clicked = false
    local labelWidth = gfx.measurestr(label)
    local totalWidth = boxSize + S(8) + labelWidth
    local mx, my = gfx.mouse_x, gfx.mouse_y
    local mouseDown = gfx.mouse_cap & 1 == 1

    if mouseDown and mx >= x and mx <= x + totalWidth and my >= y and my <= y + boxSize then
        if not GUI.wasMouseDown then clicked = true end
    end

    if checked then
        gfx.set(THEME.checkboxChecked[1], THEME.checkboxChecked[2], THEME.checkboxChecked[3], 1)
    else
        gfx.set(THEME.checkbox[1], THEME.checkbox[2], THEME.checkbox[3], 1)
    end
    gfx.rect(x, y, boxSize, boxSize, 1)
    gfx.set(THEME.border[1], THEME.border[2], THEME.border[3], 1)
    gfx.rect(x, y, boxSize, boxSize, 0)

    if checked then
        gfx.set(1, 1, 1, 1)
        local s = GUI.scale
        gfx.line(x + S(3), y + S(9), x + S(7), y + S(13))
        gfx.line(x + S(7), y + S(13), x + S(14), y + S(4))
        gfx.line(x + S(3), y + S(10), x + S(7), y + S(14))
        gfx.line(x + S(7), y + S(14), x + S(14), y + S(5))
    end

    gfx.set(r/255, g/255, b/255, 1)
    gfx.x = x + boxSize + S(8)
    gfx.y = y + S(2)
    gfx.drawstr(label)

    return clicked
end

-- Draw a radio button and return if it was clicked (scaled)
local function drawRadio(x, y, selected, label)
    local radius = S(8)
    local clicked = false
    local mx, my = gfx.mouse_x, gfx.mouse_y
    local mouseDown = gfx.mouse_cap & 1 == 1

    if mouseDown and mx >= x and mx <= x + S(150) and my >= y and my <= y + radius * 2 then
        if not GUI.wasMouseDown then clicked = true end
    end

    gfx.set(THEME.border[1], THEME.border[2], THEME.border[3], 1)
    gfx.circle(x + radius, y + radius, radius, 0, 1)

    if selected then
        gfx.set(THEME.accent[1], THEME.accent[2], THEME.accent[3], 1)
        gfx.circle(x + radius, y + radius, radius - S(3), 1, 1)
    end

    gfx.set(THEME.text[1], THEME.text[2], THEME.text[3], 1)
    gfx.x = x + radius * 2 + S(8)
    gfx.y = y + S(2)
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
    gfx.rect(x, y, w, h, 1)
    gfx.set(THEME.border[1], THEME.border[2], THEME.border[3], 1)
    gfx.rect(x, y, w, h, 0)

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

    -- Update scale based on current window size
    updateScale()

    -- Background
    gfx.set(THEME.bg[1], THEME.bg[2], THEME.bg[3], 1)
    gfx.rect(0, 0, gfx.w, gfx.h, 1)

    -- Theme toggle button (sun/moon icon in top right)
    local themeX = gfx.w - S(32)
    local themeY = S(8)
    local themeSize = S(20)
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
    if themeHover and mouseDown and not GUI.wasMouseDown then
        SETTINGS.darkMode = not SETTINGS.darkMode
        updateTheme()
    end

    -- Title
    gfx.set(THEME.text[1], THEME.text[2], THEME.text[3], 1)
    gfx.setfont(1, "Arial", S(18), string.byte('b'))
    gfx.x = S(20)
    gfx.y = S(12)
    gfx.drawstr("Stemperator - AI Stem Separation")

    gfx.setfont(1, "Arial", S(13))

    -- === LEFT COLUMN: Stems ===
    local is6Stem = (SETTINGS.model == "htdemucs_6s")
    gfx.set(THEME.textDim[1], THEME.textDim[2], THEME.textDim[3], 1)
    gfx.x = S(20)
    gfx.y = S(45)
    gfx.drawstr(is6Stem and "Stems (1-6):" or "Stems (1-4):")

    local y = S(65)
    for i, stem in ipairs(STEMS) do
        -- Only show Guitar/Piano if 6-stem model selected
        if not stem.sixStemOnly or is6Stem then
            local label = stem.key .. " " .. stem.name
            if drawCheckbox(S(25), y, stem.selected, label, stem.color[1], stem.color[2], stem.color[3]) then
                STEMS[i].selected = not STEMS[i].selected
            end
            y = y + S(24)
        end
    end

    -- Presets section
    gfx.set(THEME.textDim[1], THEME.textDim[2], THEME.textDim[3], 1)
    gfx.x = S(20)
    gfx.y = y + S(8)
    gfx.drawstr("Presets:")

    y = y + S(28)
    if drawButton(S(25), y, S(60), S(22), "All", false) then applyPresetAll() end
    if drawButton(S(90), y, S(70), S(22), "Karaoke", false, {100, 180, 100}) then applyPresetKaraoke() end
    y = y + S(26)
    if drawButton(S(25), y, S(60), S(22), "Vocals", false, {255, 100, 100}) then applyPresetVocalsOnly() end
    if drawButton(S(90), y, S(70), S(22), "Drums", false, {100, 200, 255}) then applyPresetDrumsOnly() end

    -- === RIGHT COLUMN: Model & Options ===
    gfx.set(THEME.textDim[1], THEME.textDim[2], THEME.textDim[3], 1)
    gfx.x = S(180)
    gfx.y = S(45)
    gfx.drawstr("AI Model:")

    y = S(65)
    for _, model in ipairs(MODELS) do
        if drawRadio(S(185), y, SETTINGS.model == model.id, model.name) then
            SETTINGS.model = model.id
        end
        y = y + S(24)
    end

    -- Count selected stems for plural labels
    local stemCount = 0
    for _, stem in ipairs(STEMS) do
        if stem.selected and (not stem.sixStemOnly or is6Stem) then
            stemCount = stemCount + 1
        end
    end
    local stemPlural = stemCount ~= 1
    local newTracksLabel = stemPlural and "New tracks" or "New track"
    local inPlaceLabel = stemPlural and "In-place (takes)" or "In-place (take)"

    -- Output mode
    gfx.set(THEME.textDim[1], THEME.textDim[2], THEME.textDim[3], 1)
    gfx.x = S(180)
    gfx.y = y + S(10)
    gfx.drawstr("Output:")

    y = y + S(28)
    if drawRadio(S(185), y, SETTINGS.createNewTracks, newTracksLabel) then
        SETTINGS.createNewTracks = true
    end
    y = y + S(22)
    if drawRadio(S(185), y, not SETTINGS.createNewTracks, inPlaceLabel) then
        SETTINGS.createNewTracks = false
    end

    -- Options (only when creating new tracks)
    if SETTINGS.createNewTracks then
        y = y + S(28)
        if drawCheckbox(S(185), y, SETTINGS.createFolder, "Group in folder", 160, 160, 160) then
            SETTINGS.createFolder = not SETTINGS.createFolder
        end
        -- Check if there's a time selection (for selection-specific options)
        local hasTimeSel = hasTimeSelection()

        -- Count SELECTED items in time selection for plural labels
        local itemCount = 1
        if hasTimeSel then
            local selStart, selEnd = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
            local numTracks = reaper.CountTracks(0)
            itemCount = 0
            for t = 0, numTracks - 1 do
                local track = reaper.GetTrack(0, t)
                local numItems = reaper.CountTrackMediaItems(track)
                for i = 0, numItems - 1 do
                    local item = reaper.GetTrackMediaItem(track, i)
                    -- Only count items that are SELECTED
                    if reaper.IsMediaItemSelected(item) then
                        local itemStart = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
                        local itemEnd = itemStart + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
                        if itemStart < selEnd and itemEnd > selStart then
                            itemCount = itemCount + 1
                        end
                    end
                end
            end
            if itemCount == 0 then itemCount = 1 end
        end
        local plural = itemCount > 1
        local muteItemLabel = plural and "Mute items" or "Mute item"
        local deleteItemLabel = plural and "Delete items" or "Delete item"
        local deleteTrackLabel = plural and "Delete tracks" or "Delete track"

        -- Item-level options (mutually exclusive with each other and selection options)
        y = y + S(22)
        if drawCheckbox(S(185), y, SETTINGS.muteOriginal, muteItemLabel, 160, 160, 160) then
            SETTINGS.muteOriginal = not SETTINGS.muteOriginal
            if SETTINGS.muteOriginal then
                SETTINGS.deleteOriginal = false; SETTINGS.deleteOriginalTrack = false
                SETTINGS.muteSelection = false; SETTINGS.deleteSelection = false
            end
        end
        y = y + S(22)
        local delItemColor = SETTINGS.deleteOriginal and {255, 120, 120} or {160, 160, 160}
        if drawCheckbox(S(185), y, SETTINGS.deleteOriginal, deleteItemLabel, delItemColor[1], delItemColor[2], delItemColor[3]) then
            SETTINGS.deleteOriginal = not SETTINGS.deleteOriginal
            if SETTINGS.deleteOriginal then
                SETTINGS.muteOriginal = false
                SETTINGS.muteSelection = false; SETTINGS.deleteSelection = false
            end
        end
        y = y + S(22)
        local delTrackColor = SETTINGS.deleteOriginalTrack and {255, 120, 120} or {160, 160, 160}
        if drawCheckbox(S(185), y, SETTINGS.deleteOriginalTrack, deleteTrackLabel, delTrackColor[1], delTrackColor[2], delTrackColor[3]) then
            SETTINGS.deleteOriginalTrack = not SETTINGS.deleteOriginalTrack
            if SETTINGS.deleteOriginalTrack then
                SETTINGS.deleteOriginal = true; SETTINGS.muteOriginal = false
                SETTINGS.muteSelection = false; SETTINGS.deleteSelection = false
            end
        end

        -- Selection-level options (can be combined with each other, but not with item-level)
        if hasTimeSel then
            gfx.set(THEME.textDim[1], THEME.textDim[2], THEME.textDim[3], 1)
            gfx.x = S(180)
            gfx.y = y + S(36)
            gfx.drawstr("Selection only:")
            y = y + S(54)
            gfx.setfont(1, "Arial", S(13))
            if drawCheckbox(S(185), y, SETTINGS.muteSelection, "Mute selection", 160, 160, 160) then
                SETTINGS.muteSelection = not SETTINGS.muteSelection
                if SETTINGS.muteSelection then
                    SETTINGS.muteOriginal = false; SETTINGS.deleteOriginal = false; SETTINGS.deleteOriginalTrack = false
                    SETTINGS.deleteSelection = false  -- Can't mute AND delete
                end
            end
            y = y + S(22)
            local delSelColor = SETTINGS.deleteSelection and {255, 120, 120} or {160, 160, 160}
            if drawCheckbox(S(185), y, SETTINGS.deleteSelection, "Delete selection", delSelColor[1], delSelColor[2], delSelColor[3]) then
                SETTINGS.deleteSelection = not SETTINGS.deleteSelection
                if SETTINGS.deleteSelection then
                    SETTINGS.muteOriginal = false; SETTINGS.deleteOriginal = false; SETTINGS.deleteOriginalTrack = false
                    SETTINGS.muteSelection = false  -- Can't delete AND mute
                end
            end
        end
    end

    -- Keyboard shortcuts hint
    gfx.set(THEME.textHint[1], THEME.textHint[2], THEME.textHint[3], 1)
    gfx.setfont(1, "Arial", S(10))
    gfx.x = S(20)
    gfx.y = gfx.h - S(85)
    if is6Stem then
        gfx.drawstr("1-6 = stems  |  K = karaoke  |  A = all")
    else
        gfx.drawstr("1-4 = stems  |  K = karaoke  |  A = all")
    end
    gfx.x = S(20)
    gfx.y = gfx.h - S(70)
    gfx.set(THEME.buttonPrimary[1] * 1.3, THEME.buttonPrimary[2] * 1.3, THEME.buttonPrimary[3] * 1.3, 1)
    gfx.drawstr("Enter/Space = start  |  ESC = cancel")

    -- Buttons
    gfx.setfont(1, "Arial", S(13))
    local btnY = gfx.h - S(40)
    local btnW = S(80)
    local btnH = S(28)
    if drawButton(gfx.w - S(185), btnY, btnW, btnH, "Cancel", false) then
        GUI.result = false
    end
    if drawButton(gfx.w - S(95), btnY, btnW, btnH, "Separate", true) then
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
    elseif char == 107 or char == 75 then applyPresetKaraoke()  -- K
    elseif char == 105 or char == 73 then applyPresetInstrumental()  -- I
    elseif char == 100 or char == 68 then applyPresetDrumsOnly()  -- D
    elseif char == 118 or char == 86 then applyPresetVocalsOnly()  -- V
    elseif char == 97 or char == 65 then applyPresetAll()  -- A
    elseif char == 43 or char == 61 then  -- + or = to grow window
        local newW = math.min(GUI.maxW, gfx.w + 76)
        local newH = math.min(GUI.maxH, gfx.h + 68)
        gfx.init(SCRIPT_NAME, newW, newH)
    elseif char == 45 then  -- - to shrink window
        local newW = math.max(GUI.minW, gfx.w - 76)
        local newH = math.max(GUI.minH, gfx.h - 68)
        gfx.init(SCRIPT_NAME, newW, newH)
    end

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
        if GUI.result then
            reaper.defer(runSeparationWorkflow)
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

    if #selectedItems == 0 then return nil, "No selected audio items in time selection" end

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
    local time = os.clock()

    -- Calculate scale based on window size
    local scaleW = w / PROGRESS_BASE_W
    local scaleH = h / PROGRESS_BASE_H
    local scale = math.min(scaleW, scaleH)
    scale = math.max(0.5, math.min(4.0, scale))  -- Clamp scale

    -- Scaling helper
    local function PS(val) return math.floor(val * scale + 0.5) end

    -- Try to make window resizable
    makeProgressWindowResizable()

    -- Initialize waveform bars if needed
    local barCount = math.floor(w / PS(8))
    if #waveformState.bars ~= barCount then
        initWaveformBars(barCount)
    end

    -- Gradient background with subtle animation (theme-aware)
    local bgPulse = 0.02 * math.sin(time * 0.5)
    for y = 0, h do
        local t = y / h
        local baseR = THEME.bgGradientTop[1] * (1-t) + THEME.bgGradientBottom[1] * t
        local baseG = THEME.bgGradientTop[2] * (1-t) + THEME.bgGradientBottom[2] * t
        local baseB = THEME.bgGradientTop[3] * (1-t) + THEME.bgGradientBottom[3] * t
        local blueShift = 0.02 + 0.01 * math.sin(time * 0.3 + y * 0.01)
        if SETTINGS.darkMode then
            gfx.set(baseR + bgPulse, baseG + bgPulse, baseB + bgPulse + blueShift, 1)
        else
            gfx.set(baseR - bgPulse * 0.5, baseG - bgPulse * 0.5, baseB - bgPulse * 0.5 + blueShift * 0.3, 1)
        end
        gfx.line(0, y, w, y)
    end

    -- Animated background waveform visualization (bottom area)
    local waveY = h - PS(80)
    local waveH = PS(50)
    local barWidth = PS(4)
    local barGap = PS(4)

    -- Get selected stems for colors
    local selectedStems = {}
    for _, stem in ipairs(STEMS) do
        if stem.selected and (not stem.sixStemOnly or SETTINGS.model == "htdemucs_6s") then
            table.insert(selectedStems, stem)
        end
    end

    -- Draw animated waveform bars
    for i, bar in ipairs(waveformState.bars) do
        -- Smooth animation towards target
        local diff = bar.targetHeight - bar.height
        bar.velocity = bar.velocity * 0.85 + diff * 0.15
        bar.height = bar.height + bar.velocity

        -- Randomly change target
        if math.random() < 0.05 then
            bar.targetHeight = math.random() * 0.8 + 0.2
        end

        -- Calculate bar position and height
        local barX = (i - 1) * (barWidth + barGap)
        local barH = bar.height * waveH
        local barY = waveY + (waveH - barH) / 2

        -- Color based on position (blend through stem colors)
        local colorIdx = ((i - 1) / math.max(1, #waveformState.bars - 1)) * (#selectedStems - 1) + 1
        local idx1 = math.floor(colorIdx)
        local idx2 = math.min(idx1 + 1, #selectedStems)
        local blend = colorIdx - idx1

        if #selectedStems > 0 then
            idx1 = math.max(1, math.min(idx1, #selectedStems))
            idx2 = math.max(1, math.min(idx2, #selectedStems))

            local r = (selectedStems[idx1].color[1] * (1 - blend) + selectedStems[idx2].color[1] * blend) / 255
            local g = (selectedStems[idx1].color[2] * (1 - blend) + selectedStems[idx2].color[2] * blend) / 255
            local b = (selectedStems[idx1].color[3] * (1 - blend) + selectedStems[idx2].color[3] * blend) / 255

            -- Pulsing glow effect
            local pulse = 0.3 + 0.2 * math.sin(time * 3 + bar.phase)
            gfx.set(r * pulse, g * pulse, b * pulse, 0.6)
            gfx.rect(barX, barY, barWidth, barH, 1)

            -- Brighter center line
            gfx.set(r * 0.8, g * 0.8, b * 0.8, 0.9)
            gfx.rect(barX + 1, barY + 2, barWidth - 2, barH - 4, 1)
        end
    end

    -- Floating particles effect
    if #waveformState.particles < 20 and math.random() < 0.1 then
        table.insert(waveformState.particles, {
            x = math.random() * w,
            y = h,
            vx = (math.random() - 0.5) * 2,
            vy = -math.random() * 2 - 1,
            life = 1.0,
            size = math.random() * PS(3) + PS(1),
            colorIdx = math.random(1, math.max(1, #selectedStems)),
        })
    end

    -- Update and draw particles
    for i = #waveformState.particles, 1, -1 do
        local p = waveformState.particles[i]
        p.x = p.x + p.vx
        p.y = p.y + p.vy
        p.vy = p.vy - 0.02  -- Gravity (upward)
        p.life = p.life - 0.015

        if p.life <= 0 or p.y < 0 then
            table.remove(waveformState.particles, i)
        else
            local stem = selectedStems[p.colorIdx] or selectedStems[1]
            if stem then
                gfx.set(stem.color[1]/255, stem.color[2]/255, stem.color[3]/255, p.life * 0.5)
                gfx.circle(p.x, p.y, p.size * p.life, 1, 1)
            end
        end
    end

    -- Scanning line effect
    local scanX = ((time * 100) % w)
    gfx.set(1, 1, 1, 0.03)
    gfx.rect(scanX, 0, PS(2), h, 1)

    -- Model badge (top right) with glow
    local modelText = SETTINGS.model or "htdemucs"
    gfx.setfont(1, "Arial", PS(11))
    local modelW = gfx.measurestr(modelText) + PS(16)
    local badgeX = w - modelW - PS(20)
    local badgeY = PS(18)
    -- Glow
    gfx.set(THEME.accent[1], THEME.accent[2], THEME.accent[3], 0.3)
    gfx.rect(badgeX - 2, badgeY - 2, modelW + 4, PS(26), 1)
    -- Badge
    if SETTINGS.darkMode then
        gfx.set(0.15, 0.25, 0.35, 1)
    else
        gfx.set(0.85, 0.88, 0.92, 1)
    end
    gfx.rect(badgeX, badgeY, modelW, PS(22), 1)
    gfx.set(THEME.accent[1] + 0.2, THEME.accent[2] + 0.2, THEME.accent[3] + 0.2, 1)
    gfx.x = badgeX + PS(8)
    gfx.y = PS(22)
    gfx.drawstr(modelText)

    -- Title with glow effect
    gfx.setfont(1, "Arial", PS(18), string.byte('b'))
    local title = "AI Stem Separation"
    -- In multi-track mode, show which track
    if multiTrackQueue.active then
        title = "Track " .. multiTrackQueue.currentIndex .. "/" .. multiTrackQueue.totalTracks .. ": " .. (multiTrackQueue.currentTrackName or "")
    end
    local titleW = gfx.measurestr(title)
    -- Glow
    local glowIntensity = 0.3 + 0.1 * math.sin(time * 2)
    gfx.set(THEME.accent[1], THEME.accent[2], THEME.accent[3], glowIntensity)
    gfx.x = PS(25) + 1
    gfx.y = PS(20) + 1
    gfx.drawstr(title)
    -- Main text
    gfx.set(THEME.text[1], THEME.text[2], THEME.text[3], 1)
    gfx.x = PS(25)
    gfx.y = PS(20)
    gfx.drawstr(title)

    -- Stem indicators (colored boxes showing which stems are selected)
    local stemX = PS(25)
    local stemY = PS(55)
    local stemBoxSize = PS(14)
    gfx.setfont(1, "Arial", PS(11))
    for idx, stem in ipairs(STEMS) do
        if stem.selected and (not stem.sixStemOnly or SETTINGS.model == "htdemucs_6s") then
            -- Animated glow behind stem box
            local pulseAlpha = 0.3 + 0.2 * math.sin(time * 3 + idx)
            gfx.set(stem.color[1]/255, stem.color[2]/255, stem.color[3]/255, pulseAlpha)
            gfx.rect(stemX - 2, stemY - 2, stemBoxSize + 4, stemBoxSize + 4, 1)
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

    -- Progress bar background with rounded look
    local barX = PS(25)
    local barY = PS(90)
    local barW = w - PS(50)
    local barH = PS(35)

    -- Outer glow
    if SETTINGS.darkMode then
        gfx.set(0.1, 0.15, 0.2, 1)
    else
        gfx.set(0.7, 0.72, 0.75, 1)
    end
    gfx.rect(barX - 2, barY - 2, barW + 4, barH + 4, 1)
    -- Inner background
    if SETTINGS.darkMode then
        gfx.set(0.12, 0.12, 0.14, 1)
    else
        gfx.set(0.82, 0.82, 0.84, 1)
    end
    gfx.rect(barX, barY, barW, barH, 1)

    -- Progress bar fill with gradient based on stem colors
    local fillWidth = math.floor(barW * progressState.percent / 100)
    if fillWidth > 0 then
        if #selectedStems > 0 then
            for x = 0, fillWidth - 1 do
                local pos = x / math.max(1, fillWidth - 1)
                local idx = math.floor(pos * (#selectedStems - 1)) + 1
                local nextIdx = math.min(idx + 1, #selectedStems)
                local blend = (pos * (#selectedStems - 1)) % 1

                local r = selectedStems[idx].color[1] * (1 - blend) + selectedStems[nextIdx].color[1] * blend
                local g = selectedStems[idx].color[2] * (1 - blend) + selectedStems[nextIdx].color[2] * blend
                local b = selectedStems[idx].color[3] * (1 - blend) + selectedStems[nextIdx].color[3] * blend

                -- Enhanced shimmer effect
                local shimmer = 0.85 + 0.15 * math.sin((x * 0.1) + (time * 8))
                local vertGrad = 1.0

                for y = 0, barH - 1 do
                    -- Vertical gradient for 3D effect
                    if y < barH * 0.3 then
                        vertGrad = 1.1 + 0.1 * (1 - y / (barH * 0.3))
                    elseif y > barH * 0.7 then
                        vertGrad = 1.0 - 0.2 * ((y - barH * 0.7) / (barH * 0.3))
                    else
                        vertGrad = 1.0
                    end

                    gfx.set(r/255 * shimmer * vertGrad, g/255 * shimmer * vertGrad, b/255 * shimmer * vertGrad, 1)
                    gfx.rect(barX + x, barY + y, 1, 1, 1)
                end
            end

            -- Animated highlight sweep
            local sweepPos = ((time * 150) % (barW + 100)) - 50
            if sweepPos < fillWidth then
                for sx = math.max(0, sweepPos - 30), math.min(fillWidth, sweepPos + 30) do
                    local alpha = 0.3 * (1 - math.abs(sx - sweepPos) / 30)
                    gfx.set(1, 1, 1, alpha)
                    gfx.line(barX + sx, barY + 2, barX + sx, barY + barH - 3)
                end
            end
        end
    end

    -- Progress percentage in center of bar with shadow
    gfx.setfont(1, "Arial", PS(15), string.byte('b'))
    local percentText = string.format("%d%%", progressState.percent)
    local tw = gfx.measurestr(percentText)
    -- Shadow
    gfx.set(0, 0, 0, 0.5)
    gfx.x = barX + (barW - tw) / 2 + 1
    gfx.y = barY + (barH - PS(15)) / 2 + 1
    gfx.drawstr(percentText)
    -- Text
    gfx.set(1, 1, 1, 1)
    gfx.x = barX + (barW - tw) / 2
    gfx.y = barY + (barH - PS(15)) / 2
    gfx.drawstr(percentText)

    -- Stage text
    gfx.setfont(1, "Arial", PS(12))
    gfx.set(THEME.textDim[1], THEME.textDim[2], THEME.textDim[3], 1)
    gfx.x = PS(25)
    gfx.y = PS(138)
    local stageDisplay = progressState.stage or "Starting..."
    local maxStageLen = math.floor(70 * scale)
    if #stageDisplay > maxStageLen then stageDisplay = stageDisplay:sub(1, maxStageLen - 3) .. "..." end
    gfx.drawstr(stageDisplay)

    -- Animated processing indicator (spinning dots)
    if progressState.percent < 100 then
        local dotRadius = PS(12)
        local dotCenterX = w - PS(40)
        local dotCenterY = PS(143)
        for i = 0, 7 do
            local angle = (i / 8) * math.pi * 2 + time * 5
            local dx = math.cos(angle) * dotRadius
            local dy = math.sin(angle) * dotRadius
            local alpha = ((i / 8 + time * 0.8) % 1)
            gfx.set(THEME.accent[1] + 0.1, THEME.accent[2] + 0.1, THEME.accent[3] + 0.2, alpha * 0.8)
            gfx.circle(dotCenterX + dx, dotCenterY + dy, PS(2), 1, 1)
        end
    end

    -- Time info box
    local elapsed = os.time() - progressState.startTime
    local mins = math.floor(elapsed / 60)
    local secs = elapsed % 60

    if SETTINGS.darkMode then
        gfx.set(0.15, 0.18, 0.22, 1)
    else
        gfx.set(0.82, 0.84, 0.87, 1)
    end
    gfx.rect(PS(25), PS(160), PS(100), PS(22), 1)
    gfx.set(THEME.accent[1] + 0.3, THEME.accent[2] + 0.2, THEME.accent[3], 1)
    gfx.setfont(1, "Arial", PS(11))
    gfx.x = PS(32)
    gfx.y = PS(165)
    gfx.drawstr(string.format("Elapsed: %d:%02d", mins, secs))

    -- ETA box (if available)
    local eta = progressState.stage:match("ETA ([%d:]+)")
    if eta then
        if SETTINGS.darkMode then
            gfx.set(0.15, 0.20, 0.18, 1)
        else
            gfx.set(0.82, 0.87, 0.84, 1)
        end
        gfx.rect(PS(135), PS(160), PS(80), PS(22), 1)
        gfx.set(0.2, 0.7, 0.4, 1)
        gfx.x = PS(142)
        gfx.y = PS(165)
        gfx.drawstr("ETA: " .. eta)
    end

    -- GPU indicator with icon
    if SETTINGS.darkMode then
        gfx.set(0.12, 0.20, 0.15, 1)
    else
        gfx.set(0.82, 0.88, 0.84, 1)
    end
    gfx.rect(w - PS(130), PS(160), PS(105), PS(22), 1)
    gfx.set(0.2, 0.7, 0.3, 1)
    gfx.x = w - PS(123)
    gfx.y = PS(165)
    gfx.drawstr("GPU: DirectML")

    -- Cancel hint
    gfx.set(THEME.textHint[1], THEME.textHint[2], THEME.textHint[3], 1)
    gfx.setfont(1, "Arial", PS(9))
    local hintText = "Drag edges to resize  |  Press ESC or close window to cancel"
    local hintW = gfx.measurestr(hintText)
    gfx.x = (w - hintW) / 2
    gfx.y = h - PS(18)
    gfx.drawstr(hintText)

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
            batFile:write('"' .. inputFile .. '" "' .. outputDir .. '" --model ' .. model .. ' --segment-size 40 ')
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
            '"%s" -u "%s" "%s" "%s" --model %s --segment-size 40 >"%s" 2>"%s" && echo DONE > "%s/done.txt" &',
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

-- Draw result window (same style as progress window)
local function drawResultWindow()
    local w, h = gfx.w, gfx.h
    local time = os.clock()
    local elapsed = time - resultWindowState.startTime

    -- Calculate scale
    local scale = math.min(w / 380, h / 340)
    scale = math.max(0.5, math.min(4.0, scale))
    local function PS(val) return math.floor(val * scale + 0.5) end

    -- Gradient background with celebration tint (theme-aware)
    local celebrationGlow = math.max(0, 0.05 * (1 - elapsed * 0.5))
    for y = 0, h do
        local t = y / h
        local baseR = THEME.bgGradientTop[1] * (1-t) + THEME.bgGradientBottom[1] * t
        local baseG = THEME.bgGradientTop[2] * (1-t) + THEME.bgGradientBottom[2] * t
        local baseB = THEME.bgGradientTop[3] * (1-t) + THEME.bgGradientBottom[3] * t
        local greenTint = celebrationGlow * (1 - t)
        gfx.set(baseR, baseG + greenTint, baseB, 1)
        gfx.line(0, y, w, y)
    end

    -- Get stem colors for effects
    local stemColors = {}
    for _, stem in ipairs(resultWindowState.selectedStems) do
        table.insert(stemColors, stem.color)
    end
    if #stemColors == 0 then
        stemColors = {{100, 255, 150}, {255, 100, 100}, {100, 200, 255}, {150, 100, 255}}
    end

    -- Draw expanding celebration rings
    local iconX = w / 2
    local iconY = PS(50)
    for _, ring in ipairs(resultWindowState.rings) do
        if elapsed > ring.delay then
            local ringTime = elapsed - ring.delay
            ring.radius = ringTime * 80
            ring.alpha = math.max(0, 1 - ringTime * 0.8)

            if ring.alpha > 0 then
                local colorIdx = math.floor(ringTime * 3) % #stemColors + 1
                local color = stemColors[colorIdx]
                gfx.set(color[1]/255, color[2]/255, color[3]/255, ring.alpha * 0.3)
                gfx.circle(iconX, iconY, ring.radius, 0, 1)
                gfx.circle(iconX, iconY, ring.radius + 1, 0, 1)
            end
        end
    end

    -- Draw confetti
    for _, c in ipairs(resultWindowState.confetti) do
        if elapsed > c.delay then
            local confettiTime = elapsed - c.delay
            c.y = c.y + c.vy
            c.x = c.x + c.vx + math.sin(confettiTime * 3 + c.rotation) * 0.5
            c.vy = c.vy + 0.1  -- Gravity
            c.rotation = c.rotation + c.rotSpeed

            if c.y < h + 50 then
                local color = stemColors[((c.colorIdx - 1) % #stemColors) + 1]
                local alpha = math.min(1, confettiTime * 2) * math.max(0, 1 - (c.y - h * 0.7) / (h * 0.3))

                gfx.set(color[1]/255, color[2]/255, color[3]/255, alpha * 0.8)

                -- Draw rotated rectangle (confetti piece)
                local cx, cy = c.x * w / 500, c.y
                local sz = c.size * scale
                local cos_r = math.cos(c.rotation)
                local sin_r = math.sin(c.rotation)

                -- Simple confetti shape
                gfx.rect(cx - sz/2, cy - sz/4, sz, sz/2, 1)
            end
        end
    end

    -- Success checkmark icon area with animated glow
    local iconR = PS(30)
    local pulseScale = 1 + 0.05 * math.sin(time * 4)
    local glowPulse = 0.3 + 0.2 * math.sin(time * 3)

    -- Outer glow
    gfx.set(0.2, 0.8, 0.4, glowPulse * 0.5)
    gfx.circle(iconX, iconY, iconR * 1.3 * pulseScale, 1, 1)

    -- Green circle with gradient effect
    for r = iconR, 0, -1 do
        local gradientFactor = 1 - (iconR - r) / iconR * 0.3
        gfx.set(0.15 * gradientFactor, 0.65 * gradientFactor, 0.3 * gradientFactor, 1)
        gfx.circle(iconX, iconY, r * pulseScale, 1, 1)
    end

    -- Animated checkmark (draws in)
    local checkProgress = math.min(1, elapsed * 3)
    gfx.set(1, 1, 1, 1)
    local cx, cy = iconX, iconY

    if checkProgress > 0 then
        local p1 = math.min(1, checkProgress * 2)
        local p2 = math.max(0, math.min(1, (checkProgress - 0.3) * 2))

        -- First part of checkmark
        if p1 > 0 then
            local x1, y1 = cx - PS(12), cy
            local x2, y2 = cx - PS(4), cy + PS(10)
            gfx.line(x1, y1, x1 + (x2-x1)*p1, y1 + (y2-y1)*p1)
            gfx.line(x1, y1+1, x1 + (x2-x1)*p1, y1+1 + (y2-y1)*p1)
        end

        -- Second part of checkmark
        if p2 > 0 then
            local x1, y1 = cx - PS(4), cy + PS(10)
            local x2, y2 = cx + PS(12), cy - PS(8)
            gfx.line(x1, y1, x1 + (x2-x1)*p2, y1 + (y2-y1)*p2)
            gfx.line(x1, y1+1, x1 + (x2-x1)*p2, y1+1 + (y2-y1)*p2)
        end
    end

    -- Title with glow
    gfx.setfont(1, "Arial", PS(18), string.byte('b'))
    local title = "Separation Complete!"
    local titleW = gfx.measurestr(title)

    -- Title glow
    local titleGlow = 0.3 + 0.15 * math.sin(time * 2)
    gfx.set(0.2, 0.6, 0.3, titleGlow)
    gfx.x = (w - titleW) / 2 + 1
    gfx.y = PS(90) + 1
    gfx.drawstr(title)

    -- Main title
    gfx.set(THEME.text[1], THEME.text[2], THEME.text[3], 1)
    gfx.x = (w - titleW) / 2
    gfx.y = PS(90)
    gfx.drawstr(title)

    -- Stem indicators with animated glow
    local stemY = PS(125)
    local stemBoxSize = PS(16)
    gfx.setfont(1, "Arial", PS(12))

    -- Calculate total width to center
    local totalStemWidth = 0
    for _, stem in ipairs(resultWindowState.selectedStems) do
        totalStemWidth = totalStemWidth + stemBoxSize + gfx.measurestr(stem.name) + PS(18)
    end
    local stemX = (w - totalStemWidth) / 2

    for idx, stem in ipairs(resultWindowState.selectedStems) do
        -- Animated glow behind each stem
        local stemPulse = 0.3 + 0.2 * math.sin(time * 3 + idx * 0.5)
        gfx.set(stem.color[1]/255, stem.color[2]/255, stem.color[3]/255, stemPulse)
        gfx.rect(stemX - 3, stemY - 3, stemBoxSize + 6, stemBoxSize + 6, 1)

        -- Stem color box
        gfx.set(stem.color[1]/255, stem.color[2]/255, stem.color[3]/255, 1)
        gfx.rect(stemX, stemY, stemBoxSize, stemBoxSize, 1)

        -- Stem name
        gfx.set(THEME.textDim[1], THEME.textDim[2], THEME.textDim[3], 1)
        gfx.x = stemX + stemBoxSize + PS(5)
        gfx.y = stemY + PS(1)
        gfx.drawstr(stem.name)
        stemX = stemX + stemBoxSize + gfx.measurestr(stem.name) + PS(18)
    end

    -- Result message with styled background
    if SETTINGS.darkMode then
        gfx.set(0.08, 0.10, 0.12, 0.8)
    else
        gfx.set(0.95, 0.95, 0.97, 0.9)
    end
    gfx.rect(PS(20), PS(155), w - PS(40), PS(60), 1)

    gfx.set(THEME.textDim[1], THEME.textDim[2], THEME.textDim[3], 1)
    gfx.setfont(1, "Arial", PS(11))
    local msgLines = {}
    for line in (resultWindowState.message .. "\n"):gmatch("([^\n]*)\n") do
        table.insert(msgLines, line)
    end
    local msgY = PS(165)
    for _, line in ipairs(msgLines) do
        local lineW = gfx.measurestr(line)
        gfx.x = (w - lineW) / 2
        gfx.y = msgY
        gfx.drawstr(line)
        msgY = msgY + PS(16)
    end

    -- Animated stem visualization at bottom
    local vizY = h - PS(90)
    local vizH = PS(30)
    local vizW = w - PS(60)
    local barWidth = vizW / math.max(1, #resultWindowState.selectedStems)

    for idx, stem in ipairs(resultWindowState.selectedStems) do
        local barX = PS(30) + (idx - 1) * barWidth
        local animHeight = vizH * (0.3 + 0.7 * math.abs(math.sin(time * 2 + idx)))

        -- Bar glow
        gfx.set(stem.color[1]/255, stem.color[2]/255, stem.color[3]/255, 0.2)
        gfx.rect(barX + 2, vizY + (vizH - animHeight) / 2, barWidth - 8, animHeight, 1)

        -- Main bar
        gfx.set(stem.color[1]/255, stem.color[2]/255, stem.color[3]/255, 0.7)
        gfx.rect(barX + 4, vizY + (vizH - animHeight * 0.8) / 2, barWidth - 12, animHeight * 0.8, 1)
    end

    -- OK button with hover effect
    local btnW = PS(100)
    local btnH = PS(32)
    local btnX = (w - btnW) / 2
    local btnY = h - PS(50)

    local mx, my = gfx.mouse_x, gfx.mouse_y
    local hover = mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH
    local mouseDown = gfx.mouse_cap & 1 == 1

    -- Button glow on hover
    if hover then
        gfx.set(THEME.buttonHover[1], THEME.buttonHover[2], THEME.buttonHover[3], 0.3)
        gfx.rect(btnX - 3, btnY - 3, btnW + 6, btnH + 6, 1)
        gfx.set(THEME.buttonHover[1], THEME.buttonHover[2], THEME.buttonHover[3], 1)
    else
        gfx.set(THEME.button[1], THEME.button[2], THEME.button[3], 1)
    end
    gfx.rect(btnX, btnY, btnW, btnH, 1)

    -- Button border
    gfx.set(THEME.border[1], THEME.border[2], THEME.border[3], 1)
    gfx.rect(btnX, btnY, btnW, btnH, 0)

    -- Button text
    gfx.set(1, 1, 1, 1)
    gfx.setfont(1, "Arial", PS(14), string.byte('b'))
    local okText = "OK"
    local okW = gfx.measurestr(okText)
    gfx.x = btnX + (btnW - okW) / 2
    gfx.y = btnY + (btnH - PS(14)) / 2
    gfx.drawstr(okText)

    -- Hint
    gfx.set(THEME.textHint[1], THEME.textHint[2], THEME.textHint[3], 1)
    gfx.setfont(1, "Arial", PS(9))
    local hint = "Press Enter, Space, or click OK to close"
    local hintW = gfx.measurestr(hint)
    gfx.x = (w - hintW) / 2
    gfx.y = h - PS(15)
    gfx.drawstr(hint)

    gfx.update()

    -- Check for click on OK button
    if hover and mouseDown and not resultWindowState.wasMouseDown then
        return true  -- Close
    end

    -- Check for click outside window (but still in REAPER)
    if mouseDown and not resultWindowState.wasMouseDown then
        -- Check if click is outside our window bounds
        if mx < 0 or mx > w or my < 0 or my > h then
            -- Click is outside - check if REAPER is still focused
            if reaper.JS_Window_GetFocus then
                local focusedWnd = reaper.JS_Window_GetFocus()
                local reaperMain = reaper.GetMainHwnd()
                -- Check if focus is on REAPER or its children (not another app)
                if focusedWnd then
                    return true  -- Close when clicking outside in REAPER
                end
            else
                -- No JS API, just close on outside click
                return true
            end
        end
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
    if drawResultWindow() then
        gfx.quit()
        -- Return focus to REAPER main window
        local mainHwnd = reaper.GetMainHwnd()
        if mainHwnd then
            reaper.JS_Window_SetFocus(mainHwnd)
        end
        return
    end
    reaper.defer(resultWindowLoop)
end

-- Show result window
function showResultWindow(selectedStems, message)
    resultWindowState.selectedStems = selectedStems
    resultWindowState.message = message
    resultWindowState.wasMouseDown = false

    -- Initialize celebration effects
    initCelebration()

    -- Use same size as main dialog
    local winW = lastDialogW or 380
    local winH = lastDialogH or 340
    local winX, winY

    -- Use last dialog position if available
    local refX, refY  -- reference point for screen detection
    if lastDialogX and lastDialogY then
        winX = lastDialogX
        winY = lastDialogY
        refX = lastDialogX + winW / 2
        refY = lastDialogY + winH / 2
    else
        local mouseX, mouseY = reaper.GetMousePosition()
        winX = mouseX - winW / 2
        winY = mouseY - winH / 2
        refX, refY = mouseX, mouseY
    end

    -- Clamp to current monitor
    winX, winY = clampToScreen(winX, winY, winW, winH, refX, refY)

    gfx.init("Stemperator - Complete", winW, winH, 0, winX, winY)
    reaper.defer(resultWindowLoop)
end

-- Run parallel multi-track separation
runSingleTrackSeparation = function(trackList)
    -- This function now handles ALL tracks in parallel
    local baseTempDir = getTempDir() .. PATH_SEP .. "stemperator_" .. os.time()
    makeDir(baseTempDir)

    -- Prepare all tracks: extract audio and start separation processes
    local trackJobs = {}
    for i, track in ipairs(trackList) do
        local _, trackName = reaper.GetTrackName(track)
        if trackName == "" then trackName = "Track " .. math.floor(reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")) end

        local trackDir = baseTempDir .. PATH_SEP .. "track_" .. i
        makeDir(trackDir)
        local inputFile = trackDir .. PATH_SEP .. "input.wav"

        local extracted, err, sourceItem, allSourceItems = renderTrackTimeSelectionToWav(track, inputFile)
        if extracted then
            table.insert(trackJobs, {
                track = track,
                trackName = trackName,
                trackDir = trackDir,
                inputFile = inputFile,
                sourceItem = sourceItem,
                sourceItems = allSourceItems or {sourceItem},  -- All items for mute/delete
                index = i,
            })
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

    -- Start all separation processes in parallel
    for _, job in ipairs(trackJobs) do
        startSeparationProcessForJob(job)
    end

    -- Show progress window that monitors all jobs
    showMultiTrackProgressWindow()
end

-- Start a separation process for one job (no window, just background process)
startSeparationProcessForJob = function(job)
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
        -- Multi-track mode uses smaller segment size (25) to fit multiple processes in VRAM
        local batPath = job.trackDir .. PATH_SEP .. "run_separation.bat"
        local batFile = io.open(batPath, "w")
        if batFile then
            batFile:write('@echo off\n')
            batFile:write('"' .. PYTHON_PATH .. '" -u "' .. SEPARATOR_SCRIPT .. '" ')
            batFile:write('"' .. job.inputFile .. '" "' .. job.trackDir .. '" --model ' .. SETTINGS.model .. ' --segment-size 25 ')
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
        -- Multi-track mode uses smaller segment size (25) to fit multiple processes in VRAM
        local cmd = '"' .. PYTHON_PATH .. '" -u "' .. SEPARATOR_SCRIPT .. '" '
        cmd = cmd .. '"' .. job.inputFile .. '" "' .. job.trackDir .. '" --model ' .. SETTINGS.model .. ' --segment-size 25'
        cmd = cmd .. ' >"' .. stdoutFile .. '" 2>"' .. logFile .. '" && echo DONE >"' .. doneFile .. '" &'
        os.execute(cmd)
    end
end

-- Update progress for all jobs from their stdout files
updateAllJobsProgress = function()
    for _, job in ipairs(multiTrackQueue.jobs) do
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
            job.done = true
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
    local time = os.clock()

    -- Scale
    local scale = math.min(w / 480, h / 280)
    scale = math.max(0.5, math.min(4.0, scale))
    local function PS(val) return math.floor(val * scale + 0.5) end

    -- Background gradient (theme-aware)
    for y = 0, h do
        local t = y / h
        local baseR = THEME.bgGradientTop[1] * (1-t) + THEME.bgGradientBottom[1] * t
        local baseG = THEME.bgGradientTop[2] * (1-t) + THEME.bgGradientBottom[2] * t
        local baseB = THEME.bgGradientTop[3] * (1-t) + THEME.bgGradientBottom[3] * t
        gfx.set(baseR, baseG, baseB, 1)
        gfx.line(0, y, w, y)
    end

    -- Title
    gfx.setfont(1, "Arial", PS(16), string.byte('b'))
    local title = string.format("Multi-Track Separation (%d tracks)", #multiTrackQueue.jobs)
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

    if SETTINGS.darkMode then
        gfx.set(0.12, 0.12, 0.14, 1)
    else
        gfx.set(0.82, 0.82, 0.84, 1)
    end
    gfx.rect(barX, barY, barW, barH, 1)

    -- Progress fill
    local fillW = math.floor(barW * overallProgress / 100)
    if fillW > 0 then
        gfx.set(0.3, 0.6, 0.4, 1)
        gfx.rect(barX, barY, fillW, barH, 1)
    end

    -- Progress text
    gfx.setfont(1, "Arial", PS(11))
    gfx.set(THEME.text[1], THEME.text[2], THEME.text[3], 1)
    local progText = string.format("%d%%", overallProgress)
    local progW = gfx.measurestr(progText)
    gfx.x = barX + (barW - progW) / 2
    gfx.y = barY + PS(3)
    gfx.drawstr(progText)

    -- Individual track progress
    local trackY = PS(80)
    local trackH = PS(22)
    local trackSpacing = PS(26)

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
        local tBarW = barW - PS(120)

        if SETTINGS.darkMode then
            gfx.set(0.15, 0.15, 0.17, 1)
        else
            gfx.set(0.85, 0.85, 0.87, 1)
        end
        gfx.rect(tBarX, yPos, tBarW, PS(14), 1)

        -- Fill
        local tFillW = math.floor(tBarW * (job.percent or 0) / 100)
        if tFillW > 0 then
            -- Color based on stem being processed
            local stemIdx = (i - 1) % #STEMS + 1
            local stemColor = STEMS[stemIdx].color
            gfx.set(stemColor[1]/255, stemColor[2]/255, stemColor[3]/255, 0.8)
            gfx.rect(tBarX, yPos, tFillW, PS(14), 1)
        end

        -- Done checkmark or percentage
        if job.done then
            gfx.set(0.3, 0.8, 0.4, 1)
            gfx.x = tBarX + tBarW + PS(5)
            gfx.y = yPos
            gfx.drawstr("✓")
        else
            gfx.set(THEME.textHint[1], THEME.textHint[2], THEME.textHint[3], 1)
            gfx.x = tBarX + tBarW + PS(5)
            gfx.y = yPos
            gfx.drawstr(string.format("%d%%", job.percent or 0))
        end
    end

    -- Elapsed time
    local elapsed = os.time() - (multiTrackQueue.jobs[1] and multiTrackQueue.jobs[1].startTime or os.time())
    local mins = math.floor(elapsed / 60)
    local secs = elapsed % 60
    gfx.set(THEME.textHint[1], THEME.textHint[2], THEME.textHint[3], 1)
    gfx.setfont(1, "Arial", PS(9))
    gfx.x = PS(20)
    gfx.y = h - PS(20)
    gfx.drawstr(string.format("Elapsed: %d:%02d  |  Press ESC to cancel", mins, secs))

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
    -- Use saved dialog size/position like other windows
    local winW = lastDialogW or 380
    local winH = lastDialogH or 340

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

    if SETTINGS.muteOriginal then
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

    for _, job in ipairs(multiTrackQueue.jobs) do
        -- Find stem files in job directory
        local stems = {}
        for _, stem in ipairs(STEMS) do
            if stem.selected then
                local stemPath = job.trackDir .. PATH_SEP .. stem.name:lower() .. ".wav"
                local f = io.open(stemPath, "r")
                if f then
                    f:close()
                    stems[stem.name:lower()] = stemPath
                end
            end
        end

        -- Create tracks for this job's stems
        if next(stems) then
            local count = createStemTracksForSelection(stems, itemPos, itemLen, job.track)
            totalStemsCreated = totalStemsCreated + count
            table.insert(trackNames, job.trackName)
        end
    end

    reaper.Undo_EndBlock("Stemperator: Multi-track stem separation", -1)
    reaper.UpdateArrange()

    multiTrackQueue.active = false

    -- Show result
    local selectedStemData = {}
    local is6Stem = (SETTINGS.model == "htdemucs_6s")
    for _, stem in ipairs(STEMS) do
        if stem.selected and (not stem.sixStemOnly or is6Stem) then
            table.insert(selectedStemData, stem)
        end
    end

    local trackWord = totalStemsCreated == 1 and "track" or "tracks"
    local resultMsg = string.format("%d stem %s created from %d source tracks.%s", totalStemsCreated, trackWord, #multiTrackQueue.jobs, actionMsg)
    showResultWindow(selectedStemData, resultMsg)
end

-- Separation workflow
function runSeparationWorkflow()
    debugLog("=== runSeparationWorkflow started ===")
    -- Re-fetch the current selection at processing time (user may have changed it)
    selectedItem = reaper.GetSelectedMediaItem(0, 0)
    timeSelectionMode = false
    debugLog("Selected item: " .. tostring(selectedItem))

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
        -- No time selection and no item selected
        showMessage("No Selection", "Please select a media item or make a time selection to separate.", "info")
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
        -- Get original item bounds to compare
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
local function main()
    -- Load settings first (needed for window position in error messages)
    loadSettings()

    selectedItem = reaper.GetSelectedMediaItem(0, 0)
    timeSelectionMode = false

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
        -- No time selection and no item selected
        showMessage("No Selection", "Please select a media item or make a time selection to separate.", "info")
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
