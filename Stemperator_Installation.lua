-- @description STEMperator - Installation & Setup
-- @author flarkAUDIO
-- @version 1.0.0
-- @changelog
--   v1.0.0: Initial release
--   - Cross-platform Python/audio-separator installation
--   - GPU detection (NVIDIA CUDA, AMD ROCm, Apple MPS)
--   - Automatic venv creation and dependency install
-- @provides
--   [main] .
-- @link Repository https://github.com/flarkflarkflark/Stemperator
-- @about
--   # STEMperator - Installation & Setup
--
--   This script sets up the AI backend for STEMperator:
--   - Creates a Python virtual environment
--   - Installs audio-separator and Demucs
--   - Detects and configures GPU acceleration
--
--   Run this script once after installing STEMperator via ReaPack.
--
--   ## Requirements
--   - Python 3.9+ installed on your system
--   - ffmpeg installed and in PATH
--
--   ## GPU Support
--   - NVIDIA: CUDA (auto-detected)
--   - AMD: ROCm on Linux, DirectML on Windows
--   - Apple Silicon: MPS (auto-detected)

local SCRIPT_NAME = "STEMperator: Installation & Setup"
local SCRIPT_VERSION = "1.0.0"

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
local NULL_REDIRECT = OS == "Windows" and " 2>NUL" or " 2>/dev/null"

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
    if OS == "Windows" then
        local ok = os.execute('if exist "' .. path .. '\\*" (exit 0) else (exit 1)')
        return ok == true or ok == 0
    else
        local ok = os.execute('test -d "' .. path .. '"')
        return ok == true or ok == 0
    end
end

-- Execute command and get output
local function execCommand(cmd)
    local handle = io.popen(cmd .. NULL_REDIRECT)
    if handle then
        local result = handle:read("*a")
        handle:close()
        return result and result:gsub("^%s+", ""):gsub("%s+$", "") or ""
    end
    return ""
end

-- Execute command and check success
local function execCheck(cmd)
    local result = os.execute(cmd .. NULL_REDIRECT)
    return result == true or result == 0
end

-- Log messages
local log_messages = {}
local function log(msg)
    table.insert(log_messages, msg)
    reaper.ShowConsoleMsg(msg .. "\n")
end

-- Find system Python
local function findSystemPython()
    local paths = {}

    if OS == "Windows" then
        -- Windows Python locations
        local localAppData = os.getenv("LOCALAPPDATA") or ""
        table.insert(paths, {path = localAppData .. "\\Programs\\Python\\Python312\\python.exe", version = "3.12"})
        table.insert(paths, {path = localAppData .. "\\Programs\\Python\\Python311\\python.exe", version = "3.11"})
        table.insert(paths, {path = localAppData .. "\\Programs\\Python\\Python310\\python.exe", version = "3.10"})
        table.insert(paths, {path = "C:\\Python312\\python.exe", version = "3.12"})
        table.insert(paths, {path = "C:\\Python311\\python.exe", version = "3.11"})
        table.insert(paths, {path = "C:\\Python310\\python.exe", version = "3.10"})
        -- Try py launcher
        local py_version = execCommand("py --version")
        if py_version:match("Python 3") then
            return "py", py_version:match("Python ([%d%.]+)")
        end
        -- Try python directly
        local python_version = execCommand("python --version")
        if python_version:match("Python 3") then
            return "python", python_version:match("Python ([%d%.]+)")
        end
    elseif OS == "macOS" then
        -- macOS Homebrew paths
        table.insert(paths, {path = "/opt/homebrew/bin/python3", version = nil})
        table.insert(paths, {path = "/usr/local/bin/python3", version = nil})
        table.insert(paths, {path = "/usr/bin/python3", version = nil})
    else
        -- Linux paths
        table.insert(paths, {path = "/usr/bin/python3.12", version = "3.12"})
        table.insert(paths, {path = "/usr/bin/python3.11", version = "3.11"})
        table.insert(paths, {path = "/usr/bin/python3.10", version = "3.10"})
        table.insert(paths, {path = "/usr/bin/python3", version = nil})
        table.insert(paths, {path = "/usr/local/bin/python3", version = nil})
    end

    for _, p in ipairs(paths) do
        if fileExists(p.path) then
            local version = p.version
            if not version then
                local v = execCommand('"' .. p.path .. '" --version')
                version = v:match("Python ([%d%.]+)")
            end
            return p.path, version
        end
    end

    -- Last resort: try python3/python command
    local cmd = OS == "Windows" and "python" or "python3"
    local version = execCommand(cmd .. " --version")
    if version:match("Python 3") then
        return cmd, version:match("Python ([%d%.]+)")
    end

    return nil, nil
end

-- Detect GPU type
local function detectGPU()
    if OS == "Windows" then
        -- Check for NVIDIA
        if execCheck("nvidia-smi") then
            return "cuda", "NVIDIA GPU detected"
        end
        -- Check for AMD (use DirectML on Windows)
        local wmic = execCommand("wmic path win32_VideoController get name")
        if wmic:lower():match("radeon") or wmic:lower():match("amd") then
            return "directml", "AMD GPU detected (using DirectML)"
        end
        return "cpu", "No GPU detected, using CPU"
    elseif OS == "macOS" then
        -- Check for Apple Silicon
        local arch = execCommand("uname -m")
        if arch:match("arm64") then
            return "mps", "Apple Silicon detected (using MPS)"
        end
        return "cpu", "Intel Mac detected, using CPU"
    else
        -- Linux
        -- Check for NVIDIA
        if execCheck("nvidia-smi") then
            return "cuda", "NVIDIA GPU detected"
        end
        -- Check for AMD ROCm
        if execCheck("rocminfo") then
            return "rocm", "AMD GPU detected (using ROCm)"
        end
        if fileExists("/opt/rocm/bin/rocminfo") then
            return "rocm", "AMD ROCm installation detected"
        end
        return "cpu", "No GPU detected, using CPU"
    end
end

-- Get venv path
local function getVenvPath()
    return script_path .. ".venv"
end

-- Get Python executable in venv
local function getVenvPython()
    local venv = getVenvPath()
    if OS == "Windows" then
        return venv .. "\\Scripts\\python.exe"
    else
        return venv .. "/bin/python"
    end
end

-- Get pip executable in venv
local function getVenvPip()
    local venv = getVenvPath()
    if OS == "Windows" then
        return venv .. "\\Scripts\\pip.exe"
    else
        return venv .. "/bin/pip"
    end
end

-- Check if audio-separator is installed
local function checkAudioSeparator()
    local python = getVenvPython()
    if not fileExists(python) then return false end
    return execCheck('"' .. python .. '" -c "import audio_separator"')
end

-- Create virtual environment
local function createVenv(system_python)
    local venv = getVenvPath()
    log("Creating virtual environment at: " .. venv)

    local cmd = '"' .. system_python .. '" -m venv "' .. venv .. '"'
    if not execCheck(cmd) then
        log("ERROR: Failed to create virtual environment")
        return false
    end

    log("Virtual environment created successfully")
    return true
end

-- Install dependencies
local function installDependencies(gpu_type)
    local pip = getVenvPip()
    local python = getVenvPython()

    if not fileExists(pip) then
        log("ERROR: pip not found in virtual environment")
        return false
    end

    -- Upgrade pip first
    log("Upgrading pip...")
    execCheck('"' .. python .. '" -m pip install --upgrade pip')

    -- Install PyTorch based on GPU type
    log("Installing PyTorch for " .. gpu_type .. "...")
    local torch_cmd

    if gpu_type == "cuda" then
        -- NVIDIA CUDA
        torch_cmd = '"' .. pip .. '" install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121'
    elseif gpu_type == "rocm" then
        -- AMD ROCm (Linux only)
        torch_cmd = '"' .. pip .. '" install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm6.0'
    elseif gpu_type == "directml" then
        -- AMD DirectML (Windows)
        torch_cmd = '"' .. pip .. '" install torch torchvision torchaudio torch-directml'
    elseif gpu_type == "mps" then
        -- Apple MPS - standard PyTorch includes MPS support
        torch_cmd = '"' .. pip .. '" install torch torchvision torchaudio'
    else
        -- CPU fallback
        torch_cmd = '"' .. pip .. '" install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu'
    end

    if not execCheck(torch_cmd) then
        log("WARNING: PyTorch installation may have issues, continuing...")
    end

    -- Install audio-separator
    log("Installing audio-separator...")
    local sep_cmd = '"' .. pip .. '" install "audio-separator[cpu]"'
    if gpu_type ~= "cpu" then
        -- For GPU, we already installed torch, just need audio-separator without extras
        sep_cmd = '"' .. pip .. '" install audio-separator'
    end

    if not execCheck(sep_cmd) then
        log("ERROR: Failed to install audio-separator")
        return false
    end

    -- Install ffmpeg-python for audio processing
    log("Installing ffmpeg-python...")
    execCheck('"' .. pip .. '" install ffmpeg-python')

    log("Dependencies installed successfully!")
    return true
end

-- Check ffmpeg installation
local function checkFfmpeg()
    return execCheck("ffmpeg -version")
end

-- Main installation function
local function runInstallation()
    log("=" .. string.rep("=", 50))
    log("  STEMperator Installation & Setup v" .. SCRIPT_VERSION)
    log("=" .. string.rep("=", 50))
    log("")
    log("Operating System: " .. OS)
    log("Script path: " .. script_path)
    log("")

    -- Step 1: Find Python
    log("[1/5] Checking for Python installation...")
    local system_python, python_version = findSystemPython()

    if not system_python then
        log("")
        log("ERROR: Python 3.9+ not found!")
        log("")
        if OS == "Windows" then
            log("Please install Python from https://www.python.org/downloads/")
            log("Make sure to check 'Add Python to PATH' during installation")
        elseif OS == "macOS" then
            log("Install Python with Homebrew: brew install python@3.11")
        else
            log("Install Python: sudo apt install python3 python3-venv python3-pip")
        end
        return false
    end

    log("Found Python " .. (python_version or "3.x") .. " at: " .. system_python)

    -- Check Python version
    if python_version then
        local major, minor = python_version:match("(%d+)%.(%d+)")
        if major and minor then
            if tonumber(major) < 3 or (tonumber(major) == 3 and tonumber(minor) < 9) then
                log("WARNING: Python 3.9+ recommended, found " .. python_version)
            end
        end
    end

    -- Step 2: Check ffmpeg
    log("")
    log("[2/5] Checking for ffmpeg...")
    if checkFfmpeg() then
        log("ffmpeg found!")
    else
        log("")
        log("WARNING: ffmpeg not found!")
        if OS == "Windows" then
            log("Install ffmpeg: winget install ffmpeg")
            log("Or download from https://ffmpeg.org/download.html")
        elseif OS == "macOS" then
            log("Install ffmpeg: brew install ffmpeg")
        else
            log("Install ffmpeg: sudo apt install ffmpeg")
        end
        log("")
        log("Installation will continue, but stem separation won't work without ffmpeg")
    end

    -- Step 3: Detect GPU
    log("")
    log("[3/5] Detecting GPU...")
    local gpu_type, gpu_msg = detectGPU()
    log(gpu_msg)

    -- Step 4: Create venv
    log("")
    log("[4/5] Setting up Python virtual environment...")

    local venv_python = getVenvPython()
    local venv_exists = fileExists(venv_python)

    if venv_exists then
        log("Virtual environment already exists")

        -- Check if audio-separator is installed
        if checkAudioSeparator() then
            log("audio-separator is already installed!")
            log("")
            log("=" .. string.rep("=", 50))
            log("  Installation verified - STEMperator is ready!")
            log("=" .. string.rep("=", 50))
            return true
        else
            log("audio-separator not found, installing dependencies...")
        end
    else
        if not createVenv(system_python) then
            return false
        end
    end

    -- Step 5: Install dependencies
    log("")
    log("[5/5] Installing AI dependencies (this may take several minutes)...")
    if not installDependencies(gpu_type) then
        return false
    end

    -- Verify installation
    log("")
    log("Verifying installation...")
    if checkAudioSeparator() then
        log("")
        log("=" .. string.rep("=", 50))
        log("  SUCCESS! STEMperator is ready to use!")
        log("=" .. string.rep("=", 50))
        log("")
        log("GPU Backend: " .. gpu_type:upper())
        log("Python venv: " .. getVenvPath())
        log("")
        log("You can now run STEMperator from REAPER's Actions menu.")
        return true
    else
        log("")
        log("ERROR: Installation verification failed")
        log("Please check the console output for errors")
        return false
    end
end

-- Check existing installation status
local function checkStatus()
    log("=" .. string.rep("=", 50))
    log("  STEMperator Installation Status")
    log("=" .. string.rep("=", 50))
    log("")

    -- Check Python
    local system_python, python_version = findSystemPython()
    if system_python then
        log("[OK] System Python: " .. (python_version or "3.x"))
    else
        log("[!!] System Python: NOT FOUND")
    end

    -- Check ffmpeg
    if checkFfmpeg() then
        log("[OK] ffmpeg: installed")
    else
        log("[!!] ffmpeg: NOT FOUND")
    end

    -- Check venv
    local venv_python = getVenvPython()
    if fileExists(venv_python) then
        log("[OK] Virtual environment: " .. getVenvPath())
    else
        log("[!!] Virtual environment: NOT CREATED")
    end

    -- Check audio-separator
    if checkAudioSeparator() then
        log("[OK] audio-separator: installed")
    else
        log("[!!] audio-separator: NOT INSTALLED")
    end

    -- Check GPU
    local gpu_type, gpu_msg = detectGPU()
    log("[OK] GPU: " .. gpu_msg)

    -- Check audio_separator_process.py
    local separator_script = script_path .. "audio_separator_process.py"
    if fileExists(separator_script) then
        log("[OK] Processing script: found")
    else
        log("[!!] Processing script: NOT FOUND")
        log("     Expected at: " .. separator_script)
    end

    log("")
end

-- Show dialog
local function showDialog()
    local venv_exists = fileExists(getVenvPython())
    local audio_sep_ok = checkAudioSeparator()

    local status_text = ""
    if audio_sep_ok then
        status_text = "STEMperator is properly installed and ready to use!"
    elseif venv_exists then
        status_text = "Virtual environment exists but dependencies need to be installed."
    else
        status_text = "STEMperator needs to be set up before first use."
    end

    local ret = reaper.ShowMessageBox(
        "STEMperator Installation & Setup\n\n" ..
        "Status: " .. status_text .. "\n\n" ..
        "Click YES to run installation/verification\n" ..
        "Click NO to just check status\n" ..
        "Click CANCEL to exit",
        SCRIPT_NAME,
        3  -- Yes/No/Cancel
    )

    if ret == 6 then  -- Yes
        reaper.ClearConsole()
        runInstallation()
    elseif ret == 7 then  -- No
        reaper.ClearConsole()
        checkStatus()
    end
    -- Cancel = do nothing
end

-- Run
showDialog()
