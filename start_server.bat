@echo off
REM Serves the app locally so HLS streaming works. Then open the URL below.
cd /d "%~dp0"
echo.
echo  FilmFeed running at:  http://localhost:8000
echo  (open that in your browser; press Ctrl+C here to stop)
echo.
python -m http.server 8000
