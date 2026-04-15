@echo off
chcp 65001 >nul
echo ==========================================
echo 智读 (Zhidu) - 测试并运行
echo ==========================================
echo.

echo [1/3] 运行所有测试...
echo ------------------------------------------
flutter test
if errorlevel 1 (
    echo.
    echo [错误] 测试失败，停止构建
    pause
    exit /b 1
)

echo.
echo [2/3] 构建 Windows 应用...
echo ------------------------------------------
flutter build windows --debug
if errorlevel 1 (
    echo.
    echo [错误] 构建失败
    pause
    exit /b 1
)

echo.
echo [3/3] 运行应用...
echo ------------------------------------------
start build\windows\x64\runner\Debug\zhidu.exe

echo.
echo 应用已启动！
timeout /t 3 >nul
exit /b 0