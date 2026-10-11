@echo off
cd /d "%~dp0"
git add -A
git commit -m "Add Continue with Google sign-in"
git push
echo.
echo Pushed. Vercel will redeploy in about a minute.
pause
