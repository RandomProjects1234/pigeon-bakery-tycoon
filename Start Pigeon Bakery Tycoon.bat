@echo off
cd /d "%~dp0"
if exist "build\Pigeon Bakery Tycoon.exe" (
    start "" "build\Pigeon Bakery Tycoon.exe"
) else (
    start "" "D:\Programes\Godot_v4.4.1-stable_win64.exe\Godot_v4.4.1-stable_win64.exe" --path "%~dp0"
)
