@echo off
chcp 65001 >nul
echo ==========================================
echo 智读 (Zhidu) - 快速运行
echo ==========================================
echo.

echo [1/2] 构建 Windows 应用...
echo ------------------------------------------
flutter build windows --debug
if errorlevel 1 (
    echo.
    echo [错误] 构建失败
    pause
    exit /b 1
)

echo.
echo [2/2] 运行应用...
echo ------------------------------------------
start build\windows\x64\runner\Debug\zhidu.exe

echo.
echo 应用已启动！
timeout /t 3 >nul
exit /b 0