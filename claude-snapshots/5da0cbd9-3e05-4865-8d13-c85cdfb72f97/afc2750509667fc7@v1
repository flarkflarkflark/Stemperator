# Stemperator Font Sizes Reference

Dit document bevat een overzicht van alle font sizes in de Stemperator applicatie.
Gebruik dit als referentie voor het aanpassen van de UI.

---

## Main Window (PluginEditor.cpp)

### Header Section
| Size | Style | Element | Locatie |
|------|-------|---------|---------|
| 32pt | Bold (scalable) | "STEMPERATOR" titel | Line 3522 |
| 20pt | Bold (scalable) | "flarkAUDIO" brand label | Line 3524 |
| 11pt | Normal (scalable) | "AI-POWERED STEM SEPARATION" subtitle | Line 3523 |

### Transport Bar / File Info
| Size | Style | Element | Locatie |
|------|-------|---------|---------|
| 48pt | Bold | Transport bar file name (groot) | Line 240 |
| 28pt | Bold | File name label | Line 3185, 5594 |
| 28pt | Normal | "STEMS" / "LIVE" colorful labels | Line 5649, 5713 |
| 16pt | Bold | Mode label (STEMS/LIVE indicator) | Line 3191 |

### Splash Screen (No File Loaded)
| Size | Style | Element | Locatie |
|------|-------|---------|---------|
| 42pt | Bold | "Drop audio file here" text | Line 695 |
| 16pt | Normal | Instructie tekst | Line 720 |

### Processing/Progress Display
| Size | Style | Element | Locatie |
|------|-------|---------|---------|
| 28pt | Bold | Processing title | Line 546 |
| 20pt | Bold | Solo VU meter label | Line 329 |
| 15pt | Normal | Processing step beschrijving | Line 308 |
| 14pt | Normal | GPU/device info, progress details | Line 553, 272 |
| 12pt | Normal | Hotkey tips | Line 317 |
| 11pt | Normal | Build info | Line 335 |

### Master Section
| Size | Style | Element | Locatie |
|------|-------|---------|---------|
| 22pt | Bold | "MASTER" label (fixed, not scaled) | Line 3525 |

### VU Meters
| Size | Style | Element | Locatie |
|------|-------|---------|---------|
| 8pt | Normal | Meter scale markings (-60, -40, etc.) | Line 3704 |

---

## Stem Channels (StemChannel.cpp)

| Size | Style | Element | Locatie |
|------|-------|---------|---------|
| 22pt | Bold | Stem naam (VOCALS, DRUMS, BASS, OTHER, GUITAR, PIANO) | Line 50 |
| 10pt | Bold | dB waarde readout bij fader | Line 170 |
| 8pt | Normal | Meter scale markings | Line 144 |

---

## Batch Processing Window (BatchEditorWindow.h)

| Size | Style | Element | Locatie |
|------|-------|---------|---------|
| 32pt | Bold | "INPUT FILES" section label | Line 135 |
| 30pt | Bold | "MODEL", "QUALITY" labels | Line 178, 191 |
| 30pt | Normal | File list items, Output mode combo | Line 355 |
| 28pt | Normal | Status label (progress text) | Line 204 |
| 26pt | Normal | Output folder path display | Line 172 |

---

## Dialog Windows (StyledDialogWindow.h)

### Batch Complete Dialog
| Size | Style | Element | Locatie |
|------|-------|---------|---------|
| 36pt | Bold | Checkmark icon | Line 681 |
| 28pt | Bold | Summary ("4 of 4 files processed") | Line 612 |
| 20pt | Normal | Time elapsed | Line 620 |
| 18pt | Normal | Failed files count | Line 630 |
| 16pt | Normal | "Output folder:" label | Line 638 |
| 15pt | Normal | Output path text | Line 644 |

### Confirm Delete Dialog
| Size | Style | Element | Locatie |
|------|-------|---------|---------|
| 24pt | Bold | Dialog title | Line 314 |
| 15pt | Normal | Message text | Line 263 |

### Alert Dialog
| Size | Style | Element | Locatie |
|------|-------|---------|---------|
| 20pt | Bold | Dialog title | Line 168 |
| 15pt | Normal | Message text | Line 100 |

### Save Prompt Dialog
| Size | Style | Element | Locatie |
|------|-------|---------|---------|
| 20pt | Bold | Dialog title | Line 500 |
| 15pt | Normal | Message text | Line 447 |

---

## Look and Feel (PremiumLookAndFeel.h)

### Buttons
| Size | Style | Element | Locatie |
|------|-------|---------|---------|
| 22pt | Bold | Stem name buttons | Line 323 |
| 18pt | Bold | Mute/Solo (M/S) buttons | Line 325 |
| 18pt | Normal | Combo box text | Line 407, 448 |
| 14pt | Normal | Generic button text | Line 327 |
| h*0.55f | Bold | TextButton (scales with height) | Line 481 |

---

## Transport Bar (TransportBar.h)

| Size | Style | Element | Locatie |
|------|-------|---------|---------|
| 14pt | Normal | Time display (00:00 / 03:45) | Line 42 |

---

## Export Options Dialog (ExportOptionsDialog.h)

| Size | Style | Element | Locatie |
|------|-------|---------|---------|
| 20pt | Bold | Dialog title | Line 37 |

---

## Visualizer (Visualizer.cpp)

| Size | Style | Element | Locatie |
|------|-------|---------|---------|
| 14pt | Bold | Waveform section labels | Line 30 |
| 11pt | Bold | Level indicators | Line 104 |
| 9pt | Normal | Secondary labels | Line 110 |
| 8pt | Normal | Scale markers | Line 131 |

---

## Separation Wizard (SeparationWizard.cpp)

| Size | Style | Element | Locatie |
|------|-------|---------|---------|
| 24pt | Bold | Wizard title | Line 106 |
| 14pt | Bold | Section headers | Line 32, 75 |
| 12pt | Normal | Subtitle | Line 110, 96 |
| 11pt | Normal | Description text | Line 37, 79, 167 |
| 10pt | Italic | Hint text | Line 43 |
| 10pt | Normal | Detail text | Line 48 |

---

## Quick Reference: Font Size Hierarchy

```
48pt - Extra large display text (file name in transport)
42pt - Large splash text ("Drop audio file here")
36pt - Large icons (checkmark)
32pt - Window titles, major labels
30pt - Batch window labels
28pt - Important status text, colorful mode labels
26pt - Secondary paths
24pt - Dialog titles (large)
22pt - Stem names, master label
20pt - Dialog titles (medium), brand label
18pt - Mute/Solo buttons, combo boxes
16pt - Subtitles, folder labels
15pt - Dialog messages, paths
14pt - Buttons, info text, time display
12pt - Tips, subtitles
11pt - Small descriptions, build info
10pt - Hints, details
9pt  - Secondary labels
8pt  - Scale markings, meter labels
```

---

## Tips voor Aanpassingen

1. **Consistentie**: Gebruik dezelfde size voor vergelijkbare elementen
2. **Hierarchy**: Grotere fonts = belangrijker
3. **Scalable vs Fixed**:
   - Header elementen schalen met window size (`32.0f * scale`)
   - Stem labels blijven vast (22pt) voor leesbaarheid
4. **Bold gebruik**:
   - Titels en labels: Bold
   - Content en beschrijvingen: Normal
5. **Minimum leesbaar**: 8pt voor scale markers is het minimum

---

*Laatste update: December 2024*
