@echo off
REM ============================================================
REM  FilmFeed - one-click git setup
REM  Double-click this file to initialize the repo cleanly.
REM ============================================================
cd /d "%~dp0"

echo.
echo Removing any broken .git folder...
if exist ".git" rmdir /s /q ".git"

echo Checking that git is installed...
where git >nul 2>nul
if errorlevel 1 (
  echo.
  echo  [!] Git is not installed. Get it from https://git-scm.com/download/win
  echo      then run this file again.
  echo.
  pause
  exit /b 1
)

echo Initializing repository...
git init
git branch -M main
git remote remove origin >nul 2>nul
git remote add origin https://github.com/silentnoiseee/FilmSan.git
git add .
git -c user.name="Chukwuka Daniel Nwobi" -c user.email="chukanwobi29@gmail.com" commit -m "Initial commit: FilmFeed app"

echo.
echo Pushing to GitHub (a sign-in window may appear the first time)...
git push -u origin main
if errorlevel 1 (
  echo.
  echo  [!] Push was rejected -- the FilmSan repo probably already has files
  echo      (e.g. a README). Merge them in, then push, by running:
  echo.
  echo        git pull origin main --rebase --allow-unrelated-histories
  echo        git push -u origin main
  echo.
)

echo.
echo  Committed files (videos, .git, and secrets excluded by .gitignore):
git --no-pager ls-files
echo.
pause
