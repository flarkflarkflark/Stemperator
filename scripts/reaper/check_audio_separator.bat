@echo off
"%~1" -c "from audio_separator.separator import Separator; print('OK')" 2>nul
