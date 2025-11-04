# Temporarily updates PATH for this PowerShell session and runs flutterfire configure for this project.
# Usage: Open PowerShell in the project root and run: .\scripts\firebase_configure.ps1

param(
    [string]$ProjectId = 'bookswapp-3c1af',
    [string]$OutFile = 'lib/firebase_options.dart',
    [string]$Platforms = 'android,ios,web'
)

# NPM global bin and Dart pub global bin for the current user
$npmBin = Join-Path $env:USERPROFILE 'AppData\Roaming\npm'
$pubBin = Join-Path $env:USERPROFILE 'AppData\Local\Pub\Cache\bin'

# Prepend to PATH for this process only
$originalPath = $env:PATH
$env:PATH = "$npmBin;$pubBin;$env:PATH"
Write-Host "Temporarily updated PATH for this session."
Write-Host "NPM bin: $npmBin"
Write-Host "Pub cache bin: $pubBin"

# Show versions
Write-Host "firebase --version:"; try { & firebase --version } catch { Write-Host "firebase not found in session PATH" }
Write-Host "flutterfire --version:"; try { & flutterfire --version } catch { Write-Host "flutterfire not found in session PATH" }

# Run flutterfire configure non-interactively for specified platforms
Write-Host "Running: flutterfire configure --project=$ProjectId --out $OutFile --platforms $Platforms"
try {
    & flutterfire configure --project=$ProjectId --out $OutFile --platforms $Platforms
} catch {
    Write-Host "flutterfire configure failed: $_"
    Write-Host "If the command failed due to interactive prompts, re-run without --platforms or run interactively: flutterfire configure"
    exit 1
}

Write-Host "Done. Restoring original PATH."
$env:PATH = $originalPath
Write-Host "Original PATH restored."
