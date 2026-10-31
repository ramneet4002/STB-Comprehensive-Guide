# CleanYourTV — J** STB C200A AI Agent Deployment Guide

> **Instructions for the User**:
> Copy and paste this prompt into your AI coding assistant (**Claude Code, Gemini CLI, Cursor, Copilot, ChatGPT, or Antigravity**) on a computer connected to the same local network as your J** STB.
> 
> *Why use an AI agent?* While the one-shot shell scripts (`deploy_j**_stb.ps1` / `deploy_j**_stb.sh`) provide instant setup for factory defaults, an AI agent can dynamically inspect what apps you actually have installed, adapt remote button mappings (e.g., mapping SmartTube instead of YouTube, or Spotify/VLC instead of J**Cinema), adjust columns/themes, and verify every step on the live screen with screenshots.

---

```text
You are configuring CleanYourTV (a clean, Apple TV-style launcher) on a J** 4K OTT Set-Top Box (Model C200A / JMSC200A) running Android 11 (SDK 30).

Work interactively on the real device over ADB, inspect the system first, ask me for my app preferences, adapt the configuration, deploy the launcher and theme, and verify everything with screenshots.

### Safety Invariants (Strictly Enforced)
1. DISABLE ONLY, NEVER UNINSTALL: Never use `pm uninstall` on system packages. Only use `pm disable-user --user 0 <package>` or `pm enable <package>`. Every change must be reversible.
2. PRESERVE STAGE 1 DIRECT LAN PROTECTIONS: Do NOT touch or revert any FOTA update blocks or TR-069 router firewall rules from `stage1_direct_lan_guide`. Keep `com.j**.tr069client` disabled.
3. PRESERVE ESSENTIAL ANDROID PACKAGES: Never disable core system packages (`com.android.systemui`, `com.android.tv.settings`, `com.android.bluetooth`, `com.android.permissioncontroller`, `com.android.packageinstaller`, etc.).
4. APK SIZE GATE: Any compiled APK of `com.gathin.tvhome` must remain under 589,824 bytes (576 KB).
5. DO NOT COMMIT DEVICE IDENTIFIERS: Never log or commit IP addresses, MAC addresses, Wi-Fi passwords, or serial numbers.

---

### Step 1: Device Connection & Discovery
1. Find or connect to the STB over ADB:
   - Command: `adb connect <TV_IP>:5555`
   - Confirm connection: `adb devices` must report `device`.
2. Verify hardware model and Android build:
   - Run: `adb shell "getprop ro.product.model"` (Expected: `JMSC200A`)
   - Run: `adb shell "getprop ro.build.version.release"` (Expected: `11`)
3. Discover installed third-party & streaming apps:
   - Run: `adb shell "pm list packages -3"`
   - Run: `adb shell "pm list packages | grep -iE 'youtube|smarttube|netflix|hotstar|spotify|vlc|j..tv|zee5'"`
   - Present the list of detected streaming apps to the user.

---

### Step 2: Interactive Customization Interview
Ask the user the following questions before modifying anything:
1. "Which apps would you like mapped to the 5 physical remote hotkeys?"
   - Netflix Button (`KEYCODE_F7` / scancode `185`) -> Default: `com.netflix.ninja`
   - J**Hotstar Button (`KEYCODE_F8` / scancode `184`) -> Default: `in.startv.hotstar`
   - J**Cinema Button (`KEYCODE_F9` / scancode `186`) -> Default: `com.j**.media.ondemand` (or `com.spotify.tv.android`, `org.videolan.vlc`, etc.)
   - YouTube Button (`KEYCODE_F10` / scancode `187`) -> Default: `com.google.android.youtube.tv` (or SmartTube: `com.liskovsoft.smarttubetv.beta` / `com.teamsmart.videomanager.tv`)
   - J**TV+ Button (`KEYCODE_F6` / scancode `183`) -> Default: `com.j**.media.j**tvplus`
   *(Note: The physical remote mic button is left unmapped/inactive to prevent launching proprietary J** voice telemetry. In-app voice search is handled via app mobile sync e.g. SmartTube or a standard USB mic).*
2. "Would you like 4, 5, or 6 columns of app tiles per row?" (Default: 4).
3. "Do you want to deploy the rotating landscape Scenes theme (14 wallpapers, 60-min rotation)?" (Default: Yes).

---

### Step 3: Configure & Build Launcher
1. Check `j**_stb_c200a_setup/config.xml` (or `launcher/app/src/main/res/values/config.xml`):
   - Update `<string-array name="app_keys">` with the user's chosen button-to-package mappings.
   - Set `<integer name="columns">` to the chosen column count.
   - Ensure the following J** C200A-critical settings are active:
     * `<string name="stock_home_redirect">com.iwedia.ui.rj**.launcher.reliance</string>` (redirects J** stock home if triggered)
     * `<bool name="home_long_press_home">true</bool>` (intercepts and consumes hardware Home key)
     * `<bool name="restore_key_services">true</bool>` (auto-restores accessibility services)
     * `<bool name="app_library">true</bool>` (enables full app catalogue)
     * `<bool name="tile_menu">true</bool>` (enables hold OK to reorder/remove tiles)
     * `<string-array name="hidden_apps">` contains bloat tokens:
       `com.j**.controlcentre`, `com.media.j**.sso.stb`, `com.j**.dialserver`, `com.netflix.partnertoken`, `com.android.tv.settings`.
2. Verify Java patches are in place:
   - Ensure `app_library_settings_menu.patch` is applied to `MainActivity.java` and `AppLibraryDialog.java`:
     * App Library launch entry in Settings deep-press menu.
     * "Module cards" row removed.
     * App Library dialog background dynamically follows `dock_opacity` (100%, 70%, 50%, 30%).
3. Build the release APK:
   - If using the prebuilt `j**_stb_c200a_setup/app-release.apk` with default keymaps, skip building.
   - If keymaps or settings were changed, compile with Gradle:
     `cd launcher && ./gradlew assembleRelease`
   - Verify APK size is strictly < 589,824 bytes.

---

### Step 4: Sideload & Debloat System
1. Sideload the launcher APK:
   - `adb install -r app-release.apk`
2. Grant Wi-Fi SSID location permissions (enables network name on Wi-Fi pill in Android 11):
   - `adb shell "pm grant com.gathin.tvhome android.permission.ACCESS_FINE_LOCATION"`
   - `adb shell "pm grant com.gathin.tvhome android.permission.ACCESS_COARSE_LOCATION"`
3. Bind CleanYourTV Accessibility Services (handles Home redirection & remote hotkeys):
   - `adb shell "settings put secure enabled_accessibility_services com.gathin.tvhome/.InputKeyService:com.gathin.tvhome/.HomeKeyService"`
   - `adb shell "settings put secure accessibility_enabled 1"`
4. Set CleanYourTV as default Home activity:
   - `adb shell "cmd package set-home-activity com.gathin.tvhome/.MainActivity"`
5. Safely disable bloatware, ad trackers, and telemetry daemons (~500 MB RAM freed):
   - Disable J** settings app & Iwedia stock launcher:
     `adb shell "pm disable-user --user 0 com.iwedia.ui.rj**.launcher.reliance"`
     `adb shell "pm disable-user --user 0 com.rjil.j**stbsetting"`
   - Disable J** ad tracking & telemetry services:
     `adb shell "pm disable-user --user 0 com.j**.stbadservice"`
     `adb shell "pm disable-user --user 0 com.j**.adc.embedded"`
     `adb shell "pm disable-user --user 0 com.j**.adc.aka"`
     `adb shell "pm disable-user --user 0 com.j**.profileutility"`
     `adb shell "pm disable-user --user 0 com.j**.systemstats"`
     `adb shell "pm disable-user --user 0 com.rjil.podlogservice"`
     `adb shell "pm disable-user --user 0 com.j**.stb.remotediagnose"`
     `adb shell "pm disable-user --user 0 com.j**.backgroundscheduler"`
     `adb shell "pm disable-user --user 0 com.android.app.j**.voiceassist"`
   - Disable vestigial stock UI daemons, background app killers & redundant utilities:
     `adb shell "pm disable-user --user 0 com.j**.controlcentre"`
     `adb shell "pm disable-user --user 0 com.j**.stbwidget"`
     `adb shell "pm disable-user --user 0 com.j**.bioscopecontentservice"`
     `adb shell "pm disable-user --user 0 com.j**.product.exploremyremote"`
     `adb shell "pm disable-user --user 0 com.j**stb.fti"`
     `adb shell "pm disable-user --user 0 com.j**.universalsetup"`
     `adb shell "pm disable-user --user 0 com.j**.stb.bot"`
     `adb shell "pm disable-user --user 0 com.teamviewer.quicksupport.addon.j**_stb"`
     `adb shell "pm disable-user --user 0 com.aksys.j**gamepad"`
     `adb shell "pm disable-user --user 0 com.j**.appoptimizer"`
     `adb shell "pm disable-user --user 0 com.j**.smartmemorymanager"`
     `adb shell "pm disable-user --user 0 com.rjil.j**.stb.commandreceiver"`
     `adb shell "pm disable-user --user 0 com.j**.keyboard.swarachakra"`
     `adb shell "pm disable-user --user 0 com.rjl.mobileremote.receiver"`
     `adb shell "pm disable-user --user 0 com.android.printspooler"`
     `adb shell "pm disable-user --user 0 com.j**.stb.hotellauncher"`
     `adb shell "pm disable-user --user 0 com.j**.store"`
     `adb shell "pm disable-user --user 0 com.j**.stb.catv"`
     `adb shell "pm disable-user --user 0 com.android.talkback"`
     `adb shell "pm disable-user --user 0 com.j**.screensaver"`
     `adb shell "pm disable-user --user 0 com.android.dreams.basic"`
6. Fix Aurora Store on Android TV 11 (if installed):
   - Android TV 11 lacks the system activity for `MANAGE_ALL_FILES_ACCESS_PERMISSION`, causing Aurora Store to crash with `ActivityNotFoundException` when requesting storage. Grant it directly via appops:
     `adb shell "appops set com.aurora.store MANAGE_EXTERNAL_STORAGE allow"`
     `adb shell "appops set com.aurora.store LEGACY_STORAGE allow"`
     `adb shell "appops set com.aurora.store REQUEST_INSTALL_PACKAGES allow"`
7. Configure CleanYourTV ClockDream as default system screensaver:
   - Sets the clean Apple TV-style clock over rotating wallpaper as the system daydream (10-minute idle):
     `adb shell "settings put secure screensaver_components com.gathin.tvhome/.ClockDream"`
     `adb shell "settings put secure screensaver_enabled 1"`
     `adb shell "settings put secure screensaver_activate_on_sleep 1"`
     `adb shell "settings put secure screensaver_activate_on_dock 1"`
     `adb shell "settings put system screen_off_timeout 600000"`

---

### Step 5: Deploy Scenes Theme via ThemeProvider
Push wallpapers and theme config using `content write` so external storage ownership is correctly granted to the launcher UID:
1. Push wallpapers:
   For each wallpaper file `01.jpg` .. `14.jpg`:
   - `adb push theme/<file> /data/local/tmp/<file>`
   - `adb shell "content write --uri content://com.gathin.tvhome.theme/wallpapers/<file> < /data/local/tmp/<file>"`
   - `adb shell "rm /data/local/tmp/<file>"`
2. Push `config.json`:
   - `adb push theme/config.json /data/local/tmp/config.json`
   - `adb shell "content write --uri content://com.gathin.tvhome.theme/config.json < /data/local/tmp/config.json"`
   - `adb shell "rm /data/local/tmp/config.json"`

---

### Step 6: Live Validation & Screenshots
1. Restart the launcher cleanly:
   - `adb shell "am force-stop com.gathin.tvhome; monkey -p com.gathin.tvhome -c android.intent.category.HOME 1"`
2. Capture a screenshot of the Home screen:
   - `adb shell "screencap -p /sdcard/shot_home.png" && adb pull /sdcard/shot_home.png .`
3. Verify the following on the screenshot and live device:
   - Top bar displays greeting, clock, real Wi-Fi SSID name, and Settings button.
   - Clean 4-column dock with app banners.
   - Rotating landscape wallpaper is active in the background.
4. Long-press the Settings pill to confirm:
   - App Library option is present.
   - "Module cards" is absent.
5. Open App Library and confirm:
   - All installed apps appear in the catalogue.
   - Panel background transparency matches the Dock Band Opacity setting.
6. Verify remote control hotkeys:
   - Press or test each mapped button (Netflix, Hotstar, J**Cinema/Spotify, YouTube/SmartTube, J**TV+).
7. Confirm that pressing Home always returns to CleanYourTV, even after a reboot.
```
