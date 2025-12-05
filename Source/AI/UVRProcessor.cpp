#include "UVRProcessor.h"

UVRProcessor::UVRProcessor()
{
    checkAvailability();
}

UVRProcessor::~UVRProcessor()
{
    cancel();
}

void UVRProcessor::checkAvailability()
{
    uvrAvailable = false;
    gpuAvailable = false;
    useAudioSeparator = false;
    statusMessage = "Checking UVR availability...";

    // Find Python
    juce::StringArray pythonPaths = { "python3", "python", "/usr/bin/python3", "/usr/local/bin/python3" };

    for (const auto& path : pythonPaths)
    {
        juce::ChildProcess checkProcess;
        if (checkProcess.start (path + " --version"))
        {
            checkProcess.waitForProcessToFinish (5000);
            if (checkProcess.getExitCode() == 0)
            {
                pythonPath = path;
                break;
            }
        }
    }

    if (pythonPath.isEmpty())
    {
        statusMessage = "Python not found";
        return;
    }

    // First, check for audio-separator package (lightweight UVR wrapper)
    {
        juce::ChildProcess checkProcess;
        juce::String checkCmd = pythonPath + " -c \"import audio_separator; print(audio_separator.__version__)\"";

        if (checkProcess.start (checkCmd))
        {
            juce::String output = checkProcess.readAllProcessOutput();
            checkProcess.waitForProcessToFinish (10000);

            if (checkProcess.getExitCode() == 0)
            {
                useAudioSeparator = true;
                uvrAvailable = true;
                DBG ("Found audio-separator: " + output.trim());
            }
        }
    }

    // If audio-separator not found, look for full UVR installation
    if (! uvrAvailable)
    {
        // Check common UVR installation paths
        juce::StringArray uvrPaths = {
            juce::File::getSpecialLocation (juce::File::userHomeDirectory)
                .getChildFile ("ultimatevocalremovergui").getFullPathName(),
            juce::File::getSpecialLocation (juce::File::userHomeDirectory)
                .getChildFile (".local/share/ultimatevocalremovergui").getFullPathName(),
            "/opt/ultimatevocalremovergui",
            "/usr/local/share/ultimatevocalremovergui"
        };

        for (const auto& path : uvrPaths)
        {
            juce::File uvrDir (path);
            juce::File separateScript = uvrDir.getChildFile ("separate.py");

            if (separateScript.existsAsFile())
            {
                uvrPath = uvrDir;
                uvrAvailable = true;
                useAudioSeparator = false;
                DBG ("Found UVR at: " + path);
                break;
            }
        }
    }

    if (! uvrAvailable)
    {
        statusMessage = "UVR not found. Install with: " + getInstallCommand();
        return;
    }

    // Check for GPU availability
    {
        juce::ChildProcess checkProcess;
        juce::String checkCmd = pythonPath + " -c \""
            "import torch; "
            "print('CUDA:', torch.cuda.is_available()); "
            "print('GPU:', torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'None')\"";

        if (checkProcess.start (checkCmd))
        {
            juce::String output = checkProcess.readAllProcessOutput();
            checkProcess.waitForProcessToFinish (15000);

            if (output.contains ("CUDA: True"))
            {
                gpuAvailable = true;

                // Extract GPU name
                int gpuLine = output.indexOf ("GPU:");
                if (gpuLine >= 0)
                {
                    int lineEnd = output.indexOf (gpuLine, "\n");
                    if (lineEnd > gpuLine)
                        gpuName = output.substring (gpuLine + 4, lineEnd).trim();
                    else
                        gpuName = output.substring (gpuLine + 4).trim();
                }
            }

            // Also check for ROCm (AMD)
            if (! gpuAvailable && output.contains ("hip"))
            {
                gpuAvailable = true;
                gpuName = "AMD ROCm";
            }
        }
    }

    // Build status message
    juce::String backend = useAudioSeparator ? "audio-separator" : "UVR";
    if (gpuAvailable)
        statusMessage = backend + " ready (GPU: " + gpuName + ")";
    else
        statusMessage = backend + " ready (CPU mode)";

    // Query available models
    queryAvailableModels();
}

void UVRProcessor::queryAvailableModels()
{
    availableModels.clear();

    if (useAudioSeparator)
    {
        // audio-separator has built-in model list
        juce::ChildProcess process;
        juce::String cmd = pythonPath + " -c \""
            "from audio_separator.separator import Separator; "
            "s = Separator(); "
            "print('\\n'.join(s.list_supported_model_files()))\"";

        if (process.start (cmd))
        {
            juce::String output = process.readAllProcessOutput();
            process.waitForProcessToFinish (30000);

            if (process.getExitCode() == 0)
            {
                availableModels = juce::StringArray::fromLines (output);
                availableModels.removeEmptyStrings();
            }
        }
    }

    // Add known model names as fallback
    if (availableModels.isEmpty())
    {
        availableModels = {
            // MDX-Net models
            "UVR-MDX-NET-Voc_FT.onnx",
            "UVR-MDX-NET-Inst_HQ_3.onnx",
            "Kim_Vocal_2.onnx",
            "kuielab_a_vocals.onnx",
            "kuielab_a_drums.onnx",
            "kuielab_a_bass.onnx",
            "kuielab_a_other.onnx",
            // VR Architecture
            "5_HP-Karaoke-UVR.pth",
            "UVR-DeNoise.pth",
            "UVR-DeEcho-DeReverb.pth",
            // Demucs
            "htdemucs",
            "htdemucs_ft",
            "htdemucs_6s",
            // MDX23C
            "MDX23C-8KFFT-InstVoc_HQ.ckpt"
        };
    }
}

juce::String UVRProcessor::getModelName() const
{
    switch (currentPreset)
    {
        case Vocals_MDX_Kim2:       return "Kim_Vocal_2.onnx";
        case Vocals_MDX_Inst_HQ3:   return "UVR-MDX-NET-Inst_HQ_3.onnx";
        case Vocals_VR_5HP_Karaoke: return "5_HP-Karaoke-UVR.pth";
        case Stems_HTDemucs:        return "htdemucs";
        case Stems_HTDemucs_FT:     return "htdemucs_ft";
        case Stems_MDX23C_8KFFT:    return "MDX23C-8KFFT-InstVoc_HQ.ckpt";
        case Denoise_MDX_DeNoise:   return "UVR-DeNoise.pth";
        case Dereverb_MDX_DeReverb: return "UVR-DeEcho-DeReverb.pth";
        case Custom:                return customModelName;
        default:                    return "htdemucs";
    }
}

juce::String UVRProcessor::buildCommand (const juce::File& inputFile, const juce::File& outputDir) const
{
    juce::String modelName = getModelName();

    if (useAudioSeparator)
    {
        // Use audio-separator CLI
        juce::String cmd = pythonPath + " -m audio_separator.separator";
        cmd += " \"" + inputFile.getFullPathName() + "\"";
        cmd += " --output_dir \"" + outputDir.getFullPathName() + "\"";
        cmd += " --model_filename \"" + modelName + "\"";

        // Add output format
        cmd += " --output_format WAV";

        // Use single stem output mode for full separation
        if (currentPreset == Stems_HTDemucs ||
            currentPreset == Stems_HTDemucs_FT ||
            currentPreset == Stems_MDX23C_8KFFT)
        {
            cmd += " --single_stem None";  // Output all stems
        }

        return cmd;
    }
    else
    {
        // Use full UVR separate.py
        juce::File separateScript = uvrPath.getChildFile ("separate.py");

        juce::String cmd = pythonPath + " \"" + separateScript.getFullPathName() + "\"";
        cmd += " -i \"" + inputFile.getFullPathName() + "\"";
        cmd += " -o \"" + outputDir.getFullPathName() + "\"";
        cmd += " -m \"" + modelName + "\"";

        if (gpuAvailable)
            cmd += " --gpu 0";

        return cmd;
    }
}

bool UVRProcessor::process (const juce::AudioBuffer<float>& inputBuffer,
                            double sampleRate,
                            std::function<void (float)> progressCallback,
                            std::function<void (bool, const juce::String&)> completionCallback)
{
    if (! uvrAvailable)
    {
        if (completionCallback)
            completionCallback (false, statusMessage);
        return false;
    }

    if (processing.load())
    {
        if (completionCallback)
            completionCallback (false, "Already processing");
        return false;
    }

    processing.store (true);
    shouldCancel.store (false);

    // Create temp directory for processing
    juce::File tempDir = juce::File::getSpecialLocation (juce::File::tempDirectory)
                             .getChildFile ("stemperator_uvr_" + juce::Uuid().toString());
    tempDir.createDirectory();

    // Write input to temp WAV file
    juce::File inputFile = tempDir.getChildFile ("input.wav");
    {
        juce::WavAudioFormat wavFormat;
        std::unique_ptr<juce::AudioFormatWriter> writer (
            wavFormat.createWriterFor (new juce::FileOutputStream (inputFile),
                                       sampleRate,
                                       static_cast<unsigned int> (inputBuffer.getNumChannels()),
                                       24, {}, 0));

        if (writer)
            writer->writeFromAudioSampleBuffer (inputBuffer, 0, inputBuffer.getNumSamples());
        else
        {
            processing.store (false);
            tempDir.deleteRecursively();
            if (completionCallback)
                completionCallback (false, "Failed to write temp file");
            return false;
        }
    }

    // Process with UVR
    juce::File outputDir = tempDir.getChildFile ("output");
    bool success = runSeparation (inputFile, outputDir, progressCallback);

    juce::String errorMsg;
    if (success && ! shouldCancel.load())
    {
        success = loadStems (outputDir);
        if (! success)
            errorMsg = "Failed to load output stems";
        stemSampleRate = sampleRate;
    }
    else if (shouldCancel.load())
    {
        errorMsg = "Cancelled by user";
    }
    else
    {
        errorMsg = "Separation failed";
    }

    // Cleanup
    tempDir.deleteRecursively();
    processing.store (false);

    if (completionCallback)
        completionCallback (success, errorMsg);

    return success;
}

bool UVRProcessor::processFile (const juce::File& inputFile,
                                const juce::File& outputDir,
                                std::function<void (float)> progressCallback,
                                std::function<void (bool, const juce::String&)> completionCallback)
{
    if (! uvrAvailable)
    {
        if (completionCallback)
            completionCallback (false, statusMessage);
        return false;
    }

    if (processing.load())
    {
        if (completionCallback)
            completionCallback (false, "Already processing");
        return false;
    }

    if (! inputFile.existsAsFile())
    {
        if (completionCallback)
            completionCallback (false, "Input file not found");
        return false;
    }

    processing.store (true);
    shouldCancel.store (false);

    outputDir.createDirectory();

    bool success = runSeparation (inputFile, outputDir, progressCallback);

    juce::String errorMsg;
    if (success && ! shouldCancel.load())
    {
        success = loadStems (outputDir);
        if (! success)
            errorMsg = "Failed to load output stems";
    }
    else if (shouldCancel.load())
    {
        errorMsg = "Cancelled by user";
    }
    else
    {
        errorMsg = "Separation failed";
    }

    processing.store (false);

    if (completionCallback)
        completionCallback (success, errorMsg);

    return success;
}

bool UVRProcessor::runSeparation (const juce::File& inputFile,
                                  const juce::File& outputDir,
                                  std::function<void (float)> progressCallback)
{
    juce::String cmd = buildCommand (inputFile, outputDir);
    DBG ("Running UVR: " + cmd);

    juce::ChildProcess process;
    if (! process.start (cmd))
    {
        DBG ("Failed to start UVR process");
        return false;
    }

    // Monitor progress
    float progress = 0.0f;
    while (process.isRunning())
    {
        if (shouldCancel.load())
        {
            process.kill();
            return false;
        }

        // Read stderr for progress (UVR outputs progress there)
        juce::String output = process.readAllProcessOutput();

        // Parse progress from output (audio-separator format: "Progress: XX%")
        if (output.contains ("Progress:") || output.contains ("%"))
        {
            // Try to extract percentage
            int percentPos = output.lastIndexOf ("%");
            if (percentPos > 0)
            {
                int startPos = percentPos - 1;
                while (startPos > 0 && juce::CharacterFunctions::isDigit (output[startPos - 1]))
                    startPos--;

                juce::String percentStr = output.substring (startPos, percentPos);
                float parsedProgress = percentStr.getFloatValue() / 100.0f;
                if (parsedProgress > progress)
                    progress = parsedProgress;
            }
        }
        else
        {
            // Simulate progress if not available
            progress = juce::jmin (0.95f, progress + 0.005f);
        }

        if (progressCallback)
            progressCallback (progress);

        juce::Thread::sleep (200);
    }

    if (progressCallback)
        progressCallback (1.0f);

    int exitCode = process.getExitCode();
    if (exitCode != 0)
    {
        juce::String output = process.readAllProcessOutput();
        DBG ("UVR failed with exit code " + juce::String (exitCode));
        DBG ("Output: " + output);
        return false;
    }

    return true;
}

bool UVRProcessor::loadStems (const juce::File& outputDir)
{
    juce::AudioFormatManager formatManager;
    formatManager.registerBasicFormats();

    // UVR/audio-separator output naming conventions
    // For 2-stem: (Vocals).wav, (Instrumental).wav
    // For 4-stem Demucs: vocals.wav, drums.wav, bass.wav, other.wav

    // Map of possible output file names for each stem
    const std::array<juce::StringArray, NumStems> stemFileNames = {{
        { "vocals.wav", "(Vocals).wav", "vocal.wav", "*_Vocals.wav" },     // Vocals
        { "drums.wav", "(Drums).wav", "drum.wav" },                         // Drums
        { "bass.wav", "(Bass).wav" },                                       // Bass
        { "other.wav", "(Other).wav", "(Instrumental).wav", "no_vocals.wav", "*_Instrumental.wav" }  // Other
    }};

    bool anyLoaded = false;

    for (int i = 0; i < NumStems; ++i)
    {
        bool loaded = false;

        for (const auto& fileName : stemFileNames[i])
        {
            juce::File stemFile;

            if (fileName.contains ("*"))
            {
                // Wildcard search
                juce::String pattern = fileName.replace ("*", "");
                for (const auto& file : outputDir.findChildFiles (juce::File::findFiles, false))
                {
                    if (file.getFileName().contains (pattern))
                    {
                        stemFile = file;
                        break;
                    }
                }
            }
            else
            {
                stemFile = outputDir.getChildFile (fileName);
            }

            if (stemFile.existsAsFile())
            {
                std::unique_ptr<juce::AudioFormatReader> reader (
                    formatManager.createReaderFor (stemFile));

                if (reader)
                {
                    stems[i].setSize (static_cast<int> (reader->numChannels),
                                      static_cast<int> (reader->lengthInSamples));
                    reader->read (&stems[i], 0, static_cast<int> (reader->lengthInSamples), 0, true, true);
                    stemSampleRate = reader->sampleRate;
                    loaded = true;
                    anyLoaded = true;
                    DBG ("Loaded stem: " + juce::String (StemNames[i]) + " from " + stemFile.getFileName());
                    break;
                }
            }
        }

        if (! loaded)
        {
            // Clear the stem buffer if not found
            stems[i].clear();
            DBG ("Stem not found: " + juce::String (StemNames[i]));
        }
    }

    // For vocal-only models (2-stem), derive drums/bass from instrumental
    if (stems[Other].getNumSamples() > 0 && stems[Drums].getNumSamples() == 0)
    {
        // Copy instrumental to drums and bass as fallback (user can re-process if needed)
        DBG ("2-stem mode detected, instrumental assigned to 'Other'");
    }

    return anyLoaded;
}
