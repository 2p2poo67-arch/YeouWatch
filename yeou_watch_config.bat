@echo off
rem ============================================================================
rem  YeouWatch 1.1.0 - settings (edit this file only)
rem  Copyright (c) 2026 2p2poo67-arch. Licensed under the YeouWatch License 1.0 - see LICENSE.txt.
rem ============================================================================

rem Unreal Engine install folder
set "UE_DIR=C:\Program Files\Epic Games\UE_5.8"

rem Project name = .uproject file name without extension. Empty = first .uproject in this folder.
set "PROJECT_NAME="
if not defined PROJECT_NAME for %%P in ("%PROJECT_DIR%\*.uproject") do if not defined PROJECT_NAME set "PROJECT_NAME=%%~nP"

rem Build targets (Source\<Name>.Target.cs and Source\<Name>Editor.Target.cs)
set "GAME_TARGET=%PROJECT_NAME%"
set "EDITOR_TARGET=%PROJECT_NAME%Editor"

rem Screenshot run: extra arguments always passed to the game. Your game code reads them,
rem takes the shots, writes Saved\shot_status.txt "DONE ..." and quits. Example: -MyAutoShot
set "SHOT_BASE_ARGS="
set "SHOT_RES=-ResX=1600 -ResY=900"

rem Package test run: arguments for the packaged game. Your game writes Saved\e2e_status.txt "PASS ..." or "FAIL ..." and quits.
rem Leave TEST_ARGS empty for a smoke test: the packaged game just has to stay alive for 60 s.
set "TEST_ARGS="
set "TEST_TIMEOUT_MIN=15"

rem Extra project folders copied next to the packaged game, space separated, each in quotes. Example: "SourceArt\UI"
set "EXTRA_COPY_DIRS="

rem Folder that receives each new release zip when Saved\copy_after_pkg.txt exists - a Google Drive or shared folder. Empty = off.
set "COPY_DEST="

rem Files added to every release zip (README, manual), space separated, each in quotes, relative to the project. Example: "docs\README.txt"
set "ZIP_EXTRA_FILES="
exit /b 0
