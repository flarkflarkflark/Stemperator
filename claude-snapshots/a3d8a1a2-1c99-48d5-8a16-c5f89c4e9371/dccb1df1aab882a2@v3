================================================================================
STEMPERATOR - BITWIG STUDIO SETUP GUIDE
================================================================================

Bitwig Studio has built-in multi-output plugin support. No external scripts
are required - follow these steps to route Stemperator's stems to separate
tracks.

================================================================================
METHOD 1: Automatic Chain Creation (Recommended)
================================================================================

1. Insert Stemperator on an Audio Track
   - Drag audio file to a track
   - Add Stemperator VST3 to the track's device chain

2. Enable Multi-Output Mode
   - Click the small double-arrow icon (↔) next to Stemperator's name
   - Select "Add chains automatically"
   - Bitwig creates 4 separate chains for each stem output:
     * Chain 1: Vocals (Output 1-2)
     * Chain 2: Drums (Output 3-4)
     * Chain 3: Bass (Output 5-6)
     * Chain 4: Other (Output 7-8)

3. Route Chains to Separate Tracks
   - For each chain, click the output selector
   - Choose "New Track" or select an existing track
   - Each stem now goes to its own mixer channel

================================================================================
METHOD 2: Audio Receiver Device
================================================================================

This method routes Stemperator outputs to completely separate tracks.

1. Insert Stemperator on Source Track
   - Add Stemperator VST3 to your audio track

2. Create Stem Receive Tracks
   For each stem (Vocals, Drums, Bass, Other):

   a. Create a new Audio Track
   b. Name it (e.g., "Vocals")
   c. Add "Audio Receiver" device to this track
   d. In Audio Receiver:
      - SOURCE: Select the track with Stemperator
      - Scroll to "Stemperator" in the submenu
      - Select the corresponding output:
        * Vocals: Output 1-2
        * Drums: Output 3-4
        * Bass: Output 5-6
        * Other: Output 7-8

3. Disable Source Track Output
   - On the original Stemperator track, disable master output
   - This prevents double audio (stems + original mix)

================================================================================
METHOD 3: Import Stem Files (Offline Workflow)
================================================================================

If you've exported stems using Stemperator standalone:

1. Use Stemperator standalone to separate stems
   - Export stems to a folder

2. In Bitwig:
   - File > Import > Audio
   - Select all 4 stem files (vocals.wav, drums.wav, bass.wav, other.wav)
   - Bitwig creates a track for each file

3. Align stems on timeline
   - All stems should start at the same position
   - Use snap-to-grid for precise alignment

================================================================================
RECOMMENDED TRACK COLORS
================================================================================

For visual consistency with Stemperator's GUI:

- Vocals: Red/Pink (#FF6464)
- Drums:  Cyan/Blue (#64C8FF)
- Bass:   Purple (#9664FF)
- Other:  Green (#64FF96)

================================================================================
TIPS
================================================================================

* Use Track Groups: Create a group track named "[Song] Stems" and put all
  stem tracks inside for organization.

* Freeze Processing: Once stems are separated, freeze the Stemperator track
  to save CPU during mixing.

* Clip Launcher: Each stem can be dragged to separate clip slots for
  live performance/remixing.

* Modular Grid: Route stems into The Grid for advanced spectral processing.

================================================================================
SUPPORT
================================================================================

Repository: https://github.com/flarkflarkflark/Stemperator
License: MIT

================================================================================
