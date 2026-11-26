unit uWallHavenClient;

{$mode objfpc}{$H+}

interface

uses
  {$IFDEF WINDOWS}
  Windows,
  {$ENDIF}
  {$IFDEF UNIX}
  BaseUnix,
  {$ENDIF}
  Classes, SysUtils, Math, SyncObjs, Process, FileUtil, fpjson, jsonparser,
  uConfig, uLuminanceFilter;

type
  TWallHavenFetchStats = record
    QueryUrl: string;
    PagesScanned: Integer;
    CandidatesExamined: Integer;
    RejectedByPalette: Integer;
    RejectedByPixels: Integer;
    DownloadedCount: Integer;
    PrunedCount: Integer;
    LastError: string;
  end;

  TWallHavenSourceSnapshot = record
    Target: string;
    Sorting: string;
    Categories: string;
    Purity: string;
    SubDir: string;
  end;

  TWallHavenFetchState = record
    Running: Boolean;
    Finished: Boolean;
    Cancelled: Boolean;
    Stats: TWallHavenFetchStats;
  end;

  TWallHavenFetchThread = class(TThread)
  private
    FLock: TCriticalSection;
    FSources: array of TWallHavenSourceSnapshot;
    FMaxPerSource: Integer;
    FDarkFilterEnabled: Boolean;
    FMaxLuminance: Double;
    FIconZoneMaxLuminance: Double;
    FCheckIconZone: Boolean;
    FWallHavenApiKey: string;
    FWallHavenAtLeast: string;
    FWallHavenMaxPages: Integer;
    FWallHavenCacheDir: string;
    FWallHavenMaxCached: Integer;
    FProtectedFile: string;
    FCache: TLuminanceCache;

    FState: TWallHavenFetchState;
    FDownloadedFiles: TStringList;
    FLogQueue: TStringList;
    FSelectFirstOnReady: Boolean;
    FIsDailyAuto: Boolean;

    procedure PushLog(const Msg: string);
  protected
    procedure Execute; override;
  public
    constructor Create(Config: TWallCycleConfig; MaxPerSource: Integer;
      Cache: TLuminanceCache; ASelectFirstOnReady, AIsDailyAuto: Boolean;
      const AProtectedFile: string = '');
    destructor Destroy; override;
    function GetState: TWallHavenFetchState;
    procedure ConsumeLogs(Target: TStrings);
    function ConsumeResult(out Stats: TWallHavenFetchStats;
      TargetFiles: TStrings; out SelectFirst, IsDailyAuto: Boolean): Boolean;
  end;

function FetchWallHavenSource(Config: TWallCycleConfig; Source: TWallpaperSource;
  MaxToDownload: Integer; out DownloadedFiles: TStringList): TWallHavenFetchStats;

function FetchAllEnabledWallHavenSources(Config: TWallCycleConfig;
  MaxPerSource: Integer; out DownloadedFiles: TStringList): TWallHavenFetchStats;

implementation

type
  TThreadAccess = class(TThread);

function IsThreadAborted(T: TThread): Boolean; inline;
begin
  Result := (T <> nil) and TThreadAccess(T).Terminated;
end;

function SanitizeIdToken(const S: string): string;
var
  I: Integer;
  Ch: Char;
begin
  Result := '';
  for I := 1 to Length(S) do
  begin
    Ch := S[I];
    if Ch in ['a'..'z', 'A'..'Z', '0'..'9', '-', '_'] then
      Result := Result + Ch;
  end;
end;

function ExtractSafeImageExt(const Url: string): string;
var
  CleanUrl: string;
  QPos: Integer;
begin
  CleanUrl := Url;
  QPos := Pos('?', CleanUrl);
  if QPos > 0 then CleanUrl := Copy(CleanUrl, 1, QPos - 1);
  QPos := Pos('#', CleanUrl);
  if QPos > 0 then CleanUrl := Copy(CleanUrl, 1, QPos - 1);

  Result := LowerCase(ExtractFileExt(CleanUrl));
  if (Result <> '.jpg') and (Result <> '.jpeg') and (Result <> '.png') and (Result <> '.bmp') then
    Result := '.jpg';
end;

function UrlEncodeParam(const S: string): string;
const
  SafeChars = ['A'..'Z', 'a'..'z', '0'..'9', '-', '_', '.', '~'];
var
  I: Integer;
  B: Byte;
begin
  Result := '';
  for I := 1 to Length(S) do
  begin
    if S[I] in SafeChars then
      Result := Result + S[I]
    else if S[I] = ' ' then
      Result := Result + '+'
    else
    begin
      B := Ord(S[I]);
      Result := Result + '%' + IntToHex(B, 2);
    end;
  end;
end;

type
  TCacheFileEntry = record
    Path: string;
    CreatedAt: Int64;
  end;
  TCacheFileEntryArray = array of TCacheFileEntry;

function GetSearchRecCreationKey(const FullPath: string; const SR: TSearchRec): Int64;
{$IFDEF UNIX}
var
  St: TStat;
{$ENDIF}
begin
  {$IFDEF WINDOWS}
  Result := (Int64(SR.FindData.ftCreationTime.dwHighDateTime) shl 32) or
            Int64(SR.FindData.ftCreationTime.dwLowDateTime);
  if Result <= 0 then
    Result := (Int64(SR.FindData.ftLastWriteTime.dwHighDateTime) shl 32) or
              Int64(SR.FindData.ftLastWriteTime.dwLowDateTime);
  if Result <= 0 then
    Result := Int64(SR.Time);
  {$ELSE}
  {$IFDEF UNIX}
  if fpStat(FullPath, St) = 0 then
    Result := Int64(St.st_mtime)
  else
    Result := Int64(SR.Time);
  {$ELSE}
  Result := Int64(SR.Time);
  {$ENDIF}
  {$ENDIF}
end;

procedure ScanCacheDirEntries(const Dir: string; var Entries: TCacheFileEntryArray);
var
  SR: TSearchRec;
  Base, FullPath: string;
  Len: Integer;
begin
  if not DirectoryExists(Dir) then Exit;
  Base := IncludeTrailingPathDelimiter(Dir);
  if FindFirst(Base + '*', faAnyFile, SR) = 0 then
  begin
    try
      repeat
        if (SR.Name = '.') or (SR.Name = '..') then Continue;
        FullPath := Base + SR.Name;
        if (SR.Attr and faDirectory) <> 0 then
          ScanCacheDirEntries(FullPath, Entries)
        else if Pos('wallhaven-', LowerCase(SR.Name)) = 1 then
        begin
          Len := Length(Entries);
          SetLength(Entries, Len + 1);
          Entries[Len].Path := FullPath;
          Entries[Len].CreatedAt := GetSearchRecCreationKey(FullPath, SR);
        end;
      until FindNext(SR) <> 0;
    finally
      FindClose(SR);
    end;
  end;
end;

function PruneOldCacheFiles(const BaseCacheDir: string; MaxFiles: Integer;
  const ProtectedFile: string = ''): Integer;
var
  Entries: TCacheFileEntryArray;
  Tmp: TCacheFileEntry;
  I, J, Remaining: Integer;
begin
  Result := 0;
  if MaxFiles <= 0 then Exit;

  SetLength(Entries, 0);
  ScanCacheDirEntries(BaseCacheDir, Entries);

  if Length(Entries) <= MaxFiles then Exit;

  // Sort oldest-first by local creation date (tie-break deterministically by path)
  for I := 0 to Length(Entries) - 2 do
    for J := I + 1 to Length(Entries) - 1 do
      if (Entries[I].CreatedAt > Entries[J].CreatedAt) or
         ((Entries[I].CreatedAt = Entries[J].CreatedAt) and
          (CompareText(Entries[I].Path, Entries[J].Path) > 0)) then
      begin
        Tmp := Entries[I];
        Entries[I] := Entries[J];
        Entries[J] := Tmp;
      end;

  Remaining := Length(Entries);
  for I := 0 to Length(Entries) - 1 do
  begin
    if Remaining <= MaxFiles then Break;
    if (ProtectedFile <> '') and SameFileName(Entries[I].Path, ProtectedFile) then
      Continue;
    if DeleteFile(Entries[I].Path) then
    begin
      Inc(Result);
      Dec(Remaining);
    end;
  end;
end;

function ResolveCurlExecutable: string;
{$IFDEF WINDOWS}
var
  SysRoot, SysCurl: string;
{$ENDIF}
begin
  Result := FindDefaultExecutablePath('curl');
  {$IFDEF WINDOWS}
  if Result = '' then
  begin
    SysRoot := GetEnvironmentVariable('SystemRoot');
    if SysRoot = '' then SysRoot := 'C:\Windows';
    SysCurl := IncludeTrailingPathDelimiter(SysRoot) + 'System32\curl.exe';
    if FileExists(SysCurl) then
      Result := SysCurl;
  end;
  {$ENDIF}
end;

function RunCliTransfer(const Exe: string; const Params: array of string;
  out StdOutStr, ErrMsg: string; AbortThread: TThread = nil): Boolean;
var
  P: TProcess;
  MS: TMemoryStream;
  Buf: array[0..4095] of Byte;
  BytesRead, I: Integer;
begin
  Result := False;
  StdOutStr := '';
  ErrMsg := '';
  if Exe = '' then Exit;
  if IsThreadAborted(AbortThread) then
  begin
    ErrMsg := 'Cancelled';
    Exit;
  end;

  P := TProcess.Create(nil);
  MS := TMemoryStream.Create;
  try
    P.Executable := Exe;
    for I := Low(Params) to High(Params) do
      P.Parameters.Add(Params[I]);
    P.Options := [poUsePipes, poNoConsole];
    P.ShowWindow := swoHIDE;
    try
      P.Execute;
      while P.Running or (P.Output.NumBytesAvailable > 0) do
      begin
        if IsThreadAborted(AbortThread) then
        begin
          if P.Running then
            P.Terminate(1);
          ErrMsg := 'Cancelled';
          Exit(False);
        end;

        if P.Output.NumBytesAvailable > 0 then
        begin
          BytesRead := P.Output.Read(Buf, SizeOf(Buf));
          if BytesRead > 0 then
            MS.WriteBuffer(Buf, BytesRead);
        end
        else
          Sleep(10);
      end;

      if MS.Size > 0 then
      begin
        SetLength(StdOutStr, MS.Size);
        MS.Position := 0;
        MS.ReadBuffer(StdOutStr[1], MS.Size);
      end;

      Result := (P.ExitStatus = 0);
      if not Result then
      begin
        case P.ExitStatus of
          6: ErrMsg := 'DNS error (unable to resolve wallhaven.cc)';
          7: ErrMsg := 'Connection refused or network unreachable';
          22: ErrMsg := 'HTTP server error (rate limit 429 or access denied 401/403)';
          28: ErrMsg := 'Connection timed out';
          35, 60: ErrMsg := 'System SSL/TLS handshake error';
        else
          ErrMsg := Format('%s exited with code %d', [ExtractFileName(Exe), P.ExitStatus]);
        end;
      end;
    except
      on E: Exception do
        ErrMsg := E.Message;
    end;
  finally
    MS.Free;
    P.Free;
  end;
end;

function HttpGetText(const Url, ApiKey: string; out Body, ErrMsg: string;
  AbortThread: TThread = nil): Boolean;
var
  Exe: string;
begin
  Body := '';
  ErrMsg := '';
  Exe := ResolveCurlExecutable;
  if Exe <> '' then
  begin
    if Trim(ApiKey) <> '' then
      Result := RunCliTransfer(Exe, [
        '-fsSL', '--connect-timeout', '8', '--max-time', '20',
        '-A', 'WallCycle-Lazarus/1.0',
        '-H', 'X-API-Key: ' + Trim(ApiKey),
        Url
      ], Body, ErrMsg, AbortThread)
    else
      Result := RunCliTransfer(Exe, [
        '-fsSL', '--connect-timeout', '8', '--max-time', '20',
        '-A', 'WallCycle-Lazarus/1.0',
        Url
      ], Body, ErrMsg, AbortThread);
    Exit;
  end;

  Exe := FindDefaultExecutablePath('wget');
  if Exe <> '' then
  begin
    if Trim(ApiKey) <> '' then
      Result := RunCliTransfer(Exe, [
        '-qO-', '--timeout=20',
        '--user-agent=WallCycle-Lazarus/1.0',
        '--header=X-API-Key: ' + Trim(ApiKey),
        Url
      ], Body, ErrMsg, AbortThread)
    else
      Result := RunCliTransfer(Exe, [
        '-qO-', '--timeout=20',
        '--user-agent=WallCycle-Lazarus/1.0',
        Url
      ], Body, ErrMsg, AbortThread);
    Exit;
  end;

  Result := False;
  ErrMsg := 'Neither curl nor wget found in PATH to access WallHaven';
end;

function HttpDownloadFile(const Url, DestPath, ApiKey: string; out ErrMsg: string;
  AbortThread: TThread = nil): Boolean;
var
  Exe, DummyOut: string;
begin
  ErrMsg := '';
  Exe := ResolveCurlExecutable;
  if Exe <> '' then
  begin
    if Trim(ApiKey) <> '' then
      Result := RunCliTransfer(Exe, [
        '-fsSL', '--connect-timeout', '8', '--max-time', '30',
        '-A', 'WallCycle-Lazarus/1.0',
        '-H', 'X-API-Key: ' + Trim(ApiKey),
        '-o', DestPath,
        Url
      ], DummyOut, ErrMsg, AbortThread)
    else
      Result := RunCliTransfer(Exe, [
        '-fsSL', '--connect-timeout', '8', '--max-time', '30',
        '-A', 'WallCycle-Lazarus/1.0',
        '-o', DestPath,
        Url
      ], DummyOut, ErrMsg, AbortThread);
    Exit;
  end;

  Exe := FindDefaultExecutablePath('wget');
  if Exe <> '' then
  begin
    if Trim(ApiKey) <> '' then
      Result := RunCliTransfer(Exe, [
        '-q', '--timeout=30',
        '--user-agent=WallCycle-Lazarus/1.0',
        '--header=X-API-Key: ' + Trim(ApiKey),
        '-O', DestPath,
        Url
      ], DummyOut, ErrMsg, AbortThread)
    else
      Result := RunCliTransfer(Exe, [
        '-q', '--timeout=30',
        '--user-agent=WallCycle-Lazarus/1.0',
        '-O', DestPath,
        Url
      ], DummyOut, ErrMsg, AbortThread);
    Exit;
  end;

  Result := False;
  ErrMsg := 'Neither curl nor wget found in PATH';
end;

function BuildSearchUrl(const ApiAtLeast: string; const Src: TWallHavenSourceSnapshot;
  const SortOverride: string; PageNum: Integer): string;
var
  SortMode: string;
begin
  SortMode := SortOverride;
  if SortMode = '' then SortMode := Src.Sorting;
  if SortMode = '' then SortMode := 'toplist';

  Result := 'https://wallhaven.cc/api/v1/search?q=' + UrlEncodeParam(Src.Target) +
    '&categories=' + UrlEncodeParam(Src.Categories) +
    '&purity=' + UrlEncodeParam(Src.Purity) +
    '&sorting=' + UrlEncodeParam(SortMode) +
    '&page=' + IntToStr(PageNum);

  if SameText(SortMode, 'toplist') then
    Result := Result + '&topRange=1y';

  if Trim(ApiAtLeast) <> '' then
    Result := Result + '&atleast=' + UrlEncodeParam(ApiAtLeast);
end;

function FetchWallHavenSnapshot(const Src: TWallHavenSourceSnapshot;
  const ApiKey, AtLeast: string; MaxPages, MaxToDownload: Integer;
  DarkFilterEnabled: Boolean; MaxLum, IconZoneLum: Double; CheckIconZone: Boolean;
  Cache: TLuminanceCache; AbortThread: TThread;
  out DownloadedFiles: TStringList): TWallHavenFetchStats;
var
  Url, JsonText, HttpErr, DlErr, LastDlErr, ImgId, ImgUrl, Ext, LocalPath: string;
  Data: TJSONData;
  Root, MetaObj, Item: TJSONObject;
  Items, ColorsArr: TJSONArray;
  I, J, PageNum, LastPage, NewDownloads: Integer;
  Palette: array of string;
  PalLum: Double;
  Stats: TLuminanceStats;
  ActiveSort: string;
  IsNewFile: Boolean;
begin
  DownloadedFiles := TStringList.Create;
  Result.QueryUrl := '';
  Result.PagesScanned := 0;
  Result.CandidatesExamined := 0;
  Result.RejectedByPalette := 0;
  Result.RejectedByPixels := 0;
  Result.DownloadedCount := 0;
  Result.PrunedCount := 0;
  Result.LastError := '';

  if Src.SubDir = '' then Exit;
  ForceDirectories(Src.SubDir);

  ActiveSort := Src.Sorting;
  MaxPages := Max(1, MaxPages);
  LastPage := MaxPages;
  NewDownloads := 0;
  LastDlErr := '';

  for PageNum := 1 to MaxPages do
  begin
    if IsThreadAborted(AbortThread) then Break;
    if (NewDownloads >= MaxToDownload) or (PageNum > LastPage) then Break;
    if PageNum > 1 then Sleep(120);
    if IsThreadAborted(AbortThread) then Break;

    Url := BuildSearchUrl(AtLeast, Src, ActiveSort, PageNum);
    Result.QueryUrl := Url;

    Data := nil;
    try
      if not HttpGetText(Url, ApiKey, JsonText, HttpErr, AbortThread) then
      begin
        if (not IsThreadAborted(AbortThread)) and (PageNum = 1) and (Result.DownloadedCount = 0) then
          Result.LastError := 'WallHaven HTTP error: ' + HttpErr;
        Break;
      end;

      try
        Data := GetJSON(JsonText);
      except
        on E: Exception do
        begin
          if (PageNum = 1) and (Result.DownloadedCount = 0) then
            Result.LastError := 'Invalid JSON response: ' + E.Message;
          Break;
        end;
      end;

      if not (Data is TJSONObject) then Break;
      Root := TJSONObject(Data);
      Items := Root.Get('data', TJSONArray(nil));

      // If toplist returned 0 items on page 1, fallback automatically to favorites (all-time)
      if ((Items = nil) or (Items.Count = 0)) and (PageNum = 1) and SameText(ActiveSort, 'toplist') then
      begin
        FreeAndNil(Data);
        ActiveSort := 'favorites';
        Url := BuildSearchUrl(AtLeast, Src, ActiveSort, 1);
        Result.QueryUrl := Url;
        if HttpGetText(Url, ApiKey, JsonText, HttpErr, AbortThread) then
        begin
          try
            Data := GetJSON(JsonText);
            if Data is TJSONObject then
            begin
              Root := TJSONObject(Data);
              Items := Root.Get('data', TJSONArray(nil));
            end;
          except
            Items := nil;
          end;
        end;
      end;

      if (Items = nil) or (Items.Count = 0) then Break;
      Inc(Result.PagesScanned);

      MetaObj := Root.Get('meta', TJSONObject(nil));
      if MetaObj <> nil then
        LastPage := Max(1, MetaObj.Get('last_page', MaxPages));

      for I := 0 to Items.Count - 1 do
      begin
        if IsThreadAborted(AbortThread) then Break;
        if NewDownloads >= MaxToDownload then Break;
        if not (Items.Items[I] is TJSONObject) then Continue;
        Item := TJSONObject(Items.Items[I]);
        Inc(Result.CandidatesExamined);

        ImgId := SanitizeIdToken(Item.Get('id', ''));
        ImgUrl := Item.Get('path', '');
        if (ImgId = '') or (ImgUrl = '') then Continue;

        // Step 1: Fast pre-filter using WallHaven's 5 dominant palette colors
        ColorsArr := Item.Get('colors', TJSONArray(nil));
        if (ColorsArr <> nil) and (ColorsArr.Count > 0) and DarkFilterEnabled then
        begin
          SetLength(Palette, ColorsArr.Count);
          for J := 0 to ColorsArr.Count - 1 do
            Palette[J] := ColorsArr.Strings[J];
          PalLum := EstimateHexPaletteLuminance(Palette);
          if PalLum > (MaxLum + 0.07) then
          begin
            Inc(Result.RejectedByPalette);
            Continue;
          end;
        end;

        Ext := ExtractSafeImageExt(ImgUrl);
        LocalPath := IncludeTrailingPathDelimiter(Src.SubDir) + 'wallhaven-' + ImgId + Ext;

        IsNewFile := not FileExists(LocalPath);
        if IsNewFile then
        begin
          if not HttpDownloadFile(ImgUrl, LocalPath, ApiKey, DlErr, AbortThread) then
          begin
            if DlErr <> '' then LastDlErr := DlErr;
            if FileExists(LocalPath) then DeleteFile(LocalPath);
            if IsThreadAborted(AbortThread) then Break;
            Continue;
          end;
          if DetectImageFormat(LocalPath) = ifUnknown then
          begin
            LastDlErr := 'Downloaded file not recognized as a valid image';
            if FileExists(LocalPath) then DeleteFile(LocalPath);
            Continue;
          end;
        end;

        // Step 2: Always verify image integrity; also check BT.709 luminance if DarkFilterEnabled
        if DarkFilterEnabled then
        begin
          if not IsImageDarkEnough(LocalPath, MaxLum, IconZoneLum, CheckIconZone, Stats, Cache) then
          begin
            Inc(Result.RejectedByPixels);
            DeleteFile(LocalPath);
            Continue;
          end;
        end
        else
        begin
          if (Cache = nil) or (not Cache.TryGet(LocalPath, Stats)) then
          begin
            Stats := AnalyzeImageLuminance(LocalPath);
            if (Cache <> nil) and Stats.Valid then
              Cache.Put(LocalPath, Stats);
          end;
          if not Stats.Valid then
          begin
            DeleteFile(LocalPath);
            Continue;
          end;
        end;

        DownloadedFiles.Add(LocalPath);
        Inc(Result.DownloadedCount);
        if IsNewFile then
          Inc(NewDownloads);
      end;
    finally
      FreeAndNil(Data);
    end;
  end;

  if (not IsThreadAborted(AbortThread)) and (Result.DownloadedCount = 0) and (Result.LastError = '') then
  begin
    if Result.CandidatesExamined = 0 then
      Result.LastError := Format('WallHaven: 0 results found for "%s" (try a broader query or check Purity/API Key).', [Src.Target])
    else if LastDlErr <> '' then
      Result.LastError := 'WallHaven image download error: ' + LastDlErr;
  end;
end;

function FetchWallHavenSource(Config: TWallCycleConfig; Source: TWallpaperSource;
  MaxToDownload: Integer; out DownloadedFiles: TStringList): TWallHavenFetchStats;
var
  Snap: TWallHavenSourceSnapshot;
begin
  if (Source = nil) or (Source.Kind <> skWallHaven) then
  begin
    DownloadedFiles := TStringList.Create;
    FillChar(Result, SizeOf(Result), 0);
    Exit;
  end;

  Snap.Target := Source.Target;
  Snap.Sorting := Source.Sorting;
  Snap.Categories := Source.Categories;
  Snap.Purity := Source.Purity;
  Snap.SubDir := Source.GetWallHavenSubDir(Config.WallHavenCacheDir);

  Result := FetchWallHavenSnapshot(
    Snap,
    Config.WallHavenApiKey,
    Config.WallHavenAtLeast,
    Config.WallHavenMaxPages,
    MaxToDownload,
    Config.DarkFilterEnabled,
    Config.MaxLuminance,
    Config.IconZoneMaxLuminance,
    Config.CheckIconZone,
    nil,
    nil,
    DownloadedFiles
  );
  Result.PrunedCount := PruneOldCacheFiles(Config.WallHavenCacheDir, Config.WallHavenMaxCached);
end;

function FetchAllEnabledWallHavenSources(Config: TWallCycleConfig;
  MaxPerSource: Integer; out DownloadedFiles: TStringList): TWallHavenFetchStats;
var
  I: Integer;
  Src: TWallpaperSource;
  PartFiles: TStringList;
  PartStats: TWallHavenFetchStats;
begin
  DownloadedFiles := TStringList.Create;
  Result.QueryUrl := '';
  Result.PagesScanned := 0;
  Result.CandidatesExamined := 0;
  Result.RejectedByPalette := 0;
  Result.RejectedByPixels := 0;
  Result.DownloadedCount := 0;
  Result.PrunedCount := 0;
  Result.LastError := '';

  for I := 0 to Config.Sources.Count - 1 do
  begin
    Src := Config.GetSource(I);
    if not Src.Enabled then Continue;
    if Src.Kind <> skWallHaven then Continue;

    PartStats := FetchWallHavenSource(Config, Src, MaxPerSource, PartFiles);
    try
      Inc(Result.PagesScanned, PartStats.PagesScanned);
      Inc(Result.CandidatesExamined, PartStats.CandidatesExamined);
      Inc(Result.RejectedByPalette, PartStats.RejectedByPalette);
      Inc(Result.RejectedByPixels, PartStats.RejectedByPixels);
      Inc(Result.DownloadedCount, PartStats.DownloadedCount);
      Inc(Result.PrunedCount, PartStats.PrunedCount);
      if PartStats.LastError <> '' then
        Result.LastError := PartStats.LastError;
      DownloadedFiles.AddStrings(PartFiles);
    finally
      PartFiles.Free;
    end;
  end;
end;

{ TWallHavenFetchThread }

constructor TWallHavenFetchThread.Create(Config: TWallCycleConfig; MaxPerSource: Integer;
  Cache: TLuminanceCache; ASelectFirstOnReady, AIsDailyAuto: Boolean;
  const AProtectedFile: string);
var
  I, Count: Integer;
  Src: TWallpaperSource;
begin
  inherited Create(True); // Create suspended until snapshot is ready
  FreeOnTerminate := False;
  FLock := TCriticalSection.Create;
  FDownloadedFiles := TStringList.Create;
  FLogQueue := TStringList.Create;
  FCache := Cache;
  FMaxPerSource := MaxPerSource;
  FSelectFirstOnReady := ASelectFirstOnReady;
  FIsDailyAuto := AIsDailyAuto;
  FProtectedFile := AProtectedFile;

  FDarkFilterEnabled := Config.DarkFilterEnabled;
  FMaxLuminance := Config.MaxLuminance;
  FIconZoneMaxLuminance := Config.IconZoneMaxLuminance;
  FCheckIconZone := Config.CheckIconZone;
  FWallHavenApiKey := Config.WallHavenApiKey;
  FWallHavenAtLeast := Config.WallHavenAtLeast;
  FWallHavenMaxPages := Config.WallHavenMaxPages;
  FWallHavenCacheDir := Config.WallHavenCacheDir;
  FWallHavenMaxCached := Config.WallHavenMaxCached;

  Count := 0;
  SetLength(FSources, Config.Sources.Count);
  for I := 0 to Config.Sources.Count - 1 do
  begin
    Src := Config.GetSource(I);
    if (not Src.Enabled) or (Src.Kind <> skWallHaven) then Continue;
    FSources[Count].Target := Src.Target;
    FSources[Count].Sorting := Src.Sorting;
    FSources[Count].Categories := Src.Categories;
    FSources[Count].Purity := Src.Purity;
    FSources[Count].SubDir := Src.GetWallHavenSubDir(Config.WallHavenCacheDir);
    Inc(Count);
  end;
  SetLength(FSources, Count);

  FillChar(FState, SizeOf(FState), 0);
  FState.Running := True;
  Start;
end;

destructor TWallHavenFetchThread.Destroy;
begin
  FLogQueue.Free;
  FDownloadedFiles.Free;
  FLock.Free;
  inherited Destroy;
end;

procedure TWallHavenFetchThread.PushLog(const Msg: string);
begin
  if Msg = '' then Exit;
  FLock.Enter;
  try
    FLogQueue.Add(Msg);
  finally
    FLock.Leave;
  end;
end;

procedure TWallHavenFetchThread.Execute;
var
  I: Integer;
  PartFiles: TStringList;
  PartStats: TWallHavenFetchStats;
  TotalStats: TWallHavenFetchStats;
begin
  TotalStats.QueryUrl := '';
  TotalStats.PagesScanned := 0;
  TotalStats.CandidatesExamined := 0;
  TotalStats.RejectedByPalette := 0;
  TotalStats.RejectedByPixels := 0;
  TotalStats.DownloadedCount := 0;
  TotalStats.PrunedCount := 0;
  TotalStats.LastError := '';

  try
    for I := 0 to High(FSources) do
    begin
      if Terminated then Break;
      PartStats := FetchWallHavenSnapshot(
        FSources[I],
        FWallHavenApiKey,
        FWallHavenAtLeast,
        FWallHavenMaxPages,
        FMaxPerSource,
        FDarkFilterEnabled,
        FMaxLuminance,
        FIconZoneMaxLuminance,
        FCheckIconZone,
        FCache,
        Self,
        PartFiles
      );
      try
        Inc(TotalStats.PagesScanned, PartStats.PagesScanned);
        Inc(TotalStats.CandidatesExamined, PartStats.CandidatesExamined);
        Inc(TotalStats.RejectedByPalette, PartStats.RejectedByPalette);
        Inc(TotalStats.RejectedByPixels, PartStats.RejectedByPixels);
        Inc(TotalStats.DownloadedCount, PartStats.DownloadedCount);
        if PartStats.LastError <> '' then
          TotalStats.LastError := PartStats.LastError;

        FLock.Enter;
        try
          FDownloadedFiles.AddStrings(PartFiles);
        finally
          FLock.Leave;
        end;
      finally
        PartFiles.Free;
      end;
    end;

    if not Terminated then
      TotalStats.PrunedCount := PruneOldCacheFiles(FWallHavenCacheDir, FWallHavenMaxCached, FProtectedFile);

    if (not Terminated) and (FCache <> nil) then
      FCache.SaveIfDirty;
  finally
    FLock.Enter;
    try
      FState.Stats := TotalStats;
      FState.Running := False;
      FState.Cancelled := Terminated;
      FState.Finished := not Terminated;
    finally
      FLock.Leave;
    end;
  end;
end;

function TWallHavenFetchThread.GetState: TWallHavenFetchState;
begin
  FLock.Enter;
  try
    Result := FState;
  finally
    FLock.Leave;
  end;
end;

procedure TWallHavenFetchThread.ConsumeLogs(Target: TStrings);
begin
  FLock.Enter;
  try
    if FLogQueue.Count > 0 then
    begin
      Target.AddStrings(FLogQueue);
      FLogQueue.Clear;
    end;
  finally
    FLock.Leave;
  end;
end;

function TWallHavenFetchThread.ConsumeResult(out Stats: TWallHavenFetchStats;
  TargetFiles: TStrings; out SelectFirst, IsDailyAuto: Boolean): Boolean;
begin
  Result := False;
  FLock.Enter;
  try
    if not FState.Running then
    begin
      Stats := FState.Stats;
      TargetFiles.Assign(FDownloadedFiles);
      SelectFirst := FSelectFirstOnReady;
      IsDailyAuto := FIsDailyAuto;
      Result := True;
    end;
  finally
    FLock.Leave;
  end;
end;

end.
