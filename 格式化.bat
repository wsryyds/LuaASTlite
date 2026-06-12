@echo off
setlocal EnableExtensions
chcp 65001 >nul

if "%~1"=="" (
    echo Drag one or more Lua files onto this bat to format them.
    pause
    exit /b 1
)

echo [LuaAstlite Formatter]
echo [INFO] Script: "%~f0"

where lua >nul 2>nul
if errorlevel 1 (
    echo lua was not found in PATH.
    pause
    exit /b 1
)

set "ROOT=%~dp0"
set "FAILED=0"
echo [INFO] Project root: "%ROOT%"
echo.

:format_next
if "%~1"=="" goto done

echo [INFO] ------------------------------------------------------------
set "INPUT=%~f1"
set "OUTPUT=%~dp1格式化%~nx1"
echo [INFO] Input: "%INPUT%"
echo [INFO] Output: "%OUTPUT%"
if not exist "%INPUT%" (
    echo [ERROR] File not found: "%INPUT%"
    set "FAILED=1"
    shift
    goto format_next
)

if exist "%OUTPUT%" (
    echo [WARN] Output already exists and will be overwritten.
)

set "TMP=%TEMP%\LuaAstlite_format_%RANDOM%_%RANDOM%.tmp"
echo [INFO] Temp: "%TMP%"
echo [INFO] Running formatter...
echo [INFO] Command: lua "%ROOT%main.lua" --format "%INPUT%"
lua "%ROOT%main.lua" --format "%INPUT%" > "%TMP%"
if errorlevel 1 (
    echo [ERROR] Format failed: "%INPUT%"
    if exist "%TMP%" del "%TMP%" >nul 2>nul
    set "FAILED=1"
    shift
    goto format_next
)

echo [INFO] Formatter completed.
echo [INFO] Writing formatted file...
move /Y "%TMP%" "%OUTPUT%" >nul
if errorlevel 1 (
    echo [ERROR] Could not write: "%OUTPUT%"
    if exist "%TMP%" del "%TMP%" >nul 2>nul
    set "FAILED=1"
) else (
    echo [OK] Formatted: "%OUTPUT%"
    echo [INFO] Source kept unchanged: "%INPUT%"
)
echo.

shift
goto format_next

:done
if "%FAILED%"=="1" (
    echo [DONE] Completed with errors.
    pause
    exit /b 1
)

echo [DONE] All files formatted successfully.
pause
exit /b 0
