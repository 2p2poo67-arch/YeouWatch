@echo off
rem ============================================================================
rem  YeouWatch 1.1.0 - Unreal Engine <-> Claude file-request watcher
rem  Copyright (c) 2026 2p2poo67-arch. All rights reserved.
rem  Licensed under the YeouWatch License 1.0 - see LICENSE.txt.
rem  You must keep this notice in every copy. Commercial resale needs permission.
rem ============================================================================
rem  Put this file in your Unreal project folder (next to the .uproject),
rem  edit yeou_watch_config.bat once, then double-click this file and keep the window open.
rem  Every 5 seconds it calls Tools\YeouWatch\watch_step.bat, so the steps can be
rem  updated without restarting this window (only while the watcher is idle).
rem --- only one watcher per project: the window holds Saved\yeou_watch.lock open while it runs
if "%~1"=="__locked" goto run
if not exist "%~dp0Saved" mkdir "%~dp0Saved"
set "YW_RAN="
9>"%~dp0Saved\yeou_watch.lock" call :locked_start
if defined YW_RAN exit /b 0
echo.
echo YeouWatch is already running for this project in another window. Close that window first.
pause
exit /b 1
:locked_start
set "YW_RAN=1"
call "%~f0" __locked
exit /b 0

:run
setlocal
chcp 65001 >nul
set "PROJECT_DIR=%~dp0"
if "%PROJECT_DIR:~-1%"=="\" set "PROJECT_DIR=%PROJECT_DIR:~0,-1%"
call "%PROJECT_DIR%\yeou_watch_config.bat"
if not defined PROJECT_NAME goto no_project
set "PROJECT_FILE=%PROJECT_DIR%\%PROJECT_NAME%.uproject"
set "BUILD_BAT=%UE_DIR%\Engine\Build\BatchFiles\Build.bat"
set "UE_EXE=%UE_DIR%\Engine\Binaries\Win64\UnrealEditor.exe"
if not exist "%PROJECT_FILE%" goto no_project
if not exist "%UE_EXE%" goto no_engine
cd /d "%PROJECT_DIR%"
if not exist Saved mkdir Saved
> "%PROJECT_DIR%\Saved\watch_alive.txt" echo YeouWatch 1.1.0 started %date% %time%
rem a request that was running when the last watcher window was closed never finished: say so
for %%S in (build py shot pkg) do call :stale %%S
title YeouWatch - waiting
echo YeouWatch 1.1.0 - project %PROJECT_NAME%
echo Waiting for request files in Saved\. Close this window to stop.
echo Copyright (c) 2026 2p2poo67-arch - YeouWatch License 1.0, see LICENSE.txt

:loop
if exist "%PROJECT_DIR%\Tools\YeouWatch\watch_step.bat" call "%PROJECT_DIR%\Tools\YeouWatch\watch_step.bat"
cd /d "%PROJECT_DIR%"
timeout /t 5 /nobreak >nul
goto loop

:no_project
echo No .uproject found in %PROJECT_DIR% - put yeou_watch.bat next to your .uproject or set PROJECT_NAME in yeou_watch_config.bat.
pause
exit /b 1
:no_engine
echo Unreal Editor not found at %UE_EXE% - set UE_DIR in yeou_watch_config.bat.
pause
exit /b 1

:stale
if not exist "%PROJECT_DIR%\Saved\%1_status.txt" exit /b 0
findstr /B "RUNNING LAUNCHING TESTING ZIPPING PACKAGED" "%PROJECT_DIR%\Saved\%1_status.txt" >nul
if errorlevel 1 exit /b 0
> "%PROJECT_DIR%\Saved\%1_status.txt" echo FAILED interrupted - the watcher window was closed while this ran %date% %time%
echo Last %1 request was interrupted - marked FAILED.
exit /b 0
