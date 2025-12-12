# Device Selection Architecture

## Component Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                        REAPER (Lua Script)                      │
│                  Stemperator_AI_Separate.lua                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌────────────────────────────────────────────────────────┐   │
│  │              User Interface (gfx)                      │   │
│  │                                                         │   │
│  │  Model: [Fast] [Quality] [6-Stem]                     │   │
│  │  Device: [Auto] ← Click to cycle                      │   │
│  │  Output: [Tracks] [Takes]                             │   │
│  └────────────────────────────────────────────────────────┘   │
│                           ↓                                     │
│  ┌────────────────────────────────────────────────────────┐   │
│  │       Settings Persistence (ExtState)                  │   │
│  │                                                         │   │
│  │  reaper.SetExtState("Stemperator", "device", "auto")  │   │
│  │  - Survives REAPER restarts                           │   │
│  │  - Per-project or global                              │   │
│  └────────────────────────────────────────────────────────┘   │
│                           ↓                                     │
│  ┌────────────────────────────────────────────────────────┐   │
│  │       Device Detection (on startup)                    │   │
│  │                                                         │   │
│  │  detectAvailableDevices()                             │   │
│  │  ├─ Calls: python ... --list-devices                  │   │
│  │  ├─ Parses output: "cuda:0: NVIDIA RTX 3090"          │   │
│  │  └─ Builds device options array                       │   │
│  └────────────────────────────────────────────────────────┘   │
│                           ↓                                     │
│  ┌────────────────────────────────────────────────────────┐   │
│  │       Command Construction                             │   │
│  │                                                         │   │
│  │  Windows: Creates run_separation.bat with:            │   │
│  │    python ... --model htdemucs --device auto          │   │
│  │                                                         │   │
│  │  macOS/Linux: Executes command with:                  │   │
│  │    python ... --model htdemucs --device auto          │   │
│  └────────────────────────────────────────────────────────┘   │
│                           ↓                                     │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│                    Python Backend                               │
│                audio_separator_process.py                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌────────────────────────────────────────────────────────┐   │
│  │       Argument Parsing                                 │   │
│  │                                                         │   │
│  │  --device "auto"  (from command line)                 │   │
│  └────────────────────────────────────────────────────────┘   │
│                           ↓                                     │
│  ┌────────────────────────────────────────────────────────┐   │
│  │       parse_device_string()                            │   │
│  │                                                         │   │
│  │  "auto" → Detect best available:                      │   │
│  │    1. torch.cuda.is_available() → cuda:0              │   │
│  │    2. torch_directml (Windows) → directml:0           │   │
│  │    3. torch.backends.mps (macOS) → mps                │   │
│  │    4. Fallback → cpu                                   │   │
│  │                                                         │   │
│  │  Returns: (torch_device, backend_type)                │   │
│  └────────────────────────────────────────────────────────┘   │
│                           ↓                                     │
│  ┌────────────────────────────────────────────────────────┐   │
│  │       Device Initialization                            │   │
│  │                                                         │   │
│  │  CUDA/ROCm:     device = torch.device("cuda:0")       │   │
│  │  DirectML:      device = torch_directml.device(0)     │   │
│  │  MPS:           device = torch.device("mps")          │   │
│  │  CPU:           device = torch.device("cpu")          │   │
│  └────────────────────────────────────────────────────────┘   │
│                           ↓                                     │
│  ┌────────────────────────────────────────────────────────┐   │
│  │       Separator Configuration                          │   │
│  │                                                         │   │
│  │  separator = Separator(                                │   │
│  │      mdx_params={"device": device},                   │   │
│  │      demucs_params={"device": device}                 │   │
│  │  )                                                      │   │
│  └────────────────────────────────────────────────────────┘   │
│                           ↓                                     │
│  ┌────────────────────────────────────────────────────────┐   │
│  │       AI Processing                                    │   │
│  │                                                         │   │
│  │  separator.load_model("htdemucs.yaml")                │   │
│  │  output_files = separator.separate(input_file)        │   │
│  │                                                         │   │
│  │  Emits: PROGRESS:45:Processing...                     │   │
│  └────────────────────────────────────────────────────────┘   │
│                           ↓                                     │
│  ┌────────────────────────────────────────────────────────┐   │
│  │       Output Stems                                     │   │
│  │                                                         │   │
│  │  vocals.wav, drums.wav, bass.wav, other.wav           │   │
│  └────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Device Selection Options

```
┌──────────────────────────────────────────────────────────┐
│                    Available Devices                     │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  ┌─────────┐                                            │
│  │  Auto   │  ← Default, selects best available         │
│  └─────────┘                                            │
│      ↓                                                   │
│  Preference order:                                       │
│  1. CUDA (NVIDIA/AMD-ROCm)                              │
│  2. DirectML (Windows AMD/Intel)                        │
│  3. MPS (Apple Silicon)                                 │
│  4. CPU                                                  │
│                                                          │
│  ┌─────────┐                                            │
│  │   CPU   │  ← Always available, slowest               │
│  └─────────┘                                            │
│                                                          │
│  ┌─────────┐                                            │
│  │ cuda:0  │  ← NVIDIA GPU or AMD with ROCm            │
│  └─────────┘                                            │
│                                                          │
│  ┌─────────┐                                            │
│  │ cuda:1  │  ← Second NVIDIA/AMD GPU                  │
│  └─────────┘                                            │
│                                                          │
│  ┌───────────┐                                          │
│  │directml:0 │  ← AMD/Intel GPU on Windows             │
│  └───────────┘                                          │
│                                                          │
│  ┌───────────┐                                          │
│  │directml:1 │  ← Second GPU on Windows                │
│  └───────────┘                                          │
│                                                          │
│  ┌─────────┐                                            │
│  │   mps   │  ← Apple M1/M2/M3 GPU                     │
│  └─────────┘                                            │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

## Platform-Specific Behavior

### Windows
```
User selects: "Auto"
              ↓
Python checks:
  1. torch.cuda.is_available()? → Use cuda:0 (NVIDIA)
  2. torch_directml installed?  → Use directml:0 (AMD/Intel)
  3. Fallback                   → Use cpu
```

### Linux
```
User selects: "Auto"
              ↓
Python checks:
  1. torch.cuda.is_available()? → Use cuda:0 (NVIDIA or AMD-ROCm)
     Note: ROCm-PyTorch reports AMD GPUs as CUDA devices
  2. Fallback                   → Use cpu
```

### macOS
```
User selects: "Auto"
              ↓
Python checks:
  1. torch.backends.mps.is_available()? → Use mps (Apple Silicon)
  2. Fallback                           → Use cpu (Intel Mac)
```

## Multi-GPU Example (AMD RX 9070 + Radeon 780M)

```
Windows with DirectML:
┌─────────────────────────────────────┐
│  Available Devices (3):             │
│  ├─ auto                            │
│  ├─ cpu                             │
│  ├─ directml:0: AMD Radeon RX 9070 │
│  └─ directml:1: AMD Radeon 780M    │
└─────────────────────────────────────┘

User selects: directml:0 (discrete GPU)
              ↓
Processing: Uses RX 9070 for faster performance
```

## Error Handling & Fallback

```
User selects: cuda:5 (doesn't exist)
              ↓
Python checks: torch.cuda.device_count() = 1
              ↓
Logs: "WARNING: CUDA device 5 not available, falling back to CPU"
              ↓
Processing: Continues with CPU (slower but works)
```

## State Persistence

```
Session 1:
  User selects: directml:0
              ↓
  Lua saves: reaper.SetExtState("Stemperator", "device", "directml:0")
              ↓
  User closes REAPER

Session 2:
  REAPER starts
              ↓
  Lua loads: device = reaper.GetExtState("Stemperator", "device")
              ↓
  Dialog shows: "directml:0" (AMD Radeon RX 9070)
```
