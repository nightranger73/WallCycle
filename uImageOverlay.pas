unit uImageOverlay;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Forms, Graphics, GraphType, IntfGraphics, FPImage,
  FPCanvas, FPImgCanv, FPWritePNG, Types, zstream,
  uConfig, uLuminanceFilter;

function RenderWallpaperWithClock(const SourcePath, OutputDir: string;
  Config: TWallCycleConfig; var ToggleSlot: Integer; out OutputPath: string): Boolean;

procedure EnsureLocalizedDateNames;

procedure DrawOutlinedText(Canvas: TCanvas; X, Y: Integer; const Text: string;
  OutlineWidth: Integer; TextColor, OutlineColor: TColor);

function GetTargetScreenResolution: TSize;

function ComputeCoverCropRect(SrcW, SrcH, DstW, DstH: Integer): TRect;

implementation

function GetTargetScreenResolution: TSize;
var
  Mon: TMonitor;
  Scale: Double;
begin
  Result.cx := 1920;
  Result.cy := 1080;
  if Screen = nil then Exit;

  Mon := Screen.PrimaryMonitor;
  if Mon <> nil then
  begin
    Result.cx := Mon.Width;
    Result.cy := Mon.Height;
    if Mon.PixelsPerInch > 96 then
    begin
      Scale := Mon.PixelsPerInch / 96.0;
      Result.cx := Round(Result.cx * Scale);
      Result.cy := Round(Result.cy * Scale);
    end;
  end
  else if (Screen.Width > 0) and (Screen.Height > 0) then
  begin
    Result.cx := Screen.Width;
    Result.cy := Screen.Height;
  end;
end;

function ComputeCoverCropRect(SrcW, SrcH, DstW, DstH: Integer): TRect;
var
  SrcAspect, DstAspect: Double;
  CropW, CropH, OffsetX, OffsetY: Integer;
begin
  if (SrcW <= 0) or (SrcH <= 0) or (DstW <= 0) or (DstH <= 0) then
    Exit(Rect(0, 0, Max(1, SrcW), Max(1, SrcH)));

  SrcAspect := SrcW / SrcH;
  DstAspect := DstW / DstH;

  if SrcAspect > DstAspect then
  begin
    // Immagine più larga dello schermo: taglia sinistra e destra
    CropH := SrcH;
    CropW := Round(SrcH * DstAspect);
    OffsetX := (SrcW - CropW) div 2;
    OffsetY := 0;
  end
  else
  begin
    // Immagine più alta dello schermo: taglia sopra e sotto
    CropW := SrcW;
    CropH := Round(SrcW / DstAspect);
    OffsetX := 0;
    OffsetY := (SrcH - CropH) div 2;
  end;

  Result := Rect(OffsetX, OffsetY, OffsetX + CropW, OffsetY + CropH);
end;

procedure BlendRoundedScrim(Bmp: TBitmap; const Box: TRect; Radius: Integer;
  Alpha: Byte);
var
  IntfImg: TLazIntfImage;
  X, Y, DX, DY: Integer;
  InCorner, Inside: Boolean;
  A, InvA: Double;
  C: TFPColor;
  BgR, BgG, BgB: Word;
  BorderFactor: Double;
begin
  if Alpha = 0 then Exit;
  IntfImg := Bmp.CreateIntfImage;
  try
    A := Alpha / 255.0;
    InvA := 1.0 - A;
    BgR := Round(10 * 257);
    BgG := Round(14 * 257);
    BgB := Round(22 * 257);

    for Y := Max(0, Box.Top) to Min(IntfImg.Height - 1, Box.Bottom - 1) do
    begin
      for X := Max(0, Box.Left) to Min(IntfImg.Width - 1, Box.Right - 1) do
      begin
        Inside := True;
        InCorner := False;
        DX := 0;
        DY := 0;

        if (X < Box.Left + Radius) and (Y < Box.Top + Radius) then
        begin
          InCorner := True;
          DX := (Box.Left + Radius) - X;
          DY := (Box.Top + Radius) - Y;
        end
        else if (X >= Box.Right - Radius) and (Y < Box.Top + Radius) then
        begin
          InCorner := True;
          DX := X - (Box.Right - Radius - 1);
          DY := (Box.Top + Radius) - Y;
        end
        else if (X < Box.Left + Radius) and (Y >= Box.Bottom - Radius) then
        begin
          InCorner := True;
          DX := (Box.Left + Radius) - X;
          DY := Y - (Box.Bottom - Radius - 1);
        end
        else if (X >= Box.Right - Radius) and (Y >= Box.Bottom - Radius) then
        begin
          InCorner := True;
          DX := X - (Box.Right - Radius - 1);
          DY := Y - (Box.Bottom - Radius - 1);
        end;

        if InCorner and (Sqr(DX) + Sqr(DY) > Sqr(Radius)) then
          Inside := False;

        if Inside then
        begin
          C := IntfImg.Colors[X, Y];
          C.Red := EnsureRange(Round(C.Red * InvA + BgR * A), 0, 65535);
          C.Green := EnsureRange(Round(C.Green * InvA + BgG * A), 0, 65535);
          C.Blue := EnsureRange(Round(C.Blue * InvA + BgB * A), 0, 65535);

          // Subtle 1px light edge highlight for glass contrast
          if (X = Box.Left) or (X = Box.Right - 1) or (Y = Box.Top) or (Y = Box.Bottom - 1) then
          begin
            BorderFactor := 0.14;
            C.Red := EnsureRange(Round(C.Red * (1 - BorderFactor) + 65535 * BorderFactor), 0, 65535);
            C.Green := EnsureRange(Round(C.Green * (1 - BorderFactor) + 65535 * BorderFactor), 0, 65535);
            C.Blue := EnsureRange(Round(C.Blue * (1 - BorderFactor) + 65535 * BorderFactor), 0, 65535);
          end;

          IntfImg.Colors[X, Y] := C;
        end;
      end;
    end;
    Bmp.LoadFromIntfImage(IntfImg);
  finally
    IntfImg.Free;
  end;
end;

function LoadPictureSafe(Pic: TPicture; const FileName: string): Boolean;
var
  Fmt: TDetectedImageFormat;
  Ext: string;
  FS: TFileStream;
begin
  Result := False;
  Fmt := DetectImageFormat(FileName);
  Ext := ImageFormatToExt(Fmt);
  if Ext = '' then Exit;

  FS := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
  try
    try
      Pic.LoadFromStreamWithFileExt(FS, Ext);
      Result := (Pic.Width > 0) and (Pic.Height > 0);
    except
      Result := False;
    end;
  finally
    FS.Free;
  end;
end;

procedure EnsureLocalizedDateNames;
var
  Loc: string;
begin
  Loc := LowerCase(Trim(GetEnvironmentVariable('LC_ALL')));
  if Loc = '' then Loc := LowerCase(Trim(GetEnvironmentVariable('LC_TIME')));
  if Loc = '' then Loc := LowerCase(Trim(GetEnvironmentVariable('LANG')));

  if (Copy(Loc, 1, 2) = 'it') and (DefaultFormatSettings.LongDayNames[2] = 'Monday') then
  begin
    DefaultFormatSettings.ShortDayNames[1] := 'dom';
    DefaultFormatSettings.ShortDayNames[2] := 'lun';
    DefaultFormatSettings.ShortDayNames[3] := 'mar';
    DefaultFormatSettings.ShortDayNames[4] := 'mer';
    DefaultFormatSettings.ShortDayNames[5] := 'gio';
    DefaultFormatSettings.ShortDayNames[6] := 'ven';
    DefaultFormatSettings.ShortDayNames[7] := 'sab';

    DefaultFormatSettings.LongDayNames[1] := 'domenica';
    DefaultFormatSettings.LongDayNames[2] := 'lunedì';
    DefaultFormatSettings.LongDayNames[3] := 'martedì';
    DefaultFormatSettings.LongDayNames[4] := 'mercoledì';
    DefaultFormatSettings.LongDayNames[5] := 'giovedì';
    DefaultFormatSettings.LongDayNames[6] := 'venerdì';
    DefaultFormatSettings.LongDayNames[7] := 'sabato';

    DefaultFormatSettings.ShortMonthNames[1] := 'gen';
    DefaultFormatSettings.ShortMonthNames[2] := 'feb';
    DefaultFormatSettings.ShortMonthNames[3] := 'mar';
    DefaultFormatSettings.ShortMonthNames[4] := 'apr';
    DefaultFormatSettings.ShortMonthNames[5] := 'mag';
    DefaultFormatSettings.ShortMonthNames[6] := 'giu';
    DefaultFormatSettings.ShortMonthNames[7] := 'lug';
    DefaultFormatSettings.ShortMonthNames[8] := 'ago';
    DefaultFormatSettings.ShortMonthNames[9] := 'set';
    DefaultFormatSettings.ShortMonthNames[10] := 'ott';
    DefaultFormatSettings.ShortMonthNames[11] := 'nov';
    DefaultFormatSettings.ShortMonthNames[12] := 'dic';

    DefaultFormatSettings.LongMonthNames[1] := 'gennaio';
    DefaultFormatSettings.LongMonthNames[2] := 'febbraio';
    DefaultFormatSettings.LongMonthNames[3] := 'marzo';
    DefaultFormatSettings.LongMonthNames[4] := 'aprile';
    DefaultFormatSettings.LongMonthNames[5] := 'maggio';
    DefaultFormatSettings.LongMonthNames[6] := 'giugno';
    DefaultFormatSettings.LongMonthNames[7] := 'luglio';
    DefaultFormatSettings.LongMonthNames[8] := 'agosto';
    DefaultFormatSettings.LongMonthNames[9] := 'settembre';
    DefaultFormatSettings.LongMonthNames[10] := 'ottobre';
    DefaultFormatSettings.LongMonthNames[11] := 'novembre';
    DefaultFormatSettings.LongMonthNames[12] := 'dicembre';
  end;
end;

procedure DrawOutlinedText(Canvas: TCanvas; X, Y: Integer; const Text: string;
  OutlineWidth: Integer; TextColor, OutlineColor: TColor);
var
  DX, DY, R2: Integer;
begin
  Canvas.Brush.Style := bsClear;
  if OutlineWidth > 0 then
  begin
    Canvas.Font.Color := OutlineColor;
    if OutlineWidth = 1 then
      R2 := 2
    else
      R2 := Sqr(OutlineWidth);
    for DY := -OutlineWidth to OutlineWidth do
      for DX := -OutlineWidth to OutlineWidth do
      begin
        if (DX = 0) and (DY = 0) then Continue;
        if Sqr(DX) + Sqr(DY) <= R2 then
          Canvas.TextOut(X + DX, Y + DY, Text);
      end;
  end;
  Canvas.Font.Color := TextColor;
  Canvas.TextOut(X, Y, Text);
end;

function SaveBitmapFastPNG(Bmp: TBitmap; const DestPath: string): Boolean;
var
  IntfImg: TLazIntfImage;
  Writer: TFPWriterPNG;
begin
  Result := False;
  IntfImg := Bmp.CreateIntfImage;
  Writer := TFPWriterPNG.Create;
  try
    Writer.CompressionLevel := clfastest;
    Writer.UseAlpha := False;
    try
      IntfImg.SaveToFile(DestPath, Writer);
      Result := True;
    except
      Result := False;
    end;
  finally
    Writer.Free;
    IntfImg.Free;
  end;
end;

procedure RenderCoverToBitmap(Pic: TPicture; Bmp: TBitmap; TargetW, TargetH: Integer);
var
  SrcIntf, CropIntf, DstIntf: TLazIntfImage;
  FPCanv: TFPImageCanvas;
  CropRect: TRect;
  CropW, CropH, X, Y: Integer;
begin
  Bmp.SetSize(TargetW, TargetH);

  // Se l'immagine ha già esattamente la risoluzione dello schermo, copia diretta
  if (Pic.Width = TargetW) and (Pic.Height = TargetH) then
  begin
    Bmp.Canvas.Draw(0, 0, Pic.Graphic);
    Exit;
  end;

  CropRect := ComputeCoverCropRect(Pic.Width, Pic.Height, TargetW, TargetH);
  CropW := Max(1, CropRect.Right - CropRect.Left);
  CropH := Max(1, CropRect.Bottom - CropRect.Top);

  SrcIntf := Pic.Bitmap.CreateIntfImage;
  CropIntf := TLazIntfImage.Create(CropW, CropH, [riqfRGB, riqfAlpha]);
  DstIntf := TLazIntfImage.Create(TargetW, TargetH, [riqfRGB, riqfAlpha]);
  try
    // Estrae la porzione centrale con l'aspect ratio corretto
    for Y := 0 to CropH - 1 do
      for X := 0 to CropW - 1 do
        CropIntf.Colors[X, Y] := SrcIntf.Colors[CropRect.Left + X, CropRect.Top + Y];

    // Ridimensiona con interpolazione di alta qualità (Mitchell)
    FPCanv := TFPImageCanvas.Create(DstIntf);
    try
      FPCanv.StretchDraw(0, 0, TargetW, TargetH, CropIntf);
    finally
      FPCanv.Free;
    end;

    Bmp.LoadFromIntfImage(DstIntf);
  finally
    DstIntf.Free;
    CropIntf.Free;
    SrcIntf.Free;
  end;
end;

function RenderWallpaperWithClock(const SourcePath, OutputDir: string;
  Config: TWallCycleConfig; var ToggleSlot: Integer; out OutputPath: string): Boolean;
var
  Pic: TPicture;
  Bmp: TBitmap;
  TimeStr, DateStr, TimeFmt: string;
  NowDT: TDateTime;
  TimeSize, DateSize, TargetRes: TSize;
  PadX, PadY, GapY, BoxW, BoxH, BoxX, BoxY, Margin, RefSize: Integer;
  TimeOutlineW, DateOutlineW, TimeX, DateX: Integer;
  AlignRight, TransparentBg: Boolean;
  BoxRect: TRect;
  PrevFile: string;
begin
  Result := False;
  OutputPath := '';
  if not FileExists(SourcePath) then Exit;

  ForceDirectories(OutputDir);
  ToggleSlot := (ToggleSlot + 1) mod 2;
  OutputPath := IncludeTrailingPathDelimiter(OutputDir) +
    Format('wallcycle_active_%d.png', [ToggleSlot]);
  PrevFile := IncludeTrailingPathDelimiter(OutputDir) +
    Format('wallcycle_active_%d.png', [(ToggleSlot + 1) mod 2]);

  if not Config.OverlayEnabled then
  begin
    Pic := TPicture.Create;
    Bmp := TBitmap.Create;
    try
      if not LoadPictureSafe(Pic, SourcePath) then Exit(False);
      Bmp.PixelFormat := pf24bit;
      TargetRes := GetTargetScreenResolution;
      RenderCoverToBitmap(Pic, Bmp, TargetRes.cx, TargetRes.cy);
      if SaveBitmapFastPNG(Bmp, OutputPath) then
      begin
        if FileExists(PrevFile) then DeleteFile(PrevFile);
        Exit(True);
      end;
      Exit(False);
    finally
      Bmp.Free;
      Pic.Free;
    end;
  end;

  Pic := TPicture.Create;
  Bmp := TBitmap.Create;
  try
    if not LoadPictureSafe(Pic, SourcePath) then Exit(False);

    Bmp.PixelFormat := pf32bit;
    TargetRes := GetTargetScreenResolution;
    RenderCoverToBitmap(Pic, Bmp, TargetRes.cx, TargetRes.cy);

    EnsureLocalizedDateNames;
    NowDT := Now;
    TimeFmt := Config.OverlayTimeFormat;
    if Config.OverlayShowSeconds and (Pos('ss', LowerCase(TimeFmt)) = 0) then
      TimeFmt := TimeFmt + ':ss';

    TimeStr := FormatDateTime(TimeFmt, NowDT);
    DateStr := FormatDateTime(Config.OverlayDateFormat, NowDT);

    TimeOutlineW := Max(1, Round(Config.OverlayTimeFontSize * 0.04));
    DateOutlineW := Max(1, Round(Config.OverlayDateFontSize * 0.045));

    // Measure Time dimensions with Time font & size
    Bmp.Canvas.Font.Name := Config.OverlayTimeFontName;
    Bmp.Canvas.Font.Quality := fqAntialiased;
    Bmp.Canvas.Font.Size := Max(10, Config.OverlayTimeFontSize);
    Bmp.Canvas.Font.Style := [fsBold];
    TimeSize := Bmp.Canvas.TextExtent(TimeStr);

    // Measure Date dimensions with Date font & size
    Bmp.Canvas.Font.Name := Config.OverlayDateFontName;
    Bmp.Canvas.Font.Size := Max(8, Config.OverlayDateFontSize);
    Bmp.Canvas.Font.Style := [];
    DateSize := Bmp.Canvas.TextExtent(DateStr);

    RefSize := Max(Config.OverlayTimeFontSize, Config.OverlayDateFontSize);
    TransparentBg := Config.OverlayTransparentBg or (Config.OverlayBackdropOpacity = 0);
    if TransparentBg then
    begin
      PadX := Max(TimeOutlineW, DateOutlineW) + 2;
      PadY := Max(TimeOutlineW, DateOutlineW) + 2;
    end
    else
    begin
      PadX := Max(18, Round(RefSize * 0.65));
      PadY := Max(14, Round(RefSize * 0.45));
    end;

    GapY := Max(4, Round(RefSize * 0.14));
    Margin := Max(8, Config.OverlayMarginPx);

    BoxW := Max(TimeSize.cx, DateSize.cx) + PadX * 2;
    BoxH := TimeSize.cy + DateSize.cy + GapY + PadY * 2;

    case Config.OverlayCorner of
      ocTopLeft:
        begin
          BoxX := Margin;
          BoxY := Margin;
        end;
      ocTopRight:
        begin
          BoxX := Bmp.Width - BoxW - Margin;
          BoxY := Margin;
        end;
      ocBottomLeft:
        begin
          BoxX := Margin;
          BoxY := Bmp.Height - BoxH - Margin;
        end;
      ocBottomRight:
        begin
          BoxX := Bmp.Width - BoxW - Margin;
          BoxY := Bmp.Height - BoxH - Margin;
        end;
    end;

    BoxX := EnsureRange(BoxX, 8, Max(8, Bmp.Width - BoxW - 8));
    BoxY := EnsureRange(BoxY, 8, Max(8, Bmp.Height - BoxH - 8));
    BoxRect := Rect(BoxX, BoxY, BoxX + BoxW, BoxY + BoxH);

    if not TransparentBg then
      BlendRoundedScrim(Bmp, BoxRect, 14, Config.OverlayBackdropOpacity);

    // Align left when placed on left corners, right when placed on right corners
    AlignRight := Config.OverlayCorner in [ocTopRight, ocBottomRight];
    if AlignRight then
    begin
      TimeX := BoxX + BoxW - PadX - TimeSize.cx;
      DateX := BoxX + BoxW - PadX - DateSize.cx;
    end
    else
    begin
      TimeX := BoxX + PadX;
      DateX := BoxX + PadX;
    end;

    // Draw Time in pure white with black outline
    Bmp.Canvas.Font.Name := Config.OverlayTimeFontName;
    Bmp.Canvas.Font.Size := Max(10, Config.OverlayTimeFontSize);
    Bmp.Canvas.Font.Style := [fsBold];
    DrawOutlinedText(
      Bmp.Canvas,
      TimeX,
      BoxY + PadY,
      TimeStr,
      TimeOutlineW,
      RGBToColor(255, 255, 255),
      RGBToColor(0, 0, 0)
    );

    // Draw Date below Time in pure white with black outline
    Bmp.Canvas.Font.Name := Config.OverlayDateFontName;
    Bmp.Canvas.Font.Size := Max(8, Config.OverlayDateFontSize);
    Bmp.Canvas.Font.Style := [];
    DrawOutlinedText(
      Bmp.Canvas,
      DateX,
      BoxY + PadY + TimeSize.cy + GapY,
      DateStr,
      DateOutlineW,
      RGBToColor(255, 255, 255),
      RGBToColor(0, 0, 0)
    );

    Result := SaveBitmapFastPNG(Bmp, OutputPath);
    if Result and FileExists(PrevFile) then
      DeleteFile(PrevFile);
  finally
    Bmp.Free;
    Pic.Free;
  end;
end;

end.
