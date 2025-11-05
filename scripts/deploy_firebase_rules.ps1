<#
PowerShell helper: deploy_firebase_rules.ps1

What it does:
- Checks for the Firebase CLI and prompts to install if missing.
- Runs `firebase login` (interactive) if not already authenticated.
- Switches to the provided project id (adds alias if needed).
- Deploys Firestore and Storage rules from the repo root.

Usage (PowerShell):
.
# From project root (where firebase.json lives):
.
# Example:
#   .\scripts\deploy_firebase_rules.ps1 -ProjectId bookswapp-3c1af
#
# Note: This script runs locally — I cannot execute it remotely. Run in an elevated shell
# if you need to install global npm packages.
#>
param(
    [string]$ProjectId = 'bookswapp-3c1af'
)

function Check-CommandExists {
    param([string]$cmd)
    $null -ne (Get-Command $cmd -ErrorAction SilentlyContinue)
}

Write-Host "== Firebase rules deploy helper =="

if (-not (Check-CommandExists -cmd 'firebase')) {
    Write-Warning "Firebase CLI not found. You can install it with: npm install -g firebase-tools"
    $install = Read-Host "Install firebase-tools now? (y/N)"
    if ($install -match '^[Yy]') {
        if (-not (Check-CommandExists -cmd 'npm')) {
            Write-Error "npm not found. Install Node.js and npm first: https://nodejs.org/"
            exit 1
        }
        npm install -g firebase-tools
        if (-not (Check-CommandExists -cmd 'firebase')) {
            Write-Error "firebase CLI did not install correctly. Please install manually and re-run this script."
            exit 1
        }
    } else {
        Write-Host "Aborting. Install firebase-tools and re-run this script."
        exit 1
    }
}

# Ensure we're in the repo root (where firebase.json exists) — best effort
if (-not (Test-Path -Path './firebase.json')) {
    Write-Warning "firebase.json not found in the current directory. Please `cd` to the repo root (where firebase.json is) and re-run this script."
    $ok = Read-Host "Continue anyway? (y/N)"
    if ($ok -notmatch '^[Yy]') { exit 1 }
}

Write-Host "Logging into Firebase (interactive). If you're already logged in this will just confirm your session."
firebase login || { Write-Error "firebase login failed"; exit 1 }

# Add or select project
Write-Host "Setting project to $ProjectId (firebase use --add will prompt for an alias)."
# Try to use project; if it fails, attempt --add
$useResult = & firebase use $ProjectId 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Project not registered locally — running 'firebase use --add $ProjectId' (you will be prompted to enter an alias)."
    firebase use --add $ProjectId || { Write-Error "Failed to add or switch to project $ProjectId"; exit 1 }
}

# Deploy rules
Write-Host "Deploying Firestore and Storage rules..."
firebase deploy --only firestore:rules,storage:rules
if ($LASTEXITCODE -ne 0) { Write-Error "Deploy failed. Check the output above and ensure you have permission to deploy to the project."; exit 1 }

Write-Host "Deploy complete. Check the Firebase Console to confirm the published rules."
