@echo off
:: Directory QC Script - Simple Batch Version
:: Works on all Windows versions

if "%~1"=="" goto :usage

set "BASE_DIR=%~1"
set "TEST_TYPE=%~2"
if "%TEST_TYPE%"=="" set "TEST_TYPE=OTHER"

:: Extract prefix (everything before first hyphen)
for /f "tokens=1 delims=-" %%a in ("%~n1") do set "PREFIX=%%a"

echo.
echo ============================================================
echo Directory QC Report - %BASE_DIR%
echo Test Type: %TEST_TYPE%
echo ============================================================

:: Check base directory
if not exist "%BASE_DIR%" (
    echo ERROR: Directory not found: %BASE_DIR%
    exit /b 1
)

:: Check required directories
echo.
echo Checking directories...
set ERRORS=0

call :checkdir "%BASE_DIR%\NVA" "NVA"
call :checkdir "%BASE_DIR%\NVA\NESSUS" "NVA\NESSUS"
call :checkdir "%BASE_DIR%\NVA\NMAP" "NVA\NMAP"
call :checkdir "%BASE_DIR%\NVA\QUALYS" "NVA\QUALYS"
call :checkdir "%BASE_DIR%\REPORTS" "REPORTS"
call :checkdir "%BASE_DIR%\REQUESTINFO" "REQUESTINFO"

:: Check files
echo.
echo Checking files...

:: Attack Surface Profile (all test types)
set "ASP=%BASE_DIR%\REQUESTINFO\%PREFIX%-Attack Surface Profile.xlsx"
if exist "%ASP%" (
    call :getsize "%ASP%"
    if !SIZE! GTR 25600 (
        echo [OK] Attack Surface Profile found - !SIZEKB! KB
    ) else (
        echo [FAIL] Attack Surface Profile too small - !SIZEKB! KB ^(needs ^> 25 KB^)
        set /a ERRORS+=1
    )
) else (
    echo [FAIL] Missing: %PREFIX%-Attack Surface Profile.xlsx
    set /a ERRORS+=1
)

:: SB-specific files
if /i "%TEST_TYPE%"=="SB" (
    :: Check NESSUS files
    dir /b "%BASE_DIR%\NVA\NESSUS\*.nessus" >nul 2>&1
    if errorlevel 1 (
        echo [FAIL] Missing: NESSUS files ^(*.nessus^)
        set /a ERRORS+=1
    ) else (
        echo [OK] NESSUS files found
    )
    
    :: Check NMAP files
    for %%T in (TCP UDP) do (
        for %%E in (gnmap nmap xml) do (
            if exist "%BASE_DIR%\NVA\NMAP\%PREFIX%_%%T.%%E" (
                echo [OK] %PREFIX%_%%T.%%E
            ) else (
                echo [FAIL] Missing: %PREFIX%_%%T.%%E
                set /a ERRORS+=1
            )
        )
    )
)

:: Summary
echo.
echo ============================================================
if %ERRORS%==0 (
    echo RESULT: PASSED - All checks completed successfully
    echo ============================================================
    exit /b 0
) else (
    echo RESULT: FAILED - %ERRORS% issue^(s^) found
    echo ============================================================
    exit /b 1
)

:checkdir
if exist "%~1\*" (
    echo [OK] %~2
) else (
    echo [FAIL] Missing: %~2
    set /a ERRORS+=1
)
goto :eof

:getsize
set SIZE=0
set SIZEKB=0
for %%A in ("%~1") do set SIZE=%%~zA
set /a SIZEKB=%SIZE%/1024
goto :eof

:usage
echo ERROR: No directory specified
echo.
echo Usage: %~nx0 BASE_DIRECTORY [TEST_TYPE]
echo.
echo Examples:
echo   %~nx0 ABC123-20240115 SB    - Full SB test validation
echo   %~nx0 ABC123-20240115        - Basic validation
echo.
echo Expected structure:
echo   BASE_DIRECTORY\
echo     NVA\
echo       NESSUS\
echo       NMAP\
echo       QUALYS\
echo     REPORTS\
echo     REQUESTINFO\
exit /b 1
