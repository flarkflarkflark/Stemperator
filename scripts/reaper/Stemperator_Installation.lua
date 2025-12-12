-- @description STEMperator - Installation & Setup
-- @author flarkAUDIO
-- @version 2.1.0
-- @changelog
--   v2.1.0: Live progress window
--   - Added real-time progress window during installation
--   - Automatically opens console for detailed logging
--   - Shows installation status with progress bar
--   - Displays final result dialog after completion
--   v2.0.0: Enhanced installation system
--   - Cross-platform Python/audio-separator installation
--   - GPU detection (NVIDIA CUDA, AMD ROCm, Apple MPS)
--   - Automatic venv creation and dependency install
--   v1.0.0: Initial release
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
local SCRIPT_VERSION = "2.1.0"

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

-- Progress window state
local progress_window = {
    open = false,
    step = 0,
    total_steps = 5,
    current_task = "",
    status_lines = {},
    success = nil,
    error_msg = ""
}

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

-- Update progress window
local function updateProgress(step, task, status_line)
    progress_window.step = step
    progress_window.current_task = task
    if status_line then
        table.insert(progress_window.status_lines, status_line)
        -- Keep only last 8 lines
        if #progress_window.status_lines > 8 then
            table.remove(progress_window.status_lines, 1)
        end
    end
    log(task)
    if status_line then log(status_line) end
end

-- Draw progress window
local function drawProgressWindow()
    local w, h = 600, 400
    gfx.clear = 0x1a1a1a  -- Dark background
    
    -- Title
    gfx.setfont(1, "Arial", 18, 'b')
    gfx.x, gfx.y = 20, 20
    gfx.r, gfx.g, gfx.b = 0.9, 0.9, 0.9
    gfx.drawstr("STEMperator Installation & Setup v" .. SCRIPT_VERSION)
    
    -- OS info
    gfx.setfont(1, "Arial", 12)
    gfx.x, gfx.y = 20, 50
    gfx.r, gfx.g, gfx.b = 0.7, 0.7, 0.7
    gfx.drawstr("Operating System: " .. OS)
    
    -- Progress bar
    local bar_x, bar_y = 20, 80
    local bar_w, bar_h = w - 40, 30
    local progress = progress_window.step / progress_window.total_steps
    
    -- Background
    gfx.r, gfx.g, gfx.b = 0.2, 0.2, 0.2
    gfx.rect(bar_x, bar_y, bar_w, bar_h)
    
    -- Progress fill
    if progress_window.success == true then
        gfx.r, gfx.g, gfx.b = 0.2, 0.8, 0.3  -- Green for success
    elseif progress_window.success == false then
        gfx.r, gfx.g, gfx.b = 0.9, 0.2, 0.2  -- Red for error
    else
        gfx.r, gfx.g, gfx.b = 0.3, 0.6, 0.9  -- Blue for in progress
    end
    gfx.rect(bar_x, bar_y, bar_w * progress, bar_h)
    
    -- Border
    gfx.r, gfx.g, gfx.b = 0.5, 0.5, 0.5
    gfx.rect(bar_x, bar_y, bar_w, bar_h, 0)
    
    -- Progress text
    gfx.setfont(1, "Arial", 14, 'b')
    gfx.x, gfx.y = bar_x + bar_w/2 - 40, bar_y + 8
    gfx.r, gfx.g, gfx.b = 1, 1, 1
    gfx.drawstr(string.format("Step %d / %d", progress_window.step, progress_window.total_steps))
    
    -- Current task
    gfx.setfont(1, "Arial", 14, 'b')
    gfx.x, gfx.y = 20, 130
    gfx.r, gfx.g, gfx.b = 0.3, 0.8, 0.9
    gfx.drawstr(progress_window.current_task)
    
    -- Status lines
    gfx.setfont(1, "Courier New", 11)
    local line_y = 160
    for i, line in ipairs(progress_window.status_lines) do
        gfx.x, gfx.y = 20, line_y + (i-1) * 20
        gfx.r, gfx.g, gfx.b = 0.8, 0.8, 0.8
        gfx.drawstr(line)
    end
    
    -- Error message
    if progress_window.success == false and progress_window.error_msg ~= "" then
        gfx.setfont(1, "Arial", 12, 'b')
        gfx.x, gfx.y = 20, h - 60
        gfx.r, gfx.g, gfx.b = 1, 0.3, 0.3
        gfx.drawstr("ERROR: " .. progress_window.error_msg)
    end
    
    -- Instructions
    gfx.setfont(1, "Arial", 11)
    gfx.x, gfx.y = 20, h - 30
    gfx.r, gfx.g, gfx.b = 0.6, 0.6, 0.6
    if progress_window.success == nil then
        gfx.drawstr("Check the console (View -> ReaScript console) for detailed output...")
    elseif progress_window.success == true then
        gfx.drawstr("Installation complete! You can close this window.")
    else
        gfx.drawstr("Installation failed. Check console for details. Close window to exit.")
    end
    
    gfx.update()
end

-- Open progress window
local function openProgressWindow()
    gfx.init("STEMperator Installation Progress", 600, 400, 0, 100, 100)
    progress_window.open = true
    progress_window.step = 0
    progress_window.current_task = "Starting installation..."
    progress_window.status_lines = {}
    progress_window.success = nil
    
    -- Open console automatically
    reaper.ClearConsole()
    reaper.ShowConsoleMsg("STEMperator Installation Log\n")
    reaper.ShowConsoleMsg("=" .. string.rep("=", 60) .. "\n\n")
end

-- Main loop for progress window
local function progressWindowLoop()
    if gfx.getchar() >= 0 and progress_window.open then
        drawProgressWindow()
        reaper.defer(progressWindowLoop)
    else
        progress_window.open = false
        gfx.quit()
    end
end

-- Find system Python
local function findSystemPython()
    local paths = {}

    if OS == "Windows" then
        local localAppData = os.getenv("LOCALAPPDATA") or ""
        table.insert(paths, {path = localAppData .. "\\Programs\\Python\\Python313\\python.exe", version = "3.13"})
        table.insert(paths, {path = localAppData .. "\\Programs\\Python\\Python312\\python.exe", version = "3.12"})
        table.insert(paths, {path = localAppData .. "\\Programs\\Python\\Python311\\python.exe", version = "3.11"})
        table.insert(paths, {path = localAppData .. "\\Programs\\Python\\Python310\\python.exe", version = "3.10"})
        table.insert(paths, {path = "C:\\Python313\\python.exe", version = "3.13"})
        table.insert(paths, {path = "C:\\Python312\\python.exe", version = "3.12"})
        table.insert(paths, {path = "C:\\Python311\\python.exe", version = "3.11"})
        table.insert(paths, {path = "C:\\Python310\\python.exe", version = "3.10"})
        local py_version = execCommand("py --version")
        if py_version:match("Python 3") then
            return "py", py_version:match("Python ([%d%.]+)")
        end
        local python_version = execCommand("python --version")
        if python_version:match("Python 3") then
            return "python", python_version:match("Python ([%d%.]+)")
        end
    elseif OS == "macOS" then
        table.insert(paths, {path = "/opt/homebrew/bin/python3", version = nil})
        table.insert(paths, {path = "/usr/local/bin/python3", version = nil})
        table.insert(paths, {path = "/usr/bin/python3", version = nil})
    else
        table.insert(paths, {path = "/usr/bin/python3.13", version = "3.13"})
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
        if execCheck("nvidia-smi") then
            return "cuda", "NVIDIA GPU detected"
        end
        local wmic = execCommand("wmic path win32_VideoController get name")
        if wmic:lower():match("radeon") or wmic:lower():match("amd") then
            return "directml", "AMD GPU detected (using DirectML)"
        end
        return "cpu", "No GPU detected, using CPU"
    elseif OS == "macOS" then
        local arch = execCommand("uname -m")
        if arch:match("arm64") then
            return "mps", "Apple Silicon detected (using MPS)"
        end
        return "cpu", "Intel Mac detected, using CPU"
    else
        if execCheck("nvidia-smi") then
            return "cuda", "NVIDIA GPU detected"
        end
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
    updateProgress(4, "[4/5] Creating Python virtual environment...", "Path: " .. getVenvPath())

    local venv = getVenvPath()
    local cmd = '"' .. system_python .. '" -m venv "' .. venv .. '"'
    if not execCheck(cmd) then
        progress_window.success = false
        progress_window.error_msg = "Failed to create virtual environment"
        updateProgress(4, "[4/5] ERROR", "Failed to create venv")
        return false
    end

    updateProgress(4, "[4/5] Virtual environment created", "✓ venv ready")
    return true
end

-- Install dependencies
local function installDependencies(gpu_type)
    local pip = getVenvPip()
    local python = getVenvPython()

    if not fileExists(pip) then
        progress_window.success = false
        progress_window.error_msg = "pip not found in virtual environment"
        return false
    end

    updateProgress(5, "[5/5] Installing AI dependencies...", "→ Upgrading pip...")
    execCheck('"' .. python .. '" -m pip install --upgrade pip')

    updateProgress(5, "[5/5] Installing AI dependencies...", "→ Installing PyTorch for " .. gpu_type .. "...")
    local torch_cmd

    if gpu_type == "cuda" then
        torch_cmd = '"' .. pip .. '" install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121'
    elseif gpu_type == "rocm" then
        torch_cmd = '"' .. pip .. '" install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm6.0'
    elseif gpu_type == "directml" then
        torch_cmd = '"' .. pip .. '" install torch torchvision torchaudio torch-directml'
    elseif gpu_type == "mps" then
        torch_cmd = '"' .. pip .. '" install torch torchvision torchaudio'
    else
        torch_cmd = '"' .. pip .. '" install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu'
    end

    if not execCheck(torch_cmd) then
        updateProgress(5, "[5/5] Installing AI dependencies...", "⚠ PyTorch may have issues, continuing...")
    else
        updateProgress(5, "[5/5] Installing AI dependencies...", "✓ PyTorch installed")
    end

    updateProgress(5, "[5/5] Installing AI dependencies...", "→ Installing audio-separator...")
    local sep_cmd = '"' .. pip .. '" install "audio-separator[cpu]"'
    if gpu_type ~= "cpu" then
        sep_cmd = '"' .. pip .. '" install audio-separator'
    end

    if not execCheck(sep_cmd) then
        progress_window.success = false
        progress_window.error_msg = "Failed to install audio-separator"
        updateProgress(5, "[5/5] ERROR", "✗ audio-separator install failed")
        return false
    end
    updateProgress(5, "[5/5] Installing AI dependencies...", "✓ audio-separator installed")

    updateProgress(5, "[5/5] Installing AI dependencies...", "→ Installing ffmpeg-python...")
    execCheck('"' .. pip .. '" install ffmpeg-python')
    updateProgress(5, "[5/5] Installing AI dependencies...", "✓ All dependencies installed!")

    return true
end

-- Check ffmpeg installation
local function checkFfmpeg()
    return execCheck("ffmpeg -version")
end

-- Main installation function with progress window
local function runInstallationWithProgress()
    openProgressWindow()
    
    -- Defer both window rendering and installation to avoid blocking
    reaper.defer(progressWindowLoop)  -- Start window loop
    
    -- Start installation in next defer cycle
    reaper.defer(function()
        updateProgress(0, "Starting installation...", "Operating System: " .. OS)
    updateProgress(0, "", "Script path: " .. script_path)
    
    -- Step 1: Find Python
    updateProgress(1, "[1/5] Checking for Python installation...", "→ Searching for Python 3.9+...")
    local system_python, python_version = findSystemPython()

    if not system_python then
        progress_window.success = false
        progress_window.error_msg = "Python 3.9+ not found"
        updateProgress(1, "[1/5] ERROR", "✗ Python not found")
        
        if OS == "Windows" then
            log("Install from: https://www.python.org/downloads/")
        elseif OS == "macOS" then
            log("Run: brew install python@3.11")
        else
            log("Run: sudo apt install python3 python3-venv python3-pip")
        end
        
        reaper.defer(function()
            reaper.MB("Python 3.9+ not found!\n\nPlease install Python and try again.\nSee console for installation instructions.", "Installation Failed", 0)
        end)
        return false
    end

    updateProgress(1, "[1/5] Python found", "✓ Python " .. (python_version or "3.x"))

    -- Step 2: Check ffmpeg
    updateProgress(2, "[2/5] Checking for ffmpeg...", "→ Looking for ffmpeg...")
    if checkFfmpeg() then
        updateProgress(2, "[2/5] ffmpeg found", "✓ ffmpeg is installed")
    else
        updateProgress(2, "[2/5] ffmpeg not found", "⚠ WARNING: ffmpeg not found")
        log("WARNING: Stem separation won't work without ffmpeg")
    end

    -- Step 3: Detect GPU
    updateProgress(3, "[3/5] Detecting GPU...", "→ Scanning for GPU hardware...")
    local gpu_type, gpu_msg = detectGPU()
    updateProgress(3, "[3/5] GPU detection complete", "✓ " .. gpu_msg)

    -- Step 4: Create venv
    local venv_python = getVenvPython()
    local venv_exists = fileExists(venv_python)

    if venv_exists then
        updateProgress(4, "[4/5] Checking virtual environment...", "✓ venv already exists")

        if checkAudioSeparator() then
            updateProgress(5, "[5/5] Verification complete", "✓ audio-separator already installed")
            progress_window.success = true
            progress_window.current_task = "Installation verified - STEMperator is ready!"
            
            reaper.defer(function()
                reaper.MB("STEMperator is already installed and ready!\n\nGPU Backend: " .. gpu_type:upper() .. "\n\nYou can now use STEMperator from the Actions menu.", "Installation Verified", 0)
            end)
            return true
        else
            updateProgress(4, "[4/5] Virtual environment found", "→ Installing missing dependencies...")
        end
    else
        if not createVenv(system_python) then
            reaper.defer(function()
                reaper.MB("Failed to create Python virtual environment!\n\nCheck console for details.", "Installation Failed", 0)
            end)
            return false
        end
    end

    -- Step 5: Install dependencies
    if not installDependencies(gpu_type) then
        reaper.defer(function()
            reaper.MB("Failed to install AI dependencies!\n\nCheck console for details.", "Installation Failed", 0)
        end)
        return false
    end

    -- Verify installation
    updateProgress(5, "[5/5] Verifying installation...", "→ Checking audio-separator...")
    if checkAudioSeparator() then
        progress_window.success = true
        updateProgress(5, "[5/5] SUCCESS!", "✓ STEMperator is ready to use!")
        log("")
        log("GPU Backend: " .. gpu_type:upper())
        log("Python venv: " .. getVenvPath())
        
        reaper.defer(function()
            reaper.MB("Installation complete!\n\nGPU Backend: " .. gpu_type:upper() .. "\n\nYou can now use STEMperator from the Actions menu.", "Installation Successful", 0)
        end)
        return true
    else
        progress_window.success = false
        progress_window.error_msg = "Installation verification failed"
        updateProgress(5, "[5/5] ERROR", "✗ Verification failed")
        
        reaper.defer(function()
            reaper.MB("Installation verification failed!\n\nCheck console for details.", "Installation Failed", 0)
        end)
        return false
    end
    end)  -- End deferred installation function
end

-- Check existing installation status
local function checkStatus()
    reaper.ClearConsole()
    log("=" .. string.rep("=", 50))
    log("  STEMperator Installation Status")
    log("=" .. string.rep("=", 50))
    log("")

    local system_python, python_version = findSystemPython()
    if system_python then
        log("[OK] System Python: " .. (python_version or "3.x"))
    else
        log("[!!] System Python: NOT FOUND")
    end

    if checkFfmpeg() then
        log("[OK] ffmpeg: installed")
    else
        log("[!!] ffmpeg: NOT FOUND")
    end

    local venv_python = getVenvPython()
    if fileExists(venv_python) then
        log("[OK] Virtual environment: " .. getVenvPath())
    else
        log("[!!] Virtual environment: NOT CREATED")
    end

    if checkAudioSeparator() then
        log("[OK] audio-separator: installed")
    else
        log("[!!] audio-separator: NOT INSTALLED")
    end

    local gpu_type, gpu_msg = detectGPU()
    log("[OK] GPU: " .. gpu_msg)

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
        "STEMperator Installation & Setup v" .. SCRIPT_VERSION .. "\n\n" ..
        "Status: " .. status_text .. "\n\n" ..
        "Click YES to run installation/verification\n" ..
        "(A progress window will appear with live updates)\n\n" ..
        "Click NO to just check status\n" ..
        "Click CANCEL to exit",
        SCRIPT_NAME,
        3  -- Yes/No/Cancel
    )

    if ret == 6 then  -- Yes
        runInstallationWithProgress()
    elseif ret == 7 then  -- No
        checkStatus()
    end
end

-- Run
showDialog()
