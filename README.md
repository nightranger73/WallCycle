# WallCycle — Cross-Platform Desktop Wallpaper Manager (Lazarus / FPC)
<img width="483" height="580" alt="screenshot_20261125_220719" src="https://github.com/user-attachments/assets/3f6b0306-757e-452c-800f-9fcde7f39c9e" />
<img width="483" height="580" alt="screenshot_20261125_220715" src="https://github.com/user-attachments/assets/ff459f95-100d-444b-b768-54c0f5cf74bb" />

Native desktop application written in **Object Pascal (Free Pascal 3.2+ / Lazarus 3.x)** to run an automatic wallpaper slideshow from local folders and **WallHaven.cc**, featuring a **real-time Date & Time overlay**, **multi-monitor support (including distinct wallpapers per display)**, **Smart Pause**, **Favorites & Blacklist**, and a **perceived-luminance filter (ITU-R BT.709)** to protect desktop icon readability.

<img width="960" height="640" alt="screenshot_20261125_221259" src="https://github.com/user-attachments/assets/29600b83-4d32-4a5c-b6f0-b111730c801a" />

## Key Features

1. **Multi-Folder Slideshow, Real History & Transitions**:
   - Select one or more local folders (with optional recursive scanning and shuffle) and WallHaven.cc feeds; click any WallHaven feed in the checklist to edit and update its query, sorting, categories, or purity in place.
   - Real **Previous Wallpaper** navigation history stack so **Previous** restores your exact prior wallpapers rather than just stepping playlist indices.
   - Choose from 7 transition styles (**None**, **Crossfade**, **Wipe**, **Slide Left**, **Slide Right**, **Expand from Center**, **Random**) with adjustable duration (`200–3000 ms`). Uses native GPU compositor transitions on `awww`/`swww`, and fast multi-step memory blending on Windows, GNOME, KDE, XFCE, and X11 (automatically bypassing expensive software frame blending on > 4K multi-monitor/8K canvases).
2. **Multi-Monitor Support (Per-Display & Spanned)**:
   - Choose **Primary (Mirror)**, **Per-Monitor (Distinct)** (different wallpaper assigned to every connected monitor), or **Span All Displays** (one wide image stretched across the virtual desktop).
   - Uses native per-output placement on **KDE Plasma**, **XFCE 4**, **Hyprland**, **Sway**, **awww / swww** (Niri / Umbriel / Wayland), and **feh**, and automatic virtual composite **Span** rendering on **Windows 10/11**, **GNOME**, and **Cinnamon**.
   - Places the real-time Date & Time overlay cleanly on the primary monitor rectangle without distortion or clipping.
3. **Smart Pause (Game / Fullscreen & Battery Mode)**:
   - Automatically pauses wallpaper transitions, background source checks, and clock redraws whenever a fullscreen application or game is active (Windows `GetForegroundWindow`, Hyprland `hyprctl`, Sway `swaymsg`, X11 `_NET_WM_STATE_FULLSCREEN`) or while running on battery power (`GetSystemPowerStatus` on Windows, `/sys/class/power_supply/BAT*` on Linux), resuming automatically once exited or plugged in.
4. **Favorites & Permanent Blacklist**:
   - **Save Favorite** copies the active high-resolution wallpaper cleanly into `~/.config/WallCycle/favorites` (or `%APPDATA%\WallCycle\favorites`), with a one-click **Open Favorites Folder** button.
   - **Blacklist** permanently blocks offensive or unwanted wallpapers by both **WallHaven ID (`wh:<id>`)** and file path, immediately deleting matching WallHaven cache files, filtering them out of playlist scans, and skipping them before future downloads (reversible anytime via **Clear Blacklist** in **System & Logs**).
5. **Real-Time Date & Time Overlay & Crisp Downscaling**:
   - Automatically crops and cover-fits images to each monitor's aspect ratio before rendering so the overlay is never clipped off-screen; uses Win32 `HALFTONE` on Windows and a fast scanline **bilinear interpolation** resampler on Linux for sharp 4K/8K downscaling.
   - Anti-aliased bitmap clock & date rendering with customizable fonts, sizes, edge margin, corner placement, and backdrop opacity/transparent mode.
6. **WallHaven.cc + Luminance Filter**:
   - Supports `X-API-Key`, **Categories** (`General`, `Anime`, `People`), **Purity** (`SFW`, `Sketchy`, `NSFW`), **Min Res** (`Auto (Screen)` or manual resolution), **Aspect Ratio** (`16x9`, `16x10`, `21x9`, `9x16`, `landscape`, `portrait`), multi-page depth (`1..25`), **Max cached** (`5..2000`), oldest-first cache pruning by local creation date, hex-encoded cache folder slugs for special characters like `id:26654`, non-blocking background fetching, and automatic **daily source recheck**.
   - Fast pre-filtering using WallHaven's dominant `colors` palette prior to downloading plus pixel-level **ITU-R BT.709** luminance checks across the full image and left 24% desktop icon column; auto-prunes deleted files from `luminance_cache.json`.
7. **Tray Icon, Dynamic Tooltip, Single Instance & CLI Flags (`TUniqueInstance`)**:
   - Tray tooltip dynamically shows the active wallpaper filename and Pause / Smart Pause state.
   - Single-click Tray Icon advances to the next wallpaper; context menu includes **Save Current to Favorites**, **Blacklist Current Wallpaper**, **Open Info on WallHaven.cc**, and **Open Favorites Folder**.
   - Desktop right-click quick actions via `wallcycle.desktop` and CLI flags forwarded through `TUniqueInstance`: `--next` (`-n`), `--previous` (`-p`), `--pause`, `--resume`, `--toggle-pause`, `--favorite` (`-f`), `--blacklist` (`-b`), `--apply`, `--fetch`, `--info` (`-i`), `--show`, `--minimized`, `--quit`.

## Building

### Lazarus Prerequisites
- Install **UniqueInstance** (`uniqueinstance_package`) via *Package -> Online Package Manager (OPM)* in Lazarus.

### From Lazarus IDE
1. Open `WallCycle.lpi` in Lazarus (`File -> Open`).
2. Press `F9` (Run) or `Ctrl+F9` (Build).

### From Terminal (`lazbuild`)
```bash
# Linux (GTK2 / Qt5)
lazbuild --build-mode=Release WallCycle.lpi

# Windows
lazbuild --build-mode=Release WallCycle.lpi
```

### Runtime Dependencies (Linux & Windows)
- HTTPS for WallHaven: `curl` (`curl.exe` is built into Windows 10/11, or `curl`/`wget` on Linux), requiring no external OpenSSL DLLs or `libssl` bindings in FPC.
- Linux compositor backend matching your DE (`gsettings`, `qdbus6`/`qdbus`, `xfconf-query`, `awww`, `hyprpaper`, `swaymsg`, `feh`).

## Release Packages (`.deb`, `.rpm`, Windows `.exe`, AUR)

Ready-to-use packaging files are included in the repository:
- **Debian / Ubuntu (`.deb`)**: `./build-deb.sh 1.0.0` (after running `lazbuild --build-mode=Release WallCycle.lpi`).
- **Fedora & openSUSE (`.rpm`)**: `wallcycle.spec` automatically handles `gtk2`/`curl` (Fedora) and `libgtk-2_0-0`/`curl` (openSUSE) dependencies.
- **Windows 64-bit Installer (`.exe`)**: `wallcycle.iss` for Inno Setup 6 (no external DLLs needed thanks to native Windows `curl.exe`, with an optional registry autostart task).
- **Arch Linux AUR**: `PKGBUILD` + `wallcycle.desktop`.
- **CI/CD GitHub Releases**: copy `github-release.yml` to `.github/workflows/release.yml` in your GitHub repository; pushing a version tag (`git tag v1.0.0 && git push --tags`) automatically builds and attaches `.deb`, `.rpm` (Fedora + openSUSE), and `WallCycle-Setup-x64.exe` to the Release.
