@echo off
REM Fetches film data from TMDB and writes films.json.
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "%~dp0ingest_films.ps1"
echo.
pause
