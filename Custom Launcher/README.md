# CleanYourTV — Jio STB C200A (JMSC200A) Setup & One-Shot Deployment

Turnkey deployment package and documentation to install the native Apple TV-style CleanYourTV launcher (`com.gathin.tvhome`) on the **Jio 4K OTT STB (Model C200A / JMSC200A)** running AOSP Android 11.

---

## Target Device Specifications

* **Model**: Jio STB C200A (`ro.product.model`: `JMSC200A`)
* **OS**: Android 11 (SDK 30, build `11/25.1.9/8`)
* **Stock Launcher**: Reliance Iwedia UI (`com.iwedia.ui.rjio.launcher.reliance`)
* **Remote**: Bluetooth Voice Remote (`Vendor_0907_Product_0234`)
* **Chipset**: Amlogic S905-series

---

## All Fixes & Tweaks Included

### 1. Permanent Home Interception Across Reboots
* **Problem**: Jio's firmware enforces an early-boot package scan safeguard that resets `/system/priv-app/JioLauncher` back to `enabled` on cold boot. In addition, Jio's `IntroActivity` declares `android:priority="2"`, causing Android's intent resolver to prefer it over standard third-party launchers.
* **Fix**:
  * Configured `stock_home_redirect` to `com.iwedia.ui.rjio.launcher.reliance`.
  * Enabled `home_long_press_home="true"` to intercept and consume `KEYCODE_HOME` at the hardware level via `HomeKeyService`.
  * Enabled `TYPE_WINDOW_STATE_CHANGED` window listener in `HomeKeyService` to automatically redirect back to CleanYourTV if Jio's launcher ever tries to draw on screen.

### 2. Native Android TV Settings & Wi-Fi Fix
* **Problem**: Jio's proprietary settings app (`com.rjil.jiostbsetting`) claims `android.settings.SETTINGS` and `WIFI_SETTINGS` with `priority=999`. Additionally, Android 11 hides the active Wi-Fi SSID on the network pill unless location permissions are granted.
* **Fix**:
  * Disabled `com.rjil.jiostbsetting` (`pm disable-user --user 0 com.rjil.jiostbsetting`). The Settings pill now opens native Android TV settings (`com.android.tv.settings.MainSettings`) and the Wi-Fi pill opens native network settings (`.connectivity.NetworkActivity`).
  * Granted `android.permission.ACCESS_FINE_LOCATION` and `ACCESS_COARSE_LOCATION` to `com.gathin.tvhome` so the network pill displays the real SSID name.

### 3. App Library & Tile Context Menu
* **Feature**:
  * Integrated direct App Library launch option into the Settings pill deep-press menu, while cleanly removing the unused "Module cards" option (`app_library_settings_menu.patch`).
  * Dynamic App Library background opacity: The App Library dialog panel dynamically inherits the user-configured Dock Band Opacity (`dock_opacity`: 100%, 70%, 50%, 30%) from Launcher Settings.
  * Enabled `tile_menu="true"` so holding OK on any tile allows moving or removing from Home.
  * Filtered out unneeded background services and token handlers from the home grid (`hidden_apps`):
    * `com.jio.controlcentre`
    * `com.media.jio.sso.stb`
    * `com.jio.dialserver`
    * `com.netflix.partnertoken`
    * `com.android.tv.settings`

### 4. Hardware Remote Button Mappings (Default Mode)
* Maps physical remote hotkeys via `InputKeyService` based on `/system/usr/keylayout/Vendor_0907_Product_0234.kl`:
  * **Netflix** (`KEYCODE_F7` / scancode `185`) $\rightarrow$ `com.netflix.ninja`
  * **JioHotstar** (`KEYCODE_F8` / scancode `184`) $\rightarrow$ `in.startv.hotstar`
  * **JioCinema** (`KEYCODE_F9` / scancode `186`) $\rightarrow$ `com.jio.media.ondemand`
  * **YouTube** (`KEYCODE_F10` / scancode `187`) $\rightarrow$ `com.google.android.youtube.tv`
  * **JioTV+** (`KEYCODE_F6` / scancode `183`) $\rightarrow$ `com.jio.media.jiotvplus`
  *(Note: To map a custom app such as Spotify to the JioCinema button, simply change `com.jio.media.ondemand` to `com.spotify.tv.android` in `config.xml` or `theme/config.json`).*

### 5. Deep Debloating & Memory Optimization (~500 MB RAM Freed)
* **Problem**: Even with the stock launcher disabled, Jio runs multiple persistent background services (`com.jio.adc.embedded`, `com.jio.stbadservice`, `com.jio.profileutility`, `com.jio.controlcentre`, `com.jio.appoptimizer`, `com.jio.keyboard.swarachakra`, `com.rjl.mobileremote.receiver`, etc.) that consume over 500 MB of physical RAM and perform periodic telemetry/ad sync.
* **Fix**: Safely disables 28 telemetry, tracking, and redundant background daemons via `pm disable-user --user 0`, freeing approximately 500 MB of RAM while strictly preserving the Bluetooth remote driver (`com.jio.remote.btserver`) and JioTV+ account SSO (`com.media.jio.sso.stb`).

### 6. Scenes Theme with Rotating Landscapes
* Deploys 14 dark illustrated landscape wallpapers rotating every 60 minutes.
* Written via `ThemeProvider` (`content write --uri content://com.gathin.tvhome.theme/...`) so external storage file ownership is correctly assigned to the launcher UID.

### 7. Aurora Store Crash Fix (Android TV 11)
* **Problem**: When granting storage permission in Aurora Store on Android TV 11, it requests `android.settings.MANAGE_ALL_FILES_ACCESS_PERMISSION`. Because AOSP TV 11 lacks this system settings activity, Aurora Store crashes immediately with `ActivityNotFoundException`.
* **Fix**: The deployment scripts and AI agent automatically grant `MANAGE_EXTERNAL_STORAGE`, `LEGACY_STORAGE`, and `REQUEST_INSTALL_PACKAGES` via `appops`, completely bypassing the crashing setup screen:
  ```bash
  adb shell appops set com.aurora.store MANAGE_EXTERNAL_STORAGE allow
  adb shell appops set com.aurora.store LEGACY_STORAGE allow
  adb shell appops set com.aurora.store REQUEST_INSTALL_PACKAGES allow
  ```

### 8. Voice Remote & In-App Voice Search
* **Remote Mic Button**: The stock Bluetooth remote's microphone is a proprietary BLE GATT peripheral (`AB5E0001-...`), not a standard Android Audio HAL device. Audio packets can only be decoded by Jio's proprietary `com.android.app.jio.voiceassist` which streams to Jio servers. To maintain privacy, prevent launching Jio services, and keep the setup debloated, the remote mic button is left inactive.
* **In-App Voice Search**: Pure AOSP Android 11 lacks Google Mobile Services (GMS Katniss) for global voice recognition. For searching inside apps:
  * **SmartTube**: Use SmartTube's built-in phone pairing or mobile keyboard dictation to search by voice.
  * **USB Microphone / Air Mouse**: A standard 2.4GHz USB air mouse remote with mic (e.g. G10S/G20S) connects as standard Android USB Audio Class and works out of the box with apps that capture microphone audio.

### 9. ClockDream Screensaver Integration
* **Problem**: Stock Android screensavers (`com.android.dreams.basic` and `com.jio.screensaver`) were disabled as bloat, leaving the box with no active daydream.
* **Fix**: CleanYourTV provides a lightweight `ClockDream` daydream service (`com.gathin.tvhome/.ClockDream`). It displays the minimal Apple TV-style clock, date, and subtle ambient glow over the active rotating Scenes wallpaper.
* Configured automatically as the default system screensaver with a 10-minute idle timeout:
  ```bash
  adb shell settings put secure screensaver_components com.gathin.tvhome/.ClockDream
  adb shell settings put secure screensaver_enabled 1
  adb shell settings put system screen_off_timeout 600000
  ```

### 10. Stage 1 Preservation & Safe Rollback
* The restore scripts (`restore_jio_stb.ps1` / `restore_jio_stb.sh`) revert the system back to the stock Iwedia launcher and stock settings app, but **strictly leave TR-069 and FOTA update blocks from `stage1_direct_lan_guide` intact**.

---

## Directory Contents

| File / Folder | Purpose |
| :--- | :--- |
| [`PROMPT.md`](PROMPT.md) | **Recommended AI Agent Deployment Prompt** (Claude Code, Gemini CLI, Cursor, Copilot, ChatGPT). |
| [`deploy_jio_stb.ps1`](deploy_jio_stb.ps1) | One-shot automated deployment script for Windows PowerShell. |
| [`deploy_jio_stb.sh`](deploy_jio_stb.sh) | One-shot automated deployment script for Linux / macOS / Bash. |
| [`restore_jio_stb.ps1`](restore_jio_stb.ps1) | Standalone safe restore script for Windows. |
| [`restore_jio_stb.sh`](restore_jio_stb.sh) | Standalone safe restore script for Bash. |
| [`config.xml`](config.xml) | Tailored CleanYourTV configuration with Jio C200A settings & keymaps. |
| [`app-release.apk`](app-release.apk) | Pre-compiled release APK ready for direct sideloading. |
| [`app_library_settings_menu.patch`](app_library_settings_menu.patch) | Git patch for `MainActivity.java` and `AppLibraryDialog.java` (App Library in Settings popup, Module cards removed, dynamic dock-opacity panel background). |
| [`theme/`](theme/) | Scenes theme folder with 14 wallpapers, captions, and `config.json`. |

---

## Deployment Methods

### Option A: Recommended — Interactive AI Coding Agent (`PROMPT.md`)

> [!TIP]
> **Why use an AI Agent?**
> The one-shot shell scripts contain hardcoded default app assumptions (such as official YouTube, JioCinema, and standard column widths). However, many users use **different apps** (e.g. SmartTube instead of official YouTube, Spotify or VLC on the JioCinema button, or custom sideloaded packages).
> 
> By pasting [`PROMPT.md`](PROMPT.md) into an AI coding assistant (**Claude Code, Gemini CLI, Cursor, Copilot, ChatGPT, or Antigravity**):
> 1. The agent inspects your STB (`pm list packages -3`) to see what apps you actually have.
> 2. The agent asks which apps you want assigned to the physical remote buttons.
> 3. The agent customizes `config.xml`, builds or deploys the APK, and configures the Scenes theme.
> 4. The agent captures live screenshots to verify your home screen and remote hotkeys.

To use:
Open your AI coding assistant in this repository directory and paste the prompt found in [`PROMPT.md`](PROMPT.md).

---

### Option B: Fast Turnkey Shell Scripts (Factory Defaults)

If you are satisfied with standard defaults (Netflix, Hotstar, JioCinema, YouTube, JioTV+ with 4 columns per row), you can deploy in one command:

#### On Windows (PowerShell):
```powershell
cd D:\Github\cleanyourtv\jio_stb_c200a_setup
.\deploy_jio_stb.ps1 -TvHost 192.168.31.161
```

#### On Linux / macOS / Bash:
```bash
cd jio_stb_c200a_setup
chmod +x deploy_jio_stb.sh restore_jio_stb.sh
./deploy_jio_stb.sh 192.168.31.161
```

---

### Reverting / Restoring to Stock

If you ever wish to return to the stock Jio Iwedia launcher:

#### On Windows (PowerShell):
```powershell
.\restore_jio_stb.ps1 -TvHost 192.168.31.161
```

#### On Linux / macOS / Bash:
```bash
./restore_jio_stb.sh 192.168.31.161
```
*(All Stage 1 FOTA/TR-069 protection blocks remain intact).*
