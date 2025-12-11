# Stemperator - DAW Integration Guide

Stemperator outputs 4 stereo stem pairs that can be routed to separate tracks in your DAW:

| Output | Stem | Channels |
|--------|------|----------|
| 1-2 | Vocals | Stereo |
| 3-4 | Drums | Stereo |
| 5-6 | Bass | Stereo |
| 7-8 | Other | Stereo |

## Quick Links

- [Reaper](#reaper) - Full automation with ReaScript
- [Bitwig Studio](#bitwig-studio) - Built-in multi-output support
- [Ableton Live](#ableton-live) - Audio routing
- [FL Studio](#fl-studio) - Patcher/Mixer routing
- [Cubase](#cubase) - Multi-output configuration
- [Logic Pro](#logic-pro) - Aux channels

---

## Reaper

### Automatic Setup (Recommended)

Use the included ReaScript for one-click stem track creation:

1. **Load the Script**
   - Actions → Show action list → Load ReaScript
   - Select `scripts/reaper/Stemperator_Explode_Stems.lua`

2. **Run the Script**
   - Select the track with Stemperator
   - Run the script (assign a keyboard shortcut for convenience)
   - 4 new tracks are created with routing already configured

### Manual Setup

1. Insert Stemperator on an audio track
2. Right-click plugin → "Build multichannel routing for outputs"
3. Or manually create sends:
   - Create 4 new tracks (Vocals, Drums, Bass, Other)
   - On Stemperator track: disable Master send
   - Create 4 sends to stem tracks
   - Set each send's source channels:
     - Send 1: Ch 1-2 → Vocals
     - Send 2: Ch 3-4 → Drums
     - Send 3: Ch 5-6 → Bass
     - Send 4: Ch 7-8 → Other

---

## Bitwig Studio

Bitwig has excellent built-in multi-output support.

### Method 1: Auto-Chains (Easiest)

1. Insert Stemperator on an audio track
2. Click the **↔** (double-arrow) icon next to plugin name
3. Select **"Add chains automatically"**
4. Each output becomes a separate chain
5. Route chains to new tracks via output selector

### Method 2: Audio Receiver

1. Insert Stemperator on source track
2. Create 4 new audio tracks
3. On each new track, add **Audio Receiver** device
4. Set SOURCE to Stemperator track → select output pair
5. Disable master output on Stemperator track

See `scripts/bitwig/README_Bitwig_Setup.txt` for detailed instructions.

---

## Ableton Live

### Live 12+ (Native Stems)

Live 12.3+ has built-in stem separation. Stemperator can still be useful for:
- Different AI models
- GPU acceleration
- Batch processing

### Multi-Output Routing

1. Insert Stemperator on an Audio track
2. Create 3 additional Audio tracks
3. On each new track:
   - Set **"Audio From"** to the Stemperator track
   - In the submenu, select **Stems** → choose output pair
4. Set Stemperator track monitor to "Off" (prevents doubled audio)

---

## FL Studio

### Patcher Method

1. Open Patcher
2. Add Stemperator VST3
3. Right-click Stemperator → "Show outputs"
4. Connect each stereo output pair to separate "To FL Studio" outputs
5. Route Patcher outputs to mixer tracks

### Direct Mixer Routing

1. Add Stemperator to a mixer insert
2. Click the plugin wrapper's output selector
3. Route outputs 3-8 to other mixer tracks
4. Mute outputs 1-2 on the original insert (or use for stems mix)

---

## Cubase

### Activate Outputs

1. Insert Stemperator VST3 on an Audio track
2. Open the plugin window
3. Click the output routing button (or Studio → VST Instruments → Stemperator)
4. Activate all 4 output pairs
5. Create Audio tracks for each output
6. Set each track's input to corresponding Stemperator output

### Using Group Channels

1. Create 4 Group channels (Vocals, Drums, Bass, Other)
2. Route Stemperator outputs to Group channels
3. Original track sends to groups instead of master

---

## Logic Pro

### Aux Channel Method

1. Insert Stemperator on an Audio track
2. Create 4 Aux channels
3. On each Aux:
   - Set input to Bus 1-4 (or available buses)
4. On Stemperator channel strip:
   - Create Sends to Bus 1-4
   - Route each send to the correct output pair
5. Turn down Stemperator track fader (or mute)

### Using Multi-Output Instruments Pattern

Stemperator can be set up similar to multi-output software instruments:

1. Hold Option and click the track's output slot
2. Choose multi-channel routing
3. Assign each output pair to an Aux

---

## Other DAWs

### General Approach

Most DAWs support multi-output plugins. The general workflow:

1. **Insert Stemperator** as VST3 plugin
2. **Enable outputs** in the DAW's plugin routing interface
3. **Create receive tracks** for each stem
4. **Route outputs** from plugin to receive tracks
5. **Disable master send** on the plugin track to avoid doubled audio

### Offline Workflow (Universal)

If your DAW doesn't support multi-output plugins well:

1. Use Stemperator **Standalone** application
2. Export stems to files (vocals.wav, drums.wav, bass.wav, other.wav)
3. Import stems as separate tracks in your DAW
4. Align to timeline

---

## Stem Colors (for visual consistency)

| Stem | RGB | Hex |
|------|-----|-----|
| Vocals | 255, 100, 100 | #FF6464 |
| Drums | 100, 200, 255 | #64C8FF |
| Bass | 150, 100, 255 | #9664FF |
| Other | 100, 255, 150 | #64FF96 |

---

## Support

- **Repository**: https://github.com/flarkflarkflark/Stemperator
- **Issues**: https://github.com/flarkflarkflark/Stemperator/issues
- **License**: MIT
