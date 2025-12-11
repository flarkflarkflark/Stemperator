#!/usr/bin/env python3
"""
Demucs Stem Separation Script for Stemperator
Processes audio files and outputs separated stems.

Usage:
    python demucs_process.py <input.wav> <output_dir> [--model htdemucs] [--device cuda]

Outputs:
    <output_dir>/vocals.wav
    <output_dir>/drums.wav
    <output_dir>/bass.wav
    <output_dir>/other.wav
"""

import sys
import os
import argparse
import tempfile
import shutil
from pathlib import Path

def check_dependencies():
    """Check if required packages are installed."""
    missing = []
    try:
        import torch
    except ImportError:
        missing.append("torch (PyTorch)")

    try:
        import demucs
    except ImportError:
        missing.append("demucs")

    try:
        import torchaudio
    except ImportError:
        missing.append("torchaudio")

    if missing:
        print(f"ERROR: Missing dependencies: {', '.join(missing)}", file=sys.stderr)
        print("\nInstall with:", file=sys.stderr)
        print("  Arch Linux: sudo pacman -S python-pytorch-opt-rocm python-torchaudio", file=sys.stderr)
        print("  Then: pip install --user demucs", file=sys.stderr)
        return False
    return True

def separate_stems(input_file: str, output_dir: str, model_name: str = "htdemucs",
                   device: str = "cuda", two_stems: str = None):
    """
    Separate audio into stems using Demucs.

    Args:
        input_file: Path to input audio file
        output_dir: Directory to write output stems
        model_name: Demucs model to use (htdemucs, htdemucs_ft, mdx_extra)
        device: Device to use (cuda, cpu)
        two_stems: If set, only separate into two stems (e.g., "vocals")

    Returns:
        dict: Paths to output stem files
    """
    import torch
    import torchaudio
    from demucs.pretrained import get_model
    from demucs.apply import apply_model

    # Check device availability
    if device == "cuda" and not torch.cuda.is_available():
        print("CUDA not available, falling back to CPU", file=sys.stderr)
        device = "cpu"

    print(f"Loading model: {model_name}", file=sys.stderr)
    model = get_model(model_name)
    model.to(device)
    model.eval()

    print(f"Loading audio: {input_file}", file=sys.stderr)

    # Load audio
    waveform, sample_rate = torchaudio.load(input_file)

    # Resample if needed (Demucs expects 44100 Hz)
    if sample_rate != model.samplerate:
        print(f"Resampling from {sample_rate} to {model.samplerate} Hz", file=sys.stderr)
        resampler = torchaudio.transforms.Resample(sample_rate, model.samplerate)
        waveform = resampler(waveform)
        sample_rate = model.samplerate

    # Ensure stereo
    if waveform.shape[0] == 1:
        waveform = waveform.repeat(2, 1)
    elif waveform.shape[0] > 2:
        waveform = waveform[:2]

    # Add batch dimension
    waveform = waveform.unsqueeze(0).to(device)

    print(f"Processing on {device}...", file=sys.stderr)

    # Apply model
    with torch.no_grad():
        sources = apply_model(model, waveform, device=device, progress=True)

    # sources shape: [batch, sources, channels, samples]
    sources = sources[0]  # Remove batch dimension

    # Get source names from model
    source_names = model.sources  # e.g., ['drums', 'bass', 'other', 'vocals']

    # Create output directory
    os.makedirs(output_dir, exist_ok=True)

    # Save each stem
    output_files = {}
    for i, name in enumerate(source_names):
        stem = sources[i].cpu()
        output_path = os.path.join(output_dir, f"{name}.wav")
        torchaudio.save(output_path, stem, sample_rate)
        output_files[name] = output_path
        print(f"Saved: {output_path}", file=sys.stderr)

    return output_files

def main():
    parser = argparse.ArgumentParser(description="Demucs Stem Separation for Stemperator")
    parser.add_argument("input", nargs="?", help="Input audio file")
    parser.add_argument("output_dir", nargs="?", help="Output directory for stems")
    parser.add_argument("--model", default="htdemucs",
                        choices=["htdemucs", "htdemucs_ft", "htdemucs_6s", "mdx_extra", "mdx_extra_q"],
                        help="Demucs model to use")
    parser.add_argument("--device", default="cuda", choices=["cuda", "cpu"],
                        help="Device to use for processing")
    parser.add_argument("--two-stems", default=None,
                        help="Only separate into two stems (e.g., 'vocals')")
    parser.add_argument("--check", action="store_true",
                        help="Only check dependencies, don't process")

    args = parser.parse_args()

    # Handle --check first (doesn't need input/output_dir)
    if args.check:
        if not check_dependencies():
            sys.exit(1)
        print("All dependencies OK!")
        import torch
        print(f"PyTorch: {torch.__version__}")
        print(f"CUDA available: {torch.cuda.is_available()}")
        if torch.cuda.is_available():
            print(f"GPU: {torch.cuda.get_device_name(0)}")
        sys.exit(0)

    # Check dependencies for actual processing
    if not check_dependencies():
        sys.exit(1)

    # Require input and output_dir for processing
    if not args.input or not args.output_dir:
        parser.error("input and output_dir are required for processing")

    # Validate input
    if not os.path.exists(args.input):
        print(f"ERROR: Input file not found: {args.input}", file=sys.stderr)
        sys.exit(1)

    try:
        output_files = separate_stems(
            args.input,
            args.output_dir,
            model_name=args.model,
            device=args.device,
            two_stems=args.two_stems
        )

        # Print output paths as JSON for parsing
        import json
        print(json.dumps(output_files))

    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc(file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
