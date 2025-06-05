@echo off
setlocal enabledelayedexpansion

:: Directory QC Script - Batch Version
:: Verifies required folder structure and files exist for QC automation

:: Color codes for output
:: Use color command: color [background][foreground]
:: We'll use escape sequences for better control

:: Check arguments
if "%~1"=="" (
    echo ERROR: No base directory specified
    echo.
    echo Usage: %~nx0 BASE_DIRECTORY [TEST_TYPE]
    echo Example: %~nx0 ABC123-20240115 SB
    echo          %~nx0 ABC123-20240115
    echo.
    echo TEST_TYPE: 'SB' for SB tests ^(with full file checks^)
    echo            Any other value or omitted for basic checks
    echo.
    echo Expected Directory Structure:
    echo XXXXXX-XXXXXXXX\
    echo ├── NVA\
    echo │   ├── NESSUS\
    echo │   ├── NMAP\
    echo │   └── QUALYS\
    echo ├── REPORTS\
    echo └── REQUESTINFO\
    exit /b 1
)

:: Set variables
set "BASE_DIR=%~1"
set "TEST_TYPE=%~2"
if "%TEST_TYPE%"=="" set "TEST_TYPE=OTHER"

:: Extract prefix from directory name (everything before first hyphen)
for /f "tokens=1 delims=-" %%a in ("%~n1") do set "PREFIX=%%a"

:: Initialize counters
set /a MISSING_DIRS=0
set /a MISSING_FILES=0
set /a FILE_ISSUES=0
set /a EXISTING_DIRS=0
set /a EXISTING_FILES=0

:: Clear result arrays
set "MISSING_DIR_LIST="
set "MISSING_FILE_LIST="
set "FILE_ISSUE_LIST="
set "EXISTING_DIR_LIST="
set "EXISTING_FILE_LIST="

:: Display header
echo.
echo ============================================================
echo Directory Structure ^& File QC Report
echo ============================================================
echo Base Directory: %BASE_DIR%
echo Test Type: %TEST_TYPE%
echo Prefix: %PREFIX%
echo ============================================================
echo.

:: Check if base directory exists
if not exist "%BASE_DIR%" (
    echo ERROR: Base directory does not exist: %BASE_DIR%
    exit /b 1
)

:: Check directory structure
echo DIRECTORY STRUCTURE:
echo ------------------------------

:: Check base directory
if exist "%BASE_DIR%\*" (
    set /a EXISTING_DIRS+=1
    set "EXISTING_DIR_LIST=!EXISTING_DIR_LIST!  [OK] %~nx1\n"
) else (
    set /a MISSING_DIRS+=1
    set "MISSING_DIR_LIST=!MISSING_DIR_LIST!  [X] %~nx1\n"
)

:: Check main directories
for %%D in (NVA REPORTS REQUESTINFO) do (
    if exist "%BASE_DIR%\%%D\*" (
        set /a EXISTING_DIRS+=1
        set "EXISTING_DIR_LIST=!EXISTING_DIR_LIST!  [OK] %%D\n"
    ) else (
        set /a MISSING_DIRS+=1
        set "MISSING_DIR_LIST=!MISSING_DIR_LIST!  [X] %%D\n"
    )
)

:: Check NVA subdirectories
for %%D in (NESSUS NMAP QUALYS) do (
    if exist "%BASE_DIR%\NVA\%%D\*" (
        set /a EXISTING_DIRS+=1
        set "EXISTING_DIR_LIST=!EXISTING_DIR_LIST!  [OK] NVA\%%D\n"
    ) else (
        set /a MISSING_DIRS+=1
        set "MISSING_DIR_LIST=!MISSING_DIR_LIST!  [X] NVA\%%D\n"
    )
)

:: Display directory results
if not "!EXISTING_DIR_LIST!"=="" (
    echo Existing Directories:
    echo !EXISTING_DIR_LIST!
)

if not "!MISSING_DIR_LIST!"=="" (
    echo Missing Directories:
    echo !MISSING_DIR_LIST!
)

echo.
echo FILE CHECKS:
echo ------------------------------

:: File checks based on test type
if /i "%TEST_TYPE%"=="SB" (
    :: Check for NESSUS files
    set "NESSUS_FOUND=0"
    for %%F in ("%BASE_DIR%\NVA\NESSUS\*.nessus") do (
        if exist "%%F" (
            set "NESSUS_FOUND=1"
            set /a EXISTING_FILES+=1
        )
    )
    if !NESSUS_FOUND!==1 (
        set "EXISTING_FILE_LIST=!EXISTING_FILE_LIST!  [OK] NVA\NESSUS\*.nessus ^(found^)\n"
    ) else (
        set /a MISSING_FILES+=1
        set "MISSING_FILE_LIST=!MISSING_FILE_LIST!  [X] NVA\NESSUS\*.nessus\n"
    )
    
    :: Check for NMAP files
    for %%T in (TCP UDP) do (
        for %%E in (gnmap nmap xml) do (
            if exist "%BASE_DIR%\NVA\NMAP\%PREFIX%_%%T.%%E" (
                set /a EXISTING_FILES+=1
                set "EXISTING_FILE_LIST=!EXISTING_FILE_LIST!  [OK] NVA\NMAP\%PREFIX%_%%T.%%E\n"
            ) else (
                set /a MISSING_FILES+=1
                set "MISSING_FILE_LIST=!MISSING_FILE_LIST!  [X] NVA\NMAP\%PREFIX%_%%T.%%E\n"
            )
        )
    )
)

:: Check Attack Surface Profile (for all test types)
set "ASP_FILE=%BASE_DIR%\REQUESTINFO\%PREFIX%-Attack Surface Profile.xlsx"
if exist "%ASP_FILE%" (
    :: Get file size
    for %%F in ("%ASP_FILE%") do set "FILESIZE=%%~zF"
    
    :: Check if file size > 25KB (25600 bytes)
    if !FILESIZE! GTR 25600 (
        set /a FILESIZEKB=!FILESIZE!/1024
        set /a EXISTING_FILES+=1
        set "EXISTING_FILE_LIST=!EXISTING_FILE_LIST!  [OK] REQUESTINFO\%PREFIX%-Attack Surface Profile.xlsx ^(!FILESIZEKB! KB^)\n"
    ) else (
        set /a FILESIZEKB=!FILESIZE!/1024
        set /a FILE_ISSUES+=1
        set "FILE_ISSUE_LIST=!FILE_ISSUE_LIST!  [!] REQUESTINFO\%PREFIX%-Attack Surface Profile.xlsx - File too small ^(!FILESIZEKB! KB, requires ^> 25 KB^)\n"
    )
) else (
    set /a MISSING_FILES+=1
    set "MISSING_FILE_LIST=!MISSING_FILE_LIST!  [X] REQUESTINFO\%PREFIX%-Attack Surface Profile.xlsx\n"
)

:: Display file results
if not "!EXISTING_FILE_LIST!"=="" (
    echo Existing Files:
    echo !EXISTING_FILE_LIST!
)

if not "!MISSING_FILE_LIST!"=="" (
    echo Missing Files:
    echo !MISSING_FILE_LIST!
)

if not "!FILE_ISSUE_LIST!"=="" (
    echo File Issues:
    echo !FILE_ISSUE_LIST!
)

:: Calculate total issues
set /a TOTAL_ISSUES=MISSING_DIRS+MISSING_FILES+FILE_ISSUES

:: Display summary
echo.
echo ============================================================
if %TOTAL_ISSUES%==0 (
    echo QC PASSED: All required directories and files exist!
    echo ============================================================
    echo.
    exit /b 0
) else (
    echo QC FAILED: 
    if %MISSING_DIRS% GTR 0 echo   - %MISSING_DIRS% missing directories
    if %MISSING_FILES% GTR 0 echo   - %MISSING_FILES% missing files
    if %FILE_ISSUES% GTR 0 echo   - %FILE_ISSUES% file issues
    echo ============================================================
    echo.
    exit /b 1
)
