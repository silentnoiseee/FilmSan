@echo off
REM Drag a FOLDER of films onto this .bat to chop them all into one output folder.
REM Or double-click and paste the folder path when asked.
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "%~dp0chop_folder.ps1" "%~1"
