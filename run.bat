@echo off
setlocal

echo.
echo ==========================================
echo Zhidu (Smart Reader) - Quick Run
echo ==========================================
echo.

echo [1/1] Running application in development mode...
echo ------------------------------------------

REM Use flutter run without specifying release mode to avoid build artifacts that may be blocked by Windows security policies
flutter run -d windows

if errorlevel 1 (
    echo.
    echo [ERROR] Failed to run application
    pause
    exit /b 1
)

echo.
echo Application started successfully!
pause
exit /b 0