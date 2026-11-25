# WallCycle — Gestore Sfondi Desktop Cross-Platform (Lazarus / FPC)

Applicazione desktop nativa scritta in **Object Pascal (Free Pascal 3.2+ / Lazarus 3.x)** per eseguire uno slideshow automatico di sfondi da cartelle locali e da **WallHaven.cc**, con overlay **Data & Ora aggiornato in tempo reale** e filtro intelligente basato sulla **luminanza percepita (ITU-R BT.709)** per proteggere la leggibilità delle icone sulla scrivania.

## Funzionalità Principali

1. **Slideshow Multi-Cartella**: seleziona una o più cartelle locali (con scansione ricorsiva opzionale e shuffle) e imposta l'intervallo di cambio ogni `X` minuti.
2. **Compatibilità Linux & Windows**:
   - **Windows 10 / 11**: `SystemParametersInfoW(SPI_SETDESKWALLPAPER)` + registro stile `Fill`.
   - **GNOME / Ubuntu / Budgie / Cinnamon / MATE**: `gsettings` (incluse varianti `picture-uri` e `picture-uri-dark`).
   - **KDE Plasma 5 / 6**: scripting D-Bus tramite `qdbus6` / `qdbus`.
   - **XFCE 4**: `xfconf-query` su tutti i monitor in `xfce4-desktop`.
   - **Hyprland**: `awww` / `swww` (se attivi) oppure `hyprctl hyprpaper`.
   - **Niri & Umbriel**: `awww` (avvia automaticamente `awww-daemon` se non attivo, con fallback `swww`).
   - **Sway**: `swaymsg output * bg ... fill`.
   - **Wayland generico / X11**: `awww`, `swww`, `feh`, `nitrogen`.
3. **Overlay Data & Ora in Tempo Reale**: rendering anti-aliased su bitmap con scrim scuro traslucido nell'angolo selezionato (`Top-Left`, `Top-Right`, `Bottom-Left`, `Bottom-Right`), aggiornamento automatico al cambio minuto (o ogni secondo se abilitati i secondi) usando file alternati `_0.png`/`_1.png` per bypassare la cache del compositor.
4. **WallHaven.cc + Filtro Immagini Scure**:
   - Supporta `X-API-Key` nelle preferenze.
   - Pre-filtraggio rapido tramite la palette `colors` restituita dall'API WallHaven prima del download.
   - Verifica pixel-level ITU-R BT.709 (`Y = 0.2126 R + 0.7152 G + 0.0722 B`) su tutto il fotogramma e in particolare sulla colonna sinistra (24%, zona icone desktop). Le immagini troppo chiare vengono scartate automaticamente.
5. **Avvio Automatico Cross-Platform (Tab Sistema & Log)**:
   - Su **Linux**: crea o rimuove automaticamente `~/.config/autostart/wallcycle.desktop` (standard XDG Autostart).
   - Su **Windows**: registra o rimuove `WallCycle` in `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run`.
6. **Tray Icon, Istanza Singola & Parametri CLI (`TUniqueInstance`)**:
   - Clic singolo sulla Tray Icon per passare subito allo sfondo successivo; menu contestuale con **Apri Info su WallHaven.cc** (rileva automaticamente qualsiasi file `wallhaven-<id>.*`, anche in cartelle locali).
   - Impedisce l'avvio di istanze duplicate tramite `TUniqueInstance` (`uniqueinstance_package`).
   - I lanci successivi con parametri vengono inoltrati all'istanza già in esecuzione: `--next`, `--previous`, `--pause`, `--resume`, `--toggle-pause`, `--apply`, `--fetch`, `--info` (`--wallhaven-info` / `--open-wallhaven`), `--show`, `--minimized`, `--quit`.

## Compilazione

### Prerequisiti Lazarus
- Installa **UniqueInstance** (`uniqueinstance_package`) tramite *Pacchetti -> Gestore Pacchetti Online (OPM)* in Lazarus.

### Da Lazarus IDE
1. Apri `WallCycle.lpi` in Lazarus (`File -> Open`).
2. Premi `F9` (Run) o `Ctrl+F9` (Build).

### Da terminale (`lazbuild`)
```bash
# Linux (GTK2 / Qt5)
lazbuild --build-mode=Release WallCycle.lpi

# Windows
lazbuild --build-mode=Release WallCycle.lpi
```

### Dipendenze Runtime (Linux & Windows)
- HTTPS per WallHaven: `curl` (`curl.exe` già incluso nativamente in Windows 10/11, oppure `curl`/`wget` su Linux), senza richiedere DLL OpenSSL esterne né `libssl` su FPC.
- Backend compositor su Linux corrispondente al proprio DE (`gsettings`, `qdbus6`/`qdbus`, `xfconf-query`, `awww`, `hyprpaper`, `swaymsg`, `feh`).

## Pacchetti Release (`.deb`, `.rpm`, Windows `.exe`, AUR)

Nel repository sono inclusi i file di pacchettizzazione pronti:
- **Debian / Ubuntu (`.deb`)**: `./build-deb.sh 1.0.0` (dopo `lazbuild --build-mode=Release WallCycle.lpi`).
- **Fedora & openSUSE (`.rpm`)**: `wallcycle.spec` gestisce automaticamente le dipendenze `gtk2`/`curl` (Fedora) e `libgtk-2_0-0`/`curl` (openSUSE).
- **Windows 64-bit Installer (`.exe`)**: `wallcycle.iss` per Inno Setup 6 (nessuna DLL esterna richiesta grazie a `curl.exe` nativo di Windows, con opzione di avvio automatico nel registro).
- **Arch Linux AUR**: `PKGBUILD` + `wallcycle.desktop`.
- **CI/CD GitHub Releases**: copia `github-release.yml` in `.github/workflows/release.yml` sul tuo repo GitHub; creando un tag (`git tag v1.0.0 && git push --tags`) GitHub compila e allega automaticamente `.deb`, `.rpm` (Fedora + openSUSE) e `WallCycle-Setup-x64.exe` alla Release.
