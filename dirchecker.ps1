<#
.SYNOPSIS
    Windows Directory Structure and File QC Script - Verifies required folder structure and files exist

.DESCRIPTION
    This script checks if the required directory structure exists for QC automation on Windows.
    It verifies the presence of NVA, REPORTS, and REQUESTINFO folders, as well as
    NESSUS, NMAP, and QUALYS subfolders under NVA. It also checks for required files
    based on the test type.

.PARAMETER BaseDirectory
    The base directory path (XXXXXX-XXXXXXXX format)

.PARAMETER TestType
    The type of test. Use 'SB' for SB tests with full file checks.
    Any other value or omitted for basic checks (only Attack Surface Profile)

.EXAMPLE
    .\directoryqc.ps1 ABC123-20240115 SB
    
.EXAMPLE
    .\directoryqc.ps1 ABC123-20240115
    
.EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -File directoryqc.ps1 "ABC123-20240115" "SB"
    
.NOTES
    Version: 2.0
    Designed for Windows environments
    Now includes file checks
#>

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$BaseDirectory,
    
    [Parameter(Mandatory=$false, Position=1)]
    [string]$TestType = "OTHER"
)

# Define required directory structure
$RequiredStructure = @{
    'NVA' = @('NESSUS', 'NMAP', 'QUALYS')
    'REPORTS' = @()
    'REQUESTINFO' = @()
}

function Get-BasePrefix {
    param([string]$BasePath)
    
    $baseName = Split-Path $BasePath -Leaf
    if ($baseName -match '-') {
        return $baseName.Split('-')[0]
    }
    return $baseName
}

function Test-SBFiles {
    param([string]$BasePath)
    
    $missingFiles = @()
    $existingFiles = @()
    $fileIssues = @()
    
    $basePrefix = Get-BasePrefix -BasePath $BasePath
    
    # Check NESSUS folder for .nessus file
    $nessusPath = Join-Path $BasePath "NVA\NESSUS"
    if (Test-Path $nessusPath) {
        $nessusFiles = Get-ChildItem -Path $nessusPath -Filter "*.nessus" -ErrorAction SilentlyContinue
        if ($nessusFiles) {
            $existingFiles += "NVA\NESSUS\*.nessus ($($nessusFiles.Count) file(s) found)"
        } else {
            $missingFiles += "NVA\NESSUS\*.nessus"
        }
    }
    
    # Check NMAP folder for specific files
    $nmapPath = Join-Path $BasePath "NVA\NMAP"
    if (Test-Path $nmapPath) {
        $requiredNmapFiles = @(
            "${basePrefix}_TCP.gnmap",
            "${basePrefix}_TCP.nmap",
            "${basePrefix}_TCP.xml",
            "${basePrefix}_UDP.gnmap",
            "${basePrefix}_UDP.nmap",
            "${basePrefix}_UDP.xml"
        )
        
        foreach ($fileName in $requiredNmapFiles) {
            $filePath = Join-Path $nmapPath $fileName
            if (Test-Path $filePath) {
                $existingFiles += "NVA\NMAP\$fileName"
            } else {
                $missingFiles += "NVA\NMAP\$fileName"
            }
        }
    }
    
    # Check REQUESTINFO for Attack Surface Profile
    $requestInfoPath = Join-Path $BasePath "REQUESTINFO"
    if (Test-Path $requestInfoPath) {
        $attackSurfaceFile = "${basePrefix}-Attack Surface Profile.xlsx"
        $filePath = Join-Path $requestInfoPath $attackSurfaceFile
        
        if (Test-Path $filePath) {
            $fileInfo = Get-Item $filePath
            $fileSizeKB = [math]::Round($fileInfo.Length / 1KB, 1)
            
            if ($fileSizeKB -gt 25) {
                $existingFiles += "REQUESTINFO\$attackSurfaceFile ($fileSizeKB KB)"
            } else {
                $fileIssues += "REQUESTINFO\$attackSurfaceFile - File too small ($fileSizeKB KB, requires > 25 KB)"
            }
        } else {
            $missingFiles += "REQUESTINFO\$attackSurfaceFile"
        }
    }
    
    return @{
        MissingFiles = $missingFiles
        ExistingFiles = $existingFiles
        FileIssues = $fileIssues
    }
}

function Test-OtherFiles {
    param([string]$BasePath)
    
    $missingFiles = @()
    $existingFiles = @()
    $fileIssues = @()
    
    $basePrefix = Get-BasePrefix -BasePath $BasePath
    
    # Only check REQUESTINFO for Attack Surface Profile
    $requestInfoPath = Join-Path $BasePath "REQUESTINFO"
    if (Test-Path $requestInfoPath) {
        $attackSurfaceFile = "${basePrefix}-Attack Surface Profile.xlsx"
        $filePath = Join-Path $requestInfoPath $attackSurfaceFile
        
        if (Test-Path $filePath) {
            $fileInfo = Get-Item $filePath
            $fileSizeKB = [math]::Round($fileInfo.Length / 1KB, 1)
            
            if ($fileSizeKB -gt 25) {
                $existingFiles += "REQUESTINFO\$attackSurfaceFile ($fileSizeKB KB)"
            } else {
                $fileIssues += "REQUESTINFO\$attackSurfaceFile - File too small ($fileSizeKB KB, requires > 25 KB)"
            }
        } else {
            $missingFiles += "REQUESTINFO\$attackSurfaceFile"
        }
    }
    
    return @{
        MissingFiles = $missingFiles
        ExistingFiles = $existingFiles
        FileIssues = $fileIssues
    }
}

function Test-DirectoryStructure {
    param(
        [string]$BasePath
    )
    
    $missingDirs = @()
    $existingDirs = @()
    
    # Check if base directory exists
    if (-not (Test-Path $BasePath)) {
        $missingDirs += $BasePath
        return @{
            IsValid = $false
            MissingDirs = $missingDirs
            ExistingDirs = $existingDirs
        }
    }
    
    if (-not (Test-Path $BasePath -PathType Container)) {
        $missingDirs += "$BasePath (not a directory)"
        return @{
            IsValid = $false
            MissingDirs = $missingDirs
            ExistingDirs = $existingDirs
        }
    }
    
    $existingDirs += $BasePath
    
    # Check main subdirectories
    foreach ($mainDir in $RequiredStructure.Keys) {
        $mainPath = Join-Path $BasePath $mainDir
        
        if (-not (Test-Path $mainPath)) {
            $missingDirs += $mainPath
        } else {
            $existingDirs += $mainPath
            
            # Check subdirectories
            foreach ($subDir in $RequiredStructure[$mainDir]) {
                $subPath = Join-Path $mainPath $subDir
                if (-not (Test-Path $subPath)) {
                    $missingDirs += $subPath
                } else {
                    $existingDirs += $subPath
                }
            }
        }
    }
    
    return @{
        IsValid = $missingDirs.Count -eq 0
        MissingDirs = $missingDirs
        ExistingDirs = $existingDirs
    }
}

function Show-Results {
    param(
        [string]$BasePath,
        [string]$TestType,
        [hashtable]$DirResults,
        [hashtable]$FileResults
    )
    
    # Use checkmark and X symbols that work well in Windows console
    $checkMark = "[OK]"
    $xMark = "[X]"
    $warning = "[!]"
    
    # Try to use better symbols if the console supports it
    try {
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        $checkMark = "✓"
        $xMark = "✗"
        $warning = "⚠"
    } catch {}
    
    Write-Host "`nDirectory Structure & File QC Report" -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor DarkGray
    Write-Host "Base Directory: " -NoNewline -ForegroundColor White
    Write-Host $BasePath -ForegroundColor Yellow
    Write-Host "Test Type: " -NoNewline -ForegroundColor White
    Write-Host $TestType.ToUpper() -ForegroundColor Yellow
    Write-Host ("=" * 60) -ForegroundColor DarkGray
    Write-Host ""
    
    # Directory Structure Section
    Write-Host "DIRECTORY STRUCTURE:" -ForegroundColor White
    Write-Host ("-" * 30) -ForegroundColor DarkGray
    
    # Show existing directories
    if ($DirResults.ExistingDirs.Count -gt 0) {
        Write-Host "$checkMark Existing Directories:" -ForegroundColor Green
        foreach ($dir in $DirResults.ExistingDirs) {
            $relativePath = if ($dir -eq $BasePath) { 
                Split-Path $dir -Leaf 
            } else { 
                $dir.Replace($BasePath, "").TrimStart('\', '/')
            }
            Write-Host "  $checkMark " -ForegroundColor Green -NoNewline
            Write-Host $relativePath
        }
    }
    
    # Show missing directories
    if ($DirResults.MissingDirs.Count -gt 0) {
        Write-Host ""
        Write-Host "$xMark Missing Directories:" -ForegroundColor Red
        foreach ($dir in $DirResults.MissingDirs) {
            $relativePath = if ($dir -eq $BasePath) { 
                Split-Path $dir -Leaf 
            } else { 
                $dir.Replace($BasePath, "").TrimStart('\', '/')
            }
            Write-Host "  $xMark " -ForegroundColor Red -NoNewline
            Write-Host $relativePath
        }
    }
    
    # File Checks Section
    Write-Host ""
    Write-Host "FILE CHECKS:" -ForegroundColor White
    Write-Host ("-" * 30) -ForegroundColor DarkGray
    
    # Show existing files
    if ($FileResults.ExistingFiles.Count -gt 0) {
        Write-Host "$checkMark Existing Files:" -ForegroundColor Green
        foreach ($file in $FileResults.ExistingFiles) {
            Write-Host "  $checkMark " -ForegroundColor Green -NoNewline
            Write-Host $file
        }
    }
    
    # Show missing files
    if ($FileResults.MissingFiles.Count -gt 0) {
        Write-Host ""
        Write-Host "$xMark Missing Files:" -ForegroundColor Red
        foreach ($file in $FileResults.MissingFiles) {
            Write-Host "  $xMark " -ForegroundColor Red -NoNewline
            Write-Host $file
        }
    }
    
    # Show file issues
    if ($FileResults.FileIssues.Count -gt 0) {
        Write-Host ""
        Write-Host "$warning File Issues:" -ForegroundColor Yellow
        foreach ($issue in $FileResults.FileIssues) {
            Write-Host "  $warning " -ForegroundColor Yellow -NoNewline
            Write-Host $issue
        }
    }
    
    # Overall status
    $filesValid = ($FileResults.MissingFiles.Count -eq 0) -and ($FileResults.FileIssues.Count -eq 0)
    $allValid = $DirResults.IsValid -and $filesValid
    
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor DarkGray
    if ($allValid) {
        Write-Host "QC PASSED: " -ForegroundColor Green -NoNewline
        Write-Host "All required directories and files exist!"
    } else {
        $issues = @()
        if ($DirResults.MissingDirs.Count -gt 0) {
            $issues += "$($DirResults.MissingDirs.Count) missing directories"
        }
        if ($FileResults.MissingFiles.Count -gt 0) {
            $issues += "$($FileResults.MissingFiles.Count) missing files"
        }
        if ($FileResults.FileIssues.Count -gt 0) {
            $issues += "$($FileResults.FileIssues.Count) file issues"
        }
        
        Write-Host "QC FAILED: " -ForegroundColor Red -NoNewline
        Write-Host ($issues -join ", ")
    }
    Write-Host ("=" * 60) -ForegroundColor DarkGray
    Write-Host ""
    
    return $allValid
}

function Show-ExpectedStructure {
    param([string]$TestType)
    
    Write-Host "`nExpected Directory Structure:" -ForegroundColor Yellow
    Write-Host @"
XXXXXX-XXXXXXXX\
├── NVA\
│   ├── NESSUS\
│   ├── NMAP\
│   └── QUALYS\
├── REPORTS\
└── REQUESTINFO\
"@ -ForegroundColor DarkYellow
    
    Write-Host "`nExpected Files:" -ForegroundColor Yellow
    if ($TestType.ToUpper() -eq 'SB') {
        Write-Host "For SB Test Type:" -ForegroundColor Yellow
        Write-Host "  NVA\NESSUS\*.nessus (any .nessus file)" -ForegroundColor DarkYellow
        Write-Host "  NVA\NMAP\XXXXXX_TCP.gnmap" -ForegroundColor DarkYellow
        Write-Host "  NVA\NMAP\XXXXXX_TCP.nmap" -ForegroundColor DarkYellow
        Write-Host "  NVA\NMAP\XXXXXX_TCP.xml" -ForegroundColor DarkYellow
        Write-Host "  NVA\NMAP\XXXXXX_UDP.gnmap" -ForegroundColor DarkYellow
        Write-Host "  NVA\NMAP\XXXXXX_UDP.nmap" -ForegroundColor DarkYellow
        Write-Host "  NVA\NMAP\XXXXXX_UDP.xml" -ForegroundColor DarkYellow
        Write-Host "  REQUESTINFO\XXXXXX-Attack Surface Profile.xlsx (>25KB)" -ForegroundColor DarkYellow
    } else {
        Write-Host "For Other Test Types:" -ForegroundColor Yellow
        Write-Host "  REQUESTINFO\XXXXXX-Attack Surface Profile.xlsx (>25KB)" -ForegroundColor DarkYellow
    }
    Write-Host ""
}

# Main execution
try {
    # Validate input
    if ([string]::IsNullOrWhiteSpace($BaseDirectory)) {
        Write-Host "Error: Base directory cannot be empty" -ForegroundColor Red
        Write-Host "Usage: .\directoryqc.ps1 <BASE_DIRECTORY> [TEST_TYPE]"
        Write-Host "Example: .\directoryqc.ps1 ABC123-20240115 SB"
        Write-Host "         .\directoryqc.ps1 ABC123-20240115"
        Write-Host ""
        Write-Host "TEST_TYPE: 'SB' for SB tests (with full file checks)"
        Write-Host "          Any other value or omitted for basic checks"
        Show-ExpectedStructure -TestType 'SB'
        exit 1
    }
    
    # Check directory structure
    $dirResults = Test-DirectoryStructure -BasePath $BaseDirectory
    
    # Check files based on test type
    if ($TestType.ToUpper() -eq 'SB') {
        $fileResults = Test-SBFiles -BasePath $BaseDirectory
    } else {
        $fileResults = Test-OtherFiles -BasePath $BaseDirectory
    }
    
    # Show results
    $success = Show-Results -BasePath $BaseDirectory -TestType $TestType -DirResults $dirResults -FileResults $fileResults
    
    # Exit with appropriate code
    if ($success) {
        exit 0
    } else {
        exit 1
    }
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
    exit 1
}
