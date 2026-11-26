unit uLuminanceFilter;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, SyncObjs, FPImage, FPReadJPEG, FPReadPNG, FPReadBMP,
  fpjson, jsonparser;

type
  TDetectedImageFormat = (ifUnknown, ifJPEG, ifPNG, ifBMP);

  TLuminanceStats = record
    Valid: Boolean;
    ErrorReason: string;
    Format: TDetectedImageFormat;
    Width: Integer;
    Height: Integer;
    AverageLuminance: Double;   // 0.0 (black) .. 1.0 (white)
    IconZoneLuminance: Double;  // Average luminance in left 24% desktop icon area
    P90Luminance: Double;       // 90th percentile brightness to catch bright patches
  end;

  // Thread-safe persistent cache keyed by FilePath + FileSize + MTime
  TLuminanceCache = class
  private
    FLock: TCriticalSection;
    FEntries: TJSONObject;
    FCacheFile: string;
    FDirty: Boolean;
    function BuildKey(const FileName: string; Size: Int64; MTime: Int64): string;
  public
    constructor Create(const CacheFilePath: string);
    destructor Destroy; override;
    procedure Load;
    procedure SaveIfDirty;
    function TryGet(const FileName: string; out Stats: TLuminanceStats): Boolean;
    procedure Put(const FileName: string; const Stats: TLuminanceStats);
    function PruneMissingFiles: Integer;
  end;

function DetectImageFormat(const FileName: string): TDetectedImageFormat;
function ImageFormatToExt(Fmt: TDetectedImageFormat): string;
function AnalyzeImageLuminance(const FileName: string): TLuminanceStats;
function IsImageDarkEnough(const FileName: string; MaxAvgLum, MaxIconZoneLum: Double;
  CheckIconZone: Boolean; out Stats: TLuminanceStats;
  Cache: TLuminanceCache = nil): Boolean;
function EstimateHexPaletteLuminance(const HexColors: array of string): Double;
function HexColorToLuminance(const HexStr: string): Double;

implementation

function GetFileStamp(const FileName: string; out Size: Int64; out MTime: Int64): Boolean;
var
  SR: TSearchRec;
begin
  Result := False;
  Size := 0;
  MTime := 0;
  if FindFirst(FileName, faAnyFile, SR) = 0 then
  begin
    Size := SR.Size;
    MTime := SR.Time;
    FindClose(SR);
    Result := True;
  end;
end;

function DetectImageFormat(const FileName: string): TDetectedImageFormat;
var
  FS: TFileStream;
  Buf: array[0..11] of Byte;
  ReadCount: Integer;
begin
  Result := ifUnknown;
  if not FileExists(FileName) then Exit;

  try
    FS := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
    try
      if FS.Size < 32 then Exit; // Empty or truncated file
      FillChar(Buf, SizeOf(Buf), 0);
      ReadCount := FS.Read(Buf, SizeOf(Buf));
      if ReadCount < 4 then Exit;

      // JPEG: FF D8 FF
      if (Buf[0] = $FF) and (Buf[1] = $D8) and (Buf[2] = $FF) then
        Exit(ifJPEG);

      // PNG: 89 50 4E 47 0D 0A 1A 0A
      if (ReadCount >= 8) and (Buf[0] = $89) and (Buf[1] = $50) and
         (Buf[2] = $4E) and (Buf[3] = $47) and (Buf[4] = $0D) and
         (Buf[5] = $0A) and (Buf[6] = $1A) and (Buf[7] = $0A) then
        Exit(ifPNG);

      // BMP: 42 4D ('BM')
      if (Buf[0] = $42) and (Buf[1] = $4D) then
        Exit(ifBMP);
    finally
      FS.Free;
    end;
  except
    Result := ifUnknown;
  end;
end;

function ImageFormatToExt(Fmt: TDetectedImageFormat): string;
begin
  case Fmt of
    ifJPEG: Result := '.jpg';
    ifPNG: Result := '.png';
    ifBMP: Result := '.bmp';
  else
    Result := '';
  end;
end;

{ TLuminanceCache }

constructor TLuminanceCache.Create(const CacheFilePath: string);
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FEntries := TJSONObject.Create;
  FCacheFile := CacheFilePath;
  FDirty := False;
end;

destructor TLuminanceCache.Destroy;
begin
  SaveIfDirty;
  FLock.Enter;
  try
    FEntries.Free;
  finally
    FLock.Leave;
  end;
  FLock.Free;
  inherited Destroy;
end;

function TLuminanceCache.BuildKey(const FileName: string; Size: Int64; MTime: Int64): string;
begin
  Result := FileName + '|' + IntToStr(Size) + '|' + IntToStr(MTime);
end;

procedure TLuminanceCache.Load;
var
  FS: TFileStream;
  Data: TJSONData;
begin
  if (FCacheFile = '') or (not FileExists(FCacheFile)) then Exit;
  FLock.Enter;
  try
    Data := nil;
    FS := TFileStream.Create(FCacheFile, fmOpenRead or fmShareDenyWrite);
    try
      try
        Data := GetJSON(FS);
        if Data is TJSONObject then
        begin
          FEntries.Free;
          FEntries := TJSONObject(Data);
          Data := nil;
        end;
      except
        // Ignore corrupted cache and rebuild cleanly
      end;
    finally
      Data.Free;
      FS.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TLuminanceCache.SaveIfDirty;
var
  S: string;
  FS: TFileStream;
begin
  if FCacheFile = '' then Exit;
  FLock.Enter;
  try
    if not FDirty then Exit;
    ForceDirectories(ExtractFileDir(FCacheFile));
    S := FEntries.AsJSON;
    FS := TFileStream.Create(FCacheFile, fmCreate);
    try
      if Length(S) > 0 then
        FS.WriteBuffer(S[1], Length(S));
    finally
      FS.Free;
    end;
    FDirty := False;
  finally
    FLock.Leave;
  end;
end;

function TLuminanceCache.TryGet(const FileName: string; out Stats: TLuminanceStats): Boolean;
var
  Size, MTime: Int64;
  Key: string;
  Obj: TJSONObject;
begin
  Result := False;
  Stats.Valid := False;
  Stats.ErrorReason := '';
  Stats.Format := ifUnknown;
  if not GetFileStamp(FileName, Size, MTime) then Exit;
  Key := BuildKey(FileName, Size, MTime);

  FLock.Enter;
  try
    Obj := FEntries.Get(Key, TJSONObject(nil));
    if Obj <> nil then
    begin
      Stats.AverageLuminance := Obj.Get('a', 1.0);
      Stats.IconZoneLuminance := Obj.Get('i', 1.0);
      Stats.P90Luminance := Obj.Get('p', 1.0);
      Stats.Width := Obj.Get('w', 0);
      Stats.Height := Obj.Get('h', 0);
      Stats.Format := TDetectedImageFormat(Obj.Get('f', 0));
      Stats.Valid := True;
      Result := True;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TLuminanceCache.Put(const FileName: string; const Stats: TLuminanceStats);
var
  Size, MTime: Int64;
  Key: string;
  Obj: TJSONObject;
begin
  if not Stats.Valid then Exit;
  if not GetFileStamp(FileName, Size, MTime) then Exit;
  Key := BuildKey(FileName, Size, MTime);

  FLock.Enter;
  try
    if FEntries.Count > 25000 then
      FEntries.Clear;
    Obj := TJSONObject.Create;
    Obj.Add('a', RoundTo(Stats.AverageLuminance, -4));
    Obj.Add('i', RoundTo(Stats.IconZoneLuminance, -4));
    Obj.Add('p', RoundTo(Stats.P90Luminance, -4));
    Obj.Add('w', Stats.Width);
    Obj.Add('h', Stats.Height);
    Obj.Add('f', Ord(Stats.Format));
    FEntries.Elements[Key] := Obj;
    FDirty := True;
  finally
    FLock.Leave;
  end;
end;

function TLuminanceCache.PruneMissingFiles: Integer;
var
  I, P: Integer;
  Key, FilePath: string;
  ToRemove: TStringList;
begin
  Result := 0;
  ToRemove := TStringList.Create;
  try
    FLock.Enter;
    try
      for I := 0 to FEntries.Count - 1 do
      begin
        Key := FEntries.Names[I];
        P := Pos('|', Key);
        if P > 1 then
          FilePath := Copy(Key, 1, P - 1)
        else
          FilePath := Key;
        if (FilePath = '') or (not FileExists(FilePath)) then
          ToRemove.Add(Key);
      end;

      for I := 0 to ToRemove.Count - 1 do
      begin
        FEntries.Delete(ToRemove[I]);
        Inc(Result);
      end;
      if Result > 0 then
        FDirty := True;
    finally
      FLock.Leave;
    end;
  finally
    ToRemove.Free;
  end;
end;

function HexColorToLuminance(const HexStr: string): Double;
var
  S: string;
  R, G, B: Byte;
begin
  S := Trim(HexStr);
  if (Length(S) > 0) and (S[1] = '#') then
    Delete(S, 1, 1);
  if Length(S) <> 6 then
    Exit(0.5);
  R := StrToIntDef('$' + Copy(S, 1, 2), 128);
  G := StrToIntDef('$' + Copy(S, 3, 2), 128);
  B := StrToIntDef('$' + Copy(S, 5, 2), 128);
  Result := (0.2126 * R + 0.7152 * G + 0.0722 * B) / 255.0;
end;

function EstimateHexPaletteLuminance(const HexColors: array of string): Double;
var
  I, Count: Integer;
  Sum: Double;
begin
  Count := Length(HexColors);
  if Count = 0 then Exit(0.5);
  Sum := 0.0;
  for I := 0 to Count - 1 do
    Sum := Sum + HexColorToLuminance(HexColors[I]);
  Result := Sum / Count;
end;

function TryDecodeImage(const FileName: string; Fmt: TDetectedImageFormat;
  JpegScale: TJPEGScale; Img: TFPMemoryImage; out ErrMsg: string): Boolean;
var
  Reader: TFPCustomImageReader;
  JpgReader: TFPReaderJPEG;
begin
  Result := False;
  ErrMsg := '';
  Reader := nil;
  case Fmt of
    ifJPEG:
      begin
        JpgReader := TFPReaderJPEG.Create;
        JpgReader.Scale := JpegScale;
        Reader := JpgReader;
      end;
    ifPNG:
      Reader := TFPReaderPNG.Create;
    ifBMP:
      Reader := TFPReaderBMP.Create;
  else
    begin
      ErrMsg := 'Unrecognized file header or corrupted file';
      Exit(False);
    end;
  end;

  try
    try
      Img.LoadFromFile(FileName, Reader);
      if (Img.Width <= 0) or (Img.Height <= 0) then
      begin
        ErrMsg := 'Invalid image dimensions (0x0)';
        Exit(False);
      end;
      Result := True;
    except
      on E: Exception do
      begin
        ErrMsg := E.Message;
        Result := False;
      end;
    end;
  finally
    Reader.Free;
  end;
end;

function AnalyzeImageLuminance(const FileName: string): TLuminanceStats;
var
  Img: TFPMemoryImage;
  Fmt: TDetectedImageFormat;
  ErrMsg: string;
  StepX, StepY, X, Y, IconLimitX: Integer;
  TotalCount, IconCount: Int64;
  TotalSum, IconSum, Lum: Double;
  C: TFPColor;
  R8, G8, B8: Double;
  Histogram: array[0..255] of Int64;
  TargetIdx, Acc: Int64;
  I: Integer;
begin
  Result.Valid := False;
  Result.ErrorReason := '';
  Result.Format := ifUnknown;
  Result.Width := 0;
  Result.Height := 0;
  Result.AverageLuminance := 1.0;
  Result.IconZoneLuminance := 1.0;
  Result.P90Luminance := 1.0;

  if not FileExists(FileName) then
  begin
    Result.ErrorReason := 'File not found';
    Exit;
  end;

  // Detect actual binary format via magic bytes (ignores wrong extensions!)
  Fmt := DetectImageFormat(FileName);
  Result.Format := Fmt;
  if Fmt = ifUnknown then
  begin
    Result.ErrorReason := 'Corrupted header or unsupported format (expected JPEG/PNG/BMP)';
    Exit;
  end;

  Img := TFPMemoryImage.Create(0, 0);
  try
    if Fmt = ifJPEG then
    begin
      // Try fast 1/4 DCT scaling first; fallback to full-size if JPEG has unusual markers
      if not TryDecodeImage(FileName, ifJPEG, jsQuarter, Img, ErrMsg) then
      begin
        Img.SetSize(0, 0);
        if not TryDecodeImage(FileName, ifJPEG, jsFullSize, Img, ErrMsg) then
        begin
          Result.ErrorReason := 'Corrupted JPEG: ' + ErrMsg;
          Exit;
        end;
      end;
    end
    else
    begin
      if not TryDecodeImage(FileName, Fmt, jsFullSize, Img, ErrMsg) then
      begin
        Result.ErrorReason := 'Corrupted image: ' + ErrMsg;
        Exit;
      end;
    end;

    Result.Width := Img.Width;
    Result.Height := Img.Height;

    StepX := Max(1, Img.Width div 140);
    StepY := Max(1, Img.Height div 80);
    IconLimitX := Round(Img.Width * 0.24);

    TotalCount := 0;
    IconCount := 0;
    TotalSum := 0.0;
    IconSum := 0.0;
    FillChar(Histogram, SizeOf(Histogram), 0);

    Y := 0;
    while Y < Img.Height do
    begin
      X := 0;
      while X < Img.Width do
      begin
        C := Img.Colors[X, Y];
        R8 := C.Red shr 8;
        G8 := C.Green shr 8;
        B8 := C.Blue shr 8;

        Lum := (0.2126 * R8 + 0.7152 * G8 + 0.0722 * B8) / 255.0;
        TotalSum := TotalSum + Lum;
        Inc(TotalCount);
        Inc(Histogram[EnsureRange(Round(Lum * 255.0), 0, 255)]);

        if X <= IconLimitX then
        begin
          IconSum := IconSum + Lum;
          Inc(IconCount);
        end;

        Inc(X, StepX);
      end;
      Inc(Y, StepY);
    end;

    if TotalCount > 0 then
    begin
      Result.AverageLuminance := TotalSum / TotalCount;
      if IconCount > 0 then
        Result.IconZoneLuminance := IconSum / IconCount
      else
        Result.IconZoneLuminance := Result.AverageLuminance;

      TargetIdx := Round(TotalCount * 0.90);
      Acc := 0;
      for I := 0 to 255 do
      begin
        Inc(Acc, Histogram[I]);
        if Acc >= TargetIdx then
        begin
          Result.P90Luminance := I / 255.0;
          Break;
        end;
      end;
      Result.Valid := True;
    end
    else
      Result.ErrorReason := 'No readable pixels';
  finally
    Img.Free;
  end;
end;

function IsImageDarkEnough(const FileName: string; MaxAvgLum, MaxIconZoneLum: Double;
  CheckIconZone: Boolean; out Stats: TLuminanceStats;
  Cache: TLuminanceCache): Boolean;
begin
  if (Cache = nil) or (not Cache.TryGet(FileName, Stats)) then
  begin
    Stats := AnalyzeImageLuminance(FileName);
    if (Cache <> nil) and Stats.Valid then
      Cache.Put(FileName, Stats);
  end;

  if not Stats.Valid then
    Exit(False);
  if Stats.AverageLuminance > MaxAvgLum then
    Exit(False);
  if CheckIconZone and (Stats.IconZoneLuminance > MaxIconZoneLum) then
    Exit(False);
  Result := True;
end;

end.
