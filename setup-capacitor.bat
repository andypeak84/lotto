@echo off
REM Installs Capacitor and generates the native iOS + Android projects.
cd /d "%~dp0capacitor-app"
call npm install
call npx cap add android
call npx cap add ios
call npx cap sync
echo.
echo  Done. Open capacitor-app\android in Android Studio to build the APK.
echo  (iOS needs a Mac with Xcode - the ios\ folder is ready for one.)
echo.
pause
