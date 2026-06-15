@echo off
REM Uploads ALL clips to Bunny. Safe to re-run: it skips anything already uploaded.
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "%~dp0bunny_upload.ps1"
