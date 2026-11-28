unit uLiveWallpaper;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, SyncObjs, Math, Graphics, IntfGraphics, FPImage,
  uConfig, uShaderEngine
  {$IFDEF WINDOWS}, uWinWallpaper{$ENDIF}
  {$IFDEF LINUX}, uWaylandLayer{$ENDIF};

type
  TLiveEngineStatus = (lesStopped, lesStarting, lesReady, lesFailed);

function BitmapToShaderTexture(Bmp: TBitmap): TShaderTextureData;
function TransitionToShaderName(T: TWallpaperTransition): string;

procedure StartLiveWallpaperEngine;
procedure StopLiveWallpaperEngine;
function GetLiveEngineStatus(out StatusMsg: string): TLiveEngineStatus;
function WaitForLiveEngineReady(TimeoutMs: Integer): Boolean;
function IsLiveEngineReady: Boolean;
function IsLiveEngineTransitioning: Boolean;
function HasLiveEnginePreviousFrame: Boolean;

procedure LivePresentImmediate(const ATex: TShaderTextureData);
procedure LiveTransitionTo(const ANextTex: TShaderTextureData;
  const APrevTex: TShaderTextureData; const AShaderName: string;
  ADurationMs: Integer);

implementation

type
  TPendingMode = (pmNone, pmImmediate, pmTransition);

  TLiveWallpaperThread = class(TThread)
  protected
    procedure Execute; override;
  end;

var
  GLock: TCriticalSection = nil;
  GInitEvent: TEvent = nil;
  GCmdEvent: TEvent = nil;
  GThread: TLiveWallpaperThread = nil;

  GStatus: TLiveEngineStatus = lesStopped;
  GStatusMsg: string = '';

  GPendingMode: TPendingMode = pmNone;
  GPendingTexA: TShaderTextureData;
  GPendingTexB: TShaderTextureData;
  GPendingShader: string = 'fade';
  GPendingDurationMs: Integer = 1000;
  GRequestSeq: QWord = 0;
  GTransitioning: Boolean = False;
  GHasFrameA: Boolean = False;

function BitmapToShaderTexture(Bmp: TBitmap): TShaderTextureData;
var
  IntfImg: TLazIntfImage;
  X, Y, W, H, Idx: Integer;
  Px: TFPColor;
begin
  Result.Width := 0;
  Result.Height := 0;
  SetLength(Result.RGB, 0);
  if (Bmp = nil) or (Bmp.Width <= 0) or (Bmp.Height <= 0) then Exit;

  W := Bmp.Width;
  H := Bmp.Height;
  IntfImg := Bmp.CreateIntfImage;
  try
    if (IntfImg.Width <> W) or (IntfImg.Height <> H) then Exit;
    SetLength(Result.RGB, W * H * 3);
    Idx := 0;
    for Y := 0 to H - 1 do
      for X := 0 to W - 1 do
      begin
        Px := IntfImg.Colors[X, Y];
        Result.RGB[Idx] := Px.Red shr 8;
        Result.RGB[Idx + 1] := Px.Green shr 8;
        Result.RGB[Idx + 2] := Px.Blue shr 8;
        Inc(Idx, 3);
      end;
    Result.Width := W;
    Result.Height := H;
  finally
    IntfImg.Free;
  end;
end;

function TransitionToShaderName(T: TWallpaperTransition): string;
begin
  case T of
    wtFade: Result := 'fade';
    wtWipe: Result := 'wipe';
    wtLeft: Result := 'left';
    wtRight: Result := 'right';
    wtCenter: Result := 'center';
    wtFilmBurn: Result := 'film_burn';
    wtNaturalWave: Result := 'natural_wave';
    wtRainMelt: Result := 'rain_melt';
    wtInkDissolve: Result := 'ink_dissolve';
    wtPrismWipe: Result := 'prism_wipe';
    wtEarthquakeCollapse: Result := 'earthquake_collapse';
    wtPuzzleBuild: Result := 'puzzle_build';
    wtKaleidoPrism: Result := 'kaleido_prism';
    wtBioluminescentSpores: Result := 'bioluminescent_spores';
    wtShatteredGlass: Result := 'shattered_glass';
  else
    Result := 'fade';
  end;
end;

function GetDefaultOverrideShaderDir: string;
var
  ExeDir: string;
begin
  ExeDir := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + 'shaders';
  if DirectoryExists(ExeDir) then
    Result := ExeDir
  else if DirectoryExists('shaders') then
    Result := 'shaders'
  else
    Result := '';
end;

procedure SwapDesktopBuffers;
begin
  {$IFDEF WINDOWS}
  SwapWindowsGLBuffers;
  {$ENDIF}
  {$IFDEF LINUX}
  SwapWaylandEGLBuffers;
  {$ENDIF}
end;

function PollSurfaceEvents: Boolean;
begin
  {$IFDEF WINDOWS}
  Result := PlatformPollEvents;
  {$ELSE}
  {$IFDEF LINUX}
  Result := PlatformPollEvents;
  {$ELSE}
  Result := False;
  {$ENDIF}
  {$ENDIF}
end;

function CheckSurfaceResize(var SurfW, SurfH: Integer): Boolean;
var
  NewW, NewH: Integer;
begin
  Result := False;
  NewW := SurfW;
  NewH := SurfH;
  {$IFDEF WINDOWS}
  if not GetWindowsSurfaceSize(NewW, NewH) then Exit;
  {$ENDIF}
  {$IFDEF LINUX}
  if not GetWaylandSurfaceSize(NewW, NewH) then Exit;
  {$ENDIF}
  if (NewW <> SurfW) or (NewH <> SurfH) then
  begin
    SurfW := NewW;
    SurfH := NewH;
    UpdateShaderViewport(SurfW, SurfH);
    Result := True;
  end;
end;

procedure SetEngineState(AStatus: TLiveEngineStatus; const AMsg: string);
begin
  if GLock = nil then Exit;
  GLock.Enter;
  try
    GStatus := AStatus;
    GStatusMsg := AMsg;
  finally
    GLock.Leave;
  end;
end;

procedure TLiveWallpaperThread.Execute;
var
  SurfW, SurfH, DurMs: Integer;
  PlatformReady, ShaderReady: Boolean;
  Mode: TPendingMode;
  TexA, TexB: TShaderTextureData;
  ShaderName, ErrMsg: string;
  MySeq, CurrentSeq, TransStart, NowTick, FrameStart, FrameCost: QWord;
  Progress, ElapsedSec: Single;
begin
  SurfW := 1920;
  SurfH := 1080;
  PlatformReady := False;
  ShaderReady := False;
  ErrMsg := 'OpenGL desktop layer unsupported on this platform';

  try
    {$IFDEF WINDOWS}
    PlatformReady := InitWindowsWorkerWSurface(SurfW, SurfH);
    if not PlatformReady then
      ErrMsg := GetWinWallpaperLastError;
    {$ENDIF}
    {$IFDEF LINUX}
    PlatformReady := InitWaylandBackgroundSurface(SurfW, SurfH);
    if not PlatformReady then
      ErrMsg := GetWaylandLastError;
    {$ENDIF}

    if not PlatformReady then
    begin
      if ErrMsg = '' then ErrMsg := 'Unable to create desktop OpenGL surface';
      SetEngineState(lesFailed, ErrMsg);
      GInitEvent.SetEvent;
      Exit;
    end;

    InitShaderEngine(SurfW, SurfH, GetDefaultOverrideShaderDir);
    ShaderReady := True;

    {$IFDEF WINDOWS}
    SetEngineState(lesReady, Format('Windows WorkerW OpenGL 3.3 (%dx%d)', [SurfW, SurfH]));
    {$ELSE}
    SetEngineState(lesReady, Format('Wayland zwlr_layer_shell_v1 OpenGL 3.3 (%dx%d)', [SurfW, SurfH]));
    {$ENDIF}
    GInitEvent.SetEvent;

    while (not Terminated) and PollSurfaceEvents do
    begin
      Mode := pmNone;
      TexA.Width := 0;
      TexA.Height := 0;
      SetLength(TexA.RGB, 0);
      TexB.Width := 0;
      TexB.Height := 0;
      SetLength(TexB.RGB, 0);
      ShaderName := 'fade';
      DurMs := 1000;
      MySeq := 0;

      GLock.Enter;
      try
        if GPendingMode <> pmNone then
        begin
          Mode := GPendingMode;
          GPendingMode := pmNone;
          TexA := GPendingTexA;
          TexB := GPendingTexB;
          GPendingTexA.Width := 0;
          GPendingTexA.Height := 0;
          SetLength(GPendingTexA.RGB, 0);
          GPendingTexB.Width := 0;
          GPendingTexB.Height := 0;
          SetLength(GPendingTexB.RGB, 0);
          ShaderName := GPendingShader;
          DurMs := GPendingDurationMs;
          MySeq := GRequestSeq;
        end;
      finally
        GLock.Leave;
      end;

      CheckSurfaceResize(SurfW, SurfH);

      if Mode = pmImmediate then
      begin
        UploadTextureDataA(TexB);
        RenderStaticWallpaper;
        SwapDesktopBuffers;
        GLock.Enter;
        try
          GHasFrameA := HasTextureA;
          GTransitioning := False;
        finally
          GLock.Leave;
        end;
      end
      else if Mode = pmTransition then
      begin
        if (not HasTextureA) and (Length(TexA.RGB) > 0) then
          UploadTextureDataA(TexA);
        UploadTextureDataB(TexB);
        SelectActiveShader(ShaderName);

        GLock.Enter;
        try
          GTransitioning := True;
        finally
          GLock.Leave;
        end;

        // Draw frame 0 first so GPU texture DMA / buffer allocation completes
        // before starting the stopwatch for the configured DurMs duration.
        RenderWallpaperFrame(0.0, 0.0);
        SwapDesktopBuffers;

        TransStart := GetTickCount64;
        while (not Terminated) and PollSurfaceEvents do
        begin
          FrameStart := GetTickCount64;
          GLock.Enter;
          try
            CurrentSeq := GRequestSeq;
          finally
            GLock.Leave;
          end;
          if CurrentSeq <> MySeq then Break;

          CheckSurfaceResize(SurfW, SurfH);
          NowTick := GetTickCount64;
          ElapsedSec := (NowTick - TransStart) / 1000.0;
          Progress := (NowTick - TransStart) / Max(200, DurMs);
          if Progress >= 1.0 then Break;

          RenderWallpaperFrame(Progress, ElapsedSec);
          SwapDesktopBuffers;

          FrameCost := GetTickCount64 - FrameStart;
          if FrameCost < 15 then
            Sleep(Integer(15 - FrameCost));
        end;

        GLock.Enter;
        try
          CurrentSeq := GRequestSeq;
        finally
          GLock.Leave;
        end;

        if (not Terminated) and (CurrentSeq = MySeq) then
        begin
          RenderWallpaperFrame(1.0, Max(200, DurMs) / 1000.0);
          SwapDesktopBuffers;
          PromoteTextureBToA;
          RenderStaticWallpaper;
        end;

        GLock.Enter;
        try
          GHasFrameA := HasTextureA;
          GTransitioning := False;
        finally
          GLock.Leave;
        end;
      end
      else
      begin
        if CheckSurfaceResize(SurfW, SurfH) and HasTextureA then
        begin
          RenderStaticWallpaper;
          SwapDesktopBuffers;
        end;
        GCmdEvent.WaitFor(35);
      end;
    end;
  finally
    GLock.Enter;
    try
      GTransitioning := False;
      GHasFrameA := False;
      if GStatus = lesStarting then
      begin
        GStatus := lesFailed;
        GStatusMsg := ErrMsg;
      end;
    finally
      GLock.Leave;
    end;
    GInitEvent.SetEvent;

    if ShaderReady then
      ShutdownShaderEngine;
    {$IFDEF WINDOWS}
    if PlatformReady then ShutdownWindowsWorkerW;
    {$ENDIF}
    {$IFDEF LINUX}
    if PlatformReady then ShutdownWaylandLayer;
    {$ENDIF}
  end;
end;

procedure StartLiveWallpaperEngine;
begin
  if GThread <> nil then Exit;
  GLock.Enter;
  try
    GStatus := lesStarting;
    GStatusMsg := 'Starting OpenGL 3.3 live engine...';
    GPendingMode := pmNone;
    GTransitioning := False;
    GHasFrameA := False;
  finally
    GLock.Leave;
  end;
  GInitEvent.ResetEvent;
  GCmdEvent.ResetEvent;
  GThread := TLiveWallpaperThread.Create(False);
end;

procedure StopLiveWallpaperEngine;
begin
  if GThread = nil then
  begin
    SetEngineState(lesStopped, '');
    Exit;
  end;
  GThread.Terminate;
  if GCmdEvent <> nil then
    GCmdEvent.SetEvent;
  GThread.WaitFor;
  FreeAndNil(GThread);
  GLock.Enter;
  try
    GStatus := lesStopped;
    GStatusMsg := '';
    GPendingMode := pmNone;
    GTransitioning := False;
    GHasFrameA := False;
  finally
    GLock.Leave;
  end;
end;

function GetLiveEngineStatus(out StatusMsg: string): TLiveEngineStatus;
begin
  if GLock = nil then
  begin
    StatusMsg := '';
    Exit(lesStopped);
  end;
  GLock.Enter;
  try
    Result := GStatus;
    StatusMsg := GStatusMsg;
  finally
    GLock.Leave;
  end;
end;

function WaitForLiveEngineReady(TimeoutMs: Integer): Boolean;
var
  Msg: string;
  St: TLiveEngineStatus;
begin
  St := GetLiveEngineStatus(Msg);
  if St = lesReady then Exit(True);
  if St in [lesStopped, lesFailed] then Exit(False);
  if GInitEvent <> nil then
    GInitEvent.WaitFor(Max(10, TimeoutMs));
  Result := GetLiveEngineStatus(Msg) = lesReady;
end;

function IsLiveEngineReady: Boolean;
var
  Msg: string;
begin
  Result := GetLiveEngineStatus(Msg) = lesReady;
end;

function IsLiveEngineTransitioning: Boolean;
begin
  if GLock = nil then Exit(False);
  GLock.Enter;
  try
    Result := GTransitioning or (GPendingMode = pmTransition);
  finally
    GLock.Leave;
  end;
end;

function HasLiveEnginePreviousFrame: Boolean;
begin
  if GLock = nil then Exit(False);
  GLock.Enter;
  try
    Result := GHasFrameA;
  finally
    GLock.Leave;
  end;
end;

procedure LivePresentImmediate(const ATex: TShaderTextureData);
begin
  if (GLock = nil) or (Length(ATex.RGB) = 0) then Exit;
  GLock.Enter;
  try
    Inc(GRequestSeq);
    GPendingMode := pmImmediate;
    GPendingTexB := ATex;
    GPendingTexA.Width := 0;
    GPendingTexA.Height := 0;
    SetLength(GPendingTexA.RGB, 0);
  finally
    GLock.Leave;
  end;
  if GCmdEvent <> nil then
    GCmdEvent.SetEvent;
end;

procedure LiveTransitionTo(const ANextTex: TShaderTextureData;
  const APrevTex: TShaderTextureData; const AShaderName: string;
  ADurationMs: Integer);
begin
  if (GLock = nil) or (Length(ANextTex.RGB) = 0) then Exit;
  GLock.Enter;
  try
    Inc(GRequestSeq);
    GPendingMode := pmTransition;
    GPendingTexA := APrevTex;
    GPendingTexB := ANextTex;
    GPendingShader := AShaderName;
    GPendingDurationMs := Max(200, ADurationMs);
  finally
    GLock.Leave;
  end;
  if GCmdEvent <> nil then
    GCmdEvent.SetEvent;
end;

initialization
  GLock := TCriticalSection.Create;
  GInitEvent := TEvent.Create(nil, True, False, '');
  GCmdEvent := TEvent.Create(nil, False, False, '');

finalization
  StopLiveWallpaperEngine;
  FreeAndNil(GCmdEvent);
  FreeAndNil(GInitEvent);
  FreeAndNil(GLock);

end.
