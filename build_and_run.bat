@echo off
echo Building and running application...
echo.
echo Step 1: Cleaning old build files...
flutter clean

echo.
echo Step 2: Getting dependencies...
flutter pub get

echo.
echo Step 3: Generating database code (only if needed)...
if not exist "lib\data\database\database.g.dart" (
    flutter pub run build_runner build --delete-conflicting-outputs
)

echo.
echo Step 4: Building Release version...
flutter build windows --release

echo.
echo Step 5: Running application...
start "" "build\windows\x64\runner\Release\zhidu.exe"

pause