@echo off
REM Deploys the Draw Room website (the "web" subfolder) to Vercel.
REM First time only, run:  npx vercel login
cd /d "%~dp0web"
npx vercel deploy --prod --yes
pause
