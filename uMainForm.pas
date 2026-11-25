unit uMainForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Forms, Controls, Graphics, Dialogs, ComCtrls, StdCtrls,
  ExtCtrls, Spin, Menus, CheckLst, Math, LCLType, LCLIntf, UniqueInstance,
  uConfig, uLuminanceFilter, uPlaylistScanner, uImageOverlay,
  uWallpaperBackend, uWallHavenClient;

type

  { TMainForm }

  TMainForm = class(TForm)
    Label1: TLabel;
    PageControl1: TPageControl;
    TabSources: TTabSheet;
    TabOverlay: TTabSheet;
    TabSystem: TTabSheet;

    // Unified Sources Checklist, WallHaven Feed Builder & Global Dark Filter
    LblSources: TLabel;
    CheckListSources: TCheckListBox;
    BtnAddFolder: TButton;
    BtnRemoveSource: TButton;
    BtnScanAllSources: TButton;

    GrpWallHavenAdd: TGroupBox;
    LblQuery: TLabel;
    EditQuery: TEdit;
    LblSorting: TLabel;
    ComboSorting: TComboBox;
    LblCategories: TLabel;
    ChkCatGeneral: TCheckBox;
    ChkCatAnime: TCheckBox;
    ChkCatPeople: TCheckBox;
    LblPurity: TLabel;
    ChkPurSFW: TCheckBox;
    ChkPurSketchy: TCheckBox;
    ChkPurNSFW: TCheckBox;
    LblMaxPages: TLabel;
    SpinMaxPages: TSpinEdit;
    LblApiKey: TLabel;
    EditApiKey: TEdit;
    BtnAddWallHaven: TButton;
    BtnFetchWallHaven: TButton;

    GrpDarkFilter: TGroupBox;
    ChkDarkFilter: TCheckBox;
    LblMaxLum: TLabel;
    TrackMaxLum: TTrackBar;
    ChkIconZone: TCheckBox;
    LblIconLum: TLabel;
    TrackIconLum: TTrackBar;

    ChkSubfolders: TCheckBox;
    ChkShuffle: TCheckBox;
    LblInterval: TLabel;
    SpinIntervalMin: TSpinEdit;
    BtnPrevWallpaper: TButton;
    BtnPauseResume: TButton;
    BtnNextWallpaper: TButton;
    BtnOpenWallHavenPage: TButton;
    LblCurrentFile: TLabel;

    // Overlay controls
    ChkOverlayEnabled: TCheckBox;
    RadioCorner: TRadioGroup;
    LblDateFmt: TLabel;
    EditDateFmt: TEdit;
    LblTimeFmt: TLabel;
    EditTimeFmt: TEdit;
    ChkShowSeconds: TCheckBox;
    LblTimeFont: TLabel;
    ComboTimeFont: TComboBox;
    SpinTimeFontSize: TSpinEdit;
    BtnPickTimeFont: TButton;
    LblDateFont: TLabel;
    ComboDateFont: TComboBox;
    SpinDateFontSize: TSpinEdit;
    BtnPickDateFont: TButton;
    ChkOverlayTransparentBg: TCheckBox;
    LblOpacity: TLabel;
    TrackOpacity: TTrackBar;
    LblMargin: TLabel;
    SpinMargin: TSpinEdit;
    BtnApplyOverlayNow: TButton;
    GrpOverlayPreview: TGroupBox;
    PaintBoxOverlayPreview: TPaintBox;

    // System & Logs
    LblDetectedDE: TLabel;
    LblBackendMode: TLabel;
    ComboBackend: TComboBox;
    ChkStartMinimized: TCheckBox;
    ChkAutoStart: TCheckBox;
    BtnSavePrefs: TButton;
    MemoLog: TMemo;

    // Non-visual components
    SelectDirDlg: TSelectDirectoryDialog;
    FontDlg: TFontDialog;
    TrayIcon1: TTrayIcon;
    TrayMenu: TPopupMenu;
    MnuNext: TMenuItem;
    MnuPrev: TMenuItem;
    MnuPause: TMenuItem;
    MnuFetchWH: TMenuItem;
    MnuOpenWallHavenPage: TMenuItem;
    MnuShowPrefs: TMenuItem;
    MnuExit: TMenuItem;
    TickTimer: TTimer;
    UniqueInstance1: TUniqueInstance;

    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure CheckListSourcesClickCheck(Sender: TObject);
    procedure BtnAddFolderClick(Sender: TObject);
    procedure BtnAddWallHavenClick(Sender: TObject);
    procedure BtnRemoveSourceClick(Sender: TObject);
    procedure BtnScanAllSourcesClick(Sender: TObject);
    procedure BtnPrevWallpaperClick(Sender: TObject);
    procedure BtnPauseResumeClick(Sender: TObject);
    procedure BtnNextWallpaperClick(Sender: TObject);
    procedure BtnApplyOverlayNowClick(Sender: TObject);
    procedure ChkOverlayTransparentBgChange(Sender: TObject);
    procedure ComboFontDrawItem(Control: TWinControl; Index: Integer;
      ARect: TRect; State: TOwnerDrawState);
    procedure BtnPickTimeFontClick(Sender: TObject);
    procedure BtnPickDateFontClick(Sender: TObject);
    procedure OverlayControlChange(Sender: TObject);
    procedure PaintBoxOverlayPreviewPaint(Sender: TObject);
    procedure BtnFetchWallHavenClick(Sender: TObject);
    procedure BtnSavePrefsClick(Sender: TObject);
    procedure ChkAutoStartChange(Sender: TObject);
    procedure TrackMaxLumChange(Sender: TObject);
    procedure TrackIconLumChange(Sender: TObject);
    procedure TickTimerTimer(Sender: TObject);
    procedure MnuOpenWallHavenPageClick(Sender: TObject);
    procedure MnuShowPrefsClick(Sender: TObject);
    procedure MnuExitClick(Sender: TObject);
    procedure TrayIcon1Click(Sender: TObject);
    procedure UniqueInstance1OtherInstance(Sender: TObject; ParamCount: Integer;
      const Parameters: array of string);
  private
    FConfig: TWallCycleConfig;
    FLuminanceCache: TLuminanceCache;
    FScanThread: TPlaylistScanThread;
    FPlaylist: TStringList;
    FCurrentIndex: Integer;
    FCurrentSourceImage: string;
    FToggleSlot: Integer;
    FRemainingSeconds: Integer;
    FLastTickTime: TDateTime;
    FLastMinuteRendered: Word;
    FPaused: Boolean;
    FAllowClose: Boolean;
    FAutoSelectOnReady: Boolean;
    FLoadingUI: Boolean;

    procedure LogMsg(const S: string);
    procedure SyncChecklistFromConfig;
    procedure LoadUIToConfig;
    procedure ConfigToUI;
    procedure StopAsyncScan;
    procedure StartAsyncScan(SelectFirstOnReady: Boolean);
    procedure PollScanThread;
    procedure ScheduleNextTick;
    procedure AdvanceWallpaper(Step: Integer);
    procedure ApplyCurrentImageWithOverlay;
    procedure UpdateLuminanceLabels;
    procedure PopulateSystemFonts;
    procedure SelectFontInCombo(CB: TComboBox; const FontName: string);
    function GetSelectedFontName(CB: TComboBox; const Fallback: string): string;
    function GetWallHavenCategoriesStr: string;
    function GetWallHavenPurityStr: string;
    function ExtractWallHavenId(const FilePath: string; out WhId: string): Boolean;
    procedure UpdateWallHavenInfoActions;
    procedure OpenCurrentWallHavenPage;
    procedure SetPausedState(APaused: Boolean);
    procedure HandleCommandArgs(const Args: array of string; FromOtherInstance: Boolean);
  end;

var
  MainForm: TMainForm;

implementation

{$R *.lfm}

procedure TMainForm.PopulateSystemFonts;
var
  I: Integer;
begin
  ComboTimeFont.Items.BeginUpdate;
  ComboDateFont.Items.BeginUpdate;
  try
    ComboTimeFont.Items.Clear;
    ComboDateFont.Items.Clear;
    ComboTimeFont.Items.Add('Sans');
    ComboDateFont.Items.Add('Sans');
    for I := 0 to Screen.Fonts.Count - 1 do
    begin
      if not SameText(Screen.Fonts[I], 'Sans') then
      begin
        ComboTimeFont.Items.Add(Screen.Fonts[I]);
        ComboDateFont.Items.Add(Screen.Fonts[I]);
      end;
    end;
  finally
    ComboDateFont.Items.EndUpdate;
    ComboTimeFont.Items.EndUpdate;
  end;
end;

procedure TMainForm.SelectFontInCombo(CB: TComboBox; const FontName: string);
var
  CleanName: string;
  I, Idx: Integer;
begin
  CleanName := Trim(FontName);
  if CleanName = '' then CleanName := 'Sans';

  Idx := -1;
  for I := 0 to CB.Items.Count - 1 do
  begin
    if SameText(CB.Items[I], CleanName) then
    begin
      Idx := I;
      Break;
    end;
  end;

  if Idx < 0 then
    Idx := CB.Items.Add(CleanName);
  CB.ItemIndex := Idx;
end;

function TMainForm.GetSelectedFontName(CB: TComboBox; const Fallback: string): string;
begin
  if (CB.ItemIndex >= 0) and (CB.ItemIndex < CB.Items.Count) then
    Result := Trim(CB.Items[CB.ItemIndex])
  else
    Result := Trim(CB.Text);

  if Result = '' then
    Result := Fallback;
end;

procedure TMainForm.FormCreate(Sender: TObject);
var
  CacheFile: string;
  InitArgs: array of string;
  I: Integer;
begin
  FConfig := TWallCycleConfig.Create;
  FConfig.Load;

  CacheFile := IncludeTrailingPathDelimiter(GetAppConfigDir(False)) + 'luminance_cache.json';
  FLuminanceCache := TLuminanceCache.Create(CacheFile);
  FLuminanceCache.Load;

  FScanThread := nil;
  FPlaylist := TStringList.Create;
  FCurrentIndex := -1;
  FToggleSlot := 0;
  FRemainingSeconds := FConfig.IntervalMinutes * 60;
  FLastTickTime := Now;
  FLastMinuteRendered := 99;
  FPaused := False;
  FAllowClose := False;
  FAutoSelectOnReady := False;
  FLoadingUI := False;

  Randomize;
  PopulateSystemFonts;
  ConfigToUI;
  LblDetectedDE.Caption := 'Detected Environment: ' + DetectDesktopEnvironment(FConfig.LinuxBackend);

  TrayIcon1.Hint := 'WallCycle — Click: Next wallpaper';
  TrayIcon1.Visible := True;
  UpdateWallHavenInfoActions;

  StartAsyncScan(True);

  if FConfig.StartMinimized then
  begin
    Application.ShowMainForm := False;
    Visible := False;
  end;

  if ParamCount > 0 then
  begin
    SetLength(InitArgs, ParamCount);
    for I := 1 to ParamCount do
      InitArgs[I - 1] := ParamStr(I);
    HandleCommandArgs(InitArgs, False);
  end;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  TickTimer.Enabled := False;
  StopAsyncScan;
  FPlaylist.Free;
  FLuminanceCache.Free;
  FConfig.Free;
end;

procedure TMainForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  if not FAllowClose then
  begin
    CanClose := False;
    Hide;
    TrayIcon1.ShowBalloonHint;
  end;
end;

procedure TMainForm.LogMsg(const S: string);
begin
  MemoLog.Lines.Add(FormatDateTime('[hh:nn:ss] ', Now) + S);
  if MemoLog.Lines.Count > 250 then
    MemoLog.Lines.Delete(0);
end;

procedure TMainForm.SyncChecklistFromConfig;
var
  I: Integer;
  Src: TWallpaperSource;
begin
  CheckListSources.Items.BeginUpdate;
  try
    CheckListSources.Items.Clear;
    for I := 0 to FConfig.Sources.Count - 1 do
    begin
      Src := FConfig.GetSource(I);
      CheckListSources.Items.Add(Src.DisplayLabel);
      CheckListSources.Checked[I] := Src.Enabled;
    end;
  finally
    CheckListSources.Items.EndUpdate;
  end;
end;

procedure TMainForm.ConfigToUI;
begin
  FLoadingUI := True;
  try
    SyncChecklistFromConfig;
    ChkSubfolders.Checked := FConfig.IncludeSubfolders;
    ChkShuffle.Checked := FConfig.ShuffleOrder;
    SpinIntervalMin.Value := FConfig.IntervalMinutes;

    EditApiKey.Text := FConfig.WallHavenApiKey;
    if ComboSorting.Items.Count > 0 then ComboSorting.ItemIndex := 0;
    ChkCatGeneral.Checked := (Length(FConfig.WallHavenCategories) < 1) or (FConfig.WallHavenCategories[1] = '1');
    ChkCatAnime.Checked := (Length(FConfig.WallHavenCategories) >= 2) and (FConfig.WallHavenCategories[2] = '1');
    ChkCatPeople.Checked := (Length(FConfig.WallHavenCategories) >= 3) and (FConfig.WallHavenCategories[3] = '1');
    ChkPurSFW.Checked := (Length(FConfig.WallHavenPurity) < 1) or (FConfig.WallHavenPurity[1] = '1');
    ChkPurSketchy.Checked := (Length(FConfig.WallHavenPurity) >= 2) and (FConfig.WallHavenPurity[2] = '1');
    ChkPurNSFW.Checked := (Length(FConfig.WallHavenPurity) >= 3) and (FConfig.WallHavenPurity[3] = '1');
    SpinMaxPages.Value := EnsureRange(FConfig.WallHavenMaxPages, SpinMaxPages.MinValue, SpinMaxPages.MaxValue);

    ChkDarkFilter.Checked := FConfig.DarkFilterEnabled;
    TrackMaxLum.Position := Round(FConfig.MaxLuminance * 100);
    ChkIconZone.Checked := FConfig.CheckIconZone;
    TrackIconLum.Position := Round(FConfig.IconZoneMaxLuminance * 100);
    UpdateLuminanceLabels;

    ChkOverlayEnabled.Checked := FConfig.OverlayEnabled;
    RadioCorner.ItemIndex := Ord(FConfig.OverlayCorner);
    EditDateFmt.Text := FConfig.OverlayDateFormat;
    EditTimeFmt.Text := FConfig.OverlayTimeFormat;
    ChkShowSeconds.Checked := FConfig.OverlayShowSeconds;
    SelectFontInCombo(ComboTimeFont, FConfig.OverlayTimeFontName);
    SpinTimeFontSize.Value := FConfig.OverlayTimeFontSize;
    SelectFontInCombo(ComboDateFont, FConfig.OverlayDateFontName);
    SpinDateFontSize.Value := FConfig.OverlayDateFontSize;
    ChkOverlayTransparentBg.Checked := FConfig.OverlayTransparentBg;
    TrackOpacity.Position := FConfig.OverlayBackdropOpacity;
    TrackOpacity.Enabled := not FConfig.OverlayTransparentBg;
    LblOpacity.Enabled := TrackOpacity.Enabled;
    SpinMargin.Value := FConfig.OverlayMarginPx;

    ComboBackend.ItemIndex := Ord(FConfig.LinuxBackend);
    ChkStartMinimized.Checked := FConfig.StartMinimized;
    ChkAutoStart.Checked := IsAutoStartEnabled or FConfig.AutoStart;
    PaintBoxOverlayPreview.Invalidate;
  finally
    FLoadingUI := False;
  end;
end;

function TMainForm.GetWallHavenCategoriesStr: string;
begin
  Result := '';
  if ChkCatGeneral.Checked then Result := Result + '1' else Result := Result + '0';
  if ChkCatAnime.Checked then Result := Result + '1' else Result := Result + '0';
  if ChkCatPeople.Checked then Result := Result + '1' else Result := Result + '0';
  if Result = '000' then Result := '100';
end;

function TMainForm.GetWallHavenPurityStr: string;
begin
  Result := '';
  if ChkPurSFW.Checked then Result := Result + '1' else Result := Result + '0';
  if ChkPurSketchy.Checked then Result := Result + '1' else Result := Result + '0';
  if ChkPurNSFW.Checked then Result := Result + '1' else Result := Result + '0';
  if Result = '000' then Result := '100';
end;

procedure TMainForm.LoadUIToConfig;
var
  I: Integer;
begin
  for I := 0 to Min(CheckListSources.Count, FConfig.Sources.Count) - 1 do
    FConfig.GetSource(I).Enabled := CheckListSources.Checked[I];

  FConfig.IncludeSubfolders := ChkSubfolders.Checked;
  FConfig.ShuffleOrder := ChkShuffle.Checked;
  FConfig.IntervalMinutes := SpinIntervalMin.Value;

  FConfig.WallHavenApiKey := Trim(EditApiKey.Text);
  FConfig.WallHavenCategories := GetWallHavenCategoriesStr;
  FConfig.WallHavenPurity := GetWallHavenPurityStr;
  FConfig.WallHavenMaxPages := SpinMaxPages.Value;

  FConfig.DarkFilterEnabled := ChkDarkFilter.Checked;
  FConfig.MaxLuminance := TrackMaxLum.Position / 100.0;
  FConfig.CheckIconZone := ChkIconZone.Checked;
  FConfig.IconZoneMaxLuminance := TrackIconLum.Position / 100.0;

  FConfig.OverlayEnabled := ChkOverlayEnabled.Checked;
  if RadioCorner.ItemIndex >= 0 then
    FConfig.OverlayCorner := TOverlayCorner(RadioCorner.ItemIndex);
  FConfig.OverlayDateFormat := EditDateFmt.Text;
  FConfig.OverlayTimeFormat := EditTimeFmt.Text;
  FConfig.OverlayShowSeconds := ChkShowSeconds.Checked;
  FConfig.OverlayTimeFontName := GetSelectedFontName(ComboTimeFont, 'Sans');
  FConfig.OverlayTimeFontSize := SpinTimeFontSize.Value;
  FConfig.OverlayDateFontName := GetSelectedFontName(ComboDateFont, 'Sans');
  FConfig.OverlayDateFontSize := SpinDateFontSize.Value;
  FConfig.OverlayTransparentBg := ChkOverlayTransparentBg.Checked;
  FConfig.OverlayBackdropOpacity := Byte(TrackOpacity.Position);
  FConfig.OverlayMarginPx := SpinMargin.Value;

  if ComboBackend.ItemIndex >= 0 then
    FConfig.LinuxBackend := TLinuxBackendMode(ComboBackend.ItemIndex);
  FConfig.StartMinimized := ChkStartMinimized.Checked;
  FConfig.AutoStart := ChkAutoStart.Checked;
end;

procedure TMainForm.UpdateLuminanceLabels;
begin
  LblMaxLum.Caption := Format('Max global Brightness allowed: %d%%', [TrackMaxLum.Position]);
  LblIconLum.Caption := Format('Max Brightness for icons zone: %d%%', [TrackIconLum.Position]);
end;

procedure TMainForm.TrackMaxLumChange(Sender: TObject);
begin
  UpdateLuminanceLabels;
end;

procedure TMainForm.TrackIconLumChange(Sender: TObject);
begin
  UpdateLuminanceLabels;
end;

procedure TMainForm.StopAsyncScan;
begin
  if FScanThread <> nil then
  begin
    FScanThread.Terminate;
    FScanThread.WaitFor;
    FreeAndNil(FScanThread);
  end;
end;

procedure TMainForm.ScheduleNextTick;
var
  H, M, S, MS: Word;
  MsToNextMinute, MsToNextSlide, NextInterval: Int64;
begin
  TickTimer.Enabled := False;

  if FScanThread <> nil then
  begin
    TickTimer.Interval := 150;
    TickTimer.Enabled := True;
    Exit;
  end;

  if FConfig.OverlayEnabled and FConfig.OverlayShowSeconds then
  begin
    TickTimer.Interval := 1000;
    TickTimer.Enabled := True;
    Exit;
  end;

  if not FConfig.OverlayEnabled then
  begin
    if FPaused then Exit; // 0 wakeups while paused without clock overlay
    MsToNextSlide := Int64(Max(1, FRemainingSeconds)) * 1000;
    if MsToNextSlide > 3600000 then MsToNextSlide := 3600000;
    TickTimer.Interval := Integer(MsToNextSlide);
    TickTimer.Enabled := True;
    Exit;
  end;

  // Align precisely to the :00 second boundary, then tick once per minute
  DecodeTime(Now, H, M, S, MS);
  MsToNextMinute := (Int64(60 - S) * 1000) - Int64(MS) + 50;
  if MsToNextMinute < 250 then
    Inc(MsToNextMinute, 60000);

  if not FPaused then
  begin
    MsToNextSlide := Int64(Max(1, FRemainingSeconds)) * 1000;
    NextInterval := Min(MsToNextMinute, MsToNextSlide);
  end
  else
    NextInterval := MsToNextMinute;

  if NextInterval < 250 then NextInterval := 250;
  TickTimer.Interval := Integer(NextInterval);
  TickTimer.Enabled := True;
end;

procedure TMainForm.StartAsyncScan(SelectFirstOnReady: Boolean);
begin
  StopAsyncScan;
  FAutoSelectOnReady := SelectFirstOnReady;
  FScanThread := TPlaylistScanThread.Create(FConfig, FLuminanceCache);
  // Poll briefly during initial async discovery (~150ms), then align to 1-minute boundary
  ScheduleNextTick;
  LogMsg('Scanning sources in background...');
end;

procedure TMainForm.PollScanThread;
var
  State: TScanState;
  NewList: TStringList;
begin
  if FScanThread = nil then Exit;

  NewList := TStringList.Create;
  try
    // Phase 1 ready: immediate playlist populated without blocking UI
    if FScanThread.ConsumeDiscoveredList(NewList) then
    begin
      FPlaylist.Assign(NewList);
      FCurrentIndex := -1;
      LogMsg(Format('Found %d files in active sources (indexing brightness in background).',
        [FPlaylist.Count]));

      if FAutoSelectOnReady and (FPlaylist.Count > 0) then
      begin
        FAutoSelectOnReady := False;
        AdvanceWallpaper(1);
      end;
    end;

    // Phase 2 ready: full pre-filtered dark list completed in background
    if FScanThread.ConsumeEligibleList(NewList) then
    begin
      FPlaylist.Assign(NewList);
      FCurrentIndex := FPlaylist.IndexOf(FCurrentSourceImage);
    end;
  finally
    NewList.Free;
  end;

  State := FScanThread.GetState;
  if not State.Running then
  begin
    if FConfig.DarkFilterEnabled then
      LogMsg(Format('Index completed: %d valid, discarded too bright (%d local, %d WallHaven).',
        [FPlaylist.Count, State.RejectedLocal, State.RejectedWallHaven]));

    FScanThread.WaitFor;
    FreeAndNil(FScanThread);
    ScheduleNextTick;
  end;
end;

procedure TMainForm.ApplyCurrentImageWithOverlay;
var
  RenderDir, RenderedPath: string;
  Res: TBackendResult;
  H, M, S, MS: Word;
begin
  if (FCurrentSourceImage = '') or (not FileExists(FCurrentSourceImage)) then Exit;

  DecodeTime(Now, H, M, S, MS);
  FLastMinuteRendered := M;

  RenderDir := IncludeTrailingPathDelimiter(GetAppConfigDir(False)) + 'rendered';
  if not RenderWallpaperWithClock(FCurrentSourceImage, RenderDir, FConfig,
    FToggleSlot, RenderedPath) then
  begin
    LogMsg('Error rendering overlay on: ' + FCurrentSourceImage);
    Exit;
  end;

  UpdateWallHavenInfoActions;
  Res := ApplySystemWallpaper(RenderedPath, FConfig.LinuxBackend);
  if Res.Success then
    LblCurrentFile.Caption := 'Active Wallpaper: ' + ExtractFileName(FCurrentSourceImage)
  else
    LogMsg('backend error [' + Res.BackendName + ']: ' + Res.Message);
end;

procedure TMainForm.AdvanceWallpaper(Step: Integer);
var
  Attempts: Integer;
  Candidate: string;
  Stats: TLuminanceStats;
begin
  if FPlaylist.Count = 0 then
  begin
    if FScanThread = nil then
      StartAsyncScan(True);
    Exit;
  end;

  // Lazy per-file luminance check + cache lookup: never freezes UI even with thousands of files
  Attempts := 0;
  while Attempts < FPlaylist.Count do
  begin
    if FCurrentIndex < 0 then
      FCurrentIndex := 0
    else
      FCurrentIndex := (FCurrentIndex + Step + FPlaylist.Count) mod FPlaylist.Count;

    Candidate := FPlaylist[FCurrentIndex];
    Inc(Attempts);

    if not FileExists(Candidate) then Continue;

    if FConfig.DarkFilterEnabled then
    begin
      if not IsImageDarkEnough(Candidate, FConfig.MaxLuminance,
        FConfig.IconZoneMaxLuminance, FConfig.CheckIconZone, Stats, FLuminanceCache) then
      begin
        if not Stats.Valid then
          LogMsg(Format('Discarded corrupt image (%s): %s',
            [Stats.ErrorReason, ExtractFileName(Candidate)]))
        else
          LogMsg(Format('Discarded image too bright (Avg=%.0f%%, Icon=%.0f%%): %s',
            [Stats.AverageLuminance * 100, Stats.IconZoneLuminance * 100, ExtractFileName(Candidate)]));
        Continue;
      end;
    end
    else
    begin
      // Even with dark filter disabled, verify image isn't corrupted before rendering overlay
      if not FLuminanceCache.TryGet(Candidate, Stats) then
      begin
        Stats := AnalyzeImageLuminance(Candidate);
        if Stats.Valid then FLuminanceCache.Put(Candidate, Stats);
      end;
      if not Stats.Valid then
      begin
        LogMsg(Format('Discarded corrupt image (%s): %s',
          [Stats.ErrorReason, ExtractFileName(Candidate)]));
        Continue;
      end;
    end;

    FCurrentSourceImage := Candidate;
    FRemainingSeconds := Max(1, FConfig.IntervalMinutes) * 60;
    FLastTickTime := Now;
    ApplyCurrentImageWithOverlay;
    ScheduleNextTick;
    LogMsg('Applied Wallpaper: ' + ExtractFileName(Candidate));
    Exit;
  end;

  LogMsg('No valid images found. All images are too bright. Lower the threshold.');
end;

procedure TMainForm.TickTimerTimer(Sender: TObject);
var
  H, M, S, MS: Word;
  ElapsedSec: Integer;
begin
  PollScanThread;

  if FScanThread <> nil then
  begin
    DecodeTime(Now, H, M, S, MS);
    if (FCurrentSourceImage <> '') and FConfig.OverlayEnabled and (M <> FLastMinuteRendered) then
      ApplyCurrentImageWithOverlay;
    Exit;
  end;

  if not FPaused then
  begin
    ElapsedSec := Max(0, Round((Now - FLastTickTime) * 86400.0));
    FLastTickTime := Now;
    Dec(FRemainingSeconds, ElapsedSec);
    if FRemainingSeconds <= 0 then
    begin
      AdvanceWallpaper(1);
      Exit;
    end;
  end
  else
    FLastTickTime := Now;

  DecodeTime(Now, H, M, S, MS);
  if (FCurrentSourceImage <> '') and FConfig.OverlayEnabled then
  begin
    if FConfig.OverlayShowSeconds or (M <> FLastMinuteRendered) then
      ApplyCurrentImageWithOverlay;
  end;

  ScheduleNextTick;
end;

procedure TMainForm.CheckListSourcesClickCheck(Sender: TObject);
begin
  LoadUIToConfig;
  FConfig.Save;
  StartAsyncScan(False);
end;

procedure TMainForm.BtnAddFolderClick(Sender: TObject);
begin
  if SelectDirDlg.Execute then
  begin
    FConfig.AddLocalFolder(SelectDirDlg.FileName, True);
    FConfig.Save;
    SyncChecklistFromConfig;
    StartAsyncScan(FCurrentSourceImage = '');
  end;
end;

procedure TMainForm.BtnAddWallHavenClick(Sender: TObject);
var
  SortStr, CatStr, PurStr: string;
begin
  if Trim(EditQuery.Text) = '' then Exit;
  if ComboSorting.ItemIndex >= 0 then
    SortStr := ComboSorting.Items[ComboSorting.ItemIndex]
  else
    SortStr := 'toplist';

  LoadUIToConfig;
  CatStr := GetWallHavenCategoriesStr;
  PurStr := GetWallHavenPurityStr;
  if (Copy(PurStr, 3, 1) = '1') and (Trim(FConfig.WallHavenApiKey) = '') then
    LogMsg('Note: Wallhaven NSFW filter requires a valid API Key.');

  FConfig.AddWallHavenSource(Trim(EditQuery.Text), SortStr, CatStr, PurStr, True);
  FConfig.Save;
  SyncChecklistFromConfig;
  LogMsg(Format('Added and activated WallHaven.cc source: "%s" (%s · Cat:%s · Pur:%s)',
    [Trim(EditQuery.Text), SortStr, CatStr, PurStr]));
end;

procedure TMainForm.BtnRemoveSourceClick(Sender: TObject);
var
  Idx: Integer;
begin
  Idx := CheckListSources.ItemIndex;
  if (Idx >= 0) and (Idx < FConfig.Sources.Count) then
  begin
    FConfig.Sources.Delete(Idx);
    FConfig.Save;
    SyncChecklistFromConfig;
    StartAsyncScan(False);
  end;
end;

procedure TMainForm.BtnScanAllSourcesClick(Sender: TObject);
begin
  LoadUIToConfig;
  FConfig.Save;
  StartAsyncScan(True);
end;

procedure TMainForm.BtnPrevWallpaperClick(Sender: TObject);
begin
  AdvanceWallpaper(-1);
end;

procedure TMainForm.BtnNextWallpaperClick(Sender: TObject);
begin
  AdvanceWallpaper(1);
end;

procedure TMainForm.SetPausedState(APaused: Boolean);
var
  ElapsedSec: Integer;
begin
  if APaused and (not FPaused) then
  begin
    ElapsedSec := Max(0, Round((Now - FLastTickTime) * 86400.0));
    FRemainingSeconds := Max(1, FRemainingSeconds - ElapsedSec);
  end;
  FPaused := APaused;
  FLastTickTime := Now;
  if FPaused then
  begin
    BtnPauseResume.Caption := 'Unpause Slideshow';
    MnuPause.Caption := 'Unpause Slideshow';
    LogMsg('Slideshow paused.');
  end
  else
  begin
    BtnPauseResume.Caption := 'Pause Slideshow';
    MnuPause.Caption := 'Pause Slideshow';
    LogMsg('Slideshow restarted.');
  end;
  ScheduleNextTick;
end;

procedure TMainForm.BtnPauseResumeClick(Sender: TObject);
begin
  SetPausedState(not FPaused);
end;

procedure TMainForm.BtnApplyOverlayNowClick(Sender: TObject);
begin
  LoadUIToConfig;
  FConfig.Save;
  ApplyCurrentImageWithOverlay;
  ScheduleNextTick;
end;

procedure TMainForm.ChkOverlayTransparentBgChange(Sender: TObject);
begin
  TrackOpacity.Enabled := not ChkOverlayTransparentBg.Checked;
  LblOpacity.Enabled := TrackOpacity.Enabled;
  if not FLoadingUI then
    PaintBoxOverlayPreview.Invalidate;
end;

procedure TMainForm.OverlayControlChange(Sender: TObject);
begin
  if not FLoadingUI then
    PaintBoxOverlayPreview.Invalidate;
end;

procedure TMainForm.ComboFontDrawItem(Control: TWinControl; Index: Integer;
  ARect: TRect; State: TOwnerDrawState);
var
  CB: TComboBox;
  FontName, LabelText: string;
  TextY: Integer;
  IsHighlight: Boolean;
begin
  if not (Control is TComboBox) then Exit;
  CB := TComboBox(Control);
  if (Index < 0) or (Index >= CB.Items.Count) then Exit;

  IsHighlight := (odSelected in State) and (not (odComboBoxEdit in State) or CB.Focused);
  if IsHighlight then
  begin
    CB.Canvas.Brush.Color := clHighlight;
    CB.Canvas.Font.Color := clHighlightText;
  end
  else
  begin
    CB.Canvas.Brush.Color := clWindow;
    CB.Canvas.Font.Color := clWindowText;
  end;
  CB.Canvas.FillRect(ARect);

  FontName := CB.Items[Index];
  CB.Canvas.Font.Name := FontName;
  CB.Canvas.Font.Size := 10;
  CB.Canvas.Font.Style := [];
  CB.Canvas.Font.Quality := fqAntialiased;

  if odComboBoxEdit in State then
    LabelText := FontName
  else
    LabelText := FontName + '  —  12:34';

  TextY := ARect.Top + Max(0, (ARect.Bottom - ARect.Top - CB.Canvas.TextHeight(LabelText)) div 2);
  CB.Canvas.TextRect(ARect, ARect.Left + 6, TextY, LabelText);
end;

procedure TMainForm.BtnPickTimeFontClick(Sender: TObject);
begin
  FontDlg.Font.Name := GetSelectedFontName(ComboTimeFont, 'Sans');
  FontDlg.Font.Size := SpinTimeFontSize.Value;
  FontDlg.Font.Style := [fsBold];
  if FontDlg.Execute then
  begin
    SelectFontInCombo(ComboTimeFont, FontDlg.Font.Name);
    SpinTimeFontSize.Value := EnsureRange(FontDlg.Font.Size,
      SpinTimeFontSize.MinValue, SpinTimeFontSize.MaxValue);
    PaintBoxOverlayPreview.Invalidate;
  end;
end;

procedure TMainForm.BtnPickDateFontClick(Sender: TObject);
begin
  FontDlg.Font.Name := GetSelectedFontName(ComboDateFont, 'Sans');
  FontDlg.Font.Size := SpinDateFontSize.Value;
  FontDlg.Font.Style := [];
  if FontDlg.Execute then
  begin
    SelectFontInCombo(ComboDateFont, FontDlg.Font.Name);
    SpinDateFontSize.Value := EnsureRange(FontDlg.Font.Size,
      SpinDateFontSize.MinValue, SpinDateFontSize.MaxValue);
    PaintBoxOverlayPreview.Invalidate;
  end;
end;

procedure TMainForm.PaintBoxOverlayPreviewPaint(Sender: TObject);
var
  C: TCanvas;
  W, H, TimePt, DatePt, TimeX, DateX, TimeY, DateY: Integer;
  BoxW, BoxH, BoxX, BoxY, PadX, PadY, GapY, TimeOutW, DateOutW: Integer;
  TimeFmt, DateFmt, TimeStr, DateStr, TimeFontName, DateFontName: string;
  TimeSize, DateSize: TSize;
  Scale: Double;
  AlignRight, TransparentBg: Boolean;
  BoxRect: TRect;
begin
  C := PaintBoxOverlayPreview.Canvas;
  W := PaintBoxOverlayPreview.Width;
  H := PaintBoxOverlayPreview.Height;
  if (W <= 4) or (H <= 4) then Exit;

  // Simulated dark desktop background gradient
  C.GradientFill(Rect(0, 0, W, H), RGBToColor(24, 34, 52), RGBToColor(12, 17, 27), gdVertical);
  C.Pen.Color := RGBToColor(45, 58, 82);
  C.Brush.Style := bsClear;
  C.Rectangle(0, 0, W, H);

  EnsureLocalizedDateNames;
  TimeFmt := Trim(EditTimeFmt.Text);
  if TimeFmt = '' then TimeFmt := 'hh:nn';
  if ChkShowSeconds.Checked and (Pos('ss', LowerCase(TimeFmt)) = 0) then
    TimeFmt := TimeFmt + ':ss';
  DateFmt := Trim(EditDateFmt.Text);
  if DateFmt = '' then DateFmt := 'ddd dd mmm yyyy';

  try
    TimeStr := FormatDateTime(TimeFmt, Now);
  except
    TimeStr := '12:34';
  end;
  try
    DateStr := FormatDateTime(DateFmt, Now);
  except
    DateStr := 'lun 23 nov 2026';
  end;

  TimeFontName := GetSelectedFontName(ComboTimeFont, 'Sans');
  DateFontName := GetSelectedFontName(ComboDateFont, 'Sans');

  // Scale down gently if chosen font size exceeds preview box height/width
  TimePt := Round(SpinTimeFontSize.Value * 0.72);
  DatePt := Round(SpinDateFontSize.Value * 0.80);
  Scale := 1.0;

  C.Font.Quality := fqAntialiased;
  C.Font.Name := TimeFontName;
  C.Font.Size := Max(9, TimePt);
  C.Font.Style := [fsBold];
  TimeSize := C.TextExtent(TimeStr);

  C.Font.Name := DateFontName;
  C.Font.Size := Max(8, DatePt);
  C.Font.Style := [];
  DateSize := C.TextExtent(DateStr);

  if (Max(TimeSize.cx, DateSize.cx) > W - 36) or ((TimeSize.cy + DateSize.cy + 24) > H - 16) then
  begin
    Scale := Min((W - 36) / Max(1, Max(TimeSize.cx, DateSize.cx)),
                 (H - 28) / Max(1, TimeSize.cy + DateSize.cy + 8));
    TimePt := Max(9, Round(TimePt * Scale));
    DatePt := Max(8, Round(DatePt * Scale));

    C.Font.Name := TimeFontName;
    C.Font.Size := TimePt;
    C.Font.Style := [fsBold];
    TimeSize := C.TextExtent(TimeStr);

    C.Font.Name := DateFontName;
    C.Font.Size := DatePt;
    C.Font.Style := [];
    DateSize := C.TextExtent(DateStr);
  end;

  TransparentBg := ChkOverlayTransparentBg.Checked or (TrackOpacity.Position = 0);
  if TransparentBg then
  begin
    PadX := 6;
    PadY := 4;
  end
  else
  begin
    PadX := 16;
    PadY := 10;
  end;
  GapY := 4;
  BoxW := Max(TimeSize.cx, DateSize.cx) + PadX * 2;
  BoxH := TimeSize.cy + DateSize.cy + GapY + PadY * 2;

  AlignRight := RadioCorner.ItemIndex in [1, 3];
  if AlignRight then
    BoxX := Max(10, W - BoxW - 14)
  else
    BoxX := 14;
  BoxY := Max(6, (H - BoxH) div 2);

  if not TransparentBg then
  begin
    BoxRect := Rect(BoxX, BoxY, BoxX + BoxW, BoxY + BoxH);
    C.Brush.Style := bsSolid;
    C.Brush.Color := RGBToColor(10, 14, 22);
    C.Pen.Color := RGBToColor(58, 72, 96);
    C.RoundRect(BoxRect.Left, BoxRect.Top, BoxRect.Right, BoxRect.Bottom, 12, 12);
  end;

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
  TimeY := BoxY + PadY;
  DateY := TimeY + TimeSize.cy + GapY;

  TimeOutW := Max(1, Round(SpinTimeFontSize.Value * 0.04 * Scale));
  DateOutW := Max(1, Round(SpinDateFontSize.Value * 0.045 * Scale));

  C.Font.Name := TimeFontName;
  C.Font.Size := TimePt;
  C.Font.Style := [fsBold];
  DrawOutlinedText(C, TimeX, TimeY, TimeStr, TimeOutW,
    RGBToColor(255, 255, 255), RGBToColor(0, 0, 0));

  C.Font.Name := DateFontName;
  C.Font.Size := DatePt;
  C.Font.Style := [];
  DrawOutlinedText(C, DateX, DateY, DateStr, DateOutW,
    RGBToColor(255, 255, 255), RGBToColor(0, 0, 0));
end;

procedure TMainForm.BtnFetchWallHavenClick(Sender: TObject);
var
  Files: TStringList;
  Stats: TWallHavenFetchStats;
  I, EnabledWH, MaxPerSrc: Integer;
  SortStr, CatStr, PurStr: string;
begin
  LoadUIToConfig;
  CatStr := GetWallHavenCategoriesStr;
  PurStr := GetWallHavenPurityStr;

  EnabledWH := 0;
  for I := 0 to FConfig.Sources.Count - 1 do
    if (FConfig.GetSource(I).Kind = skWallHaven) and FConfig.GetSource(I).Enabled then
      Inc(EnabledWH);

  if EnabledWH = 0 then
  begin
    if Trim(EditQuery.Text) <> '' then
    begin
      if ComboSorting.ItemIndex >= 0 then
        SortStr := ComboSorting.Items[ComboSorting.ItemIndex]
      else
        SortStr := 'toplist';
      FConfig.AddWallHavenSource(Trim(EditQuery.Text), SortStr, CatStr, PurStr, True);
      SyncChecklistFromConfig;
      LogMsg(Format('No WallHaven sources: automatically added "%s" (%s · Cat:%s · Pur:%s).',
        [Trim(EditQuery.Text), SortStr, CatStr, PurStr]));
    end
    else
    begin
      LogMsg('No WallHaven sources on the checklist. Add or tick one source.');
      Exit;
    end;
  end;

  if (Copy(PurStr, 3, 1) = '1') and (Trim(FConfig.WallHavenApiKey) = '') then
    LogMsg('Warning: purity NSFW selected without API Key; WallHaven might give empty responses or HTTP 401.');

  FConfig.Save;
  BtnFetchWallHaven.Enabled := False;
  try
    LogMsg(Format('Downloading active WallHaven.cc sources (Depth %d pages)...',
      [FConfig.WallHavenMaxPages]));
    Application.ProcessMessages;
    MaxPerSrc := Max(12, FConfig.WallHavenMaxPages * 3);
    Stats := FetchAllEnabledWallHavenSources(FConfig, MaxPerSrc, Files);
    try
      if Stats.LastError <> '' then
        LogMsg(Stats.LastError);

      LogMsg(Format('WallHaven (%d pag.): %d analyzed, %d discarded (palette), %d discarded (pixel), %d ready.',
        [Stats.PagesScanned, Stats.CandidatesExamined, Stats.RejectedByPalette, Stats.RejectedByPixels, Stats.DownloadedCount]));

      if (Stats.DownloadedCount = 0) and (Stats.CandidatesExamined > 0) and
         ((Stats.RejectedByPalette + Stats.RejectedByPixels) >= Stats.CandidatesExamined) then
        LogMsg('Tip: all the images analyzed where beyond brightness thesholdo (Try raising the threshold or untick the filter');

      StartAsyncScan(Files.Count = 0);
      if Files.Count > 0 then
      begin
        FCurrentSourceImage := Files[0];
        FRemainingSeconds := Max(1, FConfig.IntervalMinutes) * 60;
        FLastTickTime := Now;
        ApplyCurrentImageWithOverlay;
        ScheduleNextTick;
      end;
    finally
      Files.Free;
    end;
  finally
    BtnFetchWallHaven.Enabled := True;
  end;
end;

procedure TMainForm.ChkAutoStartChange(Sender: TObject);
var
  Msg: string;
begin
  if FLoadingUI then Exit;
  FConfig.AutoStart := ChkAutoStart.Checked;
  if SetAutoStartEnabled(FConfig.AutoStart, Msg) then
  begin
    FConfig.Save;
    if Msg <> '' then LogMsg(Msg);
  end
  else
  begin
    if Msg <> '' then LogMsg(Msg);
    FLoadingUI := True;
    try
      ChkAutoStart.Checked := IsAutoStartEnabled;
      FConfig.AutoStart := ChkAutoStart.Checked;
    finally
      FLoadingUI := False;
    end;
  end;
end;

procedure TMainForm.BtnSavePrefsClick(Sender: TObject);
var
  AutoMsg: string;
begin
  LoadUIToConfig;
  SetAutoStartEnabled(FConfig.AutoStart, AutoMsg);
  FConfig.Save;
  FRemainingSeconds := Min(FRemainingSeconds, Max(1, FConfig.IntervalMinutes) * 60);
  LblDetectedDE.Caption := 'Detected Environment: ' + DetectDesktopEnvironment(FConfig.LinuxBackend);
  StartAsyncScan(False);
  ApplyCurrentImageWithOverlay;
  ScheduleNextTick;
  if AutoMsg <> '' then LogMsg(AutoMsg);
  LogMsg('Preferences saved in ' + FConfig.GetConfigFilePath);
end;

function TMainForm.ExtractWallHavenId(const FilePath: string; out WhId: string): Boolean;
var
  BaseName, Tail, Cand: string;
  P, I: Integer;
  Ch: Char;
begin
  Result := False;
  WhId := '';
  if Trim(FilePath) = '' then Exit;

  BaseName := LowerCase(ChangeFileExt(ExtractFileName(FilePath), ''));
  P := Pos('wallhaven-', BaseName);
  if P = 0 then
    P := Pos('wallhaven_', BaseName);
  if P = 0 then Exit;

  Tail := Copy(BaseName, P + 10, Length(BaseName));
  Cand := '';
  for I := 1 to Length(Tail) do
  begin
    Ch := Tail[I];
    if Ch in ['a'..'z', '0'..'9'] then
      Cand := Cand + Ch
    else
      Break;
  end;

  if (Length(Cand) >= 5) and (Length(Cand) <= 7) then
  begin
    WhId := Cand;
    Result := True;
  end;
end;

procedure TMainForm.UpdateWallHavenInfoActions;
var
  WhId: string;
  HasId: Boolean;
begin
  HasId := ExtractWallHavenId(FCurrentSourceImage, WhId);
  MnuOpenWallHavenPage.Enabled := HasId;
  BtnOpenWallHavenPage.Enabled := HasId;
  if HasId then
  begin
    MnuOpenWallHavenPage.Caption := Format('Show Info on WallHaven.cc (%s)', [WhId]);
    BtnOpenWallHavenPage.Caption := Format('Info WallHaven (%s)', [WhId]);
  end
  else
  begin
    MnuOpenWallHavenPage.Caption := 'Show Info su WallHaven.cc';
    BtnOpenWallHavenPage.Caption := 'Info WallHaven.cc';
  end;
end;

procedure TMainForm.OpenCurrentWallHavenPage;
var
  WhId, Url: string;
begin
  if Trim(FCurrentSourceImage) = '' then
  begin
    LogMsg('No active background: no valid ID.');
    Exit;
  end;

  if not ExtractWallHavenId(FCurrentSourceImage, WhId) then
  begin
    LogMsg('Active background is not from WallHaven.cc or it has been renamed: ' + ExtractFileName(FCurrentSourceImage));
    Exit;
  end;

  Url := 'https://wallhaven.cc/w/' + WhId;
  if OpenURL(Url) then
    LogMsg('Opening info page on WallHaven.cc: ' + Url)
  else
    LogMsg('Can''t start the browser for: ' + Url);
end;

procedure TMainForm.MnuOpenWallHavenPageClick(Sender: TObject);
begin
  OpenCurrentWallHavenPage;
end;

procedure TMainForm.MnuShowPrefsClick(Sender: TObject);
begin
  Application.ShowMainForm := True;
  Show;
  WindowState := wsNormal;
  BringToFront;
end;

procedure TMainForm.TrayIcon1Click(Sender: TObject);
begin
  AdvanceWallpaper(1);
end;

procedure TMainForm.MnuExitClick(Sender: TObject);
begin
  FAllowClose := True;
  Close;
end;

procedure TMainForm.HandleCommandArgs(const Args: array of string;
  FromOtherInstance: Boolean);
var
  I: Integer;
  Arg: string;
begin
  if (Length(Args) = 0) and FromOtherInstance then
  begin
    MnuShowPrefsClick(nil);
    LogMsg('Second instance detected (TUniqueInstance): Bring windows to front.');
    Exit;
  end;

  for I := Low(Args) to High(Args) do
  begin
    Arg := LowerCase(Trim(Args[I]));
    if (Arg = '--next') or (Arg = '-n') then
    begin
      LogMsg('CLI Command: ' + Arg);
      AdvanceWallpaper(1);
    end
    else if (Arg = '--previous') or (Arg = '--prev') or (Arg = '-p') then
    begin
      LogMsg('CLI Command: ' + Arg);
      AdvanceWallpaper(-1);
    end
    else if Arg = '--pause' then
      SetPausedState(True)
    else if Arg = '--resume' then
      SetPausedState(False)
    else if Arg = '--toggle-pause' then
      SetPausedState(not FPaused)
    else if (Arg = '--apply') or (Arg = '--refresh') then
    begin
      LogMsg('CLI Command: ' + Arg);
      ApplyCurrentImageWithOverlay;
    end
    else if Arg = '--fetch' then
      BtnFetchWallHavenClick(nil)
    else if (Arg = '--info') or (Arg = '--wallhaven-info') or
            (Arg = '--open-wallhaven') or (Arg = '-i') then
    begin
      LogMsg('CLI Command: ' + Arg);
      OpenCurrentWallHavenPage;
    end
    else if Arg = '--show' then
      MnuShowPrefsClick(nil)
    else if Arg = '--minimized' then
    begin
      Application.ShowMainForm := False;
      Visible := False;
      Hide;
    end
    else if (Arg = '--quit') or (Arg = '--exit') then
      MnuExitClick(nil)
    else if Arg <> '' then
      LogMsg('CLI parameter ignored: ' + Args[I]);
  end;
end;

procedure TMainForm.UniqueInstance1OtherInstance(Sender: TObject;
  ParamCount: Integer; const Parameters: array of string);
begin
  HandleCommandArgs(Parameters, True);
end;

end.
