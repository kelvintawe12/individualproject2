<#
PowerShell helper: flutterfire_configure.ps1

What it does:
- Ensures the FlutterFire CLI is installed and runs `flutterfire configure` interactively for the given project.
- This is interactive: you will choose platforms and confirm app registrations.

Usage:
  .\scripts\flutterfire_configure.ps1 -ProjectId bookswapp-3c1af

Note: flutterfire configure is interactive and may open a browser for auth.
#>
param(
    [string]$ProjectId = 'bookswapp-3c1af'
)

function Check-CommandExists {
    param([string]$cmd)
    $null -ne (Get-Command $cmd -ErrorAction SilentlyContinue)
}

Write-Host "== FlutterFire configure helper =="

if (-not (Check-CommandExists -cmd 'flutterfire')) {
    Write-Warning "FlutterFire CLI not found. Install with: dart pub global activate flutterfire_cli"
    $install = Read-Host "Install flutterfire_cli now? (y/N)"
    if ($install -match '^[Yy]') {
        if (-not (Check-CommandExists -cmd 'dart')) {
            Write-Error "Dart not found. Ensure Flutter is installed and 'dart' is on PATH."
            exit 1
        }
        dart pub global activate flutterfire_cli
        if (-not (Check-CommandExists -cmd 'flutterfire')) {
            Write-Error "flutterfire CLI did not install correctly. Please install manually and re-run this script."
            exit 1
        }
    } else {
        Write-Host "Aborting. Install flutterfire_cli and re-run this script."
        exit 1
    }
}

Write-Host "Running 'flutterfire configure' for project: $ProjectId"
# Runs interactively. The CLI will ask you to select the project and platforms.
flutterfire configure --project $ProjectId

if ($LASTEXITCODE -ne 0) { Write-Error "flutterfire configure failed or was cancelled."; exit 1 }

Write-Host "flutterfire configure finished. Verify that 'lib/firebase_options.dart' was updated."