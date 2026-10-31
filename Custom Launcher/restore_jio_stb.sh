#!/usr/bin/env bash
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

set -euo pipefail

TV_HOST="${1:-${TV_HOST:-192.168.31.161}}"
TARGET="$TV_HOST:5555"

echo "Connecting to Jio STB at $TARGET..."
adb connect "$TARGET" >/dev/null 2>&1 || true

if ! adb devices | grep -q "$TARGET[[:space:]]\+device"; then
    echo "ERROR: STB at $TARGET is not connected or unauthorized. Check TV screen." >&2
    exit 1
fi

echo ""
echo "[1/5] Re-enabling stock Iwedia Reliance Launcher & UI services..."
RESTORE_PACKAGES=(
    "com.iwedia.ui.rjio.launcher.reliance"
    "com.rjil.jiostbsetting"
    "com.jio.controlcentre"
    "com.jio.stbwidget"
    "com.jio.bioscopecontentservice"
    "com.jio.keyboard.swarachakra"
    "com.rjl.mobileremote.receiver"
    "com.jio.appoptimizer"
    "com.jio.smartmemorymanager"
)
for pkg in "${RESTORE_PACKAGES[@]}"; do
    adb -s "$TARGET" shell "pm enable $pkg" >/dev/null 2>&1 || true
done
echo "  [✓] Stock Iwedia launcher and UI components restored"

echo ""
echo "[3/5] Restoring stock Home activity..."
adb -s "$TARGET" shell "cmd package set-home-activity --user 0 com.iwedia.ui.rjio.launcher.reliance/com.iwedia.ui.rjio.launcher.ui.intro.IntroActivity"
echo "  [✓] Default Home activity restored to Iwedia launcher"

echo ""
echo "[4/5] Resetting accessibility and screensaver services..."
adb -s "$TARGET" shell "settings put secure enabled_accessibility_services 'null'; settings put secure accessibility_enabled 0; settings put secure screensaver_components 'null'; settings put secure screensaver_enabled 0"
echo "  [✓] Accessibility and screensaver reset"

echo ""
echo "[5/5] Removing CleanYourTV launcher (com.gathin.tvhome)..."
adb -s "$TARGET" shell "pm uninstall com.gathin.tvhome"
echo "  [✓] com.gathin.tvhome uninstalled"

echo ""
echo "Refreshing Home screen..."
adb -s "$TARGET" shell "am start -W -a android.intent.action.MAIN -c android.intent.category.HOME" >/dev/null 2>&1 || true

echo ""
echo "=============================================================================="
echo "  RESTORE COMPLETE! Stock launcher and settings are back."
echo "  FOTA/TR-069 protections from Stage 1 remain intact."
echo "=============================================================================="
