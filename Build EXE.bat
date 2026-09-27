@echo off
title Pigeon Bakery Tycoon - build exe
cd /d "%~dp0"
set "GODOT=D:\Programes\Godot_v4.4.1-stable_win64.exe\Godot_v4.4.1-stable_win64_console.exe"
if not exist "%GODOT%" (
    echo Could not find Godot at %GODOT% -- edit this .bat to point at yours.
    pause
    exit /b 1
)
if not exist build mkdir build
"%GODOT%" --headless --import --path "%~dp0"
"%GODOT%" --headless --path "%~dp0" --export-release "Windows Desktop" "build/Pigeon Bakery Tycoon.exe"
if exist "build\Pigeon Bakery Tycoon.exe" (echo Done: build\Pigeon Bakery Tycoon.exe) else (echo Export failed.)
pause
