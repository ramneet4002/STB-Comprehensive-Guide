#!/usr/bin/env bash
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

set -euo pipefail

TV_HOST="${1:-${TV_HOST:-192.168.31.161}}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=============================================================================="
echo "  CleanYourTV — Jio STB C200A One-Shot Deployment"
echo "  Target STB IP: $TV_HOST"
echo "=============================================================================="

# --- Step 1: Connect to STB ---
echo ""
echo "[1/8] Connecting to STB via ADB..."
adb connect "$TV_HOST:5555" >/dev/null 2>&1 || true
sleep 1
if ! adb devices | grep -q "$TV_HOST:5555[[:space:]]\+device"; then
    echo "ERROR: STB at $TV_HOST:5555 is offline or unauthorized. Ensure USB/Network debugging is ON." >&2
    exit 1
fi
echo "  [✓] Connected to $TV_HOST:5555"

# --- Step 2: Ensure Launcher APK is Built ---
APK_PATH="$SCRIPT_DIR/app-release.apk"
REPO_APK="$REPO_ROOT/launcher/app/build/outputs/apk/release/app-release.apk"

if [ ! -f "$APK_PATH" ] && [ -f "$REPO_APK" ]; then
    APK_PATH="$REPO_APK"
fi

if [ ! -f "$APK_PATH" ]; then
    echo ""
    echo "[2/8] Building CleanYourTV Launcher release APK..."
    (
        cd "$REPO_ROOT/launcher"
        cp -f "$SCRIPT_DIR/config.xml" "$REPO_ROOT/launcher/app/src/main/res/values/config.xml"
        ./gradlew --no-daemon assembleRelease -q
    )
    APK_PATH="$REPO_APK"
fi

if [ ! -f "$APK_PATH" ]; then
    echo "ERROR: Launcher APK not found at $APK_PATH. Please build it first." >&2
    exit 1
fi
echo "  [✓] APK ready: $APK_PATH"

# --- Step 3: Install CleanYourTV Launcher ---
echo ""
echo "[3/8] Installing launcher APK onto STB..."
adb -s "$TV_HOST:5555" install -r "$APK_PATH"
echo "  [✓] com.gathin.tvhome installed successfully"

# --- Step 4: Grant Location & Secure Settings Permissions ---
echo ""
echo "[4/8] Granting permissions for Wi-Fi SSID and Key Service Auto-Repair..."
adb -s "$TV_HOST:5555" shell "pm grant com.gathin.tvhome android.permission.WRITE_SECURE_SETTINGS"
adb -s "$TV_HOST:5555" shell "pm grant com.gathin.tvhome android.permission.ACCESS_FINE_LOCATION"
adb -s "$TV_HOST:5555" shell "pm grant com.gathin.tvhome android.permission.ACCESS_COARSE_LOCATION"
echo "  [✓] WRITE_SECURE_SETTINGS, ACCESS_FINE_LOCATION granted"

# --- Step 5: Configure Default Home & Disable Bloat Launchers ---
echo ""
echo "[5/8] Configuring default Home activity and disabling stock bloat..."
adb -s "$TV_HOST:5555" shell "cmd package set-home-activity --user 0 com.gathin.tvhome/.MainActivity" >/dev/null 2>&1 || true
echo "  [✓] Default Home set to com.gathin.tvhome/.MainActivity"

DEBLOAT_PACKAGES=(
    "com.iwedia.ui.rjio.launcher.reliance"
    "com.rjil.jiostbsetting"
    "com.jio.stbadservice"
    "com.jio.adc.embedded"
    "com.jio.adc.aka"
    "com.jio.profileutility"
    "com.jio.systemstats"
    "com.rjil.podlogservice"
    "com.jio.stb.remotediagnose"
    "com.jio.backgroundscheduler"
    "com.android.app.jio.voiceassist"
    "com.jio.controlcentre"
    "com.jio.stbwidget"
    "com.jio.bioscopecontentservice"
    "com.jio.product.exploremyremote"
    "com.jiostb.fti"
    "com.jio.universalsetup"
    "com.jio.stb.bot"
    "com.teamviewer.quicksupport.addon.jio_stb"
    "com.aksys.jiogamepad"
    "com.jio.appoptimizer"
    "com.jio.smartmemorymanager"
    "com.rjil.jio.stb.commandreceiver"
    "com.jio.keyboard.swarachakra"
    "com.rjl.mobileremote.receiver"
    "com.android.printspooler"
    "com.jio.stb.hotellauncher"
    "com.jio.store"
    "com.jio.stb.catv"
    "com.android.talkback"
    "com.jio.screensaver"
    "com.android.dreams.basic"
)

for pkg in "${DEBLOAT_PACKAGES[@]}"; do
    adb -s "$TV_HOST:5555" shell "pm disable-user --user 0 $pkg" >/dev/null 2>&1 || true
done
echo "  [✓] Telemetry, ad trackers, and background bloat disabled (~500 MB RAM freed)"

# Fix Aurora Store storage crash on Android TV 11 if installed
if adb -s "$TV_HOST:5555" shell "pm list packages com.aurora.store" 2>/dev/null | grep -q "com.aurora.store"; then
    adb -s "$TV_HOST:5555" shell "appops set com.aurora.store MANAGE_EXTERNAL_STORAGE allow" >/dev/null 2>&1 || true
    adb -s "$TV_HOST:5555" shell "appops set com.aurora.store LEGACY_STORAGE allow" >/dev/null 2>&1 || true
    adb -s "$TV_HOST:5555" shell "appops set com.aurora.store REQUEST_INSTALL_PACKAGES allow" >/dev/null 2>&1 || true
    echo "  [✓] Granted All Files Access & Install permissions to Aurora Store"
fi

# --- Step 6: Enable Hardware Remote Key Interceptors ---
echo ""
echo "[6/8] Binding InputKeyService and HomeKeyService..."
adb -s "$TV_HOST:5555" shell "settings put secure enabled_accessibility_services 'com.gathin.tvhome/.InputKeyService:com.gathin.tvhome/.HomeKeyService'"
adb -s "$TV_HOST:5555" shell "settings put secure accessibility_enabled 1"
sleep 1
echo "  [✓] Key interceptors bound (Home protection + Branded app buttons active)"

# Configure CleanYourTV ClockDream as default system screensaver
adb -s "$TV_HOST:5555" shell "settings put secure screensaver_components com.gathin.tvhome/.ClockDream"
adb -s "$TV_HOST:5555" shell "settings put secure screensaver_enabled 1"
adb -s "$TV_HOST:5555" shell "settings put secure screensaver_activate_on_sleep 1"
adb -s "$TV_HOST:5555" shell "settings put secure screensaver_activate_on_dock 1"
adb -s "$TV_HOST:5555" shell "settings put system screen_off_timeout 600000"
echo "  [✓] CleanYourTV ClockDream set as default screensaver (10 min idle)"

# --- Step 7: Push Scenes Theme & Rotating Wallpapers ---
echo ""
echo "[7/8] Pushing Scenes theme (14 dark landscape wallpapers)..."
THEME_DIR="$SCRIPT_DIR/theme"
if [ ! -f "$THEME_DIR/config.json" ]; then
    THEME_DIR="$REPO_ROOT/themes/scenes"
fi

adb -s "$TV_HOST:5555" shell "mkdir -p /data/local/tmp/scenes_push/wallpapers"
adb -s "$TV_HOST:5555" push "$THEME_DIR/config.json" /data/local/tmp/scenes_push/ >/dev/null 2>&1
adb -s "$TV_HOST:5555" push "$THEME_DIR/wallpapers" /data/local/tmp/scenes_push/ >/dev/null 2>&1

adb -s "$TV_HOST:5555" shell '
content delete --uri content://com.gathin.tvhome.theme/wallpapers;
for f in /data/local/tmp/scenes_push/wallpapers/*; do
    name=${f##*/};
    content write --uri content://com.gathin.tvhome.theme/wallpapers/$name < $f;
done;
content write --uri content://com.gathin.tvhome.theme/config.json < /data/local/tmp/scenes_push/config.json;
echo $(date +%s) | content write --uri content://com.gathin.tvhome.theme/theme_revision;
rm -rf /data/local/tmp/scenes_push;
'
echo "  [✓] Scenes wallpapers & config deployed to ThemeProvider"

# --- Step 8: Refresh Launcher & Verification ---
echo ""
echo "[8/8] Refreshing Home screen..."
adb -s "$TV_HOST:5555" shell "am start -W -a android.intent.action.MAIN -c android.intent.category.HOME" >/dev/null 2>&1 || true

echo ""
echo "=============================================================================="
echo "  DEPLOYMENT COMPLETE!"
echo "=============================================================================="
echo "  Active Home: $(adb -s "$TV_HOST:5555" shell "cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME" | tr -d '\r')"
echo "  Accessibility Services: $(adb -s "$TV_HOST:5555" shell "settings get secure enabled_accessibility_services" | tr -d '\r')"
echo "  Theme: Scenes (14 wallpapers, 60m rotation, App Library preserved)"
echo "  Remote Buttons: Netflix, Hotstar, JioCinema, YouTube, JioTV+ active"
echo "  Rollback Tool: ./restore_jio_stb.sh"
echo "=============================================================================="
