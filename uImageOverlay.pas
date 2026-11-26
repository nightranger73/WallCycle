unit uImageOverlay;

{$mode objfpc}{$H+}

interface

uses
  {$IFDEF WINDOWS}
  Windows,
  {$ENDIF}
  Classes, SysUtils, Math, Graphics, Forms, IntfGraphics, FPImage, FPWritePNG, Types, zstream,
  uConfig, uLuminanceFilter;

function CreateRenderedWallpaperBitmap(const SourcePath: string;
  Config: TWallCycleConfig): TBitmap;

function RenderWallpaperFromBitmap(Bmp: TBitmap; const OutputDir: string;
  UseBMP: Boolean; var ToggleSlot: Integer; out OutputPath: string): Boolean;

function RenderTransitionStep(PrevBmp, NextBmp: TBitmap;
  Transition: TWallpaperTransition; Progress: Double; const OutputDir: string;
  UseBMP: Boolean; var ToggleSlot: Integer; out OutputPath: string): Boolean;

function RenderWallpaperWithClock(const SourcePath, OutputDir: string;
  Config: TWallCycleConfig; var ToggleSlot: Integer; out OutputPath: string): Boolean;

procedure EnsureLocalizedDateNames;

procedure DrawOutlinedText(Canvas: TCanvas; X, Y: Integer; const Text: string;
  OutlineWidth: Integer; TextColor, OutlineColor: TColor);

implementation

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

procedure GetTargetScreenSize(out TargetW, TargetH: Integer);
begin
  TargetW := 0;
  TargetH := 0;
  if Assigned(Screen) then
  begin
    if Assigned(Screen.PrimaryMonitor) then
    begin
      TargetW := Screen.PrimaryMonitor.Width;
      TargetH := Screen.PrimaryMonitor.Height;
    end;
    if (TargetW <= 0) or (TargetH <= 0) then
    begin
      TargetW := Screen.Width;
      TargetH := Screen.Height;
    end;
  end;
  if (TargetW <= 0) or (TargetH <= 0) then
  begin
    TargetW := 1920;
    TargetH := 1080;
  end;
  TargetW := Max(640, TargetW);
  TargetH := Max(480, TargetH);
end;

function CreateScreenFittedBitmap(Pic: TPicture; TargetPF: TPixelFormat): TBitmap;
var
  SrcW, SrcH, TargetW, TargetH: Integer;
  CropX, CropY, CropW, CropH: Integer;
  SrcAspect, TargetAspect: Double;
  SrcRect, DestRect: TRect;
  SrcBmp: TBitmap;
begin
  SrcW := Max(1, Pic.Width);
  SrcH := Max(1, Pic.Height);
  GetTargetScreenSize(TargetW, TargetH);

  Result := TBitmap.Create;
  Result.PixelFormat := TargetPF;
  Result.SetSize(TargetW, TargetH);
  Result.Canvas.Brush.Color := clBlack;
  Result.Canvas.FillRect(0, 0, TargetW, TargetH);

  if (SrcW = TargetW) and (SrcH = TargetH) then
  begin
    Result.Canvas.Draw(0, 0, Pic.Graphic);
    Exit;
  end;

  SrcAspect := SrcW / SrcH;
  TargetAspect := TargetW / TargetH;
  if SrcAspect > TargetAspect then
  begin
    CropH := SrcH;
    CropW := EnsureRange(Round(SrcH * TargetAspect), 1, SrcW);
    CropX := (SrcW - CropW) div 2;
    CropY := 0;
  end
  else
  begin
    CropW := SrcW;
    CropH := EnsureRange(Round(SrcW / TargetAspect), 1, SrcH);
    CropX := 0;
    CropY := (SrcH - CropH) div 2;
  end;

  SrcRect := Rect(CropX, CropY, CropX + CropW, CropY + CropH);
  DestRect := Rect(0, 0, TargetW, TargetH);

  SrcBmp := TBitmap.Create;
  try
    SrcBmp.PixelFormat := TargetPF;
    SrcBmp.SetSize(SrcW, SrcH);
    SrcBmp.Canvas.Brush.Color := clBlack;
    SrcBmp.Canvas.FillRect(0, 0, SrcW, SrcH);
    SrcBmp.Canvas.Draw(0, 0, Pic.Graphic);

    {$IFDEF WINDOWS}
    SetStretchBltMode(Result.Canvas.Handle, HALFTONE);
    SetBrushOrgEx(Result.Canvas.Handle, 0, 0, nil);
    {$ENDIF}
    Result.Canvas.CopyRect(DestRect, SrcBmp.Canvas, SrcRect);
  finally
    SrcBmp.Free;
  end;
end;

function CreateRenderedWallpaperBitmap(const SourcePath: string;
  Config: TWallCycleConfig): TBitmap;
var
  Pic: TPicture;
  TimeStr, DateStr, TimeFmt: string;
  NowDT: TDateTime;
  TimeSize, DateSize: TSize;
  PadX, PadY, GapY, BoxW, BoxH, BoxX, BoxY, Margin, RefSize: Integer;
  TimeOutlineW, DateOutlineW, TimeX, DateX: Integer;
  AlignRight, TransparentBg: Boolean;
  BoxRect: TRect;
begin
  Result := nil;
  if not FileExists(SourcePath) then Exit;

  Pic := TPicture.Create;
  try
    if not LoadPictureSafe(Pic, SourcePath) then Exit;

    Result := CreateScreenFittedBitmap(Pic, pf24bit);
    if not Config.OverlayEnabled then Exit;

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
    Result.Canvas.Font.Name := Config.OverlayTimeFontName;
    Result.Canvas.Font.Quality := fqAntialiased;
    Result.Canvas.Font.Size := Max(10, Config.OverlayTimeFontSize);
    Result.Canvas.Font.Style := [fsBold];
    TimeSize := Result.Canvas.TextExtent(TimeStr);

    // Measure Date dimensions with Date font & size
    Result.Canvas.Font.Name := Config.OverlayDateFontName;
    Result.Canvas.Font.Size := Max(8, Config.OverlayDateFontSize);
    Result.Canvas.Font.Style := [];
    DateSize := Result.Canvas.TextExtent(DateStr);

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
          BoxX := Result.Width - BoxW - Margin;
          BoxY := Margin;
        end;
      ocBottomLeft:
        begin
          BoxX := Margin;
          BoxY := Result.Height - BoxH - Margin;
        end;
      ocBottomRight:
        begin
          BoxX := Result.Width - BoxW - Margin;
          BoxY := Result.Height - BoxH - Margin;
        end;
    end;

    BoxX := EnsureRange(BoxX, 8, Max(8, Result.Width - BoxW - 8));
    BoxY := EnsureRange(BoxY, 8, Max(8, Result.Height - BoxH - 8));
    BoxRect := Rect(BoxX, BoxY, BoxX + BoxW, BoxY + BoxH);

    if not TransparentBg then
      BlendRoundedScrim(Result, BoxRect, 14, Config.OverlayBackdropOpacity);

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
    Result.Canvas.Font.Name := Config.OverlayTimeFontName;
    Result.Canvas.Font.Size := Max(10, Config.OverlayTimeFontSize);
    Result.Canvas.Font.Style := [fsBold];
    DrawOutlinedText(
      Result.Canvas,
      TimeX,
      BoxY + PadY,
      TimeStr,
      TimeOutlineW,
      RGBToColor(255, 255, 255),
      RGBToColor(0, 0, 0)
    );

    // Draw Date below Time in pure white with black outline
    Result.Canvas.Font.Name := Config.OverlayDateFontName;
    Result.Canvas.Font.Size := Max(8, Config.OverlayDateFontSize);
    Result.Canvas.Font.Style := [];
    DrawOutlinedText(
      Result.Canvas,
      DateX,
      BoxY + PadY + TimeSize.cy + GapY,
      DateStr,
      DateOutlineW,
      RGBToColor(255, 255, 255),
      RGBToColor(0, 0, 0)
    );
  finally
    Pic.Free;
  end;
end;

function RenderWallpaperFromBitmap(Bmp: TBitmap; const OutputDir: string;
  UseBMP: Boolean; var ToggleSlot: Integer; out OutputPath: string): Boolean;
var
  Dir, Ext, PrevPng, PrevBmp: string;
  PrevSlot: Integer;
begin
  Result := False;
  OutputPath := '';
  if Bmp = nil then Exit;

  Dir := IncludeTrailingPathDelimiter(OutputDir);
  ForceDirectories(Dir);

  PrevSlot := ToggleSlot;
  ToggleSlot := (ToggleSlot + 1) mod 2;
  if UseBMP then Ext := 'bmp' else Ext := 'png';

  OutputPath := Dir + Format('wallcycle_active_%d.%s', [ToggleSlot, Ext]);
  PrevPng := Dir + Format('wallcycle_active_%d.png', [PrevSlot]);
  PrevBmp := Dir + Format('wallcycle_active_%d.bmp', [PrevSlot]);

  if UseBMP then
  begin
    try
      Bmp.SaveToFile(OutputPath);
      Result := True;
    except
      Result := False;
    end;
  end
  else
    Result := SaveBitmapFastPNG(Bmp, OutputPath);

  if Result then
  begin
    if (PrevPng <> OutputPath) and FileExists(PrevPng) then DeleteFile(PrevPng);
    if (PrevBmp <> OutputPath) and FileExists(PrevBmp) then DeleteFile(PrevBmp);
  end;
end;

procedure BlendBitmapsScanline(BmpA, BmpB, OutBmp: TBitmap; Progress: Double);
var
  IntfA, IntfB, IntfOut: TLazIntfImage;
  W, H, Y, X, RowBytes, AlphaW, InvW: Integer;
  PA, PB, POut: PByte;
begin
  W := OutBmp.Width;
  H := OutBmp.Height;
  if (BmpA.Width <> W) or (BmpA.Height <> H) or
     (BmpB.Width <> W) or (BmpB.Height <> H) then
  begin
    OutBmp.Canvas.Draw(0, 0, BmpB);
    Exit;
  end;

  AlphaW := EnsureRange(Round(Progress * 256.0), 0, 256);
  InvW := 256 - AlphaW;

  IntfA := BmpA.CreateIntfImage;
  IntfB := BmpB.CreateIntfImage;
  IntfOut := OutBmp.CreateIntfImage;
  try
    if (IntfA.DataDescription.BitsPerPixel = IntfB.DataDescription.BitsPerPixel) and
       (IntfA.DataDescription.BitsPerPixel = IntfOut.DataDescription.BitsPerPixel) and
       (IntfA.DataDescription.BitsPerPixel >= 24) then
    begin
      RowBytes := W * (IntfA.DataDescription.BitsPerPixel div 8);
      for Y := 0 to H - 1 do
      begin
        PA := PByte(IntfA.GetDataLineStart(Y));
        PB := PByte(IntfB.GetDataLineStart(Y));
        POut := PByte(IntfOut.GetDataLineStart(Y));
        if (PA = nil) or (PB = nil) or (POut = nil) then Break;
        for X := 0 to RowBytes - 1 do
        begin
          POut^ := Byte((Integer(PA^) * InvW + Integer(PB^) * AlphaW) shr 8);
          Inc(PA);
          Inc(PB);
          Inc(POut);
        end;
      end;
      OutBmp.LoadFromIntfImage(IntfOut);
    end
    else
      OutBmp.Canvas.Draw(0, 0, BmpB);
  finally
    IntfOut.Free;
    IntfB.Free;
    IntfA.Free;
  end;
end;

function RenderTransitionStep(PrevBmp, NextBmp: TBitmap;
  Transition: TWallpaperTransition; Progress: Double; const OutputDir: string;
  UseBMP: Boolean; var ToggleSlot: Integer; out OutputPath: string): Boolean;
var
  OutBmp: TBitmap;
  W, H, SplitX, CurW, CurH, X0, Y0: Integer;
  R: TRect;
begin
  Result := False;
  OutputPath := '';
  if NextBmp = nil then Exit;

  if (PrevBmp = nil) or (Transition = wtNone) or (Progress >= 0.999) then
  begin
    Result := RenderWallpaperFromBitmap(NextBmp, OutputDir, UseBMP, ToggleSlot, OutputPath);
    Exit;
  end;

  W := NextBmp.Width;
  H := NextBmp.Height;
  OutBmp := TBitmap.Create;
  try
    OutBmp.PixelFormat := NextBmp.PixelFormat;
    OutBmp.SetSize(W, H);

    case Transition of
      wtWipe:
        begin
          SplitX := EnsureRange(Round(W * Progress), 0, W);
          if SplitX > 0 then
            OutBmp.Canvas.CopyRect(Rect(0, 0, SplitX, H), NextBmp.Canvas, Rect(0, 0, SplitX, H));
          if SplitX < W then
            OutBmp.Canvas.CopyRect(Rect(SplitX, 0, W, H), PrevBmp.Canvas, Rect(SplitX, 0, W, H));
        end;
      wtLeft:
        begin
          SplitX := EnsureRange(Round(W * Progress), 0, W);
          if SplitX < W then
            OutBmp.Canvas.CopyRect(Rect(0, 0, W - SplitX, H), PrevBmp.Canvas, Rect(SplitX, 0, W, H));
          if SplitX > 0 then
            OutBmp.Canvas.CopyRect(Rect(W - SplitX, 0, W, H), NextBmp.Canvas, Rect(0, 0, SplitX, H));
        end;
      wtRight:
        begin
          SplitX := EnsureRange(Round(W * Progress), 0, W);
          if SplitX > 0 then
            OutBmp.Canvas.CopyRect(Rect(0, 0, SplitX, H), NextBmp.Canvas, Rect(W - SplitX, 0, W, H));
          if SplitX < W then
            OutBmp.Canvas.CopyRect(Rect(SplitX, 0, W, H), PrevBmp.Canvas, Rect(0, 0, W - SplitX, H));
        end;
      wtCenter:
        begin
          OutBmp.Canvas.Draw(0, 0, PrevBmp);
          CurW := EnsureRange(Round(W * Progress), 2, W);
          CurH := EnsureRange(Round(H * Progress), 2, H);
          X0 := (W - CurW) div 2;
          Y0 := (H - CurH) div 2;
          R := Rect(X0, Y0, X0 + CurW, Y0 + CurH);
          OutBmp.Canvas.CopyRect(R, NextBmp.Canvas, R);
        end;
    else
      BlendBitmapsScanline(PrevBmp, NextBmp, OutBmp, Progress);
    end;

    Result := RenderWallpaperFromBitmap(OutBmp, OutputDir, UseBMP, ToggleSlot, OutputPath);
  finally
    OutBmp.Free;
  end;
end;

function RenderWallpaperWithClock(const SourcePath, OutputDir: string;
  Config: TWallCycleConfig; var ToggleSlot: Integer; out OutputPath: string): Boolean;
var
  Bmp: TBitmap;
begin
  Result := False;
  OutputPath := '';
  Bmp := CreateRenderedWallpaperBitmap(SourcePath, Config);
  if Bmp = nil then Exit;
  try
    Result := RenderWallpaperFromBitmap(Bmp, OutputDir, False, ToggleSlot, OutputPath);
  finally
    Bmp.Free;
  end;
end;

end.
