@echo off
REM ---------------------------------------------------------------
REM  Pushes this project to a GitHub repo.
REM
REM  BEFORE RUNNING: create an EMPTY repo at https://github.com/new
REM  (no README, no .gitignore, no licence - just the bare repo),
REM  then paste its URL when prompted below.
REM ---------------------------------------------------------------
cd /d "%~dp0"

echo.
echo  Example URL:  https://github.com/andypeak84/draw-room.git
echo.
set /p REPOURL="Paste your empty GitHub repo URL: "

if "%REPOURL%"=="" (
  echo No URL entered. Nothing done.
  pause
  exit /b 1
)

git init
git add .
git commit -m "Draw Room: honest UK Lotto and EuroMillions stats app (web + Capacitor)"
git branch -M main
git remote remove origin 2>nul
git remote add origin %REPOURL%
git push -u origin main

echo.
echo  Done. Next: go to https://vercel.com/new, import this repo,
echo  and set the Root Directory to:  web
echo.
pause
