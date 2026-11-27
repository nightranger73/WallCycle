unit uWallpaperBackend;

{$mode objfpc}{$H+}

interface

uses
  {$IFDEF WINDOWS}
  Windows, Registry,
  {$ENDIF}
  Classes, SysUtils, Math, Process, FileUtil,
  uConfig;

type
  TBackendResult = record
    Success: Boolean;
    BackendName: string;
    CommandExecuted: string;
    Message: string;
  end;

function DetectDesktopEnvironment(Mode: TLinuxBackendMode): string;
function BackendHasNativeTransition(Mode: TLinuxBackendMode): Boolean;
function BackendSupportsPerMonitorFiles(Mode: TLinuxBackendMode): Boolean;
function RecommendedSoftwareTransitionSteps(Mode: TLinuxBackendMode): Integer;

function ApplySystemWallpaper(const ImagePath: string;
  Mode: TLinuxBackendMode; Transition: TWallpaperTransition = wtFade;
  TransitionMs: Integer = 600;
  MultiMode: TMultiMonitorMode = mmPrimary): TBackendResult;

function ApplySystemMultiMonitorWallpapers(const ImagePaths: TStrings;
  Mode: TLinuxBackendMode; MultiMode: TMultiMonitorMode;
  Transition: TWallpaperTransition = wtFade;
  TransitionMs: Integer = 600): TBackendResult;

function IsFullscreenAppActive: Boolean;
function IsRunningOnBattery: Boolean;

function IsAutoStartEnabled: Boolean;
function SetAutoStartEnabled(Enabled: Boolean; out Msg: string): Boolean;

implementation

{$IFDEF WINDOWS}
uses
  Forms;
{$ENDIF}

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
function ResolveEffectiveLinuxMode(Mode: TLinuxBackendMode): TLinuxBackendMode;
var
  Detected: string;
begin
  if Mode <> lbAuto then Exit(Mode);
  Detected := UpperCase(DetectDesktopEnvironment(lbAuto));
  if Pos('HYPRLAND', Detected) > 0 then Result := lbHyprland
  else if Pos('SWAY', Detected) > 0 then Result := lbSway
  else if Pos('NIRI', Detected) > 0 then Result := lbNiri
  else if Pos('UMBRIEL', Detected) > 0 then Result := lbUmbriel
  else if Pos('GNOME', Detected) > 0 then Result := lbGnome
  else if Pos('CINNAMON', Detected) > 0 then Result := lbCinnamon
  else if Pos('MATE', Detected) > 0 then Result := lbMate
  else if Pos('KDE', Detected) > 0 then Result := lbKDE
  else if Pos('XFCE', Detected) > 0 then Result := lbXFCE
  else if Pos('AWWW', Detected) > 0 then Result := lbAwww
  else if Pos('SWWW', Detected) > 0 then Result := lbSwww
  else if Pos('NITROGEN', Detected) > 0 then Result := lbNitrogen
  else Result := lbFeh;
end;

function AwwwTransitionName(T: TWallpaperTransition): string;
begin
  case T of
    wtNone: Result := 'none';
    wtFade: Result := 'fade';
    wtWipe: Result := 'wipe';
    wtLeft: Result := 'left';
    wtRight: Result := 'right';
    wtCenter: Result := 'center';
    wtRandom: Result := 'any';
  else
    Result := 'fade';
  end;
end;

function FormatTransitionSec(Ms: Integer): string;
var
  FS: TFormatSettings;
begin
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';
  Result := FormatFloat('0.00', EnsureRange(Ms, 200, 3000) / 1000.0, FS);
end;
{$ENDIF}

function BackendHasNativeTransition(Mode: TLinuxBackendMode): Boolean;
{$IFDEF UNIX}
var
  Eff: TLinuxBackendMode;
  OutStr: string;
{$ENDIF}
begin
  {$IFDEF WINDOWS}
  Exit(False);
  {$ENDIF}
  {$IFDEF UNIX}
  Eff := ResolveEffectiveLinuxMode(Mode);
  if Eff in [lbNiri, lbUmbriel, lbAwww, lbSwww] then
    Exit(True);
  if Eff = lbHyprland then
  begin
    if (FindExe('awww') <> '') and ExecCmd(FindExe('awww'), ['query'], OutStr) then Exit(True);
    if (FindExe('swww') <> '') and ExecCmd(FindExe('swww'), ['query'], OutStr) then Exit(True);
  end;
  Result := False;
  {$ENDIF}
end;

function BackendSupportsPerMonitorFiles(Mode: TLinuxBackendMode): Boolean;
{$IFDEF UNIX}
var
  Eff: TLinuxBackendMode;
{$ENDIF}
begin
  {$IFDEF WINDOWS}
  Exit(False);
  {$ENDIF}
  {$IFDEF UNIX}
  Eff := ResolveEffectiveLinuxMode(Mode);
  Result := Eff in [lbKDE, lbXFCE, lbHyprland, lbSway, lbNiri, lbUmbriel, lbAwww, lbSwww, lbFeh];
  {$ENDIF}
end;

function RecommendedSoftwareTransitionSteps(Mode: TLinuxBackendMode): Integer;
{$IFDEF UNIX}
var
  Eff: TLinuxBackendMode;
{$ENDIF}
begin
  {$IFDEF WINDOWS}
  Exit(6);
  {$ENDIF}
  {$IFDEF UNIX}
  Eff := ResolveEffectiveLinuxMode(Mode);
  if Eff in [lbFeh, lbNitrogen] then
    Result := 6
  else
    Result := 4;
  {$ENDIF}
end;

{$IFDEF UNIX}
function ApplyKDEMulti(const ImagePaths: TStrings; out CmdLog, Msg: string): Boolean;
var
  QDBus, Script, PathsArrayJS, OutStr, EscPath: string;
  I: Integer;
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

  PathsArrayJS := '[';
  for I := 0 to ImagePaths.Count - 1 do
  begin
    EscPath := StringReplace(ImagePaths[I], '\', '\\', [rfReplaceAll]);
    EscPath := StringReplace(EscPath, '"', '\"', [rfReplaceAll]);
    if I > 0 then PathsArrayJS := PathsArrayJS + ',';
    PathsArrayJS := PathsArrayJS + '"file://' + EscPath + '"';
  end;
  PathsArrayJS := PathsArrayJS + ']';

  Script :=
    'var imgs = ' + PathsArrayJS + '; ' +
    'var allDesktops = desktops(); ' +
    'for (var i = 0; i < allDesktops.length; i++) { ' +
    '  var d = allDesktops[i]; ' +
    '  d.wallpaperPlugin = "org.kde.image"; ' +
    '  d.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"]; ' +
    '  d.writeConfig("Image", imgs[i % imgs.length]); ' +
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

function ApplyKDE(const ImagePath: string; out CmdLog, Msg: string): Boolean;
var
  SL: TStringList;
begin
  SL := TStringList.Create;
  try
    SL.Add(ImagePath);
    Result := ApplyKDEMulti(SL, CmdLog, Msg);
  finally
    SL.Free;
  end;
end;

function ExtractXfceMonitorPrefix(const PropPath: string): string;
var
  P: Integer;
begin
  // Example: /backdrop/screen0/monitorHDMI-A-1/workspace0/last-image -> /backdrop/screen0/monitorHDMI-A-1/
  Result := '';
  P := Pos('/monitor', PropPath);
  if P = 0 then Exit;
  P := Pos('/', Copy(PropPath, P + 1, Length(PropPath)));
  if P = 0 then Exit;
  Result := Copy(PropPath, 1, Pos('/monitor', PropPath) + P);
end;

function ApplyXFCEMulti(const ImagePaths: TStrings; out CmdLog, Msg: string): Boolean;
var
  Xfconf, OutStr, Prop, Prefix, ImgPath: string;
  Props, Monitors: TStringList;
  I, MonIdx: Integer;
begin
  Xfconf := FindExe('xfconf-query');
  if Xfconf = '' then
  begin
    CmdLog := 'xfconf-query';
    Msg := 'xfconf-query not found in PATH';
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
  Monitors := TStringList.Create;
  try
    Monitors.CaseSensitive := True;
    Props.Text := OutStr;
    for I := 0 to Props.Count - 1 do
    begin
      Prop := Trim(Props[I]);
      if (Pos('/last-image', Prop) > 0) or (Pos('/image-path', Prop) > 0) then
      begin
        Prefix := ExtractXfceMonitorPrefix(Prop);
        if Prefix = '' then Prefix := 'default';
        MonIdx := Monitors.IndexOf(Prefix);
        if MonIdx < 0 then
          MonIdx := Monitors.Add(Prefix);
        ImgPath := ImagePaths[MonIdx mod ImagePaths.Count];
        if ExecCmd(Xfconf, ['-c', 'xfce4-desktop', '-p', Prop, '-s', ImgPath], OutStr) then
          Result := True;
      end;
    end;
    if Result then
      Msg := Format('Updated %d XFCE monitor(s)', [Max(1, Monitors.Count)])
    else
      Msg := 'No /last-image property found in xfce4-desktop';
  finally
    Monitors.Free;
    Props.Free;
  end;
end;

function ApplyXFCE(const ImagePath: string; out CmdLog, Msg: string): Boolean;
var
  SL: TStringList;
begin
  SL := TStringList.Create;
  try
    SL.Add(ImagePath);
    Result := ApplyXFCEMulti(SL, CmdLog, Msg);
  finally
    SL.Free;
  end;
end;

procedure QueryAwwwOutputs(const ExeName: string; Outputs: TStringList);
var
  OutStr, Line, OutName: string;
  Lines: TStringList;
  I, ColonPos: Integer;
begin
  Outputs.Clear;
  if not ExecCmd(ExeName, ['query'], OutStr) then Exit;
  Lines := TStringList.Create;
  try
    Lines.Text := OutStr;
    for I := 0 to Lines.Count - 1 do
    begin
      Line := Trim(Lines[I]);
      if Line = '' then Continue;
      // Format is usually: "DP-1: ..." or "Output DP-1: ..."
      if Pos('Output ', Line) = 1 then
        Delete(Line, 1, 7);
      ColonPos := Pos(':', Line);
      if ColonPos > 1 then
      begin
        OutName := Trim(Copy(Line, 1, ColonPos - 1));
        if (OutName <> '') and (Outputs.IndexOf(OutName) < 0) then
          Outputs.Add(OutName);
      end;
    end;
  finally
    Lines.Free;
  end;
end;

procedure QuerySwayOutputs(const SwayExe: string; Outputs: TStringList);
var
  OutStr, Chunk, OutName: string;
  P, Q1, Q2: Integer;
begin
  Outputs.Clear;
  if not ExecCmd(SwayExe, ['-t', 'get_outputs'], OutStr) then Exit;
  Chunk := OutStr;
  while True do
  begin
    P := Pos('"name":', Chunk);
    if P = 0 then Break;
    Delete(Chunk, 1, P + 6);
    Q1 := Pos('"', Chunk);
    if Q1 = 0 then Break;
    Delete(Chunk, 1, Q1);
    Q2 := Pos('"', Chunk);
    if Q2 = 0 then Break;
    OutName := Trim(Copy(Chunk, 1, Q2 - 1));
    Delete(Chunk, 1, Q2);
    if (OutName <> '') and (Outputs.IndexOf(OutName) < 0) then
      Outputs.Add(OutName);
  end;
end;

procedure QueryHyprOutputs(const HyprCtl: string; Outputs: TStringList);
var
  OutStr, Line, Rest, OutName: string;
  Lines: TStringList;
  I, Sp: Integer;
begin
  Outputs.Clear;
  if not ExecCmd(HyprCtl, ['monitors'], OutStr) then Exit;
  Lines := TStringList.Create;
  try
    Lines.Text := OutStr;
    for I := 0 to Lines.Count - 1 do
    begin
      Line := Trim(Lines[I]);
      if Pos('Monitor ', Line) = 1 then
      begin
        Rest := Trim(Copy(Line, 9, Length(Line)));
        Sp := Pos(' ', Rest);
        if Sp > 1 then
          OutName := Copy(Rest, 1, Sp - 1)
        else
          OutName := Rest;
        if (OutName <> '') and (Outputs.IndexOf(OutName) < 0) then
          Outputs.Add(OutName);
      end;
    end;
  finally
    Lines.Free;
  end;
end;

function RunAwwwMulti(const ExePath: string; const ImagePaths: TStrings;
  Transition: TWallpaperTransition; TransitionMs: Integer;
  out CmdLog, Msg: string): Boolean;
var
  Outputs: TStringList;
  TName, TDur, OutStr, ImgPath: string;
  I: Integer;
begin
  Result := False;
  TName := AwwwTransitionName(Transition);
  TDur := FormatTransitionSec(TransitionMs);
  Outputs := TStringList.Create;
  try
    if ImagePaths.Count > 1 then
      QueryAwwwOutputs(ExePath, Outputs);

    if Outputs.Count > 1 then
    begin
      Result := True;
      for I := 0 to Outputs.Count - 1 do
      begin
        ImgPath := ImagePaths[I mod ImagePaths.Count];
        if Transition = wtNone then
        begin
          if not ExecCmd(ExePath, ['img', '-o', Outputs[I], ImgPath, '--transition-type', 'none'], OutStr) then
            Result := False;
        end
        else
        begin
          if not ExecCmd(ExePath, ['img', '-o', Outputs[I], ImgPath, '--transition-type', TName,
            '--transition-duration', TDur], OutStr) then
            Result := False;
        end;
      end;
      CmdLog := Format('%s img -o <each monitor> (%d outputs)', [ExtractFileName(ExePath), Outputs.Count]);
      Msg := OutStr;
      Exit;
    end;

    ImgPath := ImagePaths[0];
    if Transition = wtNone then
    begin
      CmdLog := ExtractFileName(ExePath) + ' img ' + ImgPath + ' --transition-type none';
      Result := ExecCmd(ExePath, ['img', ImgPath, '--transition-type', 'none'], OutStr);
    end
    else
    begin
      CmdLog := Format('%s img %s --transition-type %s --transition-duration %s',
        [ExtractFileName(ExePath), ImgPath, TName, TDur]);
      Result := ExecCmd(ExePath, ['img', ImgPath, '--transition-type', TName,
        '--transition-duration', TDur], OutStr);
    end;
    Msg := OutStr;
  finally
    Outputs.Free;
  end;
end;

function ApplyAwwwMulti(const ImagePaths: TStrings; Transition: TWallpaperTransition;
  TransitionMs: Integer; out CmdLog, Msg: string): Boolean;
var
  Awww, Swww, OutStr: string;
begin
  Awww := FindExe('awww');
  if Awww <> '' then
  begin
    if not ExecCmd(Awww, ['query'], OutStr) then
    begin
      if FindExe('awww-daemon') <> '' then
      begin
        ExecCmd(FindExe('awww-daemon'), [], OutStr, False);
        Sleep(250);
      end;
    end;
    Result := RunAwwwMulti(Awww, ImagePaths, Transition, TransitionMs, CmdLog, Msg);
    Exit;
  end;

  Swww := FindExe('swww');
  if Swww <> '' then
  begin
    Result := RunAwwwMulti(Swww, ImagePaths, Transition, TransitionMs, CmdLog, Msg);
    Exit;
  end;

  CmdLog := 'awww img';
  Msg := 'awww not found in PATH (install awww and start awww-daemon)';
  Result := False;
end;

function ApplyAwww(const ImagePath: string; Transition: TWallpaperTransition;
  TransitionMs: Integer; out CmdLog, Msg: string): Boolean;
var
  SL: TStringList;
begin
  SL := TStringList.Create;
  try
    SL.Add(ImagePath);
    Result := ApplyAwwwMulti(SL, Transition, TransitionMs, CmdLog, Msg);
  finally
    SL.Free;
  end;
end;

function ApplyHyprlandMulti(const ImagePaths: TStrings; Transition: TWallpaperTransition;
  TransitionMs: Integer; out CmdLog, Msg: string): Boolean;
var
  HyprCtl, Awww, Swww, OutStr, ImgPath: string;
  Outputs: TStringList;
  I: Integer;
begin
  Awww := FindExe('awww');
  if (Awww <> '') and ExecCmd(Awww, ['query'], OutStr) then
  begin
    Result := RunAwwwMulti(Awww, ImagePaths, Transition, TransitionMs, CmdLog, Msg);
    Exit;
  end;

  Swww := FindExe('swww');
  if (Swww <> '') and ExecCmd(Swww, ['query'], OutStr) then
  begin
    Result := RunAwwwMulti(Swww, ImagePaths, Transition, TransitionMs, CmdLog, Msg);
    Exit;
  end;

  HyprCtl := FindExe('hyprctl');
  if HyprCtl = '' then
  begin
    CmdLog := 'hyprctl';
    Msg := 'hyprctl, awww and swww not found';
    Exit(False);
  end;

  Outputs := TStringList.Create;
  try
    if ImagePaths.Count > 1 then
      QueryHyprOutputs(HyprCtl, Outputs);

    if Outputs.Count > 1 then
    begin
      Result := True;
      for I := 0 to Outputs.Count - 1 do
      begin
        ImgPath := ImagePaths[I mod ImagePaths.Count];
        ExecCmd(HyprCtl, ['hyprpaper', 'preload', ImgPath], OutStr);
        if not ExecCmd(HyprCtl, ['hyprpaper', 'wallpaper', Outputs[I] + ',' + ImgPath], OutStr) then
          Result := False;
      end;
      ExecCmd(HyprCtl, ['hyprpaper', 'unload', 'unused'], OutStr);
      CmdLog := Format('hyprctl hyprpaper per monitor (%d outputs)', [Outputs.Count]);
      Msg := OutStr;
      Exit;
    end;

    ImgPath := ImagePaths[0];
    ExecCmd(HyprCtl, ['hyprpaper', 'preload', ImgPath], OutStr);
    CmdLog := 'hyprctl hyprpaper wallpaper ,' + ImgPath;
    Result := ExecCmd(HyprCtl, ['hyprpaper', 'wallpaper', ',' + ImgPath], OutStr);
    ExecCmd(HyprCtl, ['hyprpaper', 'unload', 'unused'], OutStr);
    Msg := OutStr;
  finally
    Outputs.Free;
  end;
end;

function ApplyHyprland(const ImagePath: string; Transition: TWallpaperTransition;
  TransitionMs: Integer; out CmdLog, Msg: string): Boolean;
var
  SL: TStringList;
begin
  SL := TStringList.Create;
  try
    SL.Add(ImagePath);
    Result := ApplyHyprlandMulti(SL, Transition, TransitionMs, CmdLog, Msg);
  finally
    SL.Free;
  end;
end;
{$ENDIF}

function ApplySystemWallpaper(const ImagePath: string;
  Mode: TLinuxBackendMode; Transition: TWallpaperTransition;
  TransitionMs: Integer; MultiMode: TMultiMonitorMode): TBackendResult;
{$IFDEF WINDOWS}
var
  Reg: TRegistry;
  WPath: UnicodeString;
  StyleVal: string;
{$ENDIF}
{$IFDEF UNIX}
var
  Exe, OutStr, PicOpt: string;
  TargetMode: TLinuxBackendMode;
{$ENDIF}
begin
  Result.Success := False;
  Result.BackendName := DetectDesktopEnvironment(Mode);
  Result.CommandExecuted := '';
  Result.Message := '';

  if not FileExists(ImagePath) then
  begin
    Result.Message := 'Image file not found: ' + ImagePath;
    Exit;
  end;

  {$IFDEF WINDOWS}
  if (MultiMode in [mmIndependent, mmSpan]) and (GetSystemMetrics(SM_CMONITORS) > 1) then
    StyleVal := '22' // Span across monitors
  else
    StyleVal := '10'; // Fill

  Reg := TRegistry.Create(KEY_WRITE);
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKey('Control Panel\Desktop', True) then
    begin
      Reg.WriteString('WallpaperStyle', StyleVal);
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
    Result.Message := 'Windows wallpaper updated successfully';
  end
  else
  begin
    Result.Message := 'Win32 error: ' + SysErrorMessage(GetLastOSError);
  end;
  {$ENDIF}

  {$IFDEF UNIX}
  TargetMode := ResolveEffectiveLinuxMode(Mode);
  if MultiMode in [mmIndependent, mmSpan] then
    PicOpt := 'spanned'
  else
    PicOpt := 'zoom';

  case TargetMode of
    lbGnome:
      begin
        Exe := FindExe('gsettings');
        Result.CommandExecuted := 'gsettings set org.gnome.desktop.background picture-uri file://' + ImagePath;
        Result.Success := ExecCmd(Exe, ['set', 'org.gnome.desktop.background', 'picture-uri', 'file://' + ImagePath], OutStr) and
          ExecCmd(Exe, ['set', 'org.gnome.desktop.background', 'picture-uri-dark', 'file://' + ImagePath], OutStr);
        ExecCmd(Exe, ['set', 'org.gnome.desktop.background', 'picture-options', PicOpt], OutStr);
        Result.Message := OutStr;
      end;
    lbCinnamon:
      begin
        Exe := FindExe('gsettings');
        Result.CommandExecuted := 'gsettings set org.cinnamon.desktop.background picture-uri file://' + ImagePath;
        Result.Success := ExecCmd(Exe, ['set', 'org.cinnamon.desktop.background', 'picture-uri', 'file://' + ImagePath], OutStr);
        ExecCmd(Exe, ['set', 'org.cinnamon.desktop.background', 'picture-options', PicOpt], OutStr);
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
      Result.Success := ApplyHyprland(ImagePath, Transition, TransitionMs, Result.CommandExecuted, Result.Message);
    lbSway:
      begin
        Exe := FindExe('swaymsg');
        Result.CommandExecuted := 'swaymsg output * bg "' + ImagePath + '" fill';
        Result.Success := ExecCmd(Exe, ['output', '*', 'bg', ImagePath, 'fill'], OutStr);
        Result.Message := OutStr;
      end;
    lbNiri, lbUmbriel, lbAwww:
      Result.Success := ApplyAwww(ImagePath, Transition, TransitionMs, Result.CommandExecuted, Result.Message);
    lbSwww:
      begin
        Exe := FindExe('swww');
        if Transition = wtNone then
        begin
          Result.CommandExecuted := 'swww img ' + ImagePath + ' --transition-type none';
          Result.Success := ExecCmd(Exe, ['img', ImagePath, '--transition-type', 'none'], OutStr);
        end
        else
        begin
          Result.CommandExecuted := Format('swww img %s --transition-type %s --transition-duration %s',
            [ImagePath, AwwwTransitionName(Transition), FormatTransitionSec(TransitionMs)]);
          Result.Success := ExecCmd(Exe, ['img', ImagePath, '--transition-type', AwwwTransitionName(Transition),
            '--transition-duration', FormatTransitionSec(TransitionMs)], OutStr);
        end;
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

function ApplySystemMultiMonitorWallpapers(const ImagePaths: TStrings;
  Mode: TLinuxBackendMode; MultiMode: TMultiMonitorMode;
  Transition: TWallpaperTransition; TransitionMs: Integer): TBackendResult;
{$IFDEF UNIX}
var
  Exe, OutStr: string;
  TargetMode: TLinuxBackendMode;
  Outputs: TStringList;
  FehArgs: array of string;
  I: Integer;
{$ENDIF}
begin
  Result.Success := False;
  Result.BackendName := DetectDesktopEnvironment(Mode);
  Result.CommandExecuted := '';
  Result.Message := '';

  if (ImagePaths = nil) or (ImagePaths.Count = 0) then
  begin
    Result.Message := 'No image paths supplied.';
    Exit;
  end;

  if ImagePaths.Count = 1 then
  begin
    Result := ApplySystemWallpaper(ImagePaths[0], Mode, Transition, TransitionMs, MultiMode);
    Exit;
  end;

  {$IFDEF WINDOWS}
  Result := ApplySystemWallpaper(ImagePaths[0], Mode, Transition, TransitionMs, MultiMode);
  {$ENDIF}

  {$IFDEF UNIX}
  TargetMode := ResolveEffectiveLinuxMode(Mode);
  case TargetMode of
    lbKDE:
      Result.Success := ApplyKDEMulti(ImagePaths, Result.CommandExecuted, Result.Message);
    lbXFCE:
      Result.Success := ApplyXFCEMulti(ImagePaths, Result.CommandExecuted, Result.Message);
    lbHyprland:
      Result.Success := ApplyHyprlandMulti(ImagePaths, Transition, TransitionMs, Result.CommandExecuted, Result.Message);
    lbSway:
      begin
        Exe := FindExe('swaymsg');
        Outputs := TStringList.Create;
        try
          QuerySwayOutputs(Exe, Outputs);
          if Outputs.Count > 1 then
          begin
            Result.Success := True;
            for I := 0 to Outputs.Count - 1 do
              if not ExecCmd(Exe, ['output', Outputs[I], 'bg',
                ImagePaths[I mod ImagePaths.Count], 'fill'], OutStr) then
                Result.Success := False;
            Result.CommandExecuted := Format('swaymsg output <each> (%d outputs)', [Outputs.Count]);
            Result.Message := OutStr;
          end
          else
            Result := ApplySystemWallpaper(ImagePaths[0], Mode, Transition, TransitionMs, MultiMode);
        finally
          Outputs.Free;
        end;
      end;
    lbNiri, lbUmbriel, lbAwww:
      Result.Success := ApplyAwwwMulti(ImagePaths, Transition, TransitionMs, Result.CommandExecuted, Result.Message);
    lbSwww:
      begin
        Exe := FindExe('swww');
        if Exe <> '' then
          Result.Success := RunAwwwMulti(Exe, ImagePaths, Transition, TransitionMs,
            Result.CommandExecuted, Result.Message)
        else
          Result.Message := 'swww not found in PATH';
      end;
    lbFeh:
      begin
        Exe := FindExe('feh');
        SetLength(FehArgs, ImagePaths.Count + 1);
        FehArgs[0] := '--bg-fill';
        for I := 0 to ImagePaths.Count - 1 do
          FehArgs[I + 1] := ImagePaths[I];
        Result.CommandExecuted := Format('feh --bg-fill (%d files)', [ImagePaths.Count]);
        Result.Success := ExecCmd(Exe, FehArgs, OutStr);
        Result.Message := OutStr;
      end;
  else
    Result := ApplySystemWallpaper(ImagePaths[0], Mode, Transition, TransitionMs, MultiMode);
  end;
  {$ENDIF}
end;

function IsFullscreenAppActive: Boolean;
{$IFDEF WINDOWS}
var
  FG: HWND;
  FgPid: DWORD;
  ClassBuf: array[0..255] of WideChar;
  ClsName: string;
  WinRect: TRect;
  I, MonW, MonH: Integer;
  Mon: TMonitor;
begin
  Result := False;
  FG := GetForegroundWindow;
  if (FG = 0) or (not IsWindowVisible(FG)) or IsIconic(FG) then Exit;
  if FG = GetDesktopWindow then Exit;

  FgPid := 0;
  GetWindowThreadProcessId(FG, @FgPid);
  if FgPid = GetCurrentProcessId then Exit;

  FillChar(ClassBuf, SizeOf(ClassBuf), 0);
  if GetClassNameW(FG, @ClassBuf[0], 255) > 0 then
  begin
    ClsName := string(UnicodeString(PWideChar(@ClassBuf[0])));
    if SameText(ClsName, 'Progman') or SameText(ClsName, 'WorkerW') or
       SameText(ClsName, 'Shell_TrayWnd') or SameText(ClsName, 'Shell_SecondaryTrayWnd') or
       SameText(ClsName, 'Windows.UI.Core.CoreWindow') then
      Exit;
  end;

  if not GetWindowRect(FG, WinRect) then Exit;

  if Assigned(Screen) and (Screen.MonitorCount > 0) then
  begin
    for I := 0 to Screen.MonitorCount - 1 do
    begin
      Mon := Screen.Monitors[I];
      if (WinRect.Left <= Mon.Left) and
         (WinRect.Top <= Mon.Top) and
         (WinRect.Right >= (Mon.Left + Mon.Width)) and
         (WinRect.Bottom >= (Mon.Top + Mon.Height)) then
        Exit(True);
    end;
  end
  else
  begin
    MonW := GetSystemMetrics(SM_CXSCREEN);
    MonH := GetSystemMetrics(SM_CYSCREEN);
    Result := (MonW > 0) and (MonH > 0) and
              (WinRect.Left <= 0) and
              (WinRect.Top <= 0) and
              (WinRect.Right >= MonW) and
              (WinRect.Bottom >= MonH);
  end;
end;
{$ENDIF}
{$IFDEF UNIX}
var
  Exe, OutStr, WinId: string;
  P, Q: Integer;
begin
  Result := False;

  if GetEnvironmentVariable('HYPRLAND_INSTANCE_SIGNATURE') <> '' then
  begin
    Exe := FindExe('hyprctl');
    if (Exe <> '') and ExecCmd(Exe, ['activewindow', '-j'], OutStr) then
    begin
      if (Pos('"fullscreen": 1', OutStr) > 0) or (Pos('"fullscreen": 2', OutStr) > 0) or
         (Pos('"fullscreen":1', OutStr) > 0) or (Pos('"fullscreen":2', OutStr) > 0) or
         (Pos('"fullscreen": true', OutStr) > 0) or (Pos('"fullscreen":true', OutStr) > 0) then
        Exit(True);
    end;
    Exit(False);
  end;

  if GetEnvironmentVariable('SWAYSOCK') <> '' then
  begin
    Exe := FindExe('swaymsg');
    if (Exe <> '') and ExecCmd(Exe, ['-t', 'get_tree'], OutStr) then
    begin
      if (Pos('"fullscreen_mode": 1', OutStr) > 0) or (Pos('"fullscreen_mode":1', OutStr) > 0) then
        Exit(True);
    end;
    Exit(False);
  end;

  if (GetEnvironmentVariable('DISPLAY') <> '') and (GetEnvironmentVariable('WAYLAND_DISPLAY') = '') then
  begin
    Exe := FindExe('xprop');
    if (Exe <> '') and ExecCmd(Exe, ['-root', '_NET_ACTIVE_WINDOW'], OutStr) then
    begin
      P := Pos('0x', OutStr);
      if P > 0 then
      begin
        WinId := Trim(Copy(OutStr, P, 32));
        Q := Pos(',', WinId);
        if Q > 0 then WinId := Trim(Copy(WinId, 1, Q - 1));
        if (WinId <> '') and (WinId <> '0x0') and
           ExecCmd(Exe, ['-id', WinId, '_NET_WM_STATE'], OutStr) then
        begin
          if Pos('_NET_WM_STATE_FULLSCREEN', OutStr) > 0 then
            Exit(True);
        end;
      end;
    end;
  end;
end;
{$ENDIF}

function IsRunningOnBattery: Boolean;
{$IFDEF WINDOWS}
var
  PS: TSystemPowerStatus;
begin
  Result := False;
  FillChar(PS, SizeOf(PS), 0);
  if GetSystemPowerStatus(PS) then
    Result := (PS.ACLineStatus = 0);
end;
{$ENDIF}
{$IFDEF UNIX}
var
  SR: TSearchRec;
  StatusFile, Line: string;
  SL: TStringList;
begin
  Result := False;
  if FindFirst('/sys/class/power_supply/BAT*', faDirectory, SR) = 0 then
  begin
    try
      repeat
        if (SR.Name = '.') or (SR.Name = '..') then Continue;
        StatusFile := '/sys/class/power_supply/' + SR.Name + '/status';
        if FileExists(StatusFile) then
        begin
          SL := TStringList.Create;
          try
            try
              SL.LoadFromFile(StatusFile);
              if SL.Count > 0 then
              begin
                Line := LowerCase(Trim(SL[0]));
                if Line = 'discharging' then
                  Exit(True);
              end;
            except
            end;
          finally
            SL.Free;
          end;
        end;
      until FindNext(SR) <> 0;
    finally
      FindClose(SR);
    end;
  end;
end;
{$ENDIF}

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
        Msg := 'Autostart added to Windows Registry (HKCU\...\Run\WallCycle)';
      end
      else
      begin
        if Reg.ValueExists('WallCycle') then
          Reg.DeleteValue('WallCycle');
        Msg := 'Autostart removed from Windows Registry';
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
      Msg := 'Windows Registry error: ' + E.Message;
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
        SL.Add('Icon=wallcycle');
        SL.Add('Terminal=false');
        SL.Add('Categories=Utility;DesktopSettings;');
        SL.Add('X-GNOME-Autostart-enabled=true');
        SL.SaveToFile(DesktopPath);
      finally
        SL.Free;
      end;
      Msg := 'Autostart enabled: ' + DesktopPath;
      Result := True;
    except
      on E: Exception do
      begin
        Result := False;
        Msg := 'Error writing XDG autostart: ' + E.Message;
      end;
    end;
  end
  else
  begin
    if FileExists(DesktopPath) then
    begin
      if DeleteFile(DesktopPath) then
      begin
        Msg := 'Autostart removed: ' + DesktopPath;
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
      Msg := 'Autostart already disabled';
      Result := True;
    end;
  end;
end;
{$ENDIF}

end.
