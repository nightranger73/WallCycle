unit uPlaylistScanner;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, SyncObjs,
  uConfig, uLuminanceFilter;

type
  TScanSourceSnapshot = record
    Kind: TSourceKind;
    PathToScan: string;
    Recursive: Boolean;
  end;

  TScanState = record
    Running: Boolean;
    FilesDiscovered: Integer;
    ListReady: Boolean;
    IndexedCount: Integer;
    RejectedLocal: Integer;
    RejectedWallHaven: Integer;
    Finished: Boolean;
  end;

  TPlaylistScanThread = class(TThread)
  private
    FLock: TCriticalSection;
    FSources: array of TScanSourceSnapshot;
    FShuffle: Boolean;
    FDarkFilterEnabled: Boolean;
    FMaxLum: Double;
    FIconLum: Double;
    FCheckIconZone: Boolean;
    FCache: TLuminanceCache;
    FBlacklist: TStringList;

    // Shared handoff state (never calls Synchronize -> 100% deadlock-free)
    FDiscovered: TStringList;
    FEligible: TStringList;
    FState: TScanState;

    function IsPathBlacklisted(const FilePath: string): Boolean;
    procedure ScanDir(const Dir: string; Recursive: Boolean; Kind: TSourceKind;
      OutPaths: TStrings; OutKinds: TList);
  protected
    procedure Execute; override;
  public
    constructor Create(Config: TWallCycleConfig; Cache: TLuminanceCache);
    destructor Destroy; override;
    function ConsumeDiscoveredList(Target: TStrings): Boolean;
    function ConsumeEligibleList(Target: TStrings): Boolean;
    function GetState: TScanState;
  end;

implementation

constructor TPlaylistScanThread.Create(Config: TWallCycleConfig; Cache: TLuminanceCache);
var
  I, Count: Integer;
  Src: TWallpaperSource;
begin
  inherited Create(True); // Create suspended until fields are initialized
  FreeOnTerminate := False;
  FLock := TCriticalSection.Create;
  FDiscovered := TStringList.Create;
  FEligible := TStringList.Create;
  FBlacklist := TStringList.Create;
  FBlacklist.CaseSensitive := False;
  FBlacklist.Assign(Config.BlacklistedItems);
  FCache := Cache;

  FShuffle := Config.ShuffleOrder;
  FDarkFilterEnabled := Config.DarkFilterEnabled;
  FMaxLum := Config.MaxLuminance;
  FIconLum := Config.IconZoneMaxLuminance;
  FCheckIconZone := Config.CheckIconZone;

  Count := 0;
  SetLength(FSources, Config.Sources.Count);
  for I := 0 to Config.Sources.Count - 1 do
  begin
    Src := Config.GetSource(I);
    if not Src.Enabled then Continue;
    FSources[Count].Kind := Src.Kind;
    if Src.Kind = skLocalFolder then
    begin
      FSources[Count].PathToScan := Src.Target;
      FSources[Count].Recursive := Config.IncludeSubfolders;
    end
    else
    begin
      FSources[Count].PathToScan := Src.GetWallHavenSubDir(Config.WallHavenCacheDir);
      FSources[Count].Recursive := False;
    end;
    Inc(Count);
  end;
  SetLength(FSources, Count);

  FillChar(FState, SizeOf(FState), 0);
  FState.Running := True;
  Start;
end;

destructor TPlaylistScanThread.Destroy;
begin
  FBlacklist.Free;
  FDiscovered.Free;
  FEligible.Free;
  FLock.Free;
  inherited Destroy;
end;

function TPlaylistScanThread.IsPathBlacklisted(const FilePath: string): Boolean;
var
  I: Integer;
  WhId, Token, Entry: string;
begin
  Result := False;
  if FBlacklist.Count = 0 then Exit;

  Token := '';
  if ExtractWallHavenIdFromPath(FilePath, WhId) then
    Token := 'wh:' + LowerCase(WhId);

  for I := 0 to FBlacklist.Count - 1 do
  begin
    Entry := Trim(FBlacklist[I]);
    if Entry = '' then Continue;
    if (Token <> '') and SameText(Entry, Token) then Exit(True);
    if SameFileName(Entry, FilePath) then Exit(True);
  end;
end;

procedure TPlaylistScanThread.ScanDir(const Dir: string; Recursive: Boolean;
  Kind: TSourceKind; OutPaths: TStrings; OutKinds: TList);
var
  SR: TSearchRec;
  Base, Ext: string;
begin
  if Terminated or (not DirectoryExists(Dir)) then Exit;
  Base := IncludeTrailingPathDelimiter(Dir);
  if FindFirst(Base + '*', faAnyFile, SR) = 0 then
  begin
    try
      repeat
        if Terminated then Break;
        if (SR.Name = '.') or (SR.Name = '..') then Continue;
        if (SR.Attr and faDirectory) <> 0 then
        begin
          if Recursive then
            ScanDir(Base + SR.Name, True, Kind, OutPaths, OutKinds);
        end
        else
        begin
          Ext := LowerCase(ExtractFileExt(SR.Name));
          if (Ext = '.jpg') or (Ext = '.jpeg') or (Ext = '.png') or (Ext = '.bmp') then
          begin
            if not IsPathBlacklisted(Base + SR.Name) then
            begin
              OutPaths.Add(Base + SR.Name);
              OutKinds.Add(Pointer(PtrInt(Ord(Kind))));
            end;
          end;
        end;
      until FindNext(SR) <> 0;
    finally
      FindClose(SR);
    end;
  end;
end;

procedure TPlaylistScanThread.Execute;
var
  Paths: TStringList;
  Kinds: TList;
  I, J: Integer;
  K: TSourceKind;
  Stats: TLuminanceStats;
  TmpPtr: Pointer;
begin
  Paths := TStringList.Create;
  Kinds := TList.Create;
  try
    // Phase 1: Ultra-fast directory traversal (no pixel decoding -> finishes in ms)
    for I := 0 to High(FSources) do
    begin
      if Terminated then Break;
      ScanDir(FSources[I].PathToScan, FSources[I].Recursive, FSources[I].Kind, Paths, Kinds);
    end;

    if Terminated then Exit;

    if FShuffle and (Paths.Count > 1) then
    begin
      for I := Paths.Count - 1 downto 1 do
      begin
        J := Random(I + 1);
        Paths.Exchange(I, J);
        TmpPtr := Kinds[I];
        Kinds[I] := Kinds[J];
        Kinds[J] := TmpPtr;
      end;
    end;

    FLock.Enter;
    try
      FDiscovered.Assign(Paths);
      FState.FilesDiscovered := Paths.Count;
      FState.ListReady := True;
    finally
      FLock.Leave;
    end;

    // Phase 2: Background luminance pre-indexing (cached + jsQuarter fast decode)
    if FDarkFilterEnabled and (Paths.Count > 0) then
    begin
      for I := 0 to Paths.Count - 1 do
      begin
        if Terminated then Break;
        K := TSourceKind(PtrInt(Kinds[I]));

        if IsImageDarkEnough(Paths[I], FMaxLum, FIconLum, FCheckIconZone, Stats, FCache) then
        begin
          FLock.Enter;
          try
            FEligible.Add(Paths[I]);
          finally
            FLock.Leave;
          end;
        end
        else
        begin
          FLock.Enter;
          try
            if K = skLocalFolder then
              Inc(FState.RejectedLocal)
            else
              Inc(FState.RejectedWallHaven);
          finally
            FLock.Leave;
          end;
        end;

        if (I mod 10 = 0) or (I = Paths.Count - 1) then
        begin
          FLock.Enter;
          try
            FState.IndexedCount := I + 1;
          finally
            FLock.Leave;
          end;
        end;

        if (I mod 4 = 0) then Sleep(5);
      end;

      if (not Terminated) and (FCache <> nil) then
      begin
        FCache.PruneMissingFiles;
        FCache.SaveIfDirty;
      end;
    end;
  finally
    FLock.Enter;
    try
      FState.Running := False;
      FState.Finished := not Terminated;
    finally
      FLock.Leave;
    end;
    Kinds.Free;
    Paths.Free;
  end;
end;

function TPlaylistScanThread.ConsumeDiscoveredList(Target: TStrings): Boolean;
begin
  Result := False;
  FLock.Enter;
  try
    if FState.ListReady then
    begin
      Target.Assign(FDiscovered);
      FState.ListReady := False;
      Result := True;
    end;
  finally
    FLock.Leave;
  end;
end;

function TPlaylistScanThread.ConsumeEligibleList(Target: TStrings): Boolean;
begin
  Result := False;
  FLock.Enter;
  try
    if FState.Finished and FDarkFilterEnabled then
    begin
      Target.Assign(FEligible);
      FState.Finished := False;
      Result := True;
    end;
  finally
    FLock.Leave;
  end;
end;

function TPlaylistScanThread.GetState: TScanState;
begin
  FLock.Enter;
  try
    Result := FState;
  finally
    FLock.Leave;
  end;
end;

end.
