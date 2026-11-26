# WallCycle — Cross-Platform Desktop Wallpaper Manager (Lazarus / FPC)
<img width="483" height="580" alt="screenshot_20261125_220719" src="https://github.com/user-attachments/assets/3f6b0306-757e-452c-800f-9fcde7f39c9e" />
<img width="483" height="580" alt="screenshot_20261125_220715" src="https://github.com/user-attachments/assets/ff459f95-100d-444b-b768-54c0f5cf74bb" />

Native desktop application written in **Object Pascal (Free Pascal 3.2+ / Lazarus 3.x)** to run an automatic wallpaper slideshow from local folders and **WallHaven.cc**, featuring a **real-time Date & Time overlay** and a smart **perceived-luminance filter (ITU-R BT.709)** to protect desktop icon readability.

<img width="960" height="640" alt="screenshot_20261125_221259" src="https://github.com/user-attachments/assets/29600b83-4d32-4a5c-b6f0-b111730c801a" />

## Key Features

1. **Multi-Folder Slideshow & Transitions**: select one or more local folders (with optional recursive scanning and shuffle), set the rotation interval every `X` minutes, and choose from 7 transition styles (**None**, **Crossfade**, **Wipe**, **Slide Left**, **Slide Right**, **Expand from Center**, **Random**) with adjustable duration (`200–3000 ms`). Uses native GPU compositor transitions on `awww`/`swww`, and fast multi-step memory blending on Windows, GNOME, KDE, XFCE, and X11.
2. **Linux & Windows Compatibility**:
   - **Windows 10 / 11**: `SystemParametersInfoW(SPI_SETDESKWALLPAPER)` + registry `Fill` wallpaper style.
   - **GNOME / Ubuntu / Budgie / Cinnamon / MATE**: `gsettings` (including both `picture-uri` and `picture-uri-dark`).
   - **KDE Plasma 5 / 6**: D-Bus scripting via `qdbus6` / `qdbus`.
   - **XFCE 4**: `xfconf-query` across all monitors in `xfce4-desktop`.
   - **Hyprland**: `awww` / `swww` (when active) or `hyprctl hyprpaper`.
   - **Niri & Umbriel**: `awww` (automatically launches `awww-daemon` if not running, with `swww` fallback).
   - **Sway**: `swaymsg output * bg ... fill`.
   - **Generic Wayland / X11**: `awww`, `swww`, `feh`, `nitrogen`.
3. **Real-Time Date & Time Overlay**: automatically crops and cover-fits images to the primary monitor resolution before rendering so the overlay is never clipped off-screen; anti-aliased bitmap rendering with a translucent dark scrim in the chosen corner (`Top-Left`, `Top-Right`, `Bottom-Left`, `Bottom-Right`), updated automatically on minute changes (or every second when seconds are enabled) using alternating `_0.png`/`_1.png` files to bypass compositor caching.
4. **WallHaven.cc + Dark Image Filter**:
   - Supports `X-API-Key`, **Categories** (`General`, `Anime`, `People`), **Purity** (`SFW`, `Sketchy`, `NSFW`), multi-page depth (`1..25`), **Max cached** (`5..2000`), non-blocking background fetching, and automatic **daily source recheck** directly from the UI.
   - Fast pre-filtering using the dominant `colors` palette returned by the WallHaven API prior to downloading.
   - Pixel-level ITU-R BT.709 verification (`Y = 0.2126 R + 0.7152 G + 0.0722 B`) across the full frame and specifically on the left column (24%, desktop icon zone). Images that are too bright are automatically skipped.
5. **Cross-Platform Autostart (System & Logs Tab)**:
   - On **Linux**: automatically creates or removes `~/.config/autostart/wallcycle.desktop` (XDG Autostart standard).
   - On **Windows**: adds or removes `WallCycle` in `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run`.
6. **Tray Icon, Single Instance & CLI Flags (`TUniqueInstance`)**:
   - Single-click the Tray Icon to advance immediately to the next wallpaper; context menu includes **Open Info on WallHaven.cc** (automatically detects any `wallhaven-<id>.*` filename, including in local folders).
   - Prevents duplicate instances via `TUniqueInstance` (`uniqueinstance_package`).
   - Subsequent launches with arguments forward commands to the running instance: `--next`, `--previous`, `--pause`, `--resume`, `--toggle-pause`, `--apply`, `--fetch`, `--info` (`--wallhaven-info` / `--open-wallhaven`), `--show`, `--minimized`, `--quit`.

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
- HTTPS for WallHaven: `curl` (`curl.exe` is already built into Windows 10/11, or `curl`/`wget` on Linux), requiring no external OpenSSL DLLs or `libssl` bindings in FPC.
- Linux compositor backend matching your DE (`gsettings`, `qdbus6`/`qdbus`, `xfconf-query`, `awww`, `hyprpaper`, `swaymsg`, `feh`).

## Release Packages (`.deb`, `.rpm`, Windows `.exe`, AUR)

Ready-to-use packaging files are included in the repository:
- **Debian / Ubuntu (`.deb`)**: `./build-deb.sh 1.0.0` (after running `lazbuild --build-mode=Release WallCycle.lpi`).
- **Fedora & openSUSE (`.rpm`)**: `wallcycle.spec` automatically handles `gtk2`/`curl` (Fedora) and `libgtk-2_0-0`/`curl` (openSUSE) dependencies.
- **Windows 64-bit Installer (`.exe`)**: `wallcycle.iss` for Inno Setup 6 (no external DLLs needed thanks to native Windows `curl.exe`, with an optional registry autostart task).
- **Arch Linux AUR**: `PKGBUILD` + `wallcycle.desktop`.
- **CI/CD GitHub Releases**: copy `github-release.yml` to `.github/workflows/release.yml` in your GitHub repository; pushing a version tag (`git tag v1.0.0 && git push --tags`) automatically builds and attaches `.deb`, `.rpm` (Fedora + openSUSE), and `WallCycle-Setup-x64.exe` to the Release.
