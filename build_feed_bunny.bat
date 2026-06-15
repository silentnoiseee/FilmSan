@echo off
REM Rebuilds videos.js to stream from Bunny. Run after uploading new clips.
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "%~dp0build_feed_bunny.ps1"
pause
