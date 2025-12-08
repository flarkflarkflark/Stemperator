# Stemperator Development Session Notes
**Datum:** 2025-12-08
**Project:** Stemperator - AI Stem Separation voor REAPER

## Projectlocaties
- **REAPER Scripts:** `C:\Users\Administrator\AppData\Roaming\REAPER\Scripts\Stemperator - AI Stem Separation\AI\Stem Separation\`
- **Development folder:** `C:\Users\Administrator\Documents\Stemperator\`
- **Python venv:** `C:\Users\Administrator\Documents\Stemperator\.venv\`

## Belangrijkste bestanden
- `Stemperator_AI_Separate.lua` - Hoofdscript met GUI
- `audio_separator_process.py` - Python backend voor AI separation

## Hardware Setup
- **CPU:** AMD Ryzen 7 7840HS met Radeon 780M iGPU
- **eGPU:** AMD RX 9070 (16GB VRAM)
- **NPU:** AMD XDNA (niet bruikbaar voor Demucs momenteel)
- **DirectML devices:** Device 0 = RX 9070, Device 1 = 780M

## Wat er gedaan is deze sessie (2025-12-08 vervolg)

### 4. Multi-track parallel processing gefixed
**Probleem:** Bij meerdere tracks werden niet alle items correct verwerkt.

**Oplossingen:**
- `renderTrackTimeSelectionToWav()` verzamelt nu ALLE selected items per track (niet alleen eerste)
- `job.sourceItems` array toegevoegd naast `job.sourceItem`
- `processAllStemsResult()` itereert nu over alle items in `allItems` array
- Reverse iteration toegevoegd om index shifting te voorkomen bij delete/split
- `reaper.ValidatePtr()` check toegevoegd voor item validatie
- Re-query van item bounds na eerste split voor correcte tweede split

### 5. Mute/Delete Selection split fix
**Probleem:** Tweede item op elke track werd niet gesplitst aan time selection einde.

**Oplossing:** Na eerste split wordt `middleItem`'s actuele positie en lengte opnieuw opgevraagd:
```lua
local middlePos = reaper.GetMediaItemInfo_Value(middleItem, "D_POSITION")
local middleLen = reaper.GetMediaItemInfo_Value(middleItem, "D_LENGTH")
local middleEnd = middlePos + middleLen
if splitEnd < middleEnd - 0.001 then
    reaper.SplitMediaItem(middleItem, splitEnd)
end
```

### 6. Window flickering gefixed
**Probleem:** CMD windows flikkeren bij starten separation (ffmpeg calls).

**Oplossing:** Nieuwe `execHidden(cmd)` functie:
- Maakt tijdelijke VBS file aan
- Runt command via `WScript.Shell.Run` met window style 0 (hidden)
- Wacht op completion (True parameter)
- Ruimt VBS file op na uitvoering
- Alle `os.execute(ffmpegCmd)` vervangen door `execHidden(ffmpegCmd)`

### 7. GPU/DirectML optimalisatie
**Probleem:** 50-60% GPU gebruik op Windows vs ~100% op Linux.

**Bevindingen:**
- DirectML is translation layer (minder efficient dan native ROCm op Linux)
- RX 9070 wordt correct gedetecteerd als Device 0
- `segment_size: 60` veroorzaakte "parameter incorrect" error
- `segment_size: 44` veroorzaakte OOM bij 3 parallel tracks (~3.4GB x 3)
- `segment_size: 25` werkt voor parallel processing

**Oplossing - Dynamic segment size:**
- Single-track: `--segment-size 40` (grotere segments, betere GPU benutting)
- Multi-track parallel: `--segment-size 25` (kleinere segments, past in VRAM)

Python script aangepast:
```python
def separate_stems(input_file, output_dir, model_name="htdemucs", segment_size=None):
    actual_segment_size = segment_size if segment_size else 40
    demucs_config = {
        "segment_size": actual_segment_size,
        ...
    }
```

Lua script aangepast:
- `startSeparationProcess()`: `--segment-size 40`
- `startSeparationProcessForJob()`: `--segment-size 25`

### 8. Debug logging toegevoegd
**Locatie:** `%TEMP%\stemperator_debug.log`

Functies:
- `debugLog(msg)` - schrijft timestamped message naar log
- `clearDebugLog()` - wist log bij script start
- `DEBUG_MODE = true` - aan/uit zetten bovenaan script

Debug punten:
- `execHidden()` - command, VBS path, execution method
- `runSeparationWorkflow()` - selection mode, temp paths, render results

## Huidige SETTINGS structuur
```lua
SETTINGS = {
    model = "htdemucs",           -- of "htdemucs_ft", "htdemucs_6s"
    createNewTracks = true,
    createFolder = true,
    muteOriginal = false,         -- Mute hele item
    muteSelection = false,        -- Mute alleen selectie (splitst item)
    deleteOriginal = false,       -- Delete hele item
    deleteSelection = false,      -- Delete alleen selectie (splitst item)
    deleteOriginalTrack = false,  -- Delete hele track
}
```

## Keyboard shortcuts in dialog
- 1-4: Toggle Vocals/Drums/Bass/Other
- 5-6: Toggle Guitar/Piano (alleen bij 6-stem model)
- K: Karaoke preset
- I: Instrumental preset
- D: Drums Only preset
- V: Vocals Only preset
- A: All stems
- +/-: Resize window
- Enter: Start separation
- Escape: Cancel

## Dependencies
- Python 3.9+ met audio-separator: `pip install audio-separator[gpu]`
- torch-directml: `pip install torch-directml` (voor AMD GPU op Windows)
- ffmpeg in PATH
- REAPER met js_ReaScriptAPI en SWS extensions (voor multi-monitor support)

## Git Repository
- GitHub: https://github.com/flarkflarkflark/Stemperator
- Branch voor deze sessie: `claude/setup-stemperator-env-01Bx475u1RpPYhtuFUuACRri`

## Afgeronde taken
1. ✅ Multi-monitor window positioning
2. ✅ Custom message windows (showMessage functie)
3. ✅ Mute/Delete selection opties
4. ✅ Multi-track parallel processing
5. ✅ Mute/Delete voor alle items op alle tracks
6. ✅ Split aan beide kanten time selection
7. ✅ Window flickering fix (execHidden)
8. ✅ Dynamic segment size (single vs multi-track)
9. ✅ Debug logging systeem

## Bekende limitaties
- DirectML op Windows: ~50-60% GPU benutting (vs ~100% met ROCm op Linux)
- AMD NPU niet bruikbaar voor Demucs (geen PyTorch/ONNX support)
- `aten::std.correction` operator valt terug naar CPU op DirectML

## Volgende stappen / TODO
1. ReaPack installatie testen op Windows 11
2. Eventueel: meer presets toevoegen
3. Toolbar scripts voor snelle acties
4. Mogelijk: WSL2 + ROCm voor betere performance op Windows
5. Debug mode uitzetten voor productie (`DEBUG_MODE = false`)

## TODO: Nieuwe Toolbar Scripts
Mogelijk toe te voegen toolbar scripts voor snelle acties zonder dialog:

### Mute Original varianten:
- `Stemperator_VocalsOnly_MuteOriginal.lua` - Vocals + mute origineel
- `Stemperator_Instrumental_MuteOriginal.lua` - Instrumental + mute origineel
- `Stemperator_DrumsOnly_MuteOriginal.lua` - Drums + mute origineel

### Replace In-Place varianten (geen nieuwe tracks):
- `Stemperator_VocalsOnly_Replace.lua` - Vervang item met vocals
- `Stemperator_Instrumental_Replace.lua` - Vervang item met instrumental
- `Stemperator_AllStems_Replace.lua` - Vervang item met alle stems als takes

### Delete Original varianten:
- `Stemperator_VocalsOnly_DeleteOriginal.lua` - Vocals + delete origineel
- `Stemperator_Instrumental_DeleteOriginal.lua` - Instrumental + delete origineel
