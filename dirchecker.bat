@echo off
setlocal enabledelayedexpansion

:: Directory QC Script - Batch Version with Colors
:: Verifies required folder structure and files exist for QC automation
:: Requires Windows 10+ for color support

:: Enable ANSI escape sequences on Windows 10+
for /f "tokens=3" %%a in ('ver') do set /a "winver=%%a"
if !winver! geq 10 (
    :: Enable virtual terminal processing for colors
    reg add HKCU\Console /v VirtualTerminalLevel /t REG_DWORD /d 1 /f >nul 2>&1
)

:: Define colors using ANSI escape codes
set "GREEN=[92m"
set "RED=[91m"
set "YELLOW=[93m"
set "BLUE=[94m"
set "RESET=[0m"
set "BOLD=[1m"

:: Check arguments
if "%~1"=="" (
    echo %RED%ERROR: No base directory specified%RESET%
    echo.
    echo Usage: %~nx0 BASE_DIRECTORY [TEST_TYPE]
    echo Example: %~nx0 ABC123-20240115 SB
    echo          %~nx0 ABC123-20240115
    echo.
    echo TEST_TYPE: 'SB' for SB tests ^(with full file checks^)
    echo            Any other value or omitted for basic checks
    echo.
    echo %YELLOW%Expected Directory Structure:%RESET%
    echo %YELLOW%XXXXXX-XXXXXXXX\%RESET%
    echo %YELLOW%├── NVA\%RESET%
    echo %YELLOW%│   ├── NESSUS\%RESET%
    echo %YELLOW%│   ├── NMAP\%RESET%
    echo %YELLOW%│   └── QUALYS\%RESET%
    echo %YELLOW%├── REPORTS\%RESET%
    echo %YELLOW%└── REQUESTINFO\%RESET%
    exit /b 1
)

:: Set variables
set "BASE_DIR=%~1"
set "TEST_TYPE=%~2"
if "%TEST_TYPE%"=="" set "TEST_TYPE=OTHER"

:: Extract prefix from directory name
for /f "tokens=1 delims=-" %%a in ("%~n1") do set "PREFIX=%%a"

:: Initialize counters
set /a MISSING_DIRS=0
set /a MISSING_FILES=0
set /a FILE_ISSUES=0

:: Display header
echo.
echo %BOLD%Directory Structure ^& File QC Report%RESET%
echo %BLUE%============================================================%RESET%
echo %BOLD%Base Directory:%RESET% %BASE_DIR%
echo %BOLD%Test Type:%RESET% %TEST_TYPE%
echo %BLUE%============================================================%RESET%
echo.

:: Check if base directory exists
if not exist "%BASE_DIR%" (
    echo %RED%ERROR: Base directory does not exist: %BASE_DIR%%RESET%
    exit /b 1
)

:: Check directory structure
echo %BOLD%DIRECTORY STRUCTURE:%RESET%
echo %BLUE%------------------------------%RESET%

:: Track if we need to print section headers
set "HAS_EXISTING_DIRS="
set "HAS_MISSING_DIRS="

:: Check and collect directory status
:: Base directory
if exist "%BASE_DIR%\*" (
    set "HAS_EXISTING_DIRS=1"
    set "EXISTING_DIR_1=%~nx1"
) else (
    set "HAS_MISSING_DIRS=1"
    set "MISSING_DIR_1=%~nx1"
    set /a MISSING_DIRS+=1
)

:: Main directories
set /a DIR_INDEX=2
for %%D in (NVA REPORTS REQUESTINFO) do (
    if exist "%BASE_DIR%\%%D\*" (
        set "HAS_EXISTING_DIRS=1"
        set "EXISTING_DIR_!DIR_INDEX!=%%D"
    ) else (
        set "HAS_MISSING_DIRS=1"
        set "MISSING_DIR_!DIR_INDEX!=%%D"
        set /a MISSING_DIRS+=1
    )
    set /a DIR_INDEX+=1
)

:: NVA subdirectories
for %%D in (NESSUS NMAP QUALYS) do (
    if exist "%BASE_DIR%\NVA\%%D\*" (
        set "HAS_EXISTING_DIRS=1"
        set "EXISTING_DIR_!DIR_INDEX!=NVA\%%D"
    ) else (
        set "HAS_MISSING_DIRS=1"
        set "MISSING_DIR_!DIR_INDEX!=NVA\%%D"
        set /a MISSING_DIRS+=1
    )
    set /a DIR_INDEX+=1
)

:: Display existing directories
if defined HAS_EXISTING_DIRS (
    echo %GREEN%%BOLD%✓ Existing Directories:%RESET%
    for /l %%i in (1,1,10) do (
        if defined EXISTING_DIR_%%i (
            echo   %GREEN%✓%RESET% !EXISTING_DIR_%%i!
        )
    )
)

:: Display missing directories
if defined HAS_MISSING_DIRS (
    echo.
    echo %RED%%BOLD%✗ Missing Directories:%RESET%
    for /l %%i in (1,1,10) do (
        if defined MISSING_DIR_%%i (
            echo   %RED%✗%RESET% !MISSING_DIR_%%i!
        )
    )
)

echo.
echo %BOLD%FILE CHECKS:%RESET%
echo %BLUE%------------------------------%RESET%

:: Reset tracking variables
set "HAS_EXISTING_FILES="
set "HAS_MISSING_FILES="
set "HAS_FILE_ISSUES="
set /a FILE_INDEX=1

:: File checks based on test type
if /i "%TEST_TYPE%"=="SB" (
    :: Check for NESSUS files
    set "NESSUS_FOUND="
    for %%F in ("%BASE_DIR%\NVA\NESSUS\*.nessus") do (
        if exist "%%F" set "NESSUS_FOUND=1"
    )
    if defined NESSUS_FOUND (
        set "HAS_EXISTING_FILES=1"
        set "EXISTING_FILE_1=NVA\NESSUS\*.nessus (found)"
    ) else (
        set "HAS_MISSING_FILES=1"
        set "MISSING_FILE_1=NVA\NESSUS\*.nessus"
        set /a MISSING_FILES+=1
    )
    
    :: Check for NMAP files
    set /a FILE_INDEX=2
    for %%T in (TCP UDP) do (
        for %%E in (gnmap nmap xml) do (
            if exist "%BASE_DIR%\NVA\NMAP\%PREFIX%_%%T.%%E" (
                set "HAS_EXISTING_FILES=1"
                set "EXISTING_FILE_!FILE_INDEX!=NVA\NMAP\%PREFIX%_%%T.%%E"
            ) else (
                set "HAS_MISSING_FILES=1"
                set "MISSING_FILE_!FILE_INDEX!=NVA\NMAP\%PREFIX%_%%T.%%E"
                set /a MISSING_FILES+=1
            )
            set /a FILE_INDEX+=1
        )
    )
)

:: Check Attack Surface Profile
set "ASP_FILE=%BASE_DIR%\REQUESTINFO\%PREFIX%-Attack Surface Profile.xlsx"
if exist "%ASP_FILE%" (
    for %%F in ("%ASP_FILE%") do set /a "FILESIZE=%%~zF"
    set /a "FILESIZEKB=!FILESIZE!/1024"
    
    if !FILESIZE! GTR 25600 (
        set "HAS_EXISTING_FILES=1"
        set "EXISTING_FILE_!FILE_INDEX!=REQUESTINFO\%PREFIX%-Attack Surface Profile.xlsx (!FILESIZEKB! KB)"
    ) else (
        set "HAS_FILE_ISSUES=1"
        set "FILE_ISSUE_1=REQUESTINFO\%PREFIX%-Attack Surface Profile.xlsx - File too small (!FILESIZEKB! KB, requires > 25 KB)"
        set /a FILE_ISSUES+=1
    )
) else (
    set "HAS_MISSING_FILES=1"
    set "MISSING_FILE_!FILE_INDEX!=REQUESTINFO\%PREFIX%-Attack Surface Profile.xlsx"
    set /a MISSING_FILES+=1
)

:: Display existing files
if defined HAS_EXISTING_FILES (
    echo %GREEN%%BOLD%✓ Existing Files:%RESET%
    for /l %%i in (1,1,20) do (
        if defined EXISTING_FILE_%%i (
            echo   %GREEN%✓%RESET% !EXISTING_FILE_%%i!
        )
    )
)

:: Display missing files
if defined HAS_MISSING_FILES (
    echo.
    echo %RED%%BOLD%✗ Missing Files:%RESET%
    for /l %%i in (1,1,20) do (
        if defined MISSING_FILE_%%i (
            echo   %RED%✗%RESET% !MISSING_FILE_%%i!
        )
    )
)

:: Display file issues
if defined HAS_FILE_ISSUES (
    echo.
    echo %YELLOW%%BOLD%⚠ File Issues:%RESET%
    for /l %%i in (1,1,10) do (
        if defined FILE_ISSUE_%%i (
            echo   %YELLOW%⚠%RESET% !FILE_ISSUE_%%i!
        )
    )
)

:: Calculate total issues
set /a TOTAL_ISSUES=MISSING_DIRS+MISSING_FILES+FILE_ISSUES

:: Display summary
echo.
echo %BLUE%============================================================%RESET%
if %TOTAL_ISSUES%==0 (
    echo %GREEN%%BOLD%QC PASSED:%RESET% All required directories and files exist!
    echo %BLUE%============================================================%RESET%
    echo.
    exit /b 0
) else (
    set "ISSUE_TEXT="
    if %MISSING_DIRS% GTR 0 set "ISSUE_TEXT=!ISSUE_TEXT!%MISSING_DIRS% missing directories"
    if %MISSING_FILES% GTR 0 (
        if defined ISSUE_TEXT set "ISSUE_TEXT=!ISSUE_TEXT!, "
        set "ISSUE_TEXT=!ISSUE_TEXT!%MISSING_FILES% missing files"
    )
    if %FILE_ISSUES% GTR 0 (
        if defined ISSUE_TEXT set "ISSUE_TEXT=!ISSUE_TEXT!, "
        set "ISSUE_TEXT=!ISSUE_TEXT!%FILE_ISSUES% file issues"
    )
    echo %RED%%BOLD%QC FAILED:%RESET% !ISSUE_TEXT!
    echo %BLUE%============================================================%RESET%
    echo.
    exit /b 1
)
