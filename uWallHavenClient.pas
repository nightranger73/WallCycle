unit uWallHavenClient;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Process, FileUtil, fpjson, jsonparser, Math,
  uConfig, uLuminanceFilter;

type
  TWallHavenFetchStats = record
    QueryUrl: string;
    PagesScanned: Integer;
    CandidatesExamined: Integer;
    RejectedByPalette: Integer;
    RejectedByPixels: Integer;
    DownloadedCount: Integer;
    LastError: string;
  end;

function FetchWallHavenSource(Config: TWallCycleConfig; Source: TWallpaperSource;
  MaxToDownload: Integer; out DownloadedFiles: TStringList): TWallHavenFetchStats;

function FetchAllEnabledWallHavenSources(Config: TWallCycleConfig;
  MaxPerSource: Integer; out DownloadedFiles: TStringList): TWallHavenFetchStats;

implementation

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

procedure PruneOldCacheFiles(const CacheDir: string; MaxFiles: Integer);
var
  SR: TSearchRec;
  Files: TStringList;
  I: Integer;
begin
  if MaxFiles <= 0 then Exit;
  Files := TStringList.Create;
  try
    if FindFirst(IncludeTrailingPathDelimiter(CacheDir) + 'wallhaven-*.*', faAnyFile, SR) = 0 then
    begin
      repeat
        if (SR.Attr and faDirectory) = 0 then
          Files.AddObject(IncludeTrailingPathDelimiter(CacheDir) + SR.Name, TObject(PtrInt(SR.Time)));
      until FindNext(SR) <> 0;
      FindClose(SR);
    end;

    if Files.Count > MaxFiles then
    begin
      for I := 0 to Files.Count - 2 do
        if PtrInt(Files.Objects[I]) > PtrInt(Files.Objects[I + 1]) then
          Files.Exchange(I, I + 1);
      for I := 0 to (Files.Count - MaxFiles) - 1 do
        DeleteFile(Files[I]);
    end;
  finally
    Files.Free;
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
  out StdOutStr, ErrMsg: string): Boolean;
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
        if P.Output.NumBytesAvailable > 0 then
        begin
          BytesRead := P.Output.Read(Buf, SizeOf(Buf));
          if BytesRead > 0 then
            MS.WriteBuffer(Buf, BytesRead);
        end
        else
          Sleep(5);
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
          28: ErrMsg := 'Connection Timeout';
          35, 60: ErrMsg := 'SSL/TLS handshake error';
        else
          ErrMsg := Format('%s terminated with code %d', [ExtractFileName(Exe), P.ExitStatus]);
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

function HttpGetText(const Url, ApiKey: string; out Body, ErrMsg: string): Boolean;
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
      ], Body, ErrMsg)
    else
      Result := RunCliTransfer(Exe, [
        '-fsSL', '--connect-timeout', '8', '--max-time', '20',
        '-A', 'WallCycle-Lazarus/1.0',
        Url
      ], Body, ErrMsg);
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
      ], Body, ErrMsg)
    else
      Result := RunCliTransfer(Exe, [
        '-qO-', '--timeout=20',
        '--user-agent=WallCycle-Lazarus/1.0',
        Url
      ], Body, ErrMsg);
    Exit;
  end;

  Result := False;
  ErrMsg := 'No curl or wget found in PATH';
end;

function HttpDownloadFile(const Url, DestPath, ApiKey: string; out ErrMsg: string): Boolean;
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
      ], DummyOut, ErrMsg)
    else
      Result := RunCliTransfer(Exe, [
        '-fsSL', '--connect-timeout', '8', '--max-time', '30',
        '-A', 'WallCycle-Lazarus/1.0',
        '-o', DestPath,
        Url
      ], DummyOut, ErrMsg);
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
      ], DummyOut, ErrMsg)
    else
      Result := RunCliTransfer(Exe, [
        '-q', '--timeout=30',
        '--user-agent=WallCycle-Lazarus/1.0',
        '-O', DestPath,
        Url
      ], DummyOut, ErrMsg);
    Exit;
  end;

  Result := False;
  ErrMsg := 'No curl or wget found in PATH';
end;

function BuildSearchUrl(Config: TWallCycleConfig; Source: TWallpaperSource;
  const SortOverride: string; PageNum: Integer): string;
var
  SortMode: string;
begin
  SortMode := SortOverride;
  if SortMode = '' then SortMode := Source.Sorting;
  if SortMode = '' then SortMode := 'toplist';

  Result := 'https://wallhaven.cc/api/v1/search?q=' + UrlEncodeParam(Source.Target) +
    '&categories=' + UrlEncodeParam(Source.Categories) +
    '&purity=' + UrlEncodeParam(Source.Purity) +
    '&sorting=' + UrlEncodeParam(SortMode) +
    '&page=' + IntToStr(PageNum);

  if SameText(SortMode, 'toplist') then
    Result := Result + '&topRange=1y';

  if Trim(Config.WallHavenAtLeast) <> '' then
    Result := Result + '&atleast=' + UrlEncodeParam(Config.WallHavenAtLeast);
end;

function FetchWallHavenSource(Config: TWallCycleConfig; Source: TWallpaperSource;
  MaxToDownload: Integer; out DownloadedFiles: TStringList): TWallHavenFetchStats;
var
  Url, JsonText, HttpErr, DlErr, LastDlErr, ImgId, ImgUrl, Ext, LocalPath, SubDir: string;
  Data: TJSONData;
  Root, MetaObj, Item: TJSONObject;
  Items, ColorsArr: TJSONArray;
  I, J, PageNum, MaxPages, LastPage, NewDownloads: Integer;
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
  Result.LastError := '';

  if (Source = nil) or (Source.Kind <> skWallHaven) then Exit;

  SubDir := Source.GetWallHavenSubDir(Config.WallHavenCacheDir);
  ForceDirectories(SubDir);

  ActiveSort := Source.Sorting;
  MaxPages := Max(1, Config.WallHavenMaxPages);
  LastPage := MaxPages;
  NewDownloads := 0;
  LastDlErr := '';

  for PageNum := 1 to MaxPages do
  begin
    if (NewDownloads >= MaxToDownload) or (PageNum > LastPage) then Break;
    if PageNum > 1 then Sleep(120);

    Url := BuildSearchUrl(Config, Source, ActiveSort, PageNum);
    Result.QueryUrl := Url;

    Data := nil;
    try
      if not HttpGetText(Url, Config.WallHavenApiKey, JsonText, HttpErr) then
      begin
        if (PageNum = 1) and (Result.DownloadedCount = 0) then
          Result.LastError := 'HTTP Error WallHaven: ' + HttpErr;
        Break;
      end;

      try
        Data := GetJSON(JsonText);
      except
        on E: Exception do
        begin
          if (PageNum = 1) and (Result.DownloadedCount = 0) then
            Result.LastError := 'JSON Response invalid: ' + E.Message;
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
        Url := BuildSearchUrl(Config, Source, ActiveSort, 1);
        Result.QueryUrl := Url;
        if HttpGetText(Url, Config.WallHavenApiKey, JsonText, HttpErr) then
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
        if NewDownloads >= MaxToDownload then Break;
        if not (Items.Items[I] is TJSONObject) then Continue;
        Item := TJSONObject(Items.Items[I]);
        Inc(Result.CandidatesExamined);

        ImgId := Item.Get('id', '');
        ImgUrl := Item.Get('path', '');
        if (ImgId = '') or (ImgUrl = '') then Continue;

        // Step 1: Fast pre-filter using WallHaven's 5 dominant palette colors
        ColorsArr := Item.Get('colors', TJSONArray(nil));
        if (ColorsArr <> nil) and (ColorsArr.Count > 0) and Config.DarkFilterEnabled then
        begin
          SetLength(Palette, ColorsArr.Count);
          for J := 0 to ColorsArr.Count - 1 do
            Palette[J] := ColorsArr.Strings[J];
          PalLum := EstimateHexPaletteLuminance(Palette);
          if PalLum > (Config.MaxLuminance + 0.07) then
          begin
            Inc(Result.RejectedByPalette);
            Continue;
          end;
        end;

        Ext := LowerCase(ExtractFileExt(ImgUrl));
        if Ext = '' then Ext := '.jpg';
        LocalPath := IncludeTrailingPathDelimiter(SubDir) + 'wallhaven-' + ImgId + Ext;

        IsNewFile := not FileExists(LocalPath);
        if IsNewFile then
        begin
          if not HttpDownloadFile(ImgUrl, LocalPath, Config.WallHavenApiKey, DlErr) then
          begin
            if DlErr <> '' then LastDlErr := DlErr;
            if FileExists(LocalPath) then DeleteFile(LocalPath);
            Continue;
          end;
          if DetectImageFormat(LocalPath) = ifUnknown then
          begin
            LastDlErr := 'Downloaded file in not a valid immage format';
            if FileExists(LocalPath) then DeleteFile(LocalPath);
            Continue;
          end;
        end;

        // Step 2: Always verify image integrity; also check BT.709 luminance if DarkFilterEnabled
        if Config.DarkFilterEnabled then
        begin
          if not IsImageDarkEnough(LocalPath, Config.MaxLuminance,
            Config.IconZoneMaxLuminance, Config.CheckIconZone, Stats) then
          begin
            Inc(Result.RejectedByPixels);
            DeleteFile(LocalPath);
            Continue;
          end;
        end
        else
        begin
          Stats := AnalyzeImageLuminance(LocalPath);
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

  PruneOldCacheFiles(SubDir, Config.WallHavenMaxCached);

  if (Result.DownloadedCount = 0) and (Result.LastError = '') then
  begin
    if Result.CandidatesExamined = 0 then
      Result.LastError := Format('WallHaven: 0 results found for "%s" (Try with a more generic query or check Purity/API Key).', [Source.Target])
    else if LastDlErr <> '' then
      Result.LastError := 'Error downloading WallHaven image: ' + LastDlErr;
  end;
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
      if PartStats.LastError <> '' then
        Result.LastError := PartStats.LastError;
      DownloadedFiles.AddStrings(PartFiles);
    finally
      PartFiles.Free;
    end;
  end;
end;

end.
