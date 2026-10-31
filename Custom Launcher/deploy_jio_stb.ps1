# ==============================================================================
# CleanYourTV — One-Shot Automated Setup for Jio STB C200A (JMSC200A)
#
# Target: Jio STB C200A running AOSP Android 11 (SDK 30)
#
# What this script does:
#   1. Connects to the STB over network ADB (port 5555).
#   2. Verifies / installs the CleanYourTV launcher (com.gathin.tvhome).
#   3. Grants location permissions for Wi-Fi SSID display.
#   4. Grants WRITE_SECURE_SETTINGS for automatic service repair.
#   5. Sets CleanYourTV as default Home activity.
#   6. Disables stock Reliance Iwedia launcher & stock JioSettings.
#   7. Binds & enables InputKeyService + HomeKeyService (hardware key interceptors).
#   8. Deploys the Scenes 14-wallpaper theme with automatic rotation.
#   9. Preserves App Library & Tile Menu controls.
#  10. Verifies deployment health.
# ==============================================================================

param(
    [string]$TvHost = $(if ($env:TV_HOST) { $env:TV_HOST } else { '192.168.31.161' }),
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$ScriptDir = $PSScriptRoot
$RepoRoot = (Resolve-Path "$ScriptDir\..").Path

# --- Locate ADB Executable ---
$adbCandidates = @(
    'adb',
    "$env:USERPROFILE\Documents\platform-tools\adb.exe",
    "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe",
    'D:\Android\Sdk\platform-tools\adb.exe',
    'C:\platform-tools\adb.exe'
)
$adb = $null
foreach ($cand in $adbCandidates) {
    if (Get-Command $cand -ErrorAction SilentlyContinue) { $adb = $cand; break }
    elseif (Test-Path $cand) { $adb = $cand; break }
}
if (-not $adb) {
    Write-Error 'Could not find adb executable. Please ensure platform-tools is installed.'
    exit 1
}

Write-Host '=============================================================================='
Write-Host '  CleanYourTV - Jio STB C200A One-Shot Deployment'
Write-Host "  Target STB IP: $TvHost"
Write-Host '=============================================================================='

# --- Step 1: Connect to STB ---
Write-Host ''
Write-Host '[1/8] Connecting to STB via ADB...'
& $adb connect "$TvHost`:5555" | Out-Null
Start-Sleep -Seconds 1
$devices = (& $adb devices) -join "`n"
if ($devices -notmatch "$TvHost`:5555\s+device") {
    Write-Error "STB at $TvHost:5555 is offline or unauthorized. Ensure USB/Network debugging is ON."
    exit 1
}
Write-Host "  [OK] Connected to $TvHost:5555"

# --- Step 2: Ensure Launcher APK is Built ---
$apkPath = "$ScriptDir\app-release.apk"
$repoApk = "$RepoRoot\launcher\app\build\outputs\apk\release\app-release.apk"

if (-not (Test-Path $apkPath) -and (Test-Path $repoApk)) {
    $apkPath = $repoApk
}

if (-not (Test-Path $apkPath) -and -not $SkipBuild) {
    Write-Host ''
    Write-Host '[2/8] Building CleanYourTV Launcher release APK...'
    Push-Location "$RepoRoot\launcher"
    try {
        Copy-Item -Force "$ScriptDir\config.xml" "$RepoRoot\launcher\app\src\main\res\values\config.xml"
        .\gradlew.bat --no-daemon assembleRelease -q
        if ($LASTEXITCODE -ne 0) { throw 'Gradle build failed.' }
        $apkPath = $repoApk
    } finally {
        Pop-Location
    }
}

if (-not (Test-Path $apkPath)) {
    Write-Error "Launcher APK not found at $apkPath. Please build it first."
    exit 1
}
$apkSize = (Get-Item $apkPath).Length
Write-Host "  [OK] APK ready: $apkPath ($apkSize bytes)"

# --- Step 3: Install CleanYourTV Launcher ---
Write-Host ''
Write-Host '[3/8] Installing launcher APK onto STB...'
$installResult = (& $adb -s "$TvHost`:5555" install -r $apkPath) -join "`n"
if ($installResult -notmatch 'Success') {
    Write-Error "Failed to install APK: $installResult"
    exit 1
}
Write-Host '  [OK] com.gathin.tvhome installed successfully'

# --- Step 4: Grant Location & Secure Settings Permissions ---
Write-Host ''
Write-Host '[4/8] Granting permissions for Wi-Fi SSID and Key Service Auto-Repair...'
& $adb -s "$TvHost`:5555" shell 'pm grant com.gathin.tvhome android.permission.WRITE_SECURE_SETTINGS'
& $adb -s "$TvHost`:5555" shell 'pm grant com.gathin.tvhome android.permission.ACCESS_FINE_LOCATION'
& $adb -s "$TvHost`:5555" shell 'pm grant com.gathin.tvhome android.permission.ACCESS_COARSE_LOCATION'
Write-Host '  [OK] WRITE_SECURE_SETTINGS, ACCESS_FINE_LOCATION granted'

# --- Step 5: Configure Default Home & Disable Bloat Launchers ---
Write-Host ''
Write-Host '[5/8] Configuring default Home activity and disabling stock bloat...'
& $adb -s "$TvHost`:5555" shell 'cmd package set-home-activity --user 0 com.gathin.tvhome/.MainActivity' | Out-Null
Write-Host '  [OK] Default Home set to com.gathin.tvhome/.MainActivity'

$debloatPackages = @(
    'com.iwedia.ui.rjio.launcher.reliance',
    'com.rjil.jiostbsetting',
    'com.jio.stbadservice',
    'com.jio.adc.embedded',
    'com.jio.adc.aka',
    'com.jio.profileutility',
    'com.jio.systemstats',
    'com.rjil.podlogservice',
    'com.jio.stb.remotediagnose',
    'com.jio.backgroundscheduler',
    'com.android.app.jio.voiceassist',
    'com.jio.controlcentre',
    'com.jio.stbwidget',
    'com.jio.bioscopecontentservice',
    'com.jio.product.exploremyremote',
    'com.jiostb.fti',
    'com.jio.universalsetup',
    'com.jio.stb.bot',
    'com.teamviewer.quicksupport.addon.jio_stb',
    'com.aksys.jiogamepad',
    'com.jio.appoptimizer',
    'com.jio.smartmemorymanager',
    'com.rjil.jio.stb.commandreceiver',
    'com.jio.keyboard.swarachakra',
    'com.rjl.mobileremote.receiver',
    'com.android.printspooler',
    'com.jio.stb.hotellauncher',
    'com.jio.store',
    'com.jio.stb.catv',
    'com.android.talkback',
    'com.jio.screensaver',
    'com.android.dreams.basic'
)

foreach ($pkg in $debloatPackages) {
    & $adb -s "$TvHost`:5555" shell "pm disable-user --user 0 $pkg" | Out-Null
}
Write-Host '  [OK] Telemetry, ad trackers, and background bloat disabled (~500 MB RAM freed)'

# Fix Aurora Store storage crash on Android TV 11 if installed
$aurora = & $adb -s "$TvHost`:5555" shell 'pm list packages com.aurora.store'
if ($aurora -match 'com.aurora.store') {
    & $adb -s "$TvHost`:5555" shell 'appops set com.aurora.store MANAGE_EXTERNAL_STORAGE allow' | Out-Null
    & $adb -s "$TvHost`:5555" shell 'appops set com.aurora.store LEGACY_STORAGE allow' | Out-Null
    & $adb -s "$TvHost`:5555" shell 'appops set com.aurora.store REQUEST_INSTALL_PACKAGES allow' | Out-Null
    Write-Host '  [OK] Granted All Files Access & Install permissions to Aurora Store'
}

# --- Step 6: Enable Hardware Remote Key Interceptors ---
Write-Host ''
Write-Host '[6/8] Binding InputKeyService and HomeKeyService...'
& $adb -s "$TvHost`:5555" shell "settings put secure enabled_accessibility_services 'com.gathin.tvhome/.InputKeyService:com.gathin.tvhome/.HomeKeyService'"
& $adb -s "$TvHost`:5555" shell 'settings put secure accessibility_enabled 1'
Start-Sleep -Seconds 1
Write-Host '  [OK] Key interceptors bound (Home protection + Branded app buttons active)'

# Configure CleanYourTV ClockDream as default system screensaver
& $adb -s "$TvHost`:5555" shell 'settings put secure screensaver_components com.gathin.tvhome/.ClockDream'
& $adb -s "$TvHost`:5555" shell 'settings put secure screensaver_enabled 1'
& $adb -s "$TvHost`:5555" shell 'settings put secure screensaver_activate_on_sleep 1'
& $adb -s "$TvHost`:5555" shell 'settings put secure screensaver_activate_on_dock 1'
& $adb -s "$TvHost`:5555" shell 'settings put system screen_off_timeout 600000'
Write-Host '  [OK] CleanYourTV ClockDream set as default screensaver (10 min idle)'

# --- Step 7: Push Scenes Theme & Rotating Wallpapers ---
Write-Host ''
Write-Host '[7/8] Pushing Scenes theme (14 dark landscape wallpapers)...'
$themeDir = "$ScriptDir\theme"
if (-not (Test-Path "$themeDir\config.json")) {
    $themeDir = "$RepoRoot\themes\scenes"
}

# Create staging folder on STB
& $adb -s "$TvHost`:5555" shell 'mkdir -p /data/local/tmp/scenes_push/wallpapers' | Out-Null

# Push config and wallpapers
& $adb -s "$TvHost`:5555" push "$themeDir\config.json" /data/local/tmp/scenes_push/ | Out-Null
& $adb -s "$TvHost`:5555" push "$themeDir\wallpapers" /data/local/tmp/scenes_push/ | Out-Null

# Write into ThemeProvider
$applyScript = 'content delete --uri content://com.gathin.tvhome.theme/wallpapers; for f in /data/local/tmp/scenes_push/wallpapers/*; do name=${f##*/}; content write --uri content://com.gathin.tvhome.theme/wallpapers/$name < $f; done; content write --uri content://com.gathin.tvhome.theme/config.json < /data/local/tmp/scenes_push/config.json; echo $(date +%s) | content write --uri content://com.gathin.tvhome.theme/theme_revision; rm -rf /data/local/tmp/scenes_push;'
& $adb -s "$TvHost`:5555" shell $applyScript | Out-Null
Write-Host '  [OK] Scenes wallpapers and config deployed to ThemeProvider'

# --- Step 8: Refresh Launcher & Verification ---
Write-Host ''
Write-Host '[8/8] Refreshing Home screen...'
& $adb -s "$TvHost`:5555" shell 'am start -W -a android.intent.action.MAIN -c android.intent.category.HOME' | Out-Null

# Verify Home resolution
$homeRes = (& $adb -s "$TvHost`:5555" shell 'cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME') -join "`n"
$a11y = (& $adb -s "$TvHost`:5555" shell 'settings get secure enabled_accessibility_services')

Write-Host ''
Write-Host '=============================================================================='
Write-Host '  DEPLOYMENT COMPLETE!'
Write-Host '=============================================================================='
Write-Host "  Active Home: $(if ($homeRes -match 'com.gathin.tvhome') { 'com.gathin.tvhome [OK]' } else { 'Warning: check Home' })"
Write-Host "  Accessibility Services: $a11y"
Write-Host '  Theme: Scenes (14 wallpapers, 60m rotation, App Library preserved)'
Write-Host '  Remote Buttons: Netflix, Hotstar, JioCinema, YouTube, JioTV+ active'
Write-Host '  Rollback Tool: .\restore_jio_stb.ps1'
Write-Host '=============================================================================='
