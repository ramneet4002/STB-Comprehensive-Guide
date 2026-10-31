# ==============================================================================
# CleanYourTV — Safe Revert Script for Jio STB C200A
#
# NOTE: This script ONLY reverts changes made by CleanYourTV (restoring the
# stock Iwedia launcher, stock settings app, and removing tvhome).
#
# It deliberately DOES NOT re-enable:
#   - com.jio.httpupdate (FOTA engine)
#   - com.jio.usbupdate  (USB updater)
#   - com.jio.tr069client (ACS management daemon)
#   - or any bloatware cleaned up by stage1_direct_lan_guide!
# ==============================================================================

param(
    [string]$TvHost = $(if ($env:TV_HOST) { $env:TV_HOST } else { "192.168.31.161" })
)

$ErrorActionPreference = "Stop"

$adbCandidates = @(
    "adb",
    "$env:USERPROFILE\Documents\platform-tools\adb.exe",
    "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe",
    "D:\Android\Sdk\platform-tools\adb.exe",
    "C:\platform-tools\adb.exe"
)

$adb = $null
foreach ($cand in $adbCandidates) {
    if (Get-Command $cand -ErrorAction SilentlyContinue) { $adb = $cand; break }
    elseif (Test-Path $cand) { $adb = $cand; break }
}

if (-not $adb) {
    Write-Error "Could not find adb executable. Ensure platform-tools is on PATH."
    exit 1
}

Write-Host "Connecting to Jio STB at $TvHost:5555..."
& $adb connect "$TvHost`:5555" | Out-Null

$deviceStatus = (& $adb devices) -join "`n"
if ($deviceStatus -notmatch "$TvHost`:5555\s+device") {
    Write-Error "STB at $TvHost:5555 is not connected or unauthorized. Check TV screen."
    exit 1
}

Write-Host "`n[1/5] Re-enabling stock Iwedia Reliance Launcher & UI services..."
$restorePackages = @(
    'com.iwedia.ui.rjio.launcher.reliance',
    'com.rjil.jiostbsetting',
    'com.jio.controlcentre',
    'com.jio.stbwidget',
    'com.jio.bioscopecontentservice',
    'com.jio.keyboard.swarachakra',
    'com.rjl.mobileremote.receiver',
    'com.jio.appoptimizer',
    'com.jio.smartmemorymanager'
)
foreach ($pkg in $restorePackages) {
    & $adb -s "$TvHost`:5555" shell "pm enable $pkg" | Out-Null
}
Write-Host "  [✓] Stock Iwedia launcher and UI components restored"

Write-Host "`n[3/5] Restoring stock Home activity..."
& $adb -s "$TvHost`:5555" shell "cmd package set-home-activity --user 0 com.iwedia.ui.rjio.launcher.reliance/com.iwedia.ui.rjio.launcher.ui.intro.IntroActivity"
Write-Host "  [✓] Default Home activity restored to Iwedia launcher"

Write-Host "`n[4/5] Resetting accessibility and screensaver services..."
& $adb -s "$TvHost`:5555" shell "settings put secure enabled_accessibility_services 'null'; settings put secure accessibility_enabled 0; settings put secure screensaver_components 'null'; settings put secure screensaver_enabled 0"
Write-Host "  [✓] Accessibility and screensaver reset"

Write-Host "`n[5/5] Removing CleanYourTV launcher (com.gathin.tvhome)..."
& $adb -s "$TvHost`:5555" shell "pm uninstall com.gathin.tvhome"
Write-Host "  [✓] com.gathin.tvhome uninstalled"

Write-Host "`nRefreshing Home screen..."
& $adb -s "$TvHost`:5555" shell "am start -W -a android.intent.action.MAIN -c android.intent.category.HOME" | Out-Null

Write-Host "`n=============================================================================="
Write-Host "  RESTORE COMPLETE! Stock launcher and settings are back."
Write-Host "  FOTA/TR-069 protections from Stage 1 remain intact."
Write-Host "=============================================================================="
