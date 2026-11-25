unit uWallpaperBackend;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Process, FileUtil,
  {$IFDEF WINDOWS}
  Windows, Registry,
  {$ENDIF}
  uConfig;

type
  TBackendResult = record
    Success: Boolean;
    BackendName: string;
    CommandExecuted: string;
    Message: string;
  end;

function DetectDesktopEnvironment(Mode: TLinuxBackendMode): string;
function ApplySystemWallpaper(const ImagePath: string;
  Mode: TLinuxBackendMode): TBackendResult;
function IsAutoStartEnabled: Boolean;
function SetAutoStartEnabled(Enabled: Boolean; out Msg: string): Boolean;

implementation

{$IFDEF UNIX}
function ExecCmd(const Exe: string; const Params: array of string;
  out OutputStr: string; WaitExit: Boolean = True): Boolean;
var
  P: TProcess;
  I: Integer;
  S: TStringList;
begin
  Result := False;
  OutputStr := '';
  if Exe = '' then Exit;

  P := TProcess.Create(nil);
  S := TStringList.Create;
  try
    P.Executable := Exe;
    for I := Low(Params) to High(Params) do
      P.Parameters.Add(Params[I]);
    if WaitExit then
      P.Options := [poWaitOnExit, poUsePipes, poStderrToOutPut]
    else
      P.Options := [poNoConsole];
    try
      P.Execute;
      if WaitExit then
      begin
        S.LoadFromStream(P.Output);
        OutputStr := Trim(S.Text);
        Result := (P.ExitStatus = 0);
      end
      else
        Result := True;
    except
      on E: Exception do
      begin
        OutputStr := E.Message;
        Result := False;
      end;
    end;
  finally
    S.Free;
    P.Free;
  end;
end;

function FindExe(const Name: string): string;
begin
  Result := FindDefaultExecutablePath(Name);
end;
{$ENDIF}

function DetectDesktopEnvironment(Mode: TLinuxBackendMode): string;
{$IFDEF UNIX}
var
  XDG, WaylandDisp, HyprSig, SwaySock, NiriSock, UmbrielSock: string;
{$ENDIF}
begin
  {$IFDEF WINDOWS}
  Exit('Windows Desktop (SystemParametersInfoW)');
  {$ENDIF}

  {$IFDEF UNIX}
  if Mode <> lbAuto then
  begin
    case Mode of
      lbGnome: Exit('GNOME (gsettings)');
      lbCinnamon: Exit('Cinnamon (gsettings)');
      lbMate: Exit('MATE (gsettings)');
      lbKDE: Exit('KDE Plasma (qdbus)');
      lbXFCE: Exit('XFCE 4 (xfconf-query)');
      lbHyprland: Exit('Hyprland (hyprpaper / awww / swww)');
      lbSway: Exit('Sway (swaymsg)');
      lbNiri: Exit('Niri (awww)');
      lbUmbriel: Exit('Umbriel (awww)');
      lbAwww: Exit('Wayland (awww)');
      lbSwww: Exit('Wayland (swww)');
      lbFeh: Exit('X11 (feh)');
      lbNitrogen: Exit('X11 (nitrogen)');
    end;
  end;

  HyprSig := GetEnvironmentVariable('HYPRLAND_INSTANCE_SIGNATURE');
  SwaySock := GetEnvironmentVariable('SWAYSOCK');
  NiriSock := GetEnvironmentVariable('NIRI_SOCKET');
  UmbrielSock := GetEnvironmentVariable('UMBRIEL_SOCKET');
  WaylandDisp := GetEnvironmentVariable('WAYLAND_DISPLAY');
  XDG := UpperCase(GetEnvironmentVariable('XDG_CURRENT_DESKTOP') + ' ' +
    GetEnvironmentVariable('DESKTOP_SESSION'));

  if HyprSig <> '' then Exit('Hyprland (hyprpaper / awww / swww)');
  if SwaySock <> '' then Exit('Sway (swaymsg)');
  if (NiriSock <> '') or (Pos('NIRI', XDG) > 0) then Exit('Niri (awww)');
  if (UmbrielSock <> '') or (Pos('UMBRIEL', XDG) > 0) then Exit('Umbriel (awww)');
  if Pos('GNOME', XDG) > 0 then Exit('GNOME (gsettings)');
  if Pos('UBUNTU', XDG) > 0 then Exit('GNOME / Ubuntu (gsettings)');
  if Pos('BUDGIE', XDG) > 0 then Exit('GNOME / Budgie (gsettings)');
  if Pos('CINNAMON', XDG) > 0 then Exit('Cinnamon (gsettings)');
  if Pos('MATE', XDG) > 0 then Exit('MATE (gsettings)');
  if (Pos('KDE', XDG) > 0) or (Pos('PLASMA', XDG) > 0) then Exit('KDE Plasma (qdbus)');
  if Pos('XFCE', XDG) > 0 then Exit('XFCE 4 (xfconf-query)');
  if Pos('LXQT', XDG) > 0 then Exit('LXQt (pcmanfm-qt)');
  if (WaylandDisp <> '') and (FindExe('awww') <> '') then Exit('Wayland (awww)');
  if (WaylandDisp <> '') and (FindExe('swww') <> '') then Exit('Wayland (swww)');
  if FindExe('feh') <> '' then Exit('X11 (feh)');
  if FindExe('nitrogen') <> '' then Exit('X11 (nitrogen)');
  Result := 'Unknown Linux Environment';
  {$ENDIF}
end;

{$IFDEF UNIX}
function ApplyKDE(const ImagePath: string; out CmdLog, Msg: string): Boolean;
var
  QDBus, Script, OutStr: string;
begin
  QDBus := FindExe('qdbus6');
  if QDBus = '' then QDBus := FindExe('qdbus-qt5');
  if QDBus = '' then QDBus := FindExe('qdbus');
  if QDBus = '' then
  begin
    CmdLog := 'qdbus';
    Msg := 'qdbus / qdbus6 not found in PATH';
    Exit(False);
  end;

  Script :=
    'var allDesktops = desktops(); ' +
    'for (var i = 0; i < allDesktops.length; i++) { ' +
    '  var d = allDesktops[i]; ' +
    '  d.wallpaperPlugin = "org.kde.image"; ' +
    '  d.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"]; ' +
    '  d.writeConfig("Image", "file://' + StringReplace(ImagePath, '"', '\"', [rfReplaceAll]) + '"); ' +
    '}';

  CmdLog := QDBus + ' org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript';
  Result := ExecCmd(QDBus, [
    'org.kde.plasmashell',
    '/PlasmaShell',
    'org.kde.PlasmaShell.evaluateScript',
    Script
  ], OutStr);
  Msg := OutStr;
end;

function ApplyXFCE(const ImagePath: string; out CmdLog, Msg: string): Boolean;
var
  Xfconf, OutStr: string;
  Props: TStringList;
  I: Integer;
begin
  Xfconf := FindExe('xfconf-query');
  if Xfconf = '' then
  begin
    CmdLog := 'xfconf-query';
    Msg := 'xfconf-query non trovato nel PATH';
    Exit(False);
  end;

  CmdLog := 'xfconf-query -c xfce4-desktop -l';
  if not ExecCmd(Xfconf, ['-c', 'xfce4-desktop', '-l'], OutStr) then
  begin
    Msg := OutStr;
    Exit(False);
  end;

  Result := False;
  Props := TStringList.Create;
  try
    Props.Text := OutStr;
    for I := 0 to Props.Count - 1 do
    begin
      if (Pos('/last-image', Props[I]) > 0) or (Pos('/image-path', Props[I]) > 0) then
      begin
        if ExecCmd(Xfconf, ['-c', 'xfce4-desktop', '-p', Trim(Props[I]), '-s', ImagePath], OutStr) then
          Result := True;
      end;
    end;
    if Result then
      Msg := 'All XFCE monitors updated'
    else
      Msg := 'No property /last-image found in xfce4-desktop';
  finally
    Props.Free;
  end;
end;

function ApplyAwww(const ImagePath: string; out CmdLog, Msg: string): Boolean;
var
  Awww, Swww, OutStr: string;
begin
  Awww := FindExe('awww');
  if Awww <> '' then
  begin
    // Start awww-daemon if not already running
    if not ExecCmd(Awww, ['query'], OutStr) then
    begin
      if FindExe('awww-daemon') <> '' then
      begin
        ExecCmd(FindExe('awww-daemon'), [], OutStr, False);
        Sleep(250);
      end;
    end;

    CmdLog := 'awww img ' + ImagePath + ' --transition-type fade --transition-duration 0.4';
    Result := ExecCmd(Awww, ['img', ImagePath, '--transition-type', 'fade', '--transition-duration', '0.4'], OutStr);
    Msg := OutStr;
    Exit;
  end;

  // Fallback to swww if user has swww installed instead of awww
  Swww := FindExe('swww');
  if Swww <> '' then
  begin
    CmdLog := 'swww img ' + ImagePath + ' --transition-type fade --transition-duration 0.4';
    Result := ExecCmd(Swww, ['img', ImagePath, '--transition-type', 'fade', '--transition-duration', '0.4'], OutStr);
    Msg := OutStr;
    Exit;
  end;

  CmdLog := 'awww img';
  Msg := 'awww not found in PATH (install awww and start awww-daemon)';
  Result := False;
end;

function ApplyHyprland(const ImagePath: string; out CmdLog, Msg: string): Boolean;
var
  HyprCtl, Awww, Swww, OutStr: string;
begin
  // Prefer awww or swww if daemon is active, else hyprctl hyprpaper
  Awww := FindExe('awww');
  if (Awww <> '') and ExecCmd(Awww, ['query'], OutStr) then
  begin
    CmdLog := 'awww img ' + ImagePath + ' --transition-type fade';
    Result := ExecCmd(Awww, ['img', ImagePath, '--transition-type', 'fade', '--transition-duration', '0.4'], OutStr);
    Msg := OutStr;
    Exit;
  end;

  Swww := FindExe('swww');
  if (Swww <> '') and ExecCmd(Swww, ['query'], OutStr) then
  begin
    CmdLog := 'swww img ' + ImagePath + ' --transition-type fade';
    Result := ExecCmd(Swww, ['img', ImagePath, '--transition-type', 'fade', '--transition-duration', '0.4'], OutStr);
    Msg := OutStr;
    Exit;
  end;

  HyprCtl := FindExe('hyprctl');
  if HyprCtl = '' then
  begin
    CmdLog := 'hyprctl';
    Msg := 'hyprctl, awww e swww not found';
    Exit(False);
  end;

  ExecCmd(HyprCtl, ['hyprpaper', 'preload', ImagePath], OutStr);
  CmdLog := 'hyprctl hyprpaper wallpaper ,' + ImagePath;
  Result := ExecCmd(HyprCtl, ['hyprpaper', 'wallpaper', ',' + ImagePath], OutStr);
  ExecCmd(HyprCtl, ['hyprpaper', 'unload', 'unused'], OutStr);
  Msg := OutStr;
end;
{$ENDIF}

function ApplySystemWallpaper(const ImagePath: string;
  Mode: TLinuxBackendMode): TBackendResult;
{$IFDEF WINDOWS}
var
  Reg: TRegistry;
  WPath: UnicodeString;
{$ENDIF}
{$IFDEF UNIX}
var
  Exe, OutStr, Detected: string;
  TargetMode: TLinuxBackendMode;
{$ENDIF}
begin
  Result.Success := False;
  Result.BackendName := DetectDesktopEnvironment(Mode);
  Result.CommandExecuted := '';
  Result.Message := '';

  if not FileExists(ImagePath) then
  begin
    Result.Message := 'Image not found: ' + ImagePath;
    Exit;
  end;

  {$IFDEF WINDOWS}
  Reg := TRegistry.Create(KEY_WRITE);
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKey('Control Panel\Desktop', True) then
    begin
      Reg.WriteString('WallpaperStyle', '10'); // Fill
      Reg.WriteString('TileWallpaper', '0');
      Reg.CloseKey;
    end;
  finally
    Reg.Free;
  end;

  WPath := UnicodeString(ImagePath);
  Result.CommandExecuted := 'SystemParametersInfoW(SPI_SETDESKWALLPAPER)';
  if SystemParametersInfoW(SPI_SETDESKWALLPAPER, 0, PWideChar(WPath),
    SPIF_UPDATEINIFILE or SPIF_SENDCHANGE) then
  begin
    Result.Success := True;
    Result.Message := 'Windows wallper succesfully updated';
  end
  else
  begin
    Result.Message := 'Win32 Error: ' + SysErrorMessage(GetLastOSError);
  end;
  {$ENDIF}

  {$IFDEF UNIX}
  TargetMode := Mode;
  if TargetMode = lbAuto then
  begin
    Detected := UpperCase(Result.BackendName);
    if Pos('HYPRLAND', Detected) > 0 then TargetMode := lbHyprland
    else if Pos('SWAY', Detected) > 0 then TargetMode := lbSway
    else if Pos('NIRI', Detected) > 0 then TargetMode := lbNiri
    else if Pos('UMBRIEL', Detected) > 0 then TargetMode := lbUmbriel
    else if Pos('GNOME', Detected) > 0 then TargetMode := lbGnome
    else if Pos('CINNAMON', Detected) > 0 then TargetMode := lbCinnamon
    else if Pos('MATE', Detected) > 0 then TargetMode := lbMate
    else if Pos('KDE', Detected) > 0 then TargetMode := lbKDE
    else if Pos('XFCE', Detected) > 0 then TargetMode := lbXFCE
    else if Pos('AWWW', Detected) > 0 then TargetMode := lbAwww
    else if Pos('SWWW', Detected) > 0 then TargetMode := lbSwww
    else if Pos('NITROGEN', Detected) > 0 then TargetMode := lbNitrogen
    else TargetMode := lbFeh;
  end;

  case TargetMode of
    lbGnome:
      begin
        Exe := FindExe('gsettings');
        Result.CommandExecuted := 'gsettings set org.gnome.desktop.background picture-uri file://' + ImagePath;
        Result.Success := ExecCmd(Exe, ['set', 'org.gnome.desktop.background', 'picture-uri', 'file://' + ImagePath], OutStr) and
          ExecCmd(Exe, ['set', 'org.gnome.desktop.background', 'picture-uri-dark', 'file://' + ImagePath], OutStr);
        ExecCmd(Exe, ['set', 'org.gnome.desktop.background', 'picture-options', 'zoom'], OutStr);
        Result.Message := OutStr;
      end;
    lbCinnamon:
      begin
        Exe := FindExe('gsettings');
        Result.CommandExecuted := 'gsettings set org.cinnamon.desktop.background picture-uri file://' + ImagePath;
        Result.Success := ExecCmd(Exe, ['set', 'org.cinnamon.desktop.background', 'picture-uri', 'file://' + ImagePath], OutStr);
        Result.Message := OutStr;
      end;
    lbMate:
      begin
        Exe := FindExe('gsettings');
        Result.CommandExecuted := 'gsettings set org.mate.desktop.background picture-filename ' + ImagePath;
        Result.Success := ExecCmd(Exe, ['set', 'org.mate.desktop.background', 'picture-filename', ImagePath], OutStr);
        Result.Message := OutStr;
      end;
    lbKDE:
      Result.Success := ApplyKDE(ImagePath, Result.CommandExecuted, Result.Message);
    lbXFCE:
      Result.Success := ApplyXFCE(ImagePath, Result.CommandExecuted, Result.Message);
    lbHyprland:
      Result.Success := ApplyHyprland(ImagePath, Result.CommandExecuted, Result.Message);
    lbSway:
      begin
        Exe := FindExe('swaymsg');
        Result.CommandExecuted := 'swaymsg output * bg "' + ImagePath + '" fill';
        Result.Success := ExecCmd(Exe, ['output', '*', 'bg', ImagePath, 'fill'], OutStr);
        Result.Message := OutStr;
      end;
    lbNiri, lbUmbriel, lbAwww:
      Result.Success := ApplyAwww(ImagePath, Result.CommandExecuted, Result.Message);
    lbSwww:
      begin
        Exe := FindExe('swww');
        Result.CommandExecuted := 'swww img ' + ImagePath + ' --transition-type fade';
        Result.Success := ExecCmd(Exe, ['img', ImagePath, '--transition-type', 'fade', '--transition-duration', '0.4'], OutStr);
        Result.Message := OutStr;
      end;
    lbNitrogen:
      begin
        Exe := FindExe('nitrogen');
        Result.CommandExecuted := 'nitrogen --set-zoom-fill --save ' + ImagePath;
        Result.Success := ExecCmd(Exe, ['--set-zoom-fill', '--save', ImagePath], OutStr);
        Result.Message := OutStr;
      end;
  else
    begin
      Exe := FindExe('feh');
      Result.CommandExecuted := 'feh --bg-fill ' + ImagePath;
      Result.Success := ExecCmd(Exe, ['--bg-fill', ImagePath], OutStr);
      Result.Message := OutStr;
    end;
  end;
  {$ENDIF}
end;

{$IFDEF UNIX}
function GetXdgAutostartFilePath: string;
var
  CfgHome: string;
begin
  CfgHome := GetEnvironmentVariable('XDG_CONFIG_HOME');
  if CfgHome = '' then
    CfgHome := IncludeTrailingPathDelimiter(GetUserDir) + '.config';
  Result := IncludeTrailingPathDelimiter(CfgHome) + 'autostart' + PathDelim + 'wallcycle.desktop';
end;
{$ENDIF}

function IsAutoStartEnabled: Boolean;
{$IFDEF WINDOWS}
var
  Reg: TRegistry;
begin
  Result := False;
  Reg := TRegistry.Create(KEY_READ);
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKeyReadOnly('Software\Microsoft\Windows\CurrentVersion\Run') then
    begin
      Result := Reg.ValueExists('WallCycle') and (Trim(Reg.ReadString('WallCycle')) <> '');
      Reg.CloseKey;
    end;
  finally
    Reg.Free;
  end;
end;
{$ENDIF}
{$IFDEF UNIX}
begin
  Result := FileExists(GetXdgAutostartFilePath);
end;
{$ENDIF}

function SetAutoStartEnabled(Enabled: Boolean; out Msg: string): Boolean;
{$IFDEF WINDOWS}
var
  Reg: TRegistry;
  ExeCmdLine: string;
begin
  Result := False;
  Msg := '';
  Reg := TRegistry.Create(KEY_WRITE);
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKey('Software\Microsoft\Windows\CurrentVersion\Run', True) then
    begin
      if Enabled then
      begin
        ExeCmdLine := '"' + ParamStr(0) + '"';
        Reg.WriteString('WallCycle', ExeCmdLine);
        Msg := 'Automatic startup added in Windows Registry (HKCU\...\Run\WallCycle)';
      end
      else
      begin
        if Reg.ValueExists('WallCycle') then
          Reg.DeleteValue('WallCycle');
        Msg := 'Automatic startup removed from Windows Registry';
      end;
      Reg.CloseKey;
      Result := True;
    end
    else
      Msg := 'Unable to open Registry key HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
  except
    on E: Exception do
    begin
      Result := False;
      Msg := 'Windows Registry Error: ' + E.Message;
    end;
  end;
  Reg.Free;
end;
{$ENDIF}
{$IFDEF UNIX}
var
  DesktopPath, AutostartDir: string;
  SL: TStringList;
begin
  Result := False;
  Msg := '';
  DesktopPath := GetXdgAutostartFilePath;
  AutostartDir := ExtractFileDir(DesktopPath);

  if Enabled then
  begin
    try
      ForceDirectories(AutostartDir);
      SL := TStringList.Create;
      try
        SL.Add('[Desktop Entry]');
        SL.Add('Type=Application');
        SL.Add('Version=1.0');
        SL.Add('Name=WallCycle');
        SL.Add('Comment=Desktop wallpaper slideshow with real-time clock overlay');
        SL.Add('Exec="' + ParamStr(0) + '"');
        SL.Add('Icon=preferences-desktop-wallpaper');
        SL.Add('Terminal=false');
        SL.Add('Categories=Utility;DesktopSettings;');
        SL.Add('X-GNOME-Autostart-enabled=true');
        SL.SaveToFile(DesktopPath);
      finally
        SL.Free;
      end;
      Msg := 'Automatic startup enabled: ' + DesktopPath;
      Result := True;
    except
      on E: Exception do
      begin
        Result := False;
        Msg := 'Error setting automatic startup XDG: ' + E.Message;
      end;
    end;
  end
  else
  begin
    if FileExists(DesktopPath) then
    begin
      if DeleteFile(DesktopPath) then
      begin
        Msg := 'Automatic startup disabled: ' + DesktopPath;
        Result := True;
      end
      else
      begin
        Msg := 'Unable to delete ' + DesktopPath;
        Result := False;
      end;
    end
    else
    begin
      Msg := 'Automatic startup already disabled';
      Result := True;
    end;
  end;
end;
{$ENDIF}

end.
