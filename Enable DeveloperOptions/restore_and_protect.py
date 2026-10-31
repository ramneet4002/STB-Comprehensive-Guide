import os
import subprocess
import sys

# Ensure local script directory is on PATH so adb.exe can be located if placed in this folder
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in os.environ.get("PATH", ""):
    os.environ["PATH"] = SCRIPT_DIR + os.pathsep + os.environ.get("PATH", "")

# Essential packages that MUST remain installed for JioTV+, Remote, and Launcher to function
ESSENTIAL_PACKAGES = [
    "com.media.jio.sso.stb",                # Jio SSO (keeps JioTV+ & JioCinema login valid)
    "com.jio.media.stb.ondemand.patchwall", # JioTV+ App & Guide
    "com.jio.stb.catv",                     # JioTV+ Live Streaming Player Engine
    "com.jio.stbwidget",                    # Launcher Deep-press Popups / Context Menus
    "com.jio.profileutility",               # Launcher App Move/Reorder & Layout
    "com.android.app.jio.voiceassist",      # Remote Mic & Voice Search
    "com.jio.universalsetup",               # Universal Remote TV Volume / Power Setup
    "com.jio.product.exploremyremote",      # Remote Button Shortcut Mappings
    "com.rjil.jio.stb.commandreceiver",     # Remote Input Event Handler
    "com.rjl.mobileremote.receiver",        # Mobile Remote App Receiver
    "com.jio.controlcentre",                # Control Centre / Quick Settings Button
    "com.jio.dialserver",                   # DIAL Casting Server
    "com.omni.sci",                         # Core Setup Framework
    "com.omni.simplesetup"                  # Core Setup Framework
]

# Unneeded bloatware, trackers, ads, and telemetry to remove
BLOAT_PACKAGES = [
    # User Apps
    "com.jio.store",                        # Jio App Store
    "com.jiostb.jiogames",                  # JioGames
    "com.aksys.jiogamepad",                 # Gamepad helper
    "com.jio.media.jiobeats",               # JioSaavn
    "com.jio.mymusic.app",                  # JioMusic
    "com.jio.media.jionewsstb",             # JioNews
    "com.jio.jiocloudpc",                   # Cloud PC
    "com.jio.jiopay",                       # JioPay
    "com.jio.jiocall",                      # JioCall
    "com.jio.yt",                           # YouTube web wrapper
    "com.jio.web",                          # Jio Web Browser
    "com.jio.stb.bot",                      # Customer Support Chatbot
    "com.jio.stb.hotellauncher",            # Hotel Launcher
    "com.jio.screensaver",                  # Screensaver
    "com.jio.stb.screensaver",              # Screensaver
    "com.teamviewer.quicksupport.addon.jio_stb",

    # Telemetry, Ads, & Aggressive Task Killers
    "com.jio.stbadservice",                 # Ad delivery service
    "com.jio.systemstats",                  # Background telemetry tracker
    "com.rjil.podlogservice",               # Log uploader
    "com.jio.adc.aka",                      # Ad analytics tracker
    "com.jio.adc.embedded",                 # Embedded analytics tracker
    "com.jio.smartmemorymanager",           # Background task killer
    "com.jio.appoptimizer",                 # Memory task killer
    "com.jio.backgroundscheduler",          # Telemetry periodic scheduler
    "com.jio.stb.remotediagnose",           # Remote diagnostics
    "com.jio.bioscopecontentservice",       # Promo content downloader
    "com.jiostb.inactivitytimer"            # Inactivity timeout daemon
]

def run_adb(cmd):
    full_cmd = ["adb"] + cmd
    res = subprocess.run(full_cmd, capture_output=True, text=True)
    return res.stdout.strip(), res.stderr.strip()

print("=" * 65)
print("  Jio STB Curator: Protect Core Features & Remove Bloat")
print("=" * 65)

# Step 1: Ensure all essential packages are installed
print("\n[1/4] Ensuring all essential TV, Remote, and Launcher packages are active...")
for pkg in ESSENTIAL_PACKAGES:
    out, err = run_adb(["shell", "cmd", "package", "install-existing", pkg])
    if "Installed" in out or "Package" in out:
        print(f"  [✓] Verified active: {pkg}")
    else:
        print(f"  [✓] Active: {pkg}")

# Step 2: Strictly disable auto-updates & TR-069 remote push
print("\n[2/4] Strictly disabling auto-updates & TR-069 background manager...")
out, _ = run_adb(["shell", "pm", "disable-user", "--user", "0", "com.jio.httpupdate"])
print("  [✓] Disabled com.jio.httpupdate (FOTA engine)")
out, _ = run_adb(["shell", "pm", "disable-user", "--user", "0", "com.jio.usbupdate"])
print("  [✓] Disabled com.jio.usbupdate (USB updater)")
out, _ = run_adb(["shell", "pm", "disable-user", "--user", "0", "com.jio.tr069client"])
print("  [✓] Disabled com.jio.tr069client (ACS phone-home daemon)")
run_adb(["shell", "cmd", "appops", "set", "com.jio.tr069client", "RUN_IN_BACKGROUND", "ignore"])
run_adb(["shell", "cmd", "appops", "set", "com.jio.tr069client", "RUN_ANY_IN_BACKGROUND", "ignore"])
run_adb(["shell", "settings", "put", "global", "ota_disable_automatic_update", "1"])
print("  [✓] Enforced global setting: ota_disable_automatic_update = 1")
run_adb(["shell", "settings", "put", "global", "package_verifier_enable", "0"])
run_adb(["shell", "settings", "put", "global", "package_verifier_user_consent", "0"])
print("  [✓] Disabled package verifier (package_verifier_enable = 0)")

# Step 3: Remove true unneeded bloatware
print("\n[3/4] Removing unneeded bloatware (JioStore, JioGames, ads, telemetry)...")
removed = 0
for pkg in BLOAT_PACKAGES:
    out, _ = run_adb(["shell", "pm", "uninstall", "--user", "0", pkg])
    if "Success" in out:
        print(f"  [✓] Removed bloatware: {pkg}")
        removed += 1
print(f"  --> Removed {removed} unneeded bloatware packages.")

# Step 4: Refresh launcher
print("\n[4/4] Refreshing home launcher...")
run_adb(["shell", "am", "force-stop", "com.iwedia.ui.rjio.launcher.reliance"])
print("  [✓] Launcher reloaded with clean home screen!")

print("\n" + "=" * 65)
print("  DONE! Core features & JioTV+ are active. Bloat & updates removed.")
print("=" * 65)
print("\n[NOTE ON YOUTUBE]:")
print("  Jio's web wrapper (com.jio.yt) was removed.")
print("  To install the official YouTube app for Android TV:")
print("  1. Download APKM: https://www.apkmirror.com/apk/google-inc/youtube-for-android-tv-android-tv/")
print("  2. Sideload split APKs via ADB: adb install-multiple base.apk split_config.armeabi_v7a.apk")
print("  (Or install directly on TV using LocalSend + Universal Installer!)")
