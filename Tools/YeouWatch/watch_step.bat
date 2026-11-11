@echo off
rem ============================================================================
rem  YeouWatch 1.1.0 - one watcher step, called every 5 s by yeou_watch.bat
rem  Copyright (c) 2026 2p2poo67-arch. All rights reserved.
rem  Licensed under the YeouWatch License 1.0 - see LICENSE.txt. Keep this notice.
rem ============================================================================
rem  Request files (Saved\)        Result files (Saved\)
rem   build_request.txt         -> build_status.txt, build_game_log.txt, build_editor_log.txt
rem   py_request.txt            -> py_status.txt, py_log.txt        (line 1 = script in Content\Python)
rem   shot_request.txt          -> shot_status.txt, AutoShots\<time>\*.png + contact_sheet.jpg
rem   pkg_request.txt           -> pkg_status.txt, logs, Release\<Project>_*.zip
rem   (switch) auto_close_editor.txt = politely close Unreal Editor when a request waits
rem   (switch) copy_after_pkg.txt    = copy the new release zip to COPY_DEST once
rem  Queue: put requests in Saved\YeouQueue\ as NNNN_build.txt, NNNN_py.txt, NNNN_shot.txt, NNNN_shotbuild.txt
rem  or NNNN_pkg.txt (file content = the request's first line). They run one at a time in name order.
rem  Every finished request also writes Saved\YeouWatch\last_<kind>.json (status, time, short error list),
rem  appends Saved\YeouWatch\history.jsonl and refreshes Saved\YeouWatch\report.html.
rem  Never edit this file while a step is running: cmd continues by byte offset.
cd /d "%PROJECT_DIR%"
if not exist "%PROJECT_DIR%\Saved\YeouWatch" mkdir "%PROJECT_DIR%\Saved\YeouWatch"
> "%PROJECT_DIR%\Saved\watch_alive.txt" echo YeouWatch 1.1.0 step %date% %time%
call :queue
if exist "%PROJECT_DIR%\Saved\auto_close_editor.txt" call :autoclose
if exist "%PROJECT_DIR%\Saved\build_request.txt" call :build
if exist "%PROJECT_DIR%\Saved\py_request.txt" call :py
if exist "%PROJECT_DIR%\Saved\shot_request.txt" call :shot
if exist "%PROJECT_DIR%\Saved\pkg_request.txt" call :pkg
exit /b 0

:queue
rem promote the first queued request when no request is waiting
if exist "%PROJECT_DIR%\Saved\build_request.txt" exit /b 0
if exist "%PROJECT_DIR%\Saved\py_request.txt" exit /b 0
if exist "%PROJECT_DIR%\Saved\shot_request.txt" exit /b 0
if exist "%PROJECT_DIR%\Saved\pkg_request.txt" exit /b 0
if not exist "%PROJECT_DIR%\Saved\YeouQueue\*.txt" exit /b 0
set "Q_FILE="
for /f "delims=" %%Q in ('dir /b /on /a-d "%PROJECT_DIR%\Saved\YeouQueue\*.txt" 2^>nul') do if not defined Q_FILE set "Q_FILE=%%Q"
if not defined Q_FILE exit /b 0
set "Q_KIND="
echo %Q_FILE%| find /I "_build." >nul && set "Q_KIND=build"
echo %Q_FILE%| find /I "_py." >nul && set "Q_KIND=py"
echo %Q_FILE%| find /I "_pkg." >nul && set "Q_KIND=pkg"
echo %Q_FILE%| find /I "_shot." >nul && set "Q_KIND=shot"
echo %Q_FILE%| find /I "_shotbuild." >nul && set "Q_KIND=shotbuild"
if not defined Q_KIND goto queue_bad
if /I "%Q_KIND%"=="shotbuild" goto queue_shotbuild
move /y "%PROJECT_DIR%\Saved\YeouQueue\%Q_FILE%" "%PROJECT_DIR%\Saved\%Q_KIND%_request.txt" >nul
echo [%date% %time%] Queue: %Q_FILE%
exit /b 0
:queue_shotbuild
> "%PROJECT_DIR%\Saved\shot_build.txt" echo build first
move /y "%PROJECT_DIR%\Saved\YeouQueue\%Q_FILE%" "%PROJECT_DIR%\Saved\shot_request.txt" >nul
echo [%date% %time%] Queue: %Q_FILE%
exit /b 0
:queue_bad
if not exist "%PROJECT_DIR%\Saved\YeouQueue\rejected" mkdir "%PROJECT_DIR%\Saved\YeouQueue\rejected"
move /y "%PROJECT_DIR%\Saved\YeouQueue\%Q_FILE%" "%PROJECT_DIR%\Saved\YeouQueue\rejected\" >nul
echo [%date% %time%] Queue: unknown request name %Q_FILE% - moved to YeouQueue\rejected
exit /b 0

:queue_skip
rem a failed build makes the queued requests behind it meaningless: park them in YeouQueue\skipped
if not exist "%PROJECT_DIR%\Saved\YeouQueue\*.txt" exit /b 0
if not exist "%PROJECT_DIR%\Saved\YeouQueue\skipped" mkdir "%PROJECT_DIR%\Saved\YeouQueue\skipped"
move /y "%PROJECT_DIR%\Saved\YeouQueue\*.txt" "%PROJECT_DIR%\Saved\YeouQueue\skipped\" >nul
echo [%date% %time%] Queue: build failed - waiting requests moved to YeouQueue\skipped
exit /b 0

:mark
rem %1 = kind. Remembers when the request started.
powershell -NoProfile -ExecutionPolicy Bypass -File "%PROJECT_DIR%\Tools\YeouWatch\write_result.ps1" -Proj "%PROJECT_DIR%" -Kind %1 -Mark >nul 2>&1
exit /b 0

:result
rem %1 = kind, %2 = status, %3 = detail, %4 %5 = logs to digest. Writes last_<kind>.json + history, refreshes report.html.
powershell -NoProfile -ExecutionPolicy Bypass -File "%PROJECT_DIR%\Tools\YeouWatch\write_result.ps1" -Proj "%PROJECT_DIR%" -Kind %1 -Status %2 -Detail "%~3" -Log "%~4" -Log2 "%~5" > "%PROJECT_DIR%\Saved\YeouWatch\result_log.txt" 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -File "%PROJECT_DIR%\Tools\YeouWatch\make_report.ps1" -Proj "%PROJECT_DIR%" > "%PROJECT_DIR%\Saved\YeouWatch\report_log.txt" 2>&1
cd /d "%PROJECT_DIR%"
exit /b 0

:editor_open
rem sets errorlevel 0 when Unreal Editor is running
tasklist /FO CSV /NH /FI "IMAGENAME eq UnrealEditor.exe" 2>nul | find /I "UnrealEditor.exe" >nul
exit /b %errorlevel%

:autoclose
set "AC_REQ="
if exist "%PROJECT_DIR%\Saved\build_request.txt" set "AC_REQ=1"
if exist "%PROJECT_DIR%\Saved\py_request.txt" set "AC_REQ=1"
if exist "%PROJECT_DIR%\Saved\shot_request.txt" set "AC_REQ=1"
if exist "%PROJECT_DIR%\Saved\pkg_request.txt" set "AC_REQ=1"
if not defined AC_REQ exit /b 0
call :editor_open
if errorlevel 1 exit /b 0
rem polite close - no /F. With unsaved changes the editor asks to save and waits for you.
echo [%date% %time%] Closing Unreal Editor for a waiting request - auto_close_editor.txt is on.
taskkill /IM UnrealEditor.exe >nul 2>&1
set /a AC_N=0
:autoclose_wait
timeout /t 2 /nobreak >nul
call :editor_open
if errorlevel 1 goto autoclose_done
set /a AC_N+=1
if %AC_N% LSS 15 goto autoclose_wait
echo [%date% %time%] Editor still open - maybe a save dialog. Waiting for you.
exit /b 0
:autoclose_done
timeout /t 3 /nobreak >nul
echo [%date% %time%] Editor closed.
exit /b 0

rem ---------------------------------------------------------------- build
:build
del /q "%PROJECT_DIR%\Saved\build_request.txt"
title YeouWatch - building
echo [%date% %time%] Build requested.
> "%PROJECT_DIR%\Saved\build_status.txt" echo RUNNING %date% %time%
call :mark build
call "%BUILD_BAT%" %GAME_TARGET% Win64 Development -Project="%PROJECT_FILE%" -WaitMutex > "%PROJECT_DIR%\Saved\build_game_log.txt" 2>&1
set "RC=%errorlevel%"
cd /d "%PROJECT_DIR%"
if not "%RC%"=="0" goto build_game_failed
call "%BUILD_BAT%" %EDITOR_TARGET% Win64 Development -Project="%PROJECT_FILE%" -WaitMutex > "%PROJECT_DIR%\Saved\build_editor_log.txt" 2>&1
set "RC=%errorlevel%"
cd /d "%PROJECT_DIR%"
if not "%RC%"=="0" goto build_editor_failed
> "%PROJECT_DIR%\Saved\build_status.txt" echo SUCCESS %date% %time%
echo [%date% %time%] SUCCESS - game and editor targets built.
call :result build SUCCESS "game+editor" "%PROJECT_DIR%\Saved\build_game_log.txt" "%PROJECT_DIR%\Saved\build_editor_log.txt"
title YeouWatch - waiting
exit /b 0
:build_game_failed
> "%PROJECT_DIR%\Saved\build_status.txt" echo FAILED game %date% %time%
echo [%date% %time%] FAILED game target. See Saved\build_game_log.txt
call :result build FAILED "game target" "%PROJECT_DIR%\Saved\build_game_log.txt"
call :queue_skip
title YeouWatch - waiting
exit /b 0
:build_editor_failed
> "%PROJECT_DIR%\Saved\build_status.txt" echo FAILED editor %date% %time%
echo [%date% %time%] FAILED editor target - close the editor if it is open. See Saved\build_editor_log.txt
call :result build FAILED "editor target - close the editor if it is open" "%PROJECT_DIR%\Saved\build_editor_log.txt"
call :queue_skip
title YeouWatch - waiting
exit /b 0

rem ---------------------------------------------------------------- python
:py
call :editor_open
if not errorlevel 1 goto py_editor_open
set "PY_SCRIPT="
set /p PY_SCRIPT=<"%PROJECT_DIR%\Saved\py_request.txt"
del /q "%PROJECT_DIR%\Saved\py_request.txt"
title YeouWatch - python
echo [%date% %time%] Python %PY_SCRIPT%
> "%PROJECT_DIR%\Saved\py_status.txt" echo RUNNING %PY_SCRIPT% %date% %time%
call :mark py
for %%D in ("%UE_EXE%") do set "UE_CMD=%%~dpDUnrealEditor-Cmd.exe"
"%UE_CMD%" "%PROJECT_FILE%" -run=pythonscript -script="%PROJECT_DIR%\Content\Python\%PY_SCRIPT%" -unattended -nosplash -nullrhi -stdout -FullStdOutLogOutput > "%PROJECT_DIR%\Saved\py_log.txt" 2>&1
set "RC=%errorlevel%"
cd /d "%PROJECT_DIR%"
rem the exit code can be 1 from unrelated engine errors - trust the script result line instead
findstr /C:"Python script executed successfully" "%PROJECT_DIR%\Saved\py_log.txt" >nul
if errorlevel 1 goto py_failed
> "%PROJECT_DIR%\Saved\py_status.txt" echo DONE %PY_SCRIPT% %date% %time%
call :result py DONE "%PY_SCRIPT%"
title YeouWatch - waiting
exit /b 0
:py_failed
> "%PROJECT_DIR%\Saved\py_status.txt" echo FAILED rc=%RC% %PY_SCRIPT% - see Saved\py_log.txt %date% %time%
call :result py FAILED "%PY_SCRIPT%" "%PROJECT_DIR%\Saved\py_log.txt"
title YeouWatch - waiting
exit /b 0
:py_editor_open
> "%PROJECT_DIR%\Saved\py_status.txt" echo WAITING editor open - runs when Unreal Editor is closed %date% %time%
exit /b 0

rem ---------------------------------------------------------------- screenshots
:shot
call :editor_open
if not errorlevel 1 goto shot_editor_open
set "SHOT_ARGS="
set /p SHOT_ARGS=<"%PROJECT_DIR%\Saved\shot_request.txt"
del /q "%PROJECT_DIR%\Saved\shot_request.txt"
rem first run of a C++ project: no editor module yet, so build before shooting instead of letting the engine ask
if exist "%PROJECT_DIR%\Source" if not exist "%PROJECT_DIR%\Binaries\Win64\UnrealEditor-%PROJECT_NAME%.dll" > "%PROJECT_DIR%\Saved\shot_build.txt" echo first build
rem Saved\shot_build.txt = build first and shoot only if the build passed
if not exist "%PROJECT_DIR%\Saved\shot_build.txt" goto shot_go
del /q "%PROJECT_DIR%\Saved\shot_build.txt"
call :build
findstr /B "SUCCESS" "%PROJECT_DIR%\Saved\build_status.txt" >nul
if errorlevel 1 goto shot_build_failed
:shot_go
title YeouWatch - screenshots
echo [%date% %time%] Screenshots requested. A game window opens and closes by itself.
> "%PROJECT_DIR%\Saved\shot_status.txt" echo LAUNCHING %date% %time%
call :mark shot
start "YeouAutoShot" /wait "%UE_EXE%" "%PROJECT_FILE%" -game -windowed %SHOT_RES% -nosplash -unattended -NoScreenMessages -log=AutoShot.log -YeouAutoShot %SHOT_BASE_ARGS% %SHOT_ARGS%
cd /d "%PROJECT_DIR%"
copy /y "%PROJECT_DIR%\Saved\Logs\AutoShot.log" "%PROJECT_DIR%\Saved\autoshot_log.txt" >nul 2>&1
findstr /B "DONE" "%PROJECT_DIR%\Saved\shot_status.txt" >nul
if errorlevel 1 goto shot_not_done
rem one small contact sheet instead of many full-size PNGs - this is what saves tokens
powershell -NoProfile -ExecutionPolicy Bypass -File "%PROJECT_DIR%\Tools\YeouWatch\make_contact_sheet.ps1" -Proj "%PROJECT_DIR%" > "%PROJECT_DIR%\Saved\contact_sheet_log.txt" 2>&1
cd /d "%PROJECT_DIR%"
rem Saved\YeouWatch\baseline.txt (first line = a run folder) = compare this run with it and mark changed shots
if not exist "%PROJECT_DIR%\Saved\YeouWatch\baseline.txt" goto shot_result
set "SHOT_BASE="
set /p SHOT_BASE=<"%PROJECT_DIR%\Saved\YeouWatch\baseline.txt"
set "SHOT_NEW="
set /p SHOT_NEW=<"%PROJECT_DIR%\Saved\contact_sheet.txt"
for %%N in ("%SHOT_NEW%") do set "SHOT_NEW=%%~dpN"
if "%SHOT_NEW:~-1%"=="\" set "SHOT_NEW=%SHOT_NEW:~0,-1%"
if exist "%SHOT_BASE%" powershell -NoProfile -ExecutionPolicy Bypass -File "%PROJECT_DIR%\Tools\YeouWatch\compare_shots.ps1" -A "%SHOT_BASE%" -B "%SHOT_NEW%" > "%PROJECT_DIR%\Saved\compare_log.txt" 2>&1
cd /d "%PROJECT_DIR%"
:shot_result
call :result shot DONE ""
echo [%date% %time%] Screenshots DONE.
title YeouWatch - waiting
exit /b 0
:shot_not_done
findstr /B "FAILED" "%PROJECT_DIR%\Saved\shot_status.txt" >nul
if not errorlevel 1 goto shot_end
> "%PROJECT_DIR%\Saved\shot_status.txt" echo FAILED game exited early - crash, closed, or the YeouAutoShot plugin is not enabled. See Saved\autoshot_log.txt %date% %time%
:shot_end
call :result shot FAILED "see Saved\shot_status.txt" "%PROJECT_DIR%\Saved\autoshot_log.txt"
echo [%date% %time%] Screenshots FAILED. See Saved\shot_status.txt
title YeouWatch - waiting
exit /b 0
:shot_build_failed
> "%PROJECT_DIR%\Saved\shot_status.txt" echo FAILED build failed before shots - see Saved\build_status.txt %date% %time%
call :result shot FAILED "build failed before shots"
title YeouWatch - waiting
exit /b 0
:shot_editor_open
rem the request is kept: shots start by themselves once the editor is closed
> "%PROJECT_DIR%\Saved\shot_status.txt" echo WAITING editor open - shots start when Unreal Editor is closed %date% %time%
exit /b 0

rem ---------------------------------------------------------------- packaging
rem pkg_request.txt line 1: full = Development package + test run, test = test run only,
rem ship = Shipping package (encrypted if your project has Config\DefaultCrypto.ini) + test + zip, shiptest = test + zip, zip = zip only
:pkg
call :editor_open
if not errorlevel 1 goto pkg_editor_open
set "PKG_MODE="
set /p PKG_MODE=<"%PROJECT_DIR%\Saved\pkg_request.txt"
del /q "%PROJECT_DIR%\Saved\pkg_request.txt"
call :mark pkg
set "PKG_DIR=%PROJECT_DIR%\Saved\Package"
set "PKG_GAME=%PKG_DIR%\Windows\%PROJECT_NAME%"
set "SHIP_DIR=%PROJECT_DIR%\Saved\PackageShip"
set "SHIP_PROJ=%SHIP_DIR%\Windows\%PROJECT_NAME%"
set "RUNUAT=%UE_DIR%\Engine\Build\BatchFiles\RunUAT.bat"
if /I "%PKG_MODE%"=="test" goto pkg_test
if /I "%PKG_MODE%"=="ship" goto pkg_ship
if /I "%PKG_MODE%"=="shiptest" goto pkg_ship_test
if /I "%PKG_MODE%"=="zip" goto pkg_ship_zip
title YeouWatch - packaging
echo [%date% %time%] Development package requested. The first one can take an hour or more.
> "%PROJECT_DIR%\Saved\pkg_status.txt" echo RUNNING package %date% %time%
call "%RUNUAT%" BuildCookRun -project="%PROJECT_FILE%" -noP4 -platform=Win64 -clientconfig=Development -build -cook -stage -pak -archive -archivedirectory="%PKG_DIR%" -unattended -utf8output > "%PROJECT_DIR%\Saved\pkg_log.txt" 2>&1
set "RC=%errorlevel%"
cd /d "%PROJECT_DIR%"
if not "%RC%"=="0" goto pkg_failed
for %%F in (%EXTRA_COPY_DIRS%) do if exist "%PROJECT_DIR%\%%~F" robocopy "%PROJECT_DIR%\%%~F" "%PKG_GAME%\%%~F" /E /NFL /NDL /NJH /NJS /NP >nul
> "%PROJECT_DIR%\Saved\pkg_status.txt" echo PACKAGED testing %date% %time%
:pkg_test
set "PKG_EXENAME=%PROJECT_NAME%.exe"
set "PKG_EXE=%PKG_GAME%\Binaries\Win64\%PKG_EXENAME%"
set "PKG_E2E=%PKG_GAME%\Saved\e2e_status.txt"
if not exist "%PKG_EXE%" goto pkg_no_exe
if exist "%PKG_E2E%" del /q "%PKG_E2E%"
title YeouWatch - testing package
> "%PROJECT_DIR%\Saved\pkg_status.txt" echo TESTING %date% %time%
start "YeouPkgTest" "%PKG_EXE%" -windowed %SHOT_RES% -nosplash -log=PkgTest.log %TEST_ARGS%
call :pkg_wait_game
copy /y "%PKG_GAME%\Saved\Logs\PkgTest.log" "%PROJECT_DIR%\Saved\pkg_test_log.txt" >nul 2>&1
if "%PKG_KILLED%"=="1" goto pkg_timeout
> "%PROJECT_DIR%\Saved\pkg_status.txt" echo DONE e2e=%PKG_RESULT% %date% %time%
echo [%date% %time%] Package test finished: %PKG_RESULT%
call :result pkg DONE "%PKG_MODE% test=%PKG_RESULT%" "%PROJECT_DIR%\Saved\pkg_log.txt"
title YeouWatch - waiting
exit /b 0

:pkg_ship
title YeouWatch - release package
echo [%date% %time%] Shipping package requested.
> "%PROJECT_DIR%\Saved\pkg_status.txt" echo RUNNING ship package %date% %time%
if exist "%SHIP_DIR%" rmdir /s /q "%SHIP_DIR%"
call "%RUNUAT%" BuildCookRun -project="%PROJECT_FILE%" -noP4 -platform=Win64 -clientconfig=Shipping -build -cook -stage -pak -iostore -compressed -prereqs -nodebuginfo -archive -archivedirectory="%SHIP_DIR%" -unattended -utf8output > "%PROJECT_DIR%\Saved\pkg_ship_log.txt" 2>&1
set "RC=%errorlevel%"
cd /d "%PROJECT_DIR%"
if not "%RC%"=="0" goto pkg_ship_failed
for %%F in (%EXTRA_COPY_DIRS%) do if exist "%PROJECT_DIR%\%%~F" robocopy "%PROJECT_DIR%\%%~F" "%SHIP_PROJ%\%%~F" /E /NFL /NDL /NJH /NJS /NP >nul
> "%PROJECT_DIR%\Saved\pkg_status.txt" echo PACKAGED ship testing %date% %time%
:pkg_ship_test
set "PKG_EXENAME=%PROJECT_NAME%-Win64-Shipping.exe"
set "PKG_EXE=%SHIP_PROJ%\Binaries\Win64\%PKG_EXENAME%"
rem a Shipping game writes Saved\ under %LOCALAPPDATA%\<Project>
set "PKG_E2E=%LOCALAPPDATA%\%PROJECT_NAME%\Saved\e2e_status.txt"
if not exist "%PKG_EXE%" goto pkg_no_exe
if exist "%PKG_E2E%" del /q "%PKG_E2E%"
title YeouWatch - testing release package
> "%PROJECT_DIR%\Saved\pkg_status.txt" echo TESTING ship %date% %time%
start "YeouShipTest" "%PKG_EXE%" -windowed %SHOT_RES% -nosplash %TEST_ARGS%
call :pkg_wait_game
rem the test run must not leave a Saved folder inside the package
if exist "%SHIP_PROJ%\Saved" rmdir /s /q "%SHIP_PROJ%\Saved"
if "%PKG_KILLED%"=="1" goto pkg_timeout
rem with no TEST_ARGS there is no game-side test: a clean exit counts as pass
if not defined TEST_ARGS goto pkg_ship_zip
if /I not "%PKG_RESULT%"=="PASS" goto pkg_ship_testfail
:pkg_ship_zip
title YeouWatch - zipping
> "%PROJECT_DIR%\Saved\pkg_status.txt" echo ZIPPING ship %date% %time%
powershell -NoProfile -ExecutionPolicy Bypass -File "%PROJECT_DIR%\Tools\YeouWatch\make_release_zip.ps1" -Proj "%PROJECT_DIR%" -Name "%PROJECT_NAME%" > "%PROJECT_DIR%\Saved\pkg_zip_log.txt" 2>&1
cd /d "%PROJECT_DIR%"
findstr /B "DONE" "%PROJECT_DIR%\Saved\pkg_zip_status.txt" >nul 2>&1
if errorlevel 1 goto pkg_ship_zipfail
> "%PROJECT_DIR%\Saved\pkg_status.txt" echo DONE ship e2e=%PKG_RESULT% zip=ok %date% %time%
if not exist "%PROJECT_DIR%\Saved\copy_after_pkg.txt" goto pkg_ship_done
del /q "%PROJECT_DIR%\Saved\copy_after_pkg.txt"
if not defined COPY_DEST goto pkg_ship_done
title YeouWatch - copying release
powershell -NoProfile -ExecutionPolicy Bypass -File "%PROJECT_DIR%\Tools\YeouWatch\copy_release.ps1" -Proj "%PROJECT_DIR%" -Dest "%COPY_DEST%" > "%PROJECT_DIR%\Saved\copy_log.txt" 2>&1
cd /d "%PROJECT_DIR%"
:pkg_ship_done
echo [%date% %time%] Release package + zip DONE. See the Release folder.
call :result pkg DONE "%PKG_MODE% test=%PKG_RESULT% zip=ok"
title YeouWatch - waiting
exit /b 0

:pkg_wait_game
rem waits for the test game; kills it after TEST_TIMEOUT_MIN, or 30 s after it reports PASS/FAIL
set /a PKG_N=0
set /a PKG_MAX=%TEST_TIMEOUT_MIN%*6
rem no TEST_ARGS = smoke test: the game only has to stay alive for 60 s
set "PKG_SMOKE="
if not defined TEST_ARGS set "PKG_SMOKE=1"
if defined PKG_SMOKE set /a PKG_MAX=6
set /a PKG_DONE_N=0
set "PKG_KILLED="
set "PKG_RESULT=none"
:pkg_wait_loop
timeout /t 10 /nobreak >nul
rem /FO CSV: the table view cuts long exe names at 25 characters
tasklist /FO CSV /NH /FI "IMAGENAME eq %PKG_EXENAME%" 2>nul | find /I "%PKG_EXENAME%" >nul
if errorlevel 1 goto pkg_wait_end
findstr /B "PASS FAIL" "%PKG_E2E%" >nul 2>&1
if not errorlevel 1 set /a PKG_DONE_N+=1
if %PKG_DONE_N% GEQ 3 goto pkg_wait_linger
set /a PKG_N+=1
if %PKG_N% LSS %PKG_MAX% goto pkg_wait_loop
taskkill /F /IM %PKG_EXENAME% >nul 2>&1
if defined PKG_SMOKE set "PKG_RESULT=smoke_ok"
if not defined PKG_SMOKE set "PKG_KILLED=1"
goto pkg_wait_end
:pkg_wait_linger
taskkill /F /IM %PKG_EXENAME% >nul 2>&1
:pkg_wait_end
if defined PKG_SMOKE if "%PKG_RESULT%"=="none" set "PKG_RESULT=exited_early"
cd /d "%PROJECT_DIR%"
rem first word only - the full line may hold a "|" that cmd would read as a pipe
if exist "%PKG_E2E%" for /f "usebackq tokens=1" %%A in ("%PKG_E2E%") do set "PKG_RESULT=%%A"
if exist "%PKG_E2E%" copy /y "%PKG_E2E%" "%PROJECT_DIR%\Saved\pkg_e2e_status.txt" >nul 2>&1
exit /b 0

:pkg_timeout
> "%PROJECT_DIR%\Saved\pkg_status.txt" echo FAILED test timeout %TEST_TIMEOUT_MIN%min e2e=%PKG_RESULT% %date% %time%
call :result pkg FAILED "test timeout"
title YeouWatch - waiting
exit /b 0
:pkg_no_exe
> "%PROJECT_DIR%\Saved\pkg_status.txt" echo FAILED no exe at %PKG_EXE% %date% %time%
call :result pkg FAILED "no packaged exe - run full or ship first"
title YeouWatch - waiting
exit /b 0
:pkg_failed
> "%PROJECT_DIR%\Saved\pkg_status.txt" echo FAILED package rc=%RC% - see Saved\pkg_log.txt %date% %time%
call :result pkg FAILED "package rc=%RC%" "%PROJECT_DIR%\Saved\pkg_log.txt"
title YeouWatch - waiting
exit /b 0
:pkg_ship_failed
> "%PROJECT_DIR%\Saved\pkg_status.txt" echo FAILED ship package rc=%RC% - see Saved\pkg_ship_log.txt %date% %time%
call :result pkg FAILED "ship package rc=%RC%" "%PROJECT_DIR%\Saved\pkg_ship_log.txt"
title YeouWatch - waiting
exit /b 0
:pkg_ship_testfail
> "%PROJECT_DIR%\Saved\pkg_status.txt" echo FAILED ship test e2e=%PKG_RESULT% %date% %time%
call :result pkg FAILED "ship test %PKG_RESULT%"
title YeouWatch - waiting
exit /b 0
:pkg_ship_zipfail
> "%PROJECT_DIR%\Saved\pkg_status.txt" echo FAILED ship zip - see Saved\pkg_zip_status.txt %date% %time%
call :result pkg FAILED "zip - see Saved\pkg_zip_status.txt"
title YeouWatch - waiting
exit /b 0
:pkg_editor_open
> "%PROJECT_DIR%\Saved\pkg_status.txt" echo WAITING editor open - packaging starts when Unreal Editor is closed %date% %time%
exit /b 0
