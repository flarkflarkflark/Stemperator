#pragma once

#include <JuceHeader.h>
#include <functional>

/**
 * SeparationWorkflow - Goal-oriented stem separation for non-expert users
 *
 * Instead of exposing cryptic model names and parameters, we ask the user:
 * "What do you want to do?" and guide them to the best result.
 *
 * Goals map to optimized model chains that UVR experts have validated.
 */
class SeparationWorkflow
{
public:
    //==========================================================================
    // USER GOALS - What does the user want to achieve?
    //==========================================================================
    enum class Goal
    {
        // Vocal-focused goals
        RemoveVocals,           // "I want karaoke / instrumental version"
        IsolateVocals,          // "I want just the vocals / acapella"
        RemoveBackingVocals,    // "I want lead vocals only (no harmonies)"

        // Instrument-focused goals
        IsolateDrums,           // "I want just the drums"
        IsolateBass,            // "I want just the bass"
        IsolateGuitar,          // "I want just the guitar"
        IsolatePiano,           // "I want just the piano/keys"

        // Full separation
        SeparateAllStems,       // "I want all 4 stems (vocals, drums, bass, other)"
        SeparateAllStems6,      // "I want 6 stems (+ piano, guitar)"

        // Audio cleanup
        RemoveNoise,            // "I want to clean up noise/hiss"
        RemoveReverb,           // "I want to remove reverb/echo"
        RemoveBleed,            // "I want to clean up mic bleed"

        // Creative/remix
        CreateRemix,            // "I want stems for remixing"
        CreateMashup,           // "I need vocals to mix with another track"
        PracticeInstrument      // "I want to play along (remove my instrument)"
    };

    //==========================================================================
    // QUALITY PRESETS - Speed vs Quality tradeoff
    //==========================================================================
    enum class Quality
    {
        Preview,    // Fast, lower quality - for quick checks
        Balanced,   // Good balance of speed and quality
        Best,       // Highest quality, slower processing
        Extreme     // Multi-pass processing for maximum quality
    };

    //==========================================================================
    // OUTPUT FORMAT
    //==========================================================================
    enum class OutputFormat
    {
        WAV_24bit,      // Highest quality, larger files
        WAV_16bit,      // Standard CD quality
        FLAC,           // Lossless compression
        MP3_320,        // High quality lossy
        MP3_192         // Smaller files
    };

    //==========================================================================
    // WORKFLOW RESULT
    //==========================================================================
    struct SeparationResult
    {
        bool success = false;
        juce::String errorMessage;

        // Output files created
        juce::StringArray outputFiles;

        // Which stems are available
        bool hasVocals = false;
        bool hasDrums = false;
        bool hasBass = false;
        bool hasOther = false;
        bool hasGuitar = false;
        bool hasPiano = false;
        bool hasInstrumental = false;  // Everything except vocals

        // Processing info
        double processingTimeSeconds = 0.0;
        juce::String modelUsed;
    };

    //==========================================================================
    // GOAL DESCRIPTIONS - For UI display
    //==========================================================================
    struct GoalInfo
    {
        Goal goal;
        juce::String name;              // Short name for UI
        juce::String description;       // What this does
        juce::String useCase;           // When to use this
        juce::String outputDescription; // What files you'll get
        bool requiresGPU;               // Recommended GPU?
        int estimatedMinutes;           // Rough time estimate (per song, CPU)
    };

    static std::vector<GoalInfo> getAvailableGoals()
    {
        return {
            // === MOST COMMON - Show these first ===
            {
                Goal::RemoveVocals,
                "Remove Vocals (Karaoke)",
                "Creates an instrumental version without vocals",
                "Making karaoke tracks, practicing music, creating backing tracks",
                "You'll get: Instrumental track (no vocals)",
                false, 2
            },
            {
                Goal::IsolateVocals,
                "Isolate Vocals (Acapella)",
                "Extracts just the vocals from the song",
                "Sampling vocals, creating acapellas, vocal analysis",
                "You'll get: Clean vocal track",
                false, 2
            },
            {
                Goal::SeparateAllStems,
                "Separate All Stems (4-stem)",
                "Splits into Vocals, Drums, Bass, and Other instruments",
                "Remixing, detailed editing, learning songs",
                "You'll get: 4 separate tracks",
                true, 5
            },

            // === INSTRUMENT ISOLATION ===
            {
                Goal::IsolateDrums,
                "Isolate Drums",
                "Extracts the drum and percussion track",
                "Drum practice, sampling beats, rhythm analysis",
                "You'll get: Drums track + Everything else",
                true, 5
            },
            {
                Goal::IsolateBass,
                "Isolate Bass",
                "Extracts the bass guitar/synth bass track",
                "Bass practice, analyzing bass lines",
                "You'll get: Bass track + Everything else",
                true, 5
            },
            {
                Goal::PracticeInstrument,
                "Practice Mode",
                "Removes a specific instrument so you can play along",
                "Musicians practicing their parts",
                "You'll get: Track without your instrument",
                true, 5
            },

            // === ADVANCED ===
            {
                Goal::SeparateAllStems6,
                "Separate All Stems (6-stem)",
                "Splits into Vocals, Drums, Bass, Guitar, Piano, Other",
                "Detailed remixing with guitar and piano separated",
                "You'll get: 6 separate tracks",
                true, 8
            },
            {
                Goal::RemoveBackingVocals,
                "Remove Backing Vocals",
                "Keeps lead vocals, removes harmonies and backing",
                "Isolating main vocal for covers or analysis",
                "You'll get: Lead vocal track",
                true, 4
            },

            // === AUDIO CLEANUP ===
            {
                Goal::RemoveNoise,
                "Remove Noise",
                "Cleans up background noise, hiss, and hum",
                "Cleaning up old recordings, improving audio quality",
                "You'll get: Cleaned audio",
                false, 1
            },
            {
                Goal::RemoveReverb,
                "Remove Reverb/Echo",
                "Reduces room reverb and echo from recordings",
                "Drying up vocals, cleaning live recordings",
                "You'll get: Dry audio (less reverb)",
                false, 2
            },

            // === CREATIVE ===
            {
                Goal::CreateRemix,
                "Prepare for Remix",
                "Optimized separation for remix production",
                "DJs and producers creating remixes",
                "You'll get: All stems optimized for mixing",
                true, 6
            },
            {
                Goal::CreateMashup,
                "Extract for Mashup",
                "High-quality vocal extraction for mashups",
                "Creating mashups with vocals from one song over another",
                "You'll get: Ultra-clean vocals",
                true, 4
            }
        };
    }

    //==========================================================================
    // QUALITY DESCRIPTIONS
    //==========================================================================
    struct QualityInfo
    {
        Quality quality;
        juce::String name;
        juce::String description;
        float speedMultiplier;  // 1.0 = normal, 0.5 = twice as fast
    };

    static std::vector<QualityInfo> getQualityOptions()
    {
        return {
            { Quality::Preview,  "Preview (Fast)", "Quick preview, some artifacts", 3.0f },
            { Quality::Balanced, "Balanced", "Good quality, reasonable speed", 1.0f },
            { Quality::Best,     "Best Quality", "Highest quality, slower", 0.5f },
            { Quality::Extreme,  "Extreme", "Multi-pass for maximum quality", 0.25f }
        };
    }

    //==========================================================================
    // MAIN API
    //==========================================================================

    SeparationWorkflow();
    ~SeparationWorkflow();

    /**
     * Check if the separation backend is available
     */
    bool isAvailable() const;
    juce::String getStatusMessage() const;

    /**
     * Get estimated processing time
     */
    juce::String getEstimatedTime (Goal goal, Quality quality, double audioDurationSeconds) const;

    /**
     * Start separation with the simplified workflow
     *
     * @param inputFile Audio file to process
     * @param outputDir Where to save the stems
     * @param goal What the user wants to achieve
     * @param quality Speed vs quality tradeoff
     * @param format Output file format
     * @param progressCallback Called with progress (0.0-1.0) and status message
     * @param completionCallback Called when done
     */
    void startSeparation (
        const juce::File& inputFile,
        const juce::File& outputDir,
        Goal goal,
        Quality quality,
        OutputFormat format,
        std::function<void (float progress, const juce::String& status)> progressCallback,
        std::function<void (const SeparationResult& result)> completionCallback
    );

    /**
     * Cancel ongoing separation
     */
    void cancel();

    /**
     * Check if currently processing
     */
    bool isProcessing() const;

private:
    class Impl;
    std::unique_ptr<Impl> impl;
};
