<#
.SYNOPSIS
Build script for Helix with dependency management

.DESCRIPTION
Automates the Helix's building process for Windows

.PARAMETER Compile
Compile and generate the executable

.PARAMETER Run
Run the executable after compilation

.PARAMETER Clean
Remove all generated files and dependencies

.PARAMETER Install
Install the application system-wide

.PARAMETER Uninstall
Uninstall the application

.EXAMPLE
.\build.ps1 -Compile -Run
#>

param (
    [switch]$Compile,
    [switch]$Run,
    [switch]$Clean,
    [switch]$Install,
    [switch]$Uninstall,
    [switch]$Help
)

# Global variables
$ProjectName = "Helix"
$SourceFiles = @("source/*.cpp", "source/include/*.cpp")
$IncludeDirs = @("include")
$OutputDir = "build"
$Executable = "$OutputDir/helix.exe"
$AssetsDir = "$env:APPDATA/Helix/assets"
$CFlags = @("-std=c++17", "-pipe", "-Os")
$WarnFlags = @("-W", "-Wall", "-Wpedantic", "-Wformat=2")
$DependenciesDir = "dependencies"

function Show-Help {
    Write-Host "USAGE:"
    Write-Host "  .\build.ps1 [OPTIONS]"
    Write-Host
    Write-Host "OPTIONS:"
    Write-Host "  -Help, -h           Display this help message and exit."
    Write-Host "  -Compile, -c        Compile and generate the executable."
    Write-Host "  -Run, -r            Run the executable."
    Write-Host "  -Clean, -cl         Clean the directory."
    Write-Host "  -Install, -i        Install system-wide."
    Write-Host "  -Uninstall, -un     Uninstall."
    Write-Host
    Write-Host "EXAMPLES:"
    Write-Host "  .\build.ps1 -Help"
    Write-Host "  .\build.ps1 -Compile -Run"
    Write-Host "  .\build.ps1 -Compile -Install -Clean"
}

function Install-Chocolatey {
    if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Host "Installing Chocolatey package manager..."
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    }
    else {
        Write-Host "Chocolatey is already installed."
    }
}

function Install-Dependencies {
    Write-Host "Checking and installing dependencies..."

    # Install MinGW
    if (!(Test-Path "C:\MinGW\bin\g++.exe")) {
        choco install mingw -y
    }

    # Install CMake
    if (!(Get-Command cmake -ErrorAction SilentlyContinue)) {
        choco install cmake -y
    }

    # Install Raylib
    if (!(Test-Path "$DependenciesDir/raylib/build/raylib/libraylib.a")) {
        if (!(Test-Path "$DependenciesDir/raylib")) {
            Expand-Archive -Path "$DependenciesDir/raylib.zip" -DestinationPath "$DependenciesDir"
        }

        New-Item -ItemType Directory -Path "$DependenciesDir/raylib/build" -Force | Out-Null
        Set-Location "$DependenciesDir/raylib/build"
        cmake .. -DBUILD_EXAMPLES=OFF -DBUILD_GAMES=OFF
        cmake --build . --config Release
        Set-Location "../../../"
    }

    # Install Symengine
    if (!(Test-Path "$DependenciesDir/symengine/build/symengine/libsymengine.a")) {
        if (!(Test-Path "$DependenciesDir/symengine")) {
            Expand-Archive -Path "$DependenciesDir/symengine.zip" -DestinationPath "$DependenciesDir"
        }

        New-Item -ItemType Directory -Path "$DependenciesDir/symengine/build" -Force | Out-Null
        Set-Location "$DependenciesDir/symengine/build"
        cmake .. -DBUILD_TESTS=OFF -DBUILD_BENCHMARKS=OFF
        cmake --build . --config Release
        Set-Location "../../../"
    }
}

function Build-Project {
    Write-Host "Building $ProjectName..."

    # Create output directory
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

    # Copy assets
    if (Test-Path $AssetsDir) {
        Remove-Item -Path $AssetsDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $AssetsDir -Force | Out-Null
    Copy-Item -Path "assets/*" -Destination $AssetsDir -Recurse -Force

    # Build command
    $RaylibPath = "$DependenciesDir/raylib/build/raylib"
    $SymenginePath = "$DependenciesDir/symengine/build/symengine"

    $IncludeFlags = $IncludeDirs | ForEach-Object { "-I$_" }
    $LinkFlags = @(
        "-L$RaylibPath", "-lraylib",
        "-L$SymenginePath", "-lsymengine",
        "-lm", "-lgmp"
    )

    $Defines = "-DASSETS=`"$AssetsDir`""

    $Command = "g++ $($SourceFiles -join ' ') $IncludeFlags $CFlags $WarnFlags $LinkFlags $Defines -o $Executable"
    Write-Host "Executing: $Command"

    Invoke-Expression $Command

    if ($LASTEXITCODE -eq 0) {
        Write-Host "+ $ProjectName compiled successfully." -ForegroundColor Green
    }
    else {
        throw "Compilation failed."
    }
}

function Run-Project {
    if (!(Test-Path $Executable)) {
        throw "Executable not found. Please compile first."
    }

    Write-Host "Running $ProjectName..." -ForegroundColor Cyan
    & $Executable
}

function Clean-Build {
    Write-Host "Cleaning build..." -ForegroundColor Yellow

    if (Test-Path $OutputDir) {
        Remove-Item -Path $OutputDir -Recurse -Force
    }

    if (Test-Path $AssetsDir) {
        Remove-Item -Path $AssetsDir -Recurse -Force
    }

    if (Test-Path "$DependenciesDir/raylib") {
        Remove-Item -Path "$DependenciesDir/raylib" -Recurse -Force
    }

    if (Test-Path "$DependenciesDir/symengine") {
        Remove-Item -Path "$DependenciesDir/symengine" -Recurse -Force
    }

    Write-Host "+ Cleaned." -ForegroundColor Green
}

function Install-Project {
    if (!(Test-Path $Executable)) {
        throw "Executable not found. Please compile first."
    }

    Write-Host "Installing $ProjectName system-wide..." -ForegroundColor Cyan
    $InstallPath = "$env:ProgramFiles\$ProjectName"

    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
    Copy-Item -Path $Executable -Destination "$InstallPath/$ProjectName.exe" -Force

    # Create shortcut
    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\$ProjectName.lnk")
    $Shortcut.TargetPath = "$InstallPath/$ProjectName.exe"
    $Shortcut.Save()

    Write-Host "+ $ProjectName installed successfully." -ForegroundColor Green
}

function Uninstall-Project {
    Write-Host "Uninstalling $ProjectName..." -ForegroundColor Yellow

    $InstallPath = "$env:ProgramFiles\$ProjectName"
    if (Test-Path $InstallPath) {
        Remove-Item -Path $InstallPath -Recurse -Force
    }

    $ShortcutPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\$ProjectName.lnk"
    if (Test-Path $ShortcutPath) {
        Remove-Item -Path $ShortcutPath -Force
    }

    Write-Host "+ $ProjectName uninstalled successfully." -ForegroundColor Green
}

# Main execution
try {
    if ($Help -or ($PSBoundParameters.Count -eq 0)) {
        Show-Help
        exit 0
    }

    if ($Clean) {
        Clean-Build
    }

    if ($Compile) {
        Install-Chocolatey
        Install-Dependencies
        Build-Project
    }

    if ($Run) {
        Run-Project
    }

    if ($Install) {
        Install-Project
    }

    if ($Uninstall) {
        Uninstall-Project
    }
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
    exit 1
}
