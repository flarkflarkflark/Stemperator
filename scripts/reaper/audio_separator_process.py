#!/usr/bin/env python3 -u
"""
Audio Separator Script for STEMperator
Uses audio-separator library for high-quality AI stem separation.

NOTE: The -u flag enables unbuffered stdout for real-time progress output.

Usage:
    python audio_separator_process.py <input.wav> <output_dir> [--model htdemucs]

Models:
    - htdemucs (default): Facebook's Hybrid Transformer Demucs
    - htdemucs_ft: Fine-tuned version (better quality, slower)
    - htdemucs_6s: 6-stem model (adds guitar, piano)
    - UVR-MDX-NET-Voc_FT: Best for vocal isolation
    - Kim_Vocal_2: Alternative vocal model

Outputs:
    <output_dir>/vocals.wav
    <output_dir>/drums.wav
    <output_dir>/bass.wav
    <output_dir>/other.wav

Progress output (stdout):
    PROGRESS:<percent>:<stage>
    Example: PROGRESS:45:Processing chunk 3/8
"""

import sys
import os
import argparse
import json
from pathlib import Path

def emit_progress(percent: float, stage: str = ""):
    """Output progress in machine-readable format for C++ to parse."""
    # Flush immediately so C++ can read it
    # Use sys.stdout.write + flush to ensure no buffering
    sys.stdout.write(f"PROGRESS:{int(percent)}:{stage}\n")
    sys.stdout.flush()

def detect_available_devices():
    """
    Detect available compute devices across platforms.
    
    Returns:
        list: List of tuples (device_string, device_name)
              e.g. [("cpu", "CPU"), ("cuda:0", "NVIDIA RTX 3090"), ("directml:0", "AMD Radeon RX 9070")]
    """
    import torch
    import platform
    
    devices = [("cpu", "CPU")]
    
    # CUDA (NVIDIA) or ROCm (AMD on Linux)
    if torch.cuda.is_available():
        count = torch.cuda.device_count()
        for i in range(count):
            name = torch.cuda.get_device_name(i)
            devices.append((f"cuda:{i}", name))
    
    # DirectML (AMD/Intel on Windows)
    if platform.system() == "Windows":
        try:
            import torch_directml
            dml_device_count = torch_directml.device_count()
            for i in range(dml_device_count):
                # Try to get device name, fallback to generic name
                try:
                    name = torch_directml.device_name(i)
                except:
                    name = f"DirectML Device {i}"
                devices.append((f"directml:{i}", name))
        except ImportError:
            pass  # DirectML not installed
    
    # MPS (Apple Silicon)
    if hasattr(torch.backends, 'mps') and torch.backends.mps.is_available():
        devices.append(("mps", "Apple Silicon GPU"))
    
    return devices

def parse_device_string(device_str: str):
    """
    Parse device string and return the appropriate torch device.
    
    Args:
        device_str: Device string like "auto", "cpu", "cuda:0", "directml:0", "mps"
    
    Returns:
        tuple: (device, backend) where device is torch device and backend is the library
    """
    import torch
    import platform
    
    device_str = device_str.lower().strip()
    
    # Auto mode: select best available device
    if device_str == "auto":
        if torch.cuda.is_available():
            return torch.device("cuda:0"), "cuda"
        elif platform.system() == "Windows":
            try:
                import torch_directml
                return torch_directml.device(0), "directml"
            except ImportError:
                pass
        elif hasattr(torch.backends, 'mps') and torch.backends.mps.is_available():
            return torch.device("mps"), "mps"
        return torch.device("cpu"), "cpu"
    
    # CPU
    if device_str == "cpu":
        return torch.device("cpu"), "cpu"
    
    # CUDA (NVIDIA or ROCm)
    if device_str.startswith("cuda"):
        if torch.cuda.is_available():
            return torch.device(device_str), "cuda"
        else:
            print(f"WARNING: {device_str} requested but CUDA not available, falling back to CPU", file=sys.stderr)
            return torch.device("cpu"), "cpu"
    
    # DirectML (Windows AMD/Intel)
    if device_str.startswith("directml"):
        try:
            import torch_directml
            device_id = int(device_str.split(":")[1]) if ":" in device_str else 0
            return torch_directml.device(device_id), "directml"
        except ImportError:
            print(f"WARNING: DirectML requested but torch-directml not installed, falling back to CPU", file=sys.stderr)
            return torch.device("cpu"), "cpu"
        except (IndexError, ValueError):
            print(f"WARNING: Invalid DirectML device string '{device_str}', falling back to CPU", file=sys.stderr)
            return torch.device("cpu"), "cpu"
    
    # MPS (Apple Silicon)
    if device_str == "mps":
        if hasattr(torch.backends, 'mps') and torch.backends.mps.is_available():
            return torch.device("mps"), "mps"
        else:
            print(f"WARNING: MPS requested but not available, falling back to CPU", file=sys.stderr)
            return torch.device("cpu"), "cpu"
    
    # Unknown device string
    print(f"WARNING: Unknown device string '{device_str}', falling back to CPU", file=sys.stderr)
    return torch.device("cpu"), "cpu"

def separate_stems(input_file: str, output_dir: str, model_name: str = "htdemucs", device: str = "auto"):
    """
    Separate audio into stems using audio-separator.

    Args:
        input_file: Path to input audio file
        output_dir: Directory to write output stems
        model_name: Model to use for separation (htdemucs, htdemucs_ft, htdemucs_6s)
        device: Device to use (auto, cpu, cuda:0, directml:0, mps)

    Returns:
        dict: Paths to output stem files
    """
    from audio_separator.separator import Separator
    import threading
    import time
    import torch

    # Map short names to full model names used by audio-separator
    # Model names require .yaml suffix for Demucs v4 models
    model_mapping = {
        'htdemucs': 'htdemucs.yaml',
        'htdemucs_ft': 'htdemucs_ft.yaml',
        'htdemucs_6s': 'htdemucs_6s.yaml',
        'hdemucs_mmi': 'hdemucs_mmi.yaml',
    }

    # Use mapped name or original if not in mapping
    full_model_name = model_mapping.get(model_name, model_name)

    # Create output directory
    os.makedirs(output_dir, exist_ok=True)

    emit_progress(0, "Initializing")
    print(f"Loading model: {full_model_name} (from {model_name})", file=sys.stderr)
    print(f"Input: {input_file}", file=sys.stderr)
    print(f"Output: {output_dir}", file=sys.stderr)

    # Parse and select device
    torch_device, backend = parse_device_string(device)
    print(f"Requested device: {device}", file=sys.stderr)
    print(f"Using device: {torch_device} (backend: {backend})", file=sys.stderr)
    
    # Print device details for debugging
    if backend == "cuda":
        device_id = torch_device.index if torch_device.index is not None else 0
        if torch.cuda.is_available() and device_id < torch.cuda.device_count():
            print(f"  GPU name: {torch.cuda.get_device_name(device_id)}", file=sys.stderr)
            props = torch.cuda.get_device_properties(device_id)
            memory_gb = props.total_memory / (1024**3)
            print(f"  GPU memory: {memory_gb:.1f} GB", file=sys.stderr)
    elif backend == "directml":
        import torch_directml
        print(f"  DirectML device count: {torch_directml.device_count()}", file=sys.stderr)
    
    # For separator params, we need the device as a string
    # DirectML uses special handling
    if backend == "directml":
        # DirectML requires the torch_directml device object
        separator_device = torch_device
    else:
        # CUDA, MPS, CPU use string representation
        separator_device = str(torch_device)

    # Progress emitter thread for model loading phase
    # This provides smooth progress during the slow model loading
    loading_done = threading.Event()
    loading_progress = [0]  # Use list to allow modification in thread

    def loading_progress_thread():
        """Emit smooth progress during model loading."""
        start_time = time.time()
        while not loading_done.is_set():
            elapsed = time.time() - start_time
            # Model loading typically takes 5-30 seconds
            # Use logarithmic progress that slows down as it approaches 10%
            progress_ratio = 1 - (0.5 ** (elapsed / 15))  # 15 second time constant
            percent = int(1 + progress_ratio * 9)  # 1% to 10%
            percent = min(10, percent)
            loading_progress[0] = percent

            if elapsed < 60:  # Show elapsed time
                emit_progress(percent, f"Loading model ({elapsed:.0f}s)")
            else:
                mins = int(elapsed) // 60
                secs = int(elapsed) % 60
                emit_progress(percent, f"Loading model ({mins}:{secs:02d})")

            loading_done.wait(0.4)  # Update every 0.4 seconds

    # Start loading progress thread
    loading_worker = threading.Thread(target=loading_progress_thread, daemon=True)
    loading_worker.start()

    emit_progress(1, "Initializing")

    # Initialize separator
    # Note: Don't set output_bitrate - it causes ffmpeg errors with WAV format
    separator = Separator(
        output_dir=output_dir,
        output_format="WAV",
        normalization_threshold=0.9,
        log_level=10,  # DEBUG
        mdx_params={"device": separator_device},
        demucs_params={"device": separator_device}
    )

    emit_progress(3, "Loading AI model")

    # Load model with full name (this is the slow part!)
    separator.load_model(full_model_name)

    # Stop loading progress thread
    loading_done.set()
    loading_worker.join(timeout=1.0)

    emit_progress(11, "Starting separation")

    # Get audio duration for time-based progress estimation
    duration_seconds = 0
    try:
        import soundfile as sf
        info = sf.info(input_file)
        duration_seconds = info.duration
        print(f"Audio duration: {duration_seconds:.1f}s", file=sys.stderr)
    except Exception:
        duration_seconds = 180  # Default estimate: 3 minutes

    # Estimate processing time based on device type
    # GPU: ~0.3-0.5x realtime, CPU: ~2-4x realtime
    if backend in ["cuda", "directml", "mps"]:
        estimated_time = duration_seconds * 0.5  # GPU: ~0.5x realtime
        print(f"Processing with GPU acceleration (estimated {estimated_time:.0f}s)", file=sys.stderr)
    else:
        estimated_time = duration_seconds * 3.0  # CPU: ~3x realtime
        print(f"Processing with CPU (estimated {estimated_time:.0f}s)", file=sys.stderr)

    # Progress emitter thread - emits smooth progress while processing
    processing_done = threading.Event()

    def progress_thread():
        start_time = time.time()
        last_percent = 11

        while not processing_done.is_set():
            elapsed = time.time() - start_time
            # Smooth asymptotic progress: never quite reaches 90%
            # Uses exponential approach to 90% based on estimated time
            if estimated_time > 0:
                progress_ratio = 1 - (0.5 ** (elapsed / estimated_time))
                percent = int(12 + progress_ratio * 76)  # 12% to 88%
            else:
                percent = min(88, int(12 + elapsed * 2))  # Fallback: 2% per second

            percent = min(88, max(last_percent, percent))  # Never go backwards, cap at 88%
            last_percent = percent

            # Format elapsed time
            mins_elapsed = int(elapsed) // 60
            secs_elapsed = int(elapsed) % 60

            # Calculate ETA based on current progress
            if percent > 15:
                # Estimate remaining time based on elapsed time and progress
                progress_fraction = (percent - 12) / 78.0  # 12-90% is the main work
                if progress_fraction > 0.05:  # Only show ETA after 5% progress
                    total_est = elapsed / progress_fraction
                    remaining = max(0, total_est - elapsed)
                    mins_remaining = int(remaining) // 60
                    secs_remaining = int(remaining) % 60
                    eta_str = f" | ETA {mins_remaining}:{secs_remaining:02d}"
                else:
                    eta_str = ""
            else:
                eta_str = ""

            # Always emit progress with time (even if percent hasn't changed)
            emit_progress(percent, f"Processing ({mins_elapsed}:{secs_elapsed:02d}{eta_str})")

            # Wait shorter interval for more responsive updates
            processing_done.wait(0.3)

    # Start progress thread
    progress_worker = threading.Thread(target=progress_thread, daemon=True)
    progress_worker.start()

    print("Processing...", file=sys.stderr)
    try:
        output_files = separator.separate(input_file)
    finally:
        # Signal thread to stop
        processing_done.set()
        progress_worker.join(timeout=1.0)

    emit_progress(92, "Writing stems")

    print(f"Raw output files: {output_files}", file=sys.stderr)

    # Rename outputs to standard names
    result = {}
    stem_mapping = {
        'vocals': ['vocals', 'vocal', 'Vocals'],
        'drums': ['drums', 'drum', 'Drums'],
        'bass': ['bass', 'Bass'],
        'other': ['other', 'Other', 'no_vocals', 'instrumental', 'Instrumental'],
        'guitar': ['guitar', 'Guitar'],
        'piano': ['piano', 'Piano', 'keys', 'Keys']
    }

    for output_file in output_files:
        # output_file may be relative or just filename - make it absolute
        if not os.path.isabs(output_file):
            output_file = os.path.join(output_dir, output_file)

        filename = Path(output_file).stem.lower()

        for stem_name, patterns in stem_mapping.items():
            for pattern in patterns:
                if pattern.lower() in filename:
                    # Rename to standard name
                    new_path = os.path.join(output_dir, f"{stem_name}.wav")
                    if output_file != new_path:
                        if os.path.exists(new_path):
                            os.remove(new_path)
                        import shutil
                        shutil.move(output_file, new_path)
                    result[stem_name] = new_path
                    print(f"  {stem_name}: {new_path}", file=sys.stderr)
                    break

    emit_progress(100, "Complete")
    return result

def check_installation():
    """Check if audio-separator is properly installed and list available devices."""
    try:
        from audio_separator.separator import Separator
        import torch

        print(f"audio-separator: OK", file=sys.stderr)
        print(f"PyTorch: {torch.__version__}", file=sys.stderr)
        
        # Detect and list all available devices
        devices = detect_available_devices()
        print(f"\nAvailable devices ({len(devices)}):", file=sys.stderr)
        for device_str, device_name in devices:
            print(f"  {device_str}: {device_name}", file=sys.stderr)

        return True
    except ImportError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        print("\nInstall with: pip install audio-separator[gpu]", file=sys.stderr)
        return False

def main():
    parser = argparse.ArgumentParser(description="Audio Separator for STEMperator")
    parser.add_argument("input", nargs="?", help="Input audio file")
    parser.add_argument("output_dir", nargs="?", help="Output directory for stems")
    parser.add_argument("--model", default="htdemucs",
                        help="Model to use (htdemucs, htdemucs_ft, UVR-MDX-NET-Voc_FT, etc.)")
    parser.add_argument("--device", default="auto",
                        help="Device to use: auto, cpu, cuda:0, cuda:1, directml:0, directml:1, mps (default: auto)")
    parser.add_argument("--gpu-id", type=int, default=None,
                        help="DEPRECATED: Use --device instead. GPU device ID (0, 1, etc.) or -1 for CPU")
    parser.add_argument("--check", action="store_true",
                        help="Only check installation, don't process")
    parser.add_argument("--list-models", action="store_true",
                        help="List available models")
    parser.add_argument("--list-devices", action="store_true",
                        help="List available compute devices")

    args = parser.parse_args()

    if args.check:
        if check_installation():
            print("Installation OK!")
            sys.exit(0)
        else:
            sys.exit(1)

    if args.list_models:
        print("Popular models:")
        print("  htdemucs - Hybrid Transformer Demucs (default, fast)")
        print("  htdemucs_ft - Fine-tuned Demucs (better quality)")
        print("  htdemucs_6s - 6-stem model (guitar, piano)")
        print("  UVR-MDX-NET-Voc_FT - Best vocal isolation")
        print("  Kim_Vocal_2 - Alternative vocal model")
        sys.exit(0)

    if args.list_devices:
        devices = detect_available_devices()
        print(f"Available devices ({len(devices)}):")
        for device_str, device_name in devices:
            print(f"  {device_str}: {device_name}")
        sys.exit(0)

    if not args.input or not args.output_dir:
        parser.print_help()
        sys.exit(1)

    if not os.path.exists(args.input):
        print(f"ERROR: Input file not found: {args.input}", file=sys.stderr)
        sys.exit(1)

    # Handle deprecated --gpu-id argument
    device = args.device
    if args.gpu_id is not None:
        print(f"WARNING: --gpu-id is deprecated, use --device instead", file=sys.stderr)
        if args.gpu_id < 0:
            device = "cpu"
        else:
            device = f"cuda:{args.gpu_id}"

    try:
        output_files = separate_stems(args.input, args.output_dir, args.model, device)

        # Output JSON for C++ to parse
        print(json.dumps(output_files))

    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc(file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
