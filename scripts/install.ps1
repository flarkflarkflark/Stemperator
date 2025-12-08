#Requires -Version 5.1
<#
.SYNOPSIS
    Stemperator - Windows Installation Script
.DESCRIPTION
    Installs Python environment and audio-separator for AI stem separation
.PARAMETER NoGPU
    Disable GPU acceleration (CPU only)
.PARAMETER SkipPython
    Skip Python installation check
.EXAMPLE
    .\install.ps1
    .\install.ps1 -NoGPU
#>

param(
    [switch]$NoGPU,
    [switch]$SkipPython
)

$ErrorActionPreference = "Stop"

# Script location
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$VenvDir = Join-Path $ProjectRoot ".venv"

# Colors
function Write-Header { Write-Host "`n==============================================`n Stemperator - AI Stem Separation Setup`n==============================================`n" -ForegroundColor Cyan }
function Write-Success { param($msg) Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Warning { param($msg) Write-Host "[!] $msg" -ForegroundColor Yellow }
function Write-Error { param($msg) Write-Host "[X] $msg" -ForegroundColor Red }
function Write-Info { param($msg) Write-Host "[-] $msg" -ForegroundColor Blue }

# Find Python
function Find-Python {
    # Try py launcher first (Windows Python)
    if (Get-Command py -ErrorAction SilentlyContinue) {
        # Try Python 3.11 specifically (best compatibility)
        try {
            $null = & py -3.11 --version 2>&1
            if ($LASTEXITCODE -eq 0) {
                $version = & py -3.11 --version 2>&1 | Out-String
                if ($version -match "Python 3\.11") {
                    Write-Info "Found Python 3.11 (preferred version)"
                    return "py -3.11"
                }
            }
        } catch {}

        # Try Python 3.10
        try {
            $null = & py -3.10 --version 2>&1
            if ($LASTEXITCODE -eq 0) {
                $version = & py -3.10 --version 2>&1 | Out-String
                if ($version -match "Python 3\.10") {
                    Write-Info "Found Python 3.10"
                    return "py -3.10"
                }
            }
        } catch {}

        # Try Python 3.12 (has limited DirectML support)
        try {
            $null = & py -3.12 --version 2>&1
            if ($LASTEXITCODE -eq 0) {
                $version = & py -3.12 --version 2>&1 | Out-String
                if ($version -match "Python 3\.12") {
                    Write-Info "Found Python 3.12"
                    return "py -3.12"
                }
            }
        } catch {}

        # Try Python 3.9
        try {
            $null = & py -3.9 --version 2>&1
            if ($LASTEXITCODE -eq 0) {
                $version = & py -3.9 --version 2>&1 | Out-String
                if ($version -match "Python 3\.9") {
                    Write-Info "Found Python 3.9"
                    return "py -3.9"
                }
            }
        } catch {}

        # Only use generic `py -3` as last resort (might pick wrong version)
        try {
            $version = & py -3 --version 2>&1 | Out-String
            if ($version -match "Python 3\.(\d+)") {
                $minor = [int]$Matches[1]
                # Reject Python 3.14+ even here
                if ($minor -lt 14) {
                    Write-Info "Found Python 3.$minor via py launcher"
                    return "py -3"
                }
            }
        } catch {}
    }

    # Try python3
    if (Get-Command python3 -ErrorAction SilentlyContinue) {
        return "python3"
    }

    # Try python
    if (Get-Command python -ErrorAction SilentlyContinue) {
        try {
            $version = & python --version 2>&1 | Out-String
            if ($version -match "Python 3") {
                return "python"
            }
        } catch {}
    }

    return $null
}

# Check Python version
function Test-PythonVersion {
    param($pythonCmd)

    $versionOutput = & cmd /c "$pythonCmd --version 2>&1"
    if ($versionOutput -match "Python (\d+)\.(\d+)") {
        $major = [int]$Matches[1]
        $minor = [int]$Matches[2]
        return ($major -ge 3 -and $minor -ge 9)
    }
    return $false
}

# Get Python version details
function Get-PythonVersion {
    param($pythonCmd)

    $versionOutput = & cmd /c "$pythonCmd --version 2>&1"
    if ($versionOutput -match "Python (\d+)\.(\d+)") {
        return @{
            Major = [int]$Matches[1]
            Minor = [int]$Matches[2]
        }
    }
    return $null
}

# Check if Python version is compatible with torch-directml
function Test-DirectMLCompatible {
    param($pythonCmd)

    $version = Get-PythonVersion $pythonCmd
    if ($null -eq $version) {
        return $false
    }

    # torch-directml typically supports Python 3.8-3.11
    # Python 3.12+ is not yet supported as of 2024
    return ($version.Major -eq 3 -and $version.Minor -ge 8 -and $version.Minor -le 11)
}

# Detect GPU
function Get-GPUType {
    # Check for NVIDIA
    if (Get-Command nvidia-smi -ErrorAction SilentlyContinue) {
        try {
            $null = & nvidia-smi 2>&1
            if ($LASTEXITCODE -eq 0) {
                return "nvidia"
            }
        } catch {}
    }

    # Check for AMD via WMI
    try {
        $gpus = Get-WmiObject Win32_VideoController | Select-Object -ExpandProperty Name
        foreach ($gpu in $gpus) {
            if ($gpu -match "AMD|Radeon") {
                return "amd"
            }
        }
    } catch {}

    return "cpu"
}

# Install Python via winget
function Install-Python {
    Write-Info "Python not found. Attempting to install via winget..."

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        try {
            # Install Python 3.11 for best compatibility with torch-directml
            winget install Python.Python.3.11 --accept-package-agreements --accept-source-agreements
            # Refresh PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            return $true
        } catch {
            Write-Warning "winget installation failed: $_"
        }
    }

    Write-Error "Could not install Python automatically."
    Write-Info "Please install Python 3.11 from https://www.python.org/downloads/"
    Write-Info "Python 3.11 is recommended for AMD GPU acceleration (DirectML support)."
    Write-Info "Make sure to check 'Add Python to PATH' during installation."
    return $false
}

# Install ffmpeg
function Install-FFmpeg {
    if (Get-Command ffmpeg -ErrorAction SilentlyContinue) {
        Write-Success "ffmpeg already installed"
        return $true
    }

    Write-Info "Installing ffmpeg via winget..."

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        try {
            winget install Gyan.FFmpeg --accept-package-agreements --accept-source-agreements
            # Refresh PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            return $true
        } catch {
            Write-Warning "ffmpeg installation failed. You may need to install it manually."
            return $false
        }
    }

    Write-Warning "Please install ffmpeg manually from https://ffmpeg.org/download.html"
    return $false
}

# Create virtual environment
function New-Venv {
    param($pythonCmd)

    Write-Info "Creating Python virtual environment..."

    if (Test-Path $VenvDir) {
        Write-Warning "Existing virtual environment found. Removing..."
        Remove-Item -Recurse -Force $VenvDir
    }

    & cmd /c "$pythonCmd -m venv `"$VenvDir`""

    if (-not (Test-Path $VenvDir)) {
        Write-Error "Failed to create virtual environment"
        exit 1
    }

    Write-Success "Virtual environment created at $VenvDir"
}

# Install PyTorch
function Install-PyTorch {
    param($gpuType, $pythonCmd)

    $pip = Join-Path $VenvDir "Scripts\pip.exe"

    Write-Info "Installing PyTorch for $gpuType..."

    switch ($gpuType) {
        "nvidia" {
            Write-Info "Installing PyTorch with CUDA support..."
            & $pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
        }
        "amd" {
            # Check if DirectML is compatible with current Python version
            $directMLCompatible = Test-DirectMLCompatible $pythonCmd

            if ($directMLCompatible) {
                Write-Info "Installing PyTorch with DirectML support (AMD on Windows)..."
                & $pip install torch torchvision torchaudio

                # Try to install torch-directml, but don't fail if it doesn't work
                Write-Info "Installing DirectML acceleration..."
                & $pip install torch-directml

                if ($LASTEXITCODE -ne 0) {
                    Write-Warning "DirectML installation failed. Falling back to CPU mode."
                    Write-Warning "PyTorch will still work, but without AMD GPU acceleration."
                }
            } else {
                $version = Get-PythonVersion $pythonCmd
                Write-Warning "Python $($version.Major).$($version.Minor) is not compatible with torch-directml (requires Python 3.8-3.11)"
                Write-Warning "Installing PyTorch in CPU mode. Consider using Python 3.11 for AMD GPU acceleration."
                & $pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
            }
        }
        default {
            Write-Info "Installing PyTorch (CPU only)..."
            & $pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
        }
    }
}

# Install audio-separator
function Install-AudioSeparator {
    param($pythonCmd)

    $pip = Join-Path $VenvDir "Scripts\pip.exe"

    Write-Info "Installing audio-separator..."
    & $pip install audio-separator

    if ($LASTEXITCODE -ne 0) {
        $version = Get-PythonVersion $pythonCmd
        Write-Error "Failed to install audio-separator"
        Write-Warning "Python $($version.Major).$($version.Minor) may be too new for audio-separator dependencies"
        Write-Info "Some packages (like diffq-fixed) don't have pre-built wheels for Python 3.14+"
        Write-Info "Recommended solution: Install Python 3.11 and re-run this installer"
        Write-Info "  winget install Python.Python.3.11"
        return $false
    }

    Write-Success "audio-separator installed"
    return $true
}

# Verify installation
function Test-Installation {
    $python = Join-Path $VenvDir "Scripts\python.exe"

    Write-Info "Verifying installation..."

    & $python -c @"
import torch
print(f'PyTorch version: {torch.__version__}')
if torch.cuda.is_available():
    print(f'CUDA available: {torch.cuda.get_device_name(0)}')
else:
    print('Using CPU (or DirectML if AMD)')

from audio_separator.separator import Separator
print('audio-separator is ready')
"@

    Write-Success "All components verified!"
}

# Download models
function Get-Models {
    $python = Join-Path $VenvDir "Scripts\python.exe"

    Write-Info "Pre-downloading AI models (this may take a few minutes)..."

    & $python -c @"
from audio_separator.separator import Separator
try:
    sep = Separator()
    sep.load_model('htdemucs')
    print('htdemucs model ready')
except Exception as e:
    print(f'Model download will happen on first use: {e}')
"@
}

# Main
function Main {
    Write-Header

    # Find Python
    if (-not $SkipPython) {
        $pythonCmd = Find-Python

        if (-not $pythonCmd) {
            if (-not (Install-Python)) {
                exit 1
            }
            $pythonCmd = Find-Python
        }

        if (-not $pythonCmd) {
            Write-Error "Could not find Python 3"
            exit 1
        }

        $pythonVersionStr = & cmd /c "$pythonCmd --version 2>&1"
        Write-Success "Found Python: $pythonVersionStr"

        if (-not (Test-PythonVersion $pythonCmd)) {
            Write-Error "Python 3.9+ required"
            exit 1
        }

        # Check if Python version is compatible
        $version = Get-PythonVersion $pythonCmd
        if ($version.Major -eq 3 -and $version.Minor -ge 14) {
            Write-Host "`n" -NoNewline
            Write-Host "==============================================" -ForegroundColor Red
            Write-Host " Python $($version.Major).$($version.Minor) is NOT COMPATIBLE" -ForegroundColor Red
            Write-Host "==============================================" -ForegroundColor Red
            Write-Host ""
            Write-Host "Python 3.14+ is too new for audio-separator and its dependencies." -ForegroundColor Yellow
            Write-Host "Required packages (diffq-fixed, torch-directml) don't support Python 3.14 yet." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Supported Python versions: 3.9, 3.10, 3.11, 3.12" -ForegroundColor Cyan
            Write-Host "Recommended: Python 3.11 (best compatibility with all features)" -ForegroundColor Green
            Write-Host ""
            Write-Host "To install Python 3.11:" -ForegroundColor Cyan
            Write-Host "  winget install Python.Python.3.11" -ForegroundColor White
            Write-Host ""
            Write-Host "After installing, run this script again and it will automatically use Python 3.11." -ForegroundColor Cyan
            Write-Host ""
            exit 1
        } elseif ($version.Major -eq 3 -and $version.Minor -ge 13) {
            Write-Warning "Python $($version.Major).$($version.Minor) detected - this may not be fully compatible"
            Write-Warning "Some packages may fail to install due to missing pre-built wheels"
            Write-Info "Python 3.11 is recommended for best compatibility"
        } elseif ($version.Major -eq 3 -and $version.Minor -eq 12) {
            Write-Warning "Python $($version.Major).$($version.Minor) detected. DirectML (AMD GPU acceleration) requires Python 3.8-3.11."
            Write-Warning "Installation will continue, but PyTorch will run in CPU mode."
            Write-Info "For AMD GPU support, consider installing Python 3.11 alongside your current version."
        }
    } else {
        $pythonCmd = "python"
    }

    # Install ffmpeg
    Install-FFmpeg

    # Detect GPU
    if ($NoGPU) {
        $gpuType = "cpu"
        Write-Info "GPU disabled by -NoGPU flag"
    } else {
        $gpuType = Get-GPUType
        Write-Info "Detected GPU: $gpuType"
    }

    # Create venv
    New-Venv $pythonCmd

    # Upgrade pip
    $pip = Join-Path $VenvDir "Scripts\pip.exe"
    Write-Info "Upgrading pip..."
    & $pip install --upgrade pip 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Success "pip upgraded"
    } else {
        Write-Info "pip upgrade skipped (already latest or locked)"
    }

    # Install PyTorch
    Install-PyTorch $gpuType $pythonCmd

    # Install audio-separator
    $separatorInstalled = Install-AudioSeparator $pythonCmd

    if (-not $separatorInstalled) {
        Write-Host "`n" -NoNewline
        Write-Host "==============================================" -ForegroundColor Red
        Write-Host " Installation Failed" -ForegroundColor Red
        Write-Host "==============================================" -ForegroundColor Red
        Write-Host ""
        Write-Host "Python 3.14 is too new for the AI audio separation ecosystem." -ForegroundColor Yellow
        Write-Host "Many dependencies don't have pre-built packages yet." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "To fix this, install Python 3.11:" -ForegroundColor Cyan
        Write-Host "  winget install Python.Python.3.11" -ForegroundColor White
        Write-Host ""
        Write-Host "Then run this installer again." -ForegroundColor Cyan
        Write-Host ""
        exit 1
    }

    # Verify
    Test-Installation

    # Ask about models
    Write-Host ""
    $response = Read-Host "Download AI models now? (recommended, ~200MB) [Y/n]"
    if ($response -ne "n" -and $response -ne "N") {
        Get-Models
    }

    Write-Host "`n" -NoNewline
    Write-Host "==============================================" -ForegroundColor Green
    Write-Host " Installation Complete!" -ForegroundColor Green
    Write-Host "==============================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Stemperator is ready to use."
    Write-Host ""
    Write-Host "For REAPER integration:"
    Write-Host "  1. Open REAPER"
    Write-Host "  2. Extensions > ReaPack > Import repositories"
    Write-Host "  3. Add: https://raw.githubusercontent.com/flarkflarkflark/Stemperator/main/scripts/reaper/index.xml"
    Write-Host "  4. Install 'Stemperator' scripts from ReaPack"
    Write-Host ""
    Write-Host "For VST3/Standalone:"
    Write-Host "  The AI backend is now configured in: $VenvDir"
    Write-Host ""
}

Main
