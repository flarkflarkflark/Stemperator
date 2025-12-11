#include "DemucsProcessor.h"

DemucsProcessor::DemucsProcessor()
{
    checkAvailability();
}

DemucsProcessor::~DemucsProcessor()
{
    cancel();
}

void DemucsProcessor::checkAvailability()
{
    demucsAvailable = false;
    gpuAvailable = false;
    statusMessage = "Checking Demucs availability...";

    // Find Python - prefer venv Python for proper dependencies
    auto executableDir = juce::File::getSpecialLocation (juce::File::currentExecutableFile).getParentDirectory();
    auto projectRoot = executableDir.getParentDirectory().getParentDirectory().getParentDirectory();
    auto envRoot = juce::SystemStats::getEnvironmentVariable ("STEMPERATOR_ROOT", "");
    
    juce::StringArray pythonPaths;
    
    // Check for venv Python in STEMPERATOR_ROOT first
    if (envRoot.isNotEmpty())
    {
        pythonPaths.add (juce::File (envRoot).getChildFile (".venv/bin/python").getFullPathName());
        pythonPaths.add (juce::File (envRoot).getChildFile (".venv/Scripts/python.exe").getFullPathName());
    }
    
    // Check for venv Python relative to executable
    pythonPaths.add (projectRoot.getChildFile (".venv/bin/python").getFullPathName());
    pythonPaths.add (executableDir.getChildFile (".venv/bin/python").getFullPathName());
    
    // Fall back to system Python
    pythonPaths.add ("python3");
    pythonPaths.add ("python");
    pythonPaths.add ("/usr/bin/python3");

    for (const auto& path : pythonPaths)
    {
        juce::File pythonFile (path);
        if (pythonFile.existsAsFile() || ! path.contains ("/"))
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
    }

    if (pythonPath.isEmpty())
    {
        statusMessage = "Python not found";
        return;
    }

    // Find our script (look in multiple locations)

    juce::StringArray scriptLocations = {
        executableDir.getChildFile ("demucs_process.py").getFullPathName(),
        executableDir.getParentDirectory().getChildFile ("Source/AI/demucs_process.py").getFullPathName(),
        projectRoot.getChildFile ("Source/AI/demucs_process.py").getFullPathName(),
        juce::File::getSpecialLocation (juce::File::currentApplicationFile)
            .getSiblingFile ("demucs_process.py").getFullPathName()
    };

    // Add STEMPERATOR_ROOT path if set
    if (envRoot.isNotEmpty())
        scriptLocations.add (juce::File (envRoot).getChildFile ("Source/AI/demucs_process.py").getFullPathName());

    for (const auto& loc : scriptLocations)
    {
        juce::File f (loc);
        if (f.existsAsFile())
        {
            scriptPath = f;
            break;
        }
    }

    if (! scriptPath.existsAsFile())
    {
        statusMessage = "Demucs script not found";
        return;
    }

    // Check if Demucs is installed and get GPU info
    juce::ChildProcess checkProcess;
    juce::String checkCmd = pythonPath + " \"" + scriptPath.getFullPathName() + "\" --check";

    if (checkProcess.start (checkCmd))
    {
        juce::String output = checkProcess.readAllProcessOutput();
        checkProcess.waitForProcessToFinish (30000);

        if (checkProcess.getExitCode() == 0)
        {
            demucsAvailable = true;

            // Parse output for GPU info
            if (output.contains ("CUDA available: True") || output.contains ("ROCm"))
            {
                gpuAvailable = true;

                // Extract GPU name
                int gpuLine = output.indexOf ("GPU:");
                if (gpuLine >= 0)
                {
                    int lineEnd = output.indexOf (gpuLine, "\n");
                    if (lineEnd > gpuLine)
                        gpuName = output.substring (gpuLine + 4, lineEnd).trim();
                }
            }

            if (gpuAvailable)
                statusMessage = "Demucs ready (GPU: " + gpuName + ")";
            else
                statusMessage = "Demucs ready (CPU mode)";
        }
        else
        {
            // Parse error message
            if (output.contains ("Missing dependencies"))
                statusMessage = "Demucs dependencies missing - install PyTorch and demucs";
            else
                statusMessage = "Demucs check failed: " + output.substring (0, 100);
        }
    }
    else
    {
        statusMessage = "Failed to run Demucs check";
    }
}

juce::String DemucsProcessor::getModelName() const
{
    switch (currentModel)
    {
        case HTDemucs:      return "htdemucs";
        case HTDemucs_FT:   return "htdemucs_ft";
        case HTDemucs_6S:   return "htdemucs_6s";
        case MDX_Extra:     return "mdx_extra";
        case MDX_Extra_Q:   return "mdx_extra_q";
        default:            return "htdemucs";
    }
}

bool DemucsProcessor::process (const juce::AudioBuffer<float>& inputBuffer,
                               double sampleRate,
                               std::function<void (float)> progressCallback)
{
    if (! demucsAvailable)
        return false;

    if (processing.load())
        return false;

    processing.store (true);
    shouldCancel.store (false);

    // Create temp directory for processing
    juce::File tempDir = juce::File::getSpecialLocation (juce::File::tempDirectory)
                             .getChildFile ("stemperator_" + juce::Uuid().toString());
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
            return false;
        }
    }

    // Process with Demucs
    juce::File outputDir = tempDir.getChildFile ("output");
    bool success = runDemucs (inputFile, outputDir, progressCallback);

    if (success && ! shouldCancel.load())
    {
        success = loadStems (outputDir);
        stemSampleRate = sampleRate;
    }

    // Cleanup
    tempDir.deleteRecursively();
    processing.store (false);

    return success;
}

bool DemucsProcessor::processFile (const juce::File& inputFile,
                                   const juce::File& outputDir,
                                   std::function<void (float)> progressCallback)
{
    if (! demucsAvailable)
        return false;

    if (processing.load())
        return false;

    if (! inputFile.existsAsFile())
        return false;

    processing.store (true);
    shouldCancel.store (false);

    outputDir.createDirectory();

    bool success = runDemucs (inputFile, outputDir, progressCallback);

    if (success && ! shouldCancel.load())
        success = loadStems (outputDir);

    processing.store (false);
    return success;
}

bool DemucsProcessor::runDemucs (const juce::File& inputFile,
                                 const juce::File& outputDir,
                                 std::function<void (float)> progressCallback)
{
    juce::String device = gpuAvailable ? "cuda" : "cpu";
    juce::String modelName = getModelName();

    juce::String cmd = pythonPath + " \"" + scriptPath.getFullPathName() + "\" "
                       + "\"" + inputFile.getFullPathName() + "\" "
                       + "\"" + outputDir.getFullPathName() + "\" "
                       + "--model " + modelName + " "
                       + "--device " + device;

    DBG ("Running Demucs: " + cmd);

    juce::ChildProcess process;
    if (! process.start (cmd))
    {
        DBG ("Failed to start Demucs process");
        return false;
    }

    // Monitor progress (simplified - real implementation would parse stderr)
    float progress = 0.0f;
    while (process.isRunning())
    {
        if (shouldCancel.load())
        {
            process.kill();
            return false;
        }

        // Simulate progress (actual progress would come from parsing stderr)
        progress = juce::jmin (0.95f, progress + 0.01f);
        if (progressCallback)
            progressCallback (progress);

        juce::Thread::sleep (500);
    }

    if (progressCallback)
        progressCallback (1.0f);

    int exitCode = process.getExitCode();
    if (exitCode != 0)
    {
        juce::String output = process.readAllProcessOutput();
        DBG ("Demucs failed with exit code " + juce::String (exitCode));
        DBG ("Output: " + output);
        return false;
    }

    return true;
}

bool DemucsProcessor::loadStems (const juce::File& outputDir)
{
    juce::AudioFormatManager formatManager;
    formatManager.registerBasicFormats();

    bool allLoaded = true;
    int numStemsToLoad = getNumStems();

    for (int i = 0; i < numStemsToLoad; ++i)
    {
        juce::File stemFile = outputDir.getChildFile (juce::String (StemNames[i]) + ".wav");

        if (! stemFile.existsAsFile())
        {
            DBG ("Stem file not found: " + stemFile.getFullPathName());
            allLoaded = false;
            continue;
        }

        std::unique_ptr<juce::AudioFormatReader> reader (
            formatManager.createReaderFor (stemFile));

        if (reader)
        {
            stems[i].setSize (static_cast<int> (reader->numChannels),
                              static_cast<int> (reader->lengthInSamples));
            reader->read (&stems[i], 0, static_cast<int> (reader->lengthInSamples), 0, true, true);
            stemSampleRate = reader->sampleRate;
            DBG ("Loaded stem: " + juce::String (StemNames[i]) + " ("
                 + juce::String (reader->lengthInSamples) + " samples)");
        }
        else
        {
            DBG ("Failed to read stem: " + stemFile.getFullPathName());
            allLoaded = false;
        }
    }

    return allLoaded;
}
