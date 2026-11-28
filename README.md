# WallCycle — Cross-Platform Desktop Wallpaper Manager + OpenGL 3.3 Shader Engine (Lazarus / FPC)


https://github.com/user-attachments/assets/75315b4a-9389-4e44-b50f-3c20facc01c6


Native desktop application written in **Object Pascal (Free Pascal 3.2+ / Lazarus 3.x)** to run an automatic wallpaper slideshow from local folders and **WallHaven.cc**, featuring a **60 FPS OpenGL 3.3 Core GLSL Shader Transition Engine**, a **real-time Date & Time overlay**, **multi-monitor support**, **Smart Pause**, **Favorites & Blacklist**, and a **perceived-luminance filter (ITU-R BT.709)** to protect desktop icon readability.

## Key Features

1. **OpenGL 3.3 Core GPU Shader Engine + Classic OS Backend Fallback**:
   - Dedicated background OpenGL 3.3 render thread (`uLiveWallpaper.pas`, `uShaderEngine.pas`) driving a **Wayland `zwlr_layer_shell_v1` BACKGROUND layer** (`uWaylandLayer.pas`, EGL + non-variadic `wl_proxy_marshal_array*`, compatible with **GTK2 / Qt5 / Qt6** main-thread LCL UI) and **Windows `WorkerW`** (`uWinWallpaper.pas`).
   - All **10 GLSL `#version 330 core` shaders** are embedded directly inside `uShaderEngine.pas` (with optional external `shaders/` folder overrides): **Crossfade**, **Wipe**, **Slide Left**, **Slide Right**, **Expand from Center**, **Film Burn**, **Natural Wave**, **Rain Melt**, **Ink Dissolve**, and **Prism Wipe** (plus **Random** across all 10).
   - Automatic transparent fallback to classic OS backends (`gsettings`, `qdbus`, `xfconf-query`, `awww`, `swww`, `hyprpaper`, `swaymsg`, `feh`, `nitrogen`, `SystemParametersInfoW`) whenever `zwlr_layer_shell_v1` or OpenGL 3.3 is unavailable (e.g., GNOME Wayland or X11) or unchecked in **System & Logs**.
2. **Multi-Folder Slideshow, Real History & Multi-Monitor Support**:
   - Mix multiple local folders and WallHaven.cc feeds; navigate exact **Previous Wallpaper** history.
   - **Primary (Mirror)**, **Per-Monitor (Distinct)**, and **Span All Displays** modes with aspect-ratio cover fit and real-time **Date & Time overlay** rendered cleanly before GPU texture upload.
3. **Smart Pause, Favorites, Blacklist & Luminance Filter (ITU-R BT.709)**:
   - Automatic Smart Pause on fullscreen games/apps or battery power; permanent `wh:<id>` & path blacklist; one-click Favorites copy; pixel-level + left 24% icon-zone darkness filter.
4. **Tray Icon, Single Instance & CLI Flags (`TUniqueInstance`)**:
   - CLI control via `--next`, `--previous`, `--pause`, `--resume`, `--toggle-pause`, `--favorite`, `--blacklist`, `--apply`, `--fetch`, `--info`, `--show`, `--minimized`, `--quit`.



https://github.com/user-attachments/assets/9e37effa-c845-46a4-9ab8-65b7ffe840bf


Other transition not covered on desktop recording

## Building

### Lazarus Prerequisites
- Install **UniqueInstance** (`uniqueinstance_package`) via *Package -> Online Package Manager (OPM)* in Lazarus.

### From Lazarus IDE or Terminal (`lazbuild`)
```bash
# Linux (GTK2 / Qt5 / Qt6)
lazbuild --build-mode=Release WallCycle.lpi

# Windows
lazbuild --build-mode=Release WallCycle.lpi
```

### Runtime Dependencies (Linux & Windows)
- **OpenGL Live Engine on Wayland**: `libwayland-client0`, `libwayland-egl1`, `libegl1` (dynamically loaded via `dynlibs` only when `WAYLAND_DISPLAY` is active).
- **HTTPS for WallHaven**: `curl` (`curl.exe` is built into Windows 10/11).
- **Fallback compositor backend**: `gsettings`, `qdbus6`/`qdbus`, `xfconf-query`, `awww`, `hyprpaper`, `swaymsg`, `feh`.
