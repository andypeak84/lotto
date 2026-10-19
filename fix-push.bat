@echo off
cd /d "%~dp0"
echo Cleaning up the half-finished merge...
git merge --abort >nul 2>&1
git rebase --abort >nul 2>&1
git fetch origin || goto :fail
echo Matching GitHub's latest version...
git reset --hard origin/main || goto :fail
echo Applying the results-sync update...
copy /y "_mine\web_index.html" "web\index.html" >nul || goto :fail
copy /y "_mine\web_index.html" "capacitor-app\www\index.html" >nul || goto :fail
copy /y "_mine\README.md" "README.md" >nul || goto :fail
git add web/index.html capacitor-app/www/index.html README.md
git commit -m "Prediction Test: official results sync and your-draw comparison card"
git push origin main || goto :fail
echo.
echo DONE - pushed. Vercel will redeploy in about a minute.
pause
exit /b 0
:fail
echo.
echo SOMETHING FAILED - copy the text above and send it to Claude.
pause
exit /b 1
