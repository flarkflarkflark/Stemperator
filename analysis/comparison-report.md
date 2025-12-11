# STEMperator v2.0 vs Old Scripts Comparison Report

**Date:** December 12, 2025

## Executive Summary

Old scripts (v1.5.0) and current v2.0 are **functionally identical**. Main change is rebranding from "Stemperator" → "STEMperator". One improvement: Installation script enhanced (+205 lines).

## Version Comparison

| Version | Lines | Key Changes |
|---------|-------|-------------|
| Old v1.5.0 (full) | 12,104 | Full features + art gallery |
| Old v1.5.0 (backup) | 6,472 | Before art gallery added |
| Current v2.0 | 12,109 | Rebranded (+5 lines) |

## Main Findings

### 1. Main Script (AI_Separate.lua)
- **Old**: 12,104 lines
- **New**: 12,109 lines (+5)
- **Changes**: Rebranding only
  - Headers: "Stemperator" → "STEMperator"
  - Window titles updated
  - Undo blocks updated
  - v2.0 changelog added
- **Functionality**: IDENTICAL

### 2. Installation Script - MAJOR IMPROVEMENT
- **Old**: Setup.lua (316 lines)
- **New**: Installation.lua (521 lines) **+205 lines (+65%)**
- **Improvements**:
  - Enhanced GPU detection (CUDA, ROCm, DirectML, MPS)
  - Automatic venv creation
  - Better path detection
  - Improved error handling
  - Better documentation

### 3. Quick Action Scripts
All identical except rebranding:
- Karaoke, VocalsOnly, DrumsOnly, BassOnly: 52-56 lines each
- Only `@description` and `SCRIPT_NAME` changed

### 4. Helper Scripts
- Explode_Stems: 267 lines (identical)
- Setup_Toolbar: 149 lines (identical)
- Only rebranding changes

## Missing Features Analysis

**From Old → New**: NONE (all preserved)
**From New → Old**: Installation improvements only

## Breaking Changes

**NONE** - Full backward compatibility:
- ExtState keys unchanged ("Stemperator")
- File paths unchanged (.stemperator)
- Python detection unchanged
- Audio processing unchanged

## Repository Structure

**Old**: Plugin code in root + scripts/reaper/
**New**: Plugin moved to legacy/ + scripts/reaper/ focus

## Recommendation

✅ **UPGRADE SAFE AND RECOMMENDED**

Reasons:
- No features lost
- Installation improved
- Cleaner structure
- Consistent branding
- Fully backward compatible

## User Impact

**Will notice:**
- "STEMperator" branding instead of "Stemperator"
- Better installation script

**Won't notice:**
- Same functionality
- Same UI
- Settings preserved
