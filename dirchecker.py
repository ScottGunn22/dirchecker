#!/usr/bin/env python3
"""
Cross-Platform Directory Structure and File QC Script
Verifies required folder structure and files exist for QC automation
Works on both Windows and Linux systems
"""

import os
import sys
from pathlib import Path
import platform
import glob

# Check if we're on Windows
IS_WINDOWS = platform.system() == 'Windows'

# Enable ANSI colors on Windows 10+
if IS_WINDOWS:
    try:
        import ctypes
        kernel32 = ctypes.windll.kernel32
        kernel32.SetConsoleMode(kernel32.GetStdHandle(-11), 7)
    except:
        pass

# ANSI color codes for terminal output
GREEN = '\033[92m'
RED = '\033[91m'
YELLOW = '\033[93m'
BLUE = '\033[94m'
RESET = '\033[0m'
BOLD = '\033[1m'

# Path separator for display
PATH_SEP = '\\' if IS_WINDOWS else '/'

# Define required directory structure
REQUIRED_STRUCTURE = {
    'NVA': ['NESSUS', 'NMAP', 'QUALYS'],
    'REPORTS': [],
    'REQUESTINFO': []
}

def get_base_prefix(base_path):
    """Extract the XXXXXX prefix from the base directory name"""
    base_name = os.path.basename(base_path)
    if '-' in base_name:
        return base_name.split('-')[0]
    return base_name

def format_path_for_display(path, base_path):
    """Format path for display using appropriate separators"""
    rel_path = os.path.relpath(path, os.path.dirname(base_path))
    if IS_WINDOWS:
        return rel_path.replace('/', '\\')
    else:
        return rel_path.replace('\\', '/')

def check_sb_files(base_path):
    """
    Check for required files in SB type test
    
    Returns:
        tuple: (missing_files, existing_files, file_issues)
    """
    missing_files = []
    existing_files = []
    file_issues = []
    
    base_prefix = get_base_prefix(base_path)
    
    # Check NESSUS folder for .nessus file
    nessus_path = base_path / 'NVA' / 'NESSUS'
    if nessus_path.exists():
        nessus_files = list(nessus_path.glob('*.nessus'))
        if nessus_files:
            existing_files.append(f"NVA{PATH_SEP}NESSUS{PATH_SEP}*.nessus ({len(nessus_files)} file(s) found)")
        else:
            missing_files.append(f"NVA{PATH_SEP}NESSUS{PATH_SEP}*.nessus")
    
    # Check NMAP folder for specific files
    nmap_path = base_path / 'NVA' / 'NMAP'
    if nmap_path.exists():
        required_nmap_files = [
            f"{base_prefix}_TCP.gnmap",
            f"{base_prefix}_TCP.nmap",
            f"{base_prefix}_TCP.xml",
            f"{base_prefix}_UDP.gnmap",
            f"{base_prefix}_UDP.nmap",
            f"{base_prefix}_UDP.xml"
        ]
        
        for file_name in required_nmap_files:
            file_path = nmap_path / file_name
            if file_path.exists():
                existing_files.append(f"NVA{PATH_SEP}NMAP{PATH_SEP}{file_name}")
            else:
                missing_files.append(f"NVA{PATH_SEP}NMAP{PATH_SEP}{file_name}")
    
    # Check REQUESTINFO for Attack Surface Profile
    requestinfo_path = base_path / 'REQUESTINFO'
    if requestinfo_path.exists():
        attack_surface_file = f"{base_prefix}-Attack Surface Profile.xlsx"
        file_path = requestinfo_path / attack_surface_file
        
        if file_path.exists():
            file_size = file_path.stat().st_size
            file_size_kb = file_size / 1024
            
            if file_size_kb > 25:
                existing_files.append(f"REQUESTINFO{PATH_SEP}{attack_surface_file} ({file_size_kb:.1f} KB)")
            else:
                file_issues.append(f"REQUESTINFO{PATH_SEP}{attack_surface_file} - File too small ({file_size_kb:.1f} KB, requires > 25 KB)")
        else:
            missing_files.append(f"REQUESTINFO{PATH_SEP}{attack_surface_file}")
    
    return missing_files, existing_files, file_issues

def check_other_files(base_path):
    """
    Check for required files in non-SB type tests
    
    Returns:
        tuple: (missing_files, existing_files, file_issues)
    """
    missing_files = []
    existing_files = []
    file_issues = []
    
    base_prefix = get_base_prefix(base_path)
    
    # Only check REQUESTINFO for Attack Surface Profile
    requestinfo_path = base_path / 'REQUESTINFO'
    if requestinfo_path.exists():
        attack_surface_file = f"{base_prefix}-Attack Surface Profile.xlsx"
        file_path = requestinfo_path / attack_surface_file
        
        if file_path.exists():
            file_size = file_path.stat().st_size
            file_size_kb = file_size / 1024
            
            if file_size_kb > 25:
                existing_files.append(f"REQUESTINFO{PATH_SEP}{attack_surface_file} ({file_size_kb:.1f} KB)")
            else:
                file_issues.append(f"REQUESTINFO{PATH_SEP}{attack_surface_file} - File too small ({file_size_kb:.1f} KB, requires > 25 KB)")
        else:
            missing_files.append(f"REQUESTINFO{PATH_SEP}{attack_surface_file}")
    
    return missing_files, existing_files, file_issues

def check_directory_structure(base_path):
    """
    Verify the required directory structure exists
    
    Args:
        base_path: Path to the base directory (XXXXXX-XXXXXXXX)
    
    Returns:
        tuple: (is_valid, missing_dirs, existing_dirs)
    """
    base_path = Path(base_path)
    missing_dirs = []
    existing_dirs = []
    
    # Check if base directory exists
    if not base_path.exists():
        return False, [str(base_path)], []
    
    if not base_path.is_dir():
        return False, [f"{base_path} (not a directory)"], []
    
    existing_dirs.append(str(base_path))
    
    # Check main subdirectories
    for main_dir, subdirs in REQUIRED_STRUCTURE.items():
        main_path = base_path / main_dir
        
        if not main_path.exists():
            missing_dirs.append(str(main_path))
        else:
            existing_dirs.append(str(main_path))
            
            # Check subdirectories
            for subdir in subdirs:
                sub_path = main_path / subdir
                if not sub_path.exists():
                    missing_dirs.append(str(sub_path))
                else:
                    existing_dirs.append(str(sub_path))
    
    return len(missing_dirs) == 0, missing_dirs, existing_dirs

def print_results(base_path, test_type, dir_valid, missing_dirs, existing_dirs, 
                 missing_files, existing_files, file_issues):
    """Print the QC results in a formatted way"""
    print(f"\n{BOLD}Directory Structure & File QC Report{RESET}")
    print(f"{BLUE}{'='*60}{RESET}")
    print(f"{BOLD}Base Directory:{RESET} {base_path}")
    print(f"{BOLD}Test Type:{RESET} {test_type.upper()}")
    print(f"{BOLD}Platform:{RESET} {platform.system()}")
    print(f"{BLUE}{'='*60}{RESET}\n")
    
    # Print directory status
    print(f"{BOLD}DIRECTORY STRUCTURE:{RESET}")
    print(f"{BLUE}{'-'*30}{RESET}")
    
    # Print existing directories
    if existing_dirs:
        print(f"{GREEN}{BOLD}✓ Existing Directories:{RESET}")
        for dir_path in existing_dirs:
            formatted_path = format_path_for_display(dir_path, base_path)
            print(f"  {GREEN}✓{RESET} {formatted_path}")
    
    # Print missing directories
    if missing_dirs:
        print(f"\n{RED}{BOLD}✗ Missing Directories:{RESET}")
        for dir_path in missing_dirs:
            formatted_path = format_path_for_display(dir_path, base_path)
            print(f"  {RED}✗{RESET} {formatted_path}")
    
    # Print file status
    print(f"\n{BOLD}FILE CHECKS:{RESET}")
    print(f"{BLUE}{'-'*30}{RESET}")
    
    # Print existing files
    if existing_files:
        print(f"{GREEN}{BOLD}✓ Existing Files:{RESET}")
        for file_info in existing_files:
            print(f"  {GREEN}✓{RESET} {file_info}")
    
    # Print missing files
    if missing_files:
        print(f"\n{RED}{BOLD}✗ Missing Files:{RESET}")
        for file_info in missing_files:
            print(f"  {RED}✗{RESET} {file_info}")
    
    # Print file issues
    if file_issues:
        print(f"\n{YELLOW}{BOLD}⚠ File Issues:{RESET}")
        for issue in file_issues:
            print(f"  {YELLOW}⚠{RESET} {issue}")
    
    # Overall status
    files_valid = len(missing_files) == 0 and len(file_issues) == 0
    all_valid = dir_valid and files_valid
    
    print(f"\n{BLUE}{'='*60}{RESET}")
    if all_valid:
        print(f"{GREEN}{BOLD}QC PASSED:{RESET} All required directories and files exist!")
    else:
        issues = []
        if missing_dirs:
            issues.append(f"{len(missing_dirs)} missing directories")
        if missing_files:
            issues.append(f"{len(missing_files)} missing files")
        if file_issues:
            issues.append(f"{len(file_issues)} file issues")
        
        print(f"{RED}{BOLD}QC FAILED:{RESET} {', '.join(issues)}")
    print(f"{BLUE}{'='*60}{RESET}\n")
    
    return all_valid

def print_expected_structure(test_type):
    """Print the expected directory structure and files"""
    print(f"\n{YELLOW}{BOLD}Expected Directory Structure:{RESET}")
    print(f"{YELLOW}XXXXXX-XXXXXXXX{PATH_SEP}{RESET}")
    print(f"{YELLOW}├── NVA{PATH_SEP}{RESET}")
    print(f"{YELLOW}│   ├── NESSUS{PATH_SEP}{RESET}")
    print(f"{YELLOW}│   ├── NMAP{PATH_SEP}{RESET}")
    print(f"{YELLOW}│   └── QUALYS{PATH_SEP}{RESET}")
    print(f"{YELLOW}├── REPORTS{PATH_SEP}{RESET}")
    print(f"{YELLOW}└── REQUESTINFO{PATH_SEP}{RESET}\n")
    
    print(f"{YELLOW}{BOLD}Expected Files:{RESET}")
    if test_type.upper() == 'SB':
        print(f"{YELLOW}For SB Test Type:{RESET}")
        print(f"{YELLOW}  NVA{PATH_SEP}NESSUS{PATH_SEP}*.nessus (any .nessus file){RESET}")
        print(f"{YELLOW}  NVA{PATH_SEP}NMAP{PATH_SEP}XXXXXX_TCP.gnmap{RESET}")
        print(f"{YELLOW}  NVA{PATH_SEP}NMAP{PATH_SEP}XXXXXX_TCP.nmap{RESET}")
        print(f"{YELLOW}  NVA{PATH_SEP}NMAP{PATH_SEP}XXXXXX_TCP.xml{RESET}")
        print(f"{YELLOW}  NVA{PATH_SEP}NMAP{PATH_SEP}XXXXXX_UDP.gnmap{RESET}")
        print(f"{YELLOW}  NVA{PATH_SEP}NMAP{PATH_SEP}XXXXXX_UDP.nmap{RESET}")
        print(f"{YELLOW}  NVA{PATH_SEP}NMAP{PATH_SEP}XXXXXX_UDP.xml{RESET}")
        print(f"{YELLOW}  REQUESTINFO{PATH_SEP}XXXXXX-Attack Surface Profile.xlsx (>25KB){RESET}")
    else:
        print(f"{YELLOW}For Other Test Types:{RESET}")
        print(f"{YELLOW}  REQUESTINFO{PATH_SEP}XXXXXX-Attack Surface Profile.xlsx (>25KB){RESET}")
    print()

def main():
    """Main function"""
    # Check command line arguments
    if len(sys.argv) < 2 or len(sys.argv) > 3:
        print(f"{RED}Error: Invalid number of arguments{RESET}")
        print(f"Usage: {sys.executable} {sys.argv[0]} <BASE_DIRECTORY> [TEST_TYPE]")
        print(f"Example: {sys.executable} {sys.argv[0]} ABC123-20240115 SB")
        print(f"         {sys.executable} {sys.argv[0]} ABC123-20240115")
        print(f"\nTEST_TYPE: 'SB' for SB tests (with full file checks)")
        print(f"           Any other value or omitted for basic checks")
        print_expected_structure('SB')
        sys.exit(1)
    
    base_directory = sys.argv[1]
    test_type = sys.argv[2] if len(sys.argv) == 3 else 'OTHER'
    
    # Convert to Path object
    base_path = Path(base_directory)
    
    # Check directory structure
    dir_valid, missing_dirs, existing_dirs = check_directory_structure(base_path)
    
    # Check files based on test type
    if test_type.upper() == 'SB':
        missing_files, existing_files, file_issues = check_sb_files(base_path)
    else:
        missing_files, existing_files, file_issues = check_other_files(base_path)
    
    # Print results
    success = print_results(base_directory, test_type, dir_valid, missing_dirs, 
                          existing_dirs, missing_files, existing_files, file_issues)
    
    # Exit with appropriate code
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
