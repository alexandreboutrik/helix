<#
.SYNOPSIS
Build script for Helix with dependency management

.DESCRIPTION
Automates the Helix's building process for Windows
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
$SourceFiles = @(Get-ChildItem -Path "source/*.cpp" -Recurse -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
$IncludeDirs = @(
    "include",
    "dependencies/raylib/src",
    "dependencies/raylib/include",
    "dependencies/symengine/include"
)
$OutputDir = "build"
$Executable = "$OutputDir/helix.exe"
$AssetsDir = "$env:APPDATA/Helix/assets"
$CFlags = @("-std=c++17", "-pipe", "-Os")
$WarnFlags = @("-W", "-Wall", "-Wpedantic", "-Wformat=2")
$DependenciesDir = "dependencies"

$env:ChocolateyInstall = "$env:LOCALAPPDATA\chocolatey"
$VCPKG_ROOT = "$env:USERPROFILE\vcpkg"

function Show-Help {
    Write-Host "USAGE: .\build.ps1 [-Compile] [-Run] [-Clean] [-Install] [-Uninstall] [-Help]"
}

function Install-Chocolatey {
    if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
        # Allow script execution (temporary)
        Set-ExecutionPolicy Bypass -Scope Process -Force

        # Force TLS 1.2 for secure download
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072

        # Install Chocolatey in user-local directory (NO ADMIN)
        $env:ChocolateyInstall = "$env:LOCALAPPDATA\chocolatey"
        iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

        # Add Chocolatey to PATH (user-level)
        [Environment]::SetEnvironmentVariable("PATH", "$env:LOCALAPPDATA\chocolatey\bin;$env:Path", "User")

        # Refresh current session
        $env:Path = "$env:LOCALAPPDATA\chocolatey\bin;$env:Path"
    }
}

function Install-Dependencies {
    Write-Host "Installing dependencies..."

    # Install required tools
    echo y | choco feature disable --name="showNonElevatedWarnings"
    choco install -y mingw --params="/AddToPath"
    choco install -y make cmake --installargs 'ADD_CMAKE_TO_PATH='

    # Install vcpkg for GMP
    if (!(Get-Command "vcpkg" -ErrorAction SilentlyContinue)) {
        # Clone repository
         if (-not (Test-Path "$VCPKG_ROOT\.git")) {
            git clone https://github.com/microsoft/vcpkg.git $VCPKG_ROOT
            if ($LASTEXITCODE -ne 0) { throw "VCPKG Failed to clone" }
        }

        # Bootstrap
        Push-Location $VCPKG_ROOT
        try {
            & .\bootstrap-vcpkg.bat
            if ($LASTEXITCODE -ne 0) { throw "VCPKG Bootstrap failed" }
        }
        finally {
            Pop-Location
        }

        # Add to PATH (if not already present)
        $currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
        if ($currentPath -notlike "*$VCPKG_ROOT*") {
            [Environment]::SetEnvironmentVariable("PATH", "$VCPKG_ROOT;$currentPath", "User")
            $env:PATH = "$VCPKG_ROOT;$env:PATH"
        }

        # Set VCPKG_ROOT variable
        if (-not [Environment]::GetEnvironmentVariable("VCPKG_ROOT", "User")) {
            [Environment]::SetEnvironmentVariable("VCPKG_ROOT", $VCPKG_ROOT, "User")
        }

        vcpkg install gmp:x64-windows
    }

    # Build Raylib
    if (!(Test-Path "$DependenciesDir/raylib")) {
        Expand-Archive -Path "$DependenciesDir/raylib.zip" -DestinationPath "$DependenciesDir" -Force
    }

    if (!(Test-Path "$DependenciesDir/raylib/build/raylib/libraylib.a")) {
        Push-Location "$DependenciesDir/raylib"
        New-Item -ItemType Directory -Path "build" -Force | Out-Null
        Set-Location "build"
        cmake .. -DBUILD_EXAMPLES=OFF -DBUILD_GAMES=OFF -DBUILD_SHARED_LIBS=OFF
        cmake --build . --config Release
        if ($LASTEXITCODE -ne 0) {
            throw "Raylib Compilation failed"
        }
        Pop-Location
    }

    # Build SymEngine
    if (!(Test-Path "$DependenciesDir/symengine")) {
        Expand-Archive -Path "$DependenciesDir/symengine.zip" -DestinationPath "$DependenciesDir" -Force
    }

    if (!(Test-Path "$DependenciesDir/symengine/build/symengine/libsymengine.a")) {
        Push-Location "$DependenciesDir/symengine"
        New-Item -ItemType Directory -Path "build" -Force | Out-Null
        Set-Location "build"
        cmake .. -DBUILD_TESTS=OFF -DBUILD_BENCHMARKS=OFF -DCMAKE_PREFIX_PATH="C:\Program Files\gmp"
        cmake --build . --config Release -DCMAKE_TOOLCHAIN_FILE="C:/path/to/vcpkg/scripts/buildsystems/vcpkg.cmake"
        if ($LASTEXITCODE -ne 0) {
            throw "Symengine Compilation failed"
        }
        Pop-Location
    }
}

function Build-Project {
    Write-Host "Building $ProjectName..."

    # Create directories
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    New-Item -ItemType Directory -Path $AssetsDir -Force | Out-Null

    # Copy assets
    if (Test-Path "assets") {
        Copy-Item -Path "assets/*" -Destination $AssetsDir -Recurse -Force
    }

    # Build command
    $RaylibPath = "$DependenciesDir/raylib/build/raylib"
    $SymenginePath = "$DependenciesDir/symengine/build/symengine"

    $IncludeFlags = $IncludeDirs | ForEach-Object { "-I$_" }
    $LinkFlags = @(
        "-L$RaylibPath", "-lraylib",
        "-L$SymenginePath", "-lsymengine",
        "-L""C:\Program Files\gmp\lib""", "-lgmp",
        "-lwinmm", "-lgdi32", "-lopengl32"
    )

    $Defines = "-DASSETS=`"$AssetsDir`""

    if ($SourceFiles.Count -eq 0) {
        throw "No source files found in source/ directory"
    }

    $Command = "g++ $($SourceFiles -join ' ') $IncludeFlags $CFlags $WarnFlags $LinkFlags $Defines -o $Executable"
    Write-Host "Executing: $Command"

    Invoke-Expression $Command

    if ($LASTEXITCODE -ne 0) {
        throw "Compilation failed"
    }

    Write-Host "Build successful!" -ForegroundColor Green
}

# [Restante das funções permanecem iguais...]

# Main execution
try {
    if ($Help) { Show-Help; exit 0 }
    if ($Clean) { Clean-Build }
    if ($Compile) { Install-Chocolatey; Install-Dependencies; Build-Project }
    if ($Run) { Run-Project }
    if ($Install) { Install-Project }
    if ($Uninstall) { Uninstall-Project }
}
catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
    exit 1
}
