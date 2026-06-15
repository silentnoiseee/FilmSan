@echo off
REM Uploads ONE clip to Bunny so you can confirm it plays before doing all of them.
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "%~dp0bunny_upload.ps1" -TestOne
