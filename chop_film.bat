@echo off
REM Drag a film file onto this .bat to chop it into clips (skipping end credits).
REM Or double-click and paste the path when asked.
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "%~dp0chop_film.ps1" "%~1"
