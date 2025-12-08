# Stemperator README Update - Prompt voor Claude Code

Ik heb nieuwe afbeeldingen voor de Stemperator README. Plaats ze in `docs/images/` en update de README.md met deze visuals.

## Beschikbare afbeeldingen

**Hero banner** (bovenaan README):
- `stemperator-hero.png` (1920×600) - Logo met waveform splitting visual, gekleurde STEM letters

**Workflow animatie** (bij "How to Use" of "Quick Start"):
- `stemperator-workflow.gif` (800×450, 14s) - Toont volledige workflow + time selection explode feature

**Feature visuals:**
- `stemperator-before-after.png` (1280×720) - Before/after vergelijking van stem separation
- `stemperator-time-selection.png` (1280×720) - Demonstratie van time selection feature (alleen selectie verwerken)
- `stemperator-6stem.png` (1280×800) - 6-stem model showcase (vocals, drums, bass, guitar, piano, other)

**UI mockups:**
- `stemperator-dialog.png` (800×500) - De Stemperator dialog met opties
- `stemperator-toolbar.png` (800×200) - Toolbar icons overzicht
- `reaper-stems.png` (1280×720) - REAPER arrange view met 4 stem tracks

## Kleurenschema (voor referentie)
- Vocals: #FF6464 (koraalrood)
- Drums: #64C8FF (hemelsblauw)  
- Bass: #9664FF (paars)
- Other: #64FF96 (mintgroen)
- Guitar: #FFB450 (oranje)
- Piano: #FF78C8 (roze)

## Suggestie voor README structuur

1. Hero banner bovenaan
2. Korte intro
3. Workflow GIF bij "Quick Start" of "How to Use"
4. Before/After bij "Features"
5. 6-stem screenshot bij uitleg over modellen
6. Time selection screenshot bij documentatie van die feature
7. Dialog screenshot bij "Configuration" of "Options"

## Markdown voorbeelden

```markdown
![Stemperator](docs/images/stemperator-hero.png)

## Quick Start

![Workflow](docs/images/stemperator-workflow.gif)

## Features

### AI Stem Separation
![Before/After](docs/images/stemperator-before-after.png)

### 6-Stem Model
![6-Stem Model](docs/images/stemperator-6stem.png)

### Time Selection
Process only what you need - select a portion of audio and Stemperator will only separate that section.

![Time Selection](docs/images/stemperator-time-selection.png)

## Configuration

![Dialog](docs/images/stemperator-dialog.png)
```

Gebruik relatieve paden: `![Alt text](docs/images/bestandsnaam.png)`
