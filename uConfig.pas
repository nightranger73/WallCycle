unit uConfig;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Contnrs, fpjson, jsonparser;

type
  TOverlayCorner = (ocTopLeft, ocTopRight, ocBottomLeft, ocBottomRight);

  TWallpaperTransition = (
    wtNone,
    wtFade,
    wtWipe,
    wtLeft,
    wtRight,
    wtCenter,
    wtRandom
  );

  TLinuxBackendMode = (
    lbAuto,
    lbGnome,
    lbCinnamon,
    lbMate,
    lbKDE,
    lbXFCE,
    lbHyprland,
    lbSway,
    lbNiri,
    lbUmbriel,
    lbAwww,
    lbSwww,
    lbFeh,
    lbNitrogen
  );

  TSourceKind = (skLocalFolder, skWallHaven);

  TWallpaperSource = class
  public
    Enabled: Boolean;
    Kind: TSourceKind;
    Target: string;     // Path for skLocalFolder, Query string for skWallHaven
    Sorting: string;    // 'random', 'toplist', 'favorites', 'views'
    Categories: string; // '100', '110', '111'
    Purity: string;     // '100'
    constructor Create(AEnabled: Boolean; AKind: TSourceKind; const ATarget: string;
      const ASorting: string = 'toplist'; const ACategories: string = '100';
      const APurity: string = '100');
    function DisplayLabel: string;
    function GetWallHavenSubDir(const BaseCacheDir: string): string;
  end;

  TWallCycleConfig = class
  public
    IntervalMinutes: Integer;
    IncludeSubfolders: Boolean;
    ShuffleOrder: Boolean;
    TransitionStyle: TWallpaperTransition;
    TransitionDurationMs: Integer;
    Sources: TObjectList; // Owns TWallpaperSource items

    // Date & Time overlay preferences
    OverlayEnabled: Boolean;
    OverlayCorner: TOverlayCorner;
    OverlayDateFormat: string;
    OverlayTimeFormat: string;
    OverlayShowSeconds: Boolean;
    OverlayTimeFontName: string;
    OverlayTimeFontSize: Integer;
    OverlayDateFontName: string;
    OverlayDateFontSize: Integer;
    OverlayBackdropOpacity: Byte; // 0..255
    OverlayTransparentBg: Boolean;
    OverlayMarginPx: Integer;

    // Global Luminance / darkness filter (applies to BOTH local PC folders & WallHaven)
    DarkFilterEnabled: Boolean;
    MaxLuminance: Double;         // 0.0..1.0 (ITU-R BT.709)
    CheckIconZone: Boolean;
    IconZoneMaxLuminance: Double; // Stricter threshold for left 24% icon column

    // WallHaven.cc API global credentials, filters & cache
    WallHavenApiKey: string;
    WallHavenAtLeast: string;        // e.g. '1920x1080'
    WallHavenCategories: string;     // '100'..'111' (General, Anime, People)
    WallHavenPurity: string;         // '100'..'111' (SFW, Sketchy, NSFW)
    WallHavenMaxPages: Integer;      // Depth in pages (default 10)
    WallHavenCacheDir: string;
    WallHavenMaxCached: Integer;
    DailySourceRecheck: Boolean;
    LastDailyRecheckUtc: Int64;

    // OS Backend preferences
    LinuxBackend: TLinuxBackendMode;
    StartMinimized: Boolean;
    AutoStart: Boolean;

    constructor Create;
    destructor Destroy; override;
    function GetConfigFilePath: string;
    function GetDefaultCacheDir: string;
    function GetSource(Index: Integer): TWallpaperSource;
    procedure AddLocalFolder(const DirPath: string; AEnabled: Boolean = True);
    procedure AddWallHavenSource(const Query, Sorting, Categories, Purity: string;
      AEnabled: Boolean = True);
    procedure Load;
    procedure Save;
  end;

function CornerToStr(C: TOverlayCorner): string;
function StrToCorner(const S: string): TOverlayCorner;
function TransitionToStr(T: TWallpaperTransition): string;
function StrToTransition(const S: string): TWallpaperTransition;
function BackendToStr(B: TLinuxBackendMode): string;
function StrToBackend(const S: string): TLinuxBackendMode;
function SourceKindToStr(K: TSourceKind): string;
function StrToSourceKind(const S: string): TSourceKind;

implementation

function CornerToStr(C: TOverlayCorner): string;
begin
  case C of
    ocTopLeft: Result := 'top-left';
    ocTopRight: Result := 'top-right';
    ocBottomLeft: Result := 'bottom-left';
    ocBottomRight: Result := 'bottom-right';
  else
    Result := 'top-right';
  end;
end;

function StrToCorner(const S: string): TOverlayCorner;
begin
  if S = 'top-left' then Exit(ocTopLeft);
  if S = 'bottom-left' then Exit(ocBottomLeft);
  if S = 'bottom-right' then Exit(ocBottomRight);
  Result := ocTopRight;
end;

function TransitionToStr(T: TWallpaperTransition): string;
begin
  case T of
    wtNone: Result := 'none';
    wtFade: Result := 'fade';
    wtWipe: Result := 'wipe';
    wtLeft: Result := 'left';
    wtRight: Result := 'right';
    wtCenter: Result := 'center';
    wtRandom: Result := 'random';
  else
    Result := 'fade';
  end;
end;

function StrToTransition(const S: string): TWallpaperTransition;
var
  LowS: string;
begin
  LowS := LowerCase(Trim(S));
  if LowS = 'none' then Exit(wtNone);
  if LowS = 'wipe' then Exit(wtWipe);
  if LowS = 'left' then Exit(wtLeft);
  if LowS = 'right' then Exit(wtRight);
  if LowS = 'center' then Exit(wtCenter);
  if LowS = 'random' then Exit(wtRandom);
  Result := wtFade;
end;

function BackendToStr(B: TLinuxBackendMode): string;
begin
  case B of
    lbAuto: Result := 'auto';
    lbGnome: Result := 'gnome';
    lbCinnamon: Result := 'cinnamon';
    lbMate: Result := 'mate';
    lbKDE: Result := 'kde';
    lbXFCE: Result := 'xfce';
    lbHyprland: Result := 'hyprland';
    lbSway: Result := 'sway';
    lbNiri: Result := 'niri';
    lbUmbriel: Result := 'umbriel';
    lbAwww: Result := 'awww';
    lbSwww: Result := 'swww';
    lbFeh: Result := 'feh';
    lbNitrogen: Result := 'nitrogen';
  else
    Result := 'auto';
  end;
end;

function StrToBackend(const S: string): TLinuxBackendMode;
begin
  if S = 'gnome' then Exit(lbGnome);
  if S = 'cinnamon' then Exit(lbCinnamon);
  if S = 'mate' then Exit(lbMate);
  if S = 'kde' then Exit(lbKDE);
  if S = 'xfce' then Exit(lbXFCE);
  if S = 'hyprland' then Exit(lbHyprland);
  if S = 'sway' then Exit(lbSway);
  if S = 'niri' then Exit(lbNiri);
  if S = 'umbriel' then Exit(lbUmbriel);
  if S = 'awww' then Exit(lbAwww);
  if S = 'swww' then Exit(lbSwww);
  if S = 'feh' then Exit(lbFeh);
  if S = 'nitrogen' then Exit(lbNitrogen);
  Result := lbAuto;
end;

function SourceKindToStr(K: TSourceKind): string;
begin
  if K = skWallHaven then
    Result := 'wallhaven'
  else
    Result := 'local';
end;

function StrToSourceKind(const S: string): TSourceKind;
begin
  if LowerCase(S) = 'wallhaven' then
    Result := skWallHaven
  else
    Result := skLocalFolder;
end;

{ TWallpaperSource }

constructor TWallpaperSource.Create(AEnabled: Boolean; AKind: TSourceKind;
  const ATarget: string; const ASorting: string; const ACategories: string;
  const APurity: string);
begin
  inherited Create;
  Enabled := AEnabled;
  Kind := AKind;
  Target := ATarget;
  Sorting := ASorting;
  Categories := ACategories;
  Purity := APurity;
end;

function TWallpaperSource.DisplayLabel: string;
begin
  if Kind = skWallHaven then
    Result := Format('[WallHaven.cc] "%s" (%s · Cat:%s · Pur:%s)',
      [Target, Sorting, Categories, Purity])
  else
    Result := '[PC Folder] ' + Target;
end;

function EncodePathSlug(const Raw: string): string;
var
  I: Integer;
  Ch: Char;
  HashVal: Cardinal;
begin
  Result := '';
  HashVal := 2166136261;
  for I := 1 to Length(Raw) do
  begin
    Ch := Raw[I];
    HashVal := (HashVal xor Ord(Ch)) * 16777619;
    if Ch in ['A'..'Z'] then
      Result := Result + Chr(Ord(Ch) + 32)
    else if Ch in ['a'..'z', '0'..'9', '-'] then
      Result := Result + Ch
    else if Ch = ' ' then
      Result := Result + '_'
    else
      Result := Result + '_' + LowerCase(IntToHex(Ord(Ch), 2));
  end;

  while (Length(Result) > 0) and (Result[1] = '_') do
    Delete(Result, 1, 1);
  while (Length(Result) > 0) and (Result[Length(Result)] = '_') do
    Delete(Result, Length(Result), 1);

  if Result = '' then
    Result := 'default';

  if Length(Result) > 64 then
    Result := Copy(Result, 1, 55) + '_' + LowerCase(IntToHex(HashVal, 8));
end;

function TWallpaperSource.GetWallHavenSubDir(const BaseCacheDir: string): string;
var
  Slug, SortSlug: string;
begin
  Slug := EncodePathSlug(Target);
  SortSlug := EncodePathSlug(Sorting);
  Result := IncludeTrailingPathDelimiter(BaseCacheDir) + Slug + '_' + SortSlug;
end;

{ TWallCycleConfig }

constructor TWallCycleConfig.Create;
begin
  inherited Create;
  Sources := TObjectList.Create(True);

  IntervalMinutes := 15;
  IncludeSubfolders := True;
  ShuffleOrder := True;
  TransitionStyle := wtFade;
  TransitionDurationMs := 600;

  OverlayEnabled := True;
  OverlayCorner := ocTopRight;
  OverlayDateFormat := 'ddd dd mmm yyyy';
  OverlayTimeFormat := 'hh:nn';
  OverlayShowSeconds := False;
  OverlayTimeFontName := 'Sans';
  OverlayTimeFontSize := 32;
  OverlayDateFontName := 'Sans';
  OverlayDateFontSize := 14;
  OverlayBackdropOpacity := 175;
  OverlayTransparentBg := False;
  OverlayMarginPx := 40;

  DarkFilterEnabled := True;
  MaxLuminance := 0.38;
  CheckIconZone := True;
  IconZoneMaxLuminance := 0.32;

  WallHavenApiKey := '';
  WallHavenAtLeast := '1920x1080';
  WallHavenCategories := '100';
  WallHavenPurity := '100';
  WallHavenMaxPages := 10;
  WallHavenCacheDir := GetDefaultCacheDir;
  WallHavenMaxCached := 100;
  DailySourceRecheck := True;
  LastDailyRecheckUtc := 0;

  LinuxBackend := lbAuto;
  StartMinimized := False;
  AutoStart := False;

  // Default WallHaven source
  AddWallHavenSource('dark landscape', 'toplist', '100', '100', False);
end;

destructor TWallCycleConfig.Destroy;
begin
  Sources.Free;
  inherited Destroy;
end;

function TWallCycleConfig.GetConfigFilePath: string;
var
  Dir: string;
begin
  Dir := IncludeTrailingPathDelimiter(GetAppConfigDir(False));
  ForceDirectories(Dir);
  Result := Dir + 'wallcycle.json';
end;

function TWallCycleConfig.GetDefaultCacheDir: string;
begin
  Result := IncludeTrailingPathDelimiter(GetAppConfigDir(False)) + 'wallhaven_cache';
end;

function TWallCycleConfig.GetSource(Index: Integer): TWallpaperSource;
begin
  Result := TWallpaperSource(Sources[Index]);
end;

procedure TWallCycleConfig.AddLocalFolder(const DirPath: string; AEnabled: Boolean);
var
  I: Integer;
  Src: TWallpaperSource;
begin
  for I := 0 to Sources.Count - 1 do
  begin
    Src := GetSource(I);
    if (Src.Kind = skLocalFolder) and (Src.Target = DirPath) then
    begin
      if AEnabled then Src.Enabled := True;
      Exit;
    end;
  end;
  Sources.Add(TWallpaperSource.Create(AEnabled, skLocalFolder, DirPath));
end;

procedure TWallCycleConfig.AddWallHavenSource(const Query, Sorting, Categories,
  Purity: string; AEnabled: Boolean);
var
  I: Integer;
  Src: TWallpaperSource;
  Q: string;
begin
  Q := Trim(Query);
  if Q = '' then Exit;
  for I := 0 to Sources.Count - 1 do
  begin
    Src := GetSource(I);
    if (Src.Kind = skWallHaven) and (SameText(Src.Target, Q)) and
       (SameText(Src.Sorting, Sorting)) then
    begin
      Src.Categories := Categories;
      Src.Purity := Purity;
      if AEnabled then Src.Enabled := True;
      Exit;
    end;
  end;
  Sources.Add(TWallpaperSource.Create(AEnabled, skWallHaven, Q, Sorting, Categories, Purity));
end;

procedure TWallCycleConfig.Load;
var
  Path: string;
  FS: TFileStream;
  Data: TJSONData;
  Obj, SrcObj: TJSONObject;
  Arr: TJSONArray;
  I, LegacySize: Integer;
  LegacyFont: string;
begin
  Path := GetConfigFilePath;
  if not FileExists(Path) then Exit;

  Data := nil;
  FS := TFileStream.Create(Path, fmOpenRead or fmShareDenyWrite);
  try
    Data := GetJSON(FS);
    if not (Data is TJSONObject) then Exit;
    Obj := TJSONObject(Data);

    IntervalMinutes := Obj.Get('intervalMinutes', IntervalMinutes);
    if IntervalMinutes < 1 then IntervalMinutes := 1;
    IncludeSubfolders := Obj.Get('includeSubfolders', IncludeSubfolders);
    ShuffleOrder := Obj.Get('shuffleOrder', ShuffleOrder);
    TransitionStyle := StrToTransition(Obj.Get('transitionStyle', TransitionToStr(TransitionStyle)));
    TransitionDurationMs := Obj.Get('transitionDurationMs', TransitionDurationMs);
    if TransitionDurationMs < 200 then TransitionDurationMs := 200;
    if TransitionDurationMs > 3000 then TransitionDurationMs := 3000;

    Arr := Obj.Get('sources', TJSONArray(nil));
    if Arr <> nil then
    begin
      Sources.Clear;
      for I := 0 to Arr.Count - 1 do
      begin
        if not (Arr.Items[I] is TJSONObject) then Continue;
        SrcObj := TJSONObject(Arr.Items[I]);
        Sources.Add(TWallpaperSource.Create(
          SrcObj.Get('enabled', True),
          StrToSourceKind(SrcObj.Get('kind', 'local')),
          SrcObj.Get('target', ''),
          SrcObj.Get('sorting', 'toplist'),
          SrcObj.Get('categories', '100'),
          SrcObj.Get('purity', '100')
        ));
      end;
    end
    else
    begin
      // Backwards compatibility with legacy config
      Arr := Obj.Get('folders', TJSONArray(nil));
      if Arr <> nil then
      begin
        Sources.Clear;
        for I := 0 to Arr.Count - 1 do
          if DirectoryExists(Arr.Strings[I]) then
            AddLocalFolder(Arr.Strings[I], True);
      end;
    end;

    OverlayEnabled := Obj.Get('overlayEnabled', OverlayEnabled);
    OverlayCorner := StrToCorner(Obj.Get('overlayCorner', CornerToStr(OverlayCorner)));
    OverlayDateFormat := Obj.Get('overlayDateFormat', OverlayDateFormat);
    OverlayTimeFormat := Obj.Get('overlayTimeFormat', OverlayTimeFormat);
    OverlayShowSeconds := Obj.Get('overlayShowSeconds', OverlayShowSeconds);
    LegacyFont := Obj.Get('overlayFontName', 'Sans');
    LegacySize := Obj.Get('overlayFontSize', 32);
    OverlayTimeFontName := Obj.Get('overlayTimeFontName', LegacyFont);
    OverlayTimeFontSize := Obj.Get('overlayTimeFontSize', LegacySize);
    if OverlayTimeFontSize < 10 then OverlayTimeFontSize := 10;
    if OverlayTimeFontSize > 144 then OverlayTimeFontSize := 144;
    OverlayDateFontName := Obj.Get('overlayDateFontName', LegacyFont);
    OverlayDateFontSize := Obj.Get('overlayDateFontSize', Round(LegacySize * 0.44));
    if OverlayDateFontSize < 8 then OverlayDateFontSize := 8;
    if OverlayDateFontSize > 96 then OverlayDateFontSize := 96;
    OverlayBackdropOpacity := Byte(Obj.Get('overlayBackdropOpacity', Integer(OverlayBackdropOpacity)));
    OverlayTransparentBg := Obj.Get('overlayTransparentBg', OverlayTransparentBg);
    OverlayMarginPx := Obj.Get('overlayMarginPx', OverlayMarginPx);

    DarkFilterEnabled := Obj.Get('darkFilterEnabled', DarkFilterEnabled);
    MaxLuminance := Obj.Get('maxLuminance', MaxLuminance);
    CheckIconZone := Obj.Get('checkIconZone', CheckIconZone);
    IconZoneMaxLuminance := Obj.Get('iconZoneMaxLuminance', IconZoneMaxLuminance);

    WallHavenApiKey := Obj.Get('wallHavenApiKey', WallHavenApiKey);
    WallHavenAtLeast := Obj.Get('wallHavenAtLeast', WallHavenAtLeast);
    WallHavenCategories := Obj.Get('wallHavenCategories', WallHavenCategories);
    WallHavenPurity := Obj.Get('wallHavenPurity', WallHavenPurity);
    WallHavenMaxPages := Obj.Get('wallHavenMaxPages', WallHavenMaxPages);
    if WallHavenMaxPages < 1 then WallHavenMaxPages := 1;
    if WallHavenMaxPages > 25 then WallHavenMaxPages := 25;
    WallHavenCacheDir := Obj.Get('wallHavenCacheDir', GetDefaultCacheDir);
    WallHavenMaxCached := Obj.Get('wallHavenMaxCached', WallHavenMaxCached);
    if WallHavenMaxCached < 5 then WallHavenMaxCached := 5;
    if WallHavenMaxCached > 2000 then WallHavenMaxCached := 2000;
    DailySourceRecheck := Obj.Get('dailySourceRecheck', DailySourceRecheck);
    LastDailyRecheckUtc := Obj.Get('lastDailyRecheckUtc', LastDailyRecheckUtc);

    LinuxBackend := StrToBackend(Obj.Get('linuxBackend', BackendToStr(LinuxBackend)));
    StartMinimized := Obj.Get('startMinimized', StartMinimized);
    AutoStart := Obj.Get('autoStart', AutoStart);
  finally
    Data.Free;
    FS.Free;
  end;
end;

procedure TWallCycleConfig.Save;
var
  Obj, SrcObj: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
  Src: TWallpaperSource;
  S: string;
  FS: TFileStream;
begin
  Obj := TJSONObject.Create;
  try
    Obj.Add('intervalMinutes', IntervalMinutes);
    Obj.Add('includeSubfolders', IncludeSubfolders);
    Obj.Add('shuffleOrder', ShuffleOrder);
    Obj.Add('transitionStyle', TransitionToStr(TransitionStyle));
    Obj.Add('transitionDurationMs', TransitionDurationMs);

    Arr := TJSONArray.Create;
    for I := 0 to Sources.Count - 1 do
    begin
      Src := GetSource(I);
      SrcObj := TJSONObject.Create;
      SrcObj.Add('enabled', Src.Enabled);
      SrcObj.Add('kind', SourceKindToStr(Src.Kind));
      SrcObj.Add('target', Src.Target);
      SrcObj.Add('sorting', Src.Sorting);
      SrcObj.Add('categories', Src.Categories);
      SrcObj.Add('purity', Src.Purity);
      Arr.Add(SrcObj);
    end;
    Obj.Add('sources', Arr);

    Obj.Add('overlayEnabled', OverlayEnabled);
    Obj.Add('overlayCorner', CornerToStr(OverlayCorner));
    Obj.Add('overlayDateFormat', OverlayDateFormat);
    Obj.Add('overlayTimeFormat', OverlayTimeFormat);
    Obj.Add('overlayShowSeconds', OverlayShowSeconds);
    Obj.Add('overlayTimeFontName', OverlayTimeFontName);
    Obj.Add('overlayTimeFontSize', OverlayTimeFontSize);
    Obj.Add('overlayDateFontName', OverlayDateFontName);
    Obj.Add('overlayDateFontSize', OverlayDateFontSize);
    Obj.Add('overlayBackdropOpacity', Integer(OverlayBackdropOpacity));
    Obj.Add('overlayTransparentBg', OverlayTransparentBg);
    Obj.Add('overlayMarginPx', OverlayMarginPx);

    Obj.Add('darkFilterEnabled', DarkFilterEnabled);
    Obj.Add('maxLuminance', MaxLuminance);
    Obj.Add('checkIconZone', CheckIconZone);
    Obj.Add('iconZoneMaxLuminance', IconZoneMaxLuminance);

    Obj.Add('wallHavenApiKey', WallHavenApiKey);
    Obj.Add('wallHavenAtLeast', WallHavenAtLeast);
    Obj.Add('wallHavenCategories', WallHavenCategories);
    Obj.Add('wallHavenPurity', WallHavenPurity);
    Obj.Add('wallHavenMaxPages', WallHavenMaxPages);
    Obj.Add('wallHavenCacheDir', WallHavenCacheDir);
    Obj.Add('wallHavenMaxCached', WallHavenMaxCached);
    Obj.Add('dailySourceRecheck', DailySourceRecheck);
    Obj.Add('lastDailyRecheckUtc', LastDailyRecheckUtc);

    Obj.Add('linuxBackend', BackendToStr(LinuxBackend));
    Obj.Add('startMinimized', StartMinimized);
    Obj.Add('autoStart', AutoStart);

    S := Obj.FormatJSON;
    FS := TFileStream.Create(GetConfigFilePath, fmCreate);
    try
      if Length(S) > 0 then
        FS.WriteBuffer(S[1], Length(S));
    finally
      FS.Free;
    end;
  finally
    Obj.Free;
  end;
end;

end.
