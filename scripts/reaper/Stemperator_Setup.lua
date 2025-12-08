-- @description Stemperator - Setup AI Backend
-- @author flarkAUDIO
-- @version 1.0.0
-- @changelog
--   Initial release - Checks and installs Python + audio-separator
-- @provides
--   [main] .
-- @link Repository https://github.com/flarkflarkflark/Stemperator
-- @about
--   # Stemperator - Setup AI Backend
--
--   This script checks if the AI backend (Python + audio-separator) is properly
--   installed and offers to install it if not found.
--
--   Run this script once after installing Stemperator via ReaPack.

local SCRIPT_NAME = "Stemperator: Setup AI Backend"

-- Get script path
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

-- Get home directory
local function getHome()
    if OS == "Windows" then
        return os.getenv("USERPROFILE") or "C:\\Users\\Default"
    else
        return os.getenv("HOME") or "/tmp"
    end
end

-- Check if file exists
local function fileExists(path)
    local f = io.open(path, "r")
    if f then f:close(); return true end
    return false
end

-- Check if directory exists
local function dirExists(path)
    -- Try to open as file first
    local f = io.open(path, "r")
    if f then
        f:close()
        return true
    end
    -- On Unix, try to list directory
    if OS ~= "Windows" then
        local ok = os.execute('test -d "' .. path .. '"')
        return ok == true or ok == 0
    end
    return false
end

-- Find Python executable
local function findPython()
    local paths = {}

    if OS == "Windows" then
        -- Check venv in script directory
        table.insert(paths, script_path .. ".venv\\Scripts\\python.exe")
        -- Check Documents/Stemperator (common install location)
        table.insert(paths, getHome() .. "\\Documents\\Stemperator\\.venv\\Scripts\\python.exe")
        -- Check global venv in user profile
        table.insert(paths, getHome() .. "\\.stemperator\\.venv\\Scripts\\python.exe")
        -- Check C:\WINDOWS\.venv (alternate install location)
        table.insert(paths, "C:\\WINDOWS\\.venv\\Scripts\\python.exe")
        -- Standard Python locations
        local localAppData = os.getenv("LOCALAPPDATA") or ""
        table.insert(paths, localAppData .. "\\Programs\\Python\\Python312\\python.exe")
        table.insert(paths, localAppData .. "\\Programs\\Python\\Python311\\python.exe")
        table.insert(paths, localAppData .. "\\Programs\\Python\\Python310\\python.exe")
        -- py launcher
        table.insert(paths, "py")
        table.insert(paths, "python")
    else
        -- Check venv in script directory
        table.insert(paths, script_path .. ".venv/bin/python")
        -- Check Documents/Stemperator (common install location)
        table.insert(paths, getHome() .. "/Documents/Stemperator/.venv/bin/python")
        -- Check global venv in home
        table.insert(paths, getHome() .. "/.stemperator/.venv/bin/python")
        -- User local bin
        table.insert(paths, getHome() .. "/.local/bin/python3")
        -- System paths
        table.insert(paths, "/usr/local/bin/python3")
        table.insert(paths, "/usr/bin/python3")
        table.insert(paths, "python3")
        table.insert(paths, "python")
    end

    for _, p in ipairs(paths) do
        if fileExists(p) then
            return p, true
        end
    end

    -- Try to find any python
    local testCmd = OS == "Windows" and "where python 2>nul" or "which python3 2>/dev/null"
    local handle = io.popen(testCmd)
    if handle then
        local result = handle:read("*l")
        handle:close()
        if result and result ~= "" then
            return result, true
        end
    end

    return nil, false
end

-- Find separator script
local function findSeparatorScript()
    local paths = {
        script_path .. "audio_separator_process.py",
        script_path .. ".." .. PATH_SEP .. "AI" .. PATH_SEP .. "audio_separator_process.py",
        getHome() .. PATH_SEP .. "Documents" .. PATH_SEP .. "Stemperator" .. PATH_SEP .. "Source" .. PATH_SEP .. "AI" .. PATH_SEP .. "audio_separator_process.py",
        getHome() .. PATH_SEP .. "Documents" .. PATH_SEP .. "Stemperator" .. PATH_SEP .. "scripts" .. PATH_SEP .. "reaper" .. PATH_SEP .. "audio_separator_process.py",
        getHome() .. PATH_SEP .. ".stemperator" .. PATH_SEP .. "audio_separator_process.py",
    }

    for _, p in ipairs(paths) do
        if fileExists(p) then
            return p
        end
    end

    return nil
end

-- Check if audio-separator is installed
local function checkAudioSeparator(pythonPath)
    local cmd
    if OS == "Windows" then
        cmd = '"' .. pythonPath .. '" -c "from audio_separator.separator import Separator; print(\'OK\')" 2>nul'
    else
        cmd = '"' .. pythonPath .. '" -c "from audio_separator.separator import Separator; print(\'OK\')" 2>/dev/null'
    end

    local handle = io.popen(cmd)
    if handle then
        local result = handle:read("*l")
        handle:close()
        return result == "OK"
    end
    return false
end

-- Check for ffmpeg
local function checkFFmpeg()
    local cmd = OS == "Windows" and "where ffmpeg 2>nul" or "which ffmpeg 2>/dev/null"
    local handle = io.popen(cmd)
    if handle then
        local result = handle:read("*l")
        handle:close()
        return result and result ~= ""
    end
    return false
end

-- Get install instructions based on OS
local function getInstallInstructions()
    if OS == "Windows" then
        return [[
WINDOWS INSTALLATION:

Option 1: Automatic (Recommended)
1. Open PowerShell as Administrator
2. Navigate to Stemperator folder
3. Run: .\scripts\install.ps1

Option 2: Manual
1. Install Python 3.10+ from https://www.python.org
   (Check "Add Python to PATH")
2. Install ffmpeg from https://ffmpeg.org
3. Open Command Prompt and run:
   pip install audio-separator[gpu]
]]
    elseif OS == "macOS" then
        return [[
macOS INSTALLATION:

Option 1: Automatic (Recommended)
1. Open Terminal
2. Navigate to Stemperator folder
3. Run: ./scripts/install.sh

Option 2: Manual with Homebrew
1. Install Homebrew if not present:
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
2. Run:
   brew install python@3.12 ffmpeg
   pip3 install audio-separator[gpu]
]]
    else
        return [[
LINUX INSTALLATION:

Option 1: Automatic (Recommended)
1. Open Terminal
2. Navigate to Stemperator folder
3. Run: ./scripts/install.sh

Option 2: Manual
Ubuntu/Debian:
  sudo apt install python3 python3-pip python3-venv ffmpeg
  pip3 install audio-separator[gpu]

Arch Linux:
  sudo pacman -S python python-pip ffmpeg
  pip install audio-separator[gpu]

Fedora:
  sudo dnf install python3 python3-pip ffmpeg
  pip3 install audio-separator[gpu]
]]
    end
end

-- Main check
local function main()
    local status = {}
    local allOk = true

    -- Check Python
    local pythonPath, pythonFound = findPython()
    if pythonFound then
        status[#status + 1] = "✓ Python found: " .. pythonPath
    else
        status[#status + 1] = "✗ Python NOT found"
        allOk = false
    end

    -- Check audio-separator
    if pythonFound then
        if checkAudioSeparator(pythonPath) then
            status[#status + 1] = "✓ audio-separator installed"
        else
            status[#status + 1] = "✗ audio-separator NOT installed"
            allOk = false
        end
    end

    -- Check ffmpeg
    if checkFFmpeg() then
        status[#status + 1] = "✓ ffmpeg found"
    else
        status[#status + 1] = "✗ ffmpeg NOT found"
        allOk = false
    end

    -- Check separator script
    local scriptPath = findSeparatorScript()
    if scriptPath then
        status[#status + 1] = "✓ Separator script found"
    else
        status[#status + 1] = "✗ Separator script NOT found"
        allOk = false
    end

    -- Build message
    local msg = "STEMPERATOR AI BACKEND STATUS\n"
    msg = msg .. "==============================\n\n"

    for _, s in ipairs(status) do
        msg = msg .. s .. "\n"
    end

    msg = msg .. "\n"

    if allOk then
        msg = msg .. "All components are installed!\n\n"
        msg = msg .. "You can now use Stemperator for AI stem separation.\n"
        msg = msg .. "Try: Stemperator > AI Stem Separation"

        reaper.MB(msg, SCRIPT_NAME, 0)
    else
        msg = msg .. "Some components are missing.\n\n"
        msg = msg .. "Would you like to see installation instructions?"

        local result = reaper.MB(msg, SCRIPT_NAME, 4)  -- Yes/No

        if result == 6 then  -- Yes
            reaper.MB(getInstallInstructions(), "Installation Instructions", 0)
        end
    end
end

main()
