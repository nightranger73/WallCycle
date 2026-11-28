unit uMainForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, DateUtils, Forms, Controls, Graphics, Dialogs, ComCtrls, StdCtrls,
  ExtCtrls, Spin, Menus, CheckLst, Math, LCLType, LCLIntf, UniqueInstance,
  uConfig, uLuminanceFilter, uPlaylistScanner, uImageOverlay,
  uWallpaperBackend, uWallHavenClient, uEmbeddedIcon, uShaderEngine, uLiveWallpaper;

type
  TMainForm = class(TForm)
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
    LblMinRes: TLabel;
    ComboMinRes: TComboBox;
    LblRatio: TLabel;
    ComboRatio: TComboBox;
    LblApiKey: TLabel;
    EditApiKey: TEdit;
    LblMaxCached: TLabel;
    SpinMaxCached: TSpinEdit;
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
    ChkDailyRecheck: TCheckBox;
    LblInterval: TLabel;
    SpinIntervalMin: TSpinEdit;
    LblTransition: TLabel;
    ComboTransition: TComboBox;
    LblTransitionDur: TLabel;
    SpinTransitionMs: TSpinEdit;
    LblMultiMonitor: TLabel;
    ComboMultiMonitor: TComboBox;
    BtnPrevWallpaper: TButton;
    BtnPauseResume: TButton;
    BtnNextWallpaper: TButton;
    BtnFavorite: TButton;
    BtnBlacklist: TButton;
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
    ChkSmartPauseFullscreen: TCheckBox;
    ChkSmartPauseBattery: TCheckBox;
    ChkUseOpenGLEngine: TCheckBox;
    BtnOpenFavorites: TButton;
    BtnClearBlacklist: TButton;
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
    MnuFavorite: TMenuItem;
    MnuBlacklist: TMenuItem;
    MnuFetchWH: TMenuItem;
    MnuOpenWallHavenPage: TMenuItem;
    MnuOpenFavorites: TMenuItem;
    MnuShowPrefs: TMenuItem;
    MnuExit: TMenuItem;
    TickTimer: TTimer;
    UniqueInstance1: TUniqueInstance;

    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure CheckListSourcesClick(Sender: TObject);
    procedure CheckListSourcesClickCheck(Sender: TObject);
    procedure BtnAddFolderClick(Sender: TObject);
    procedure BtnAddWallHavenClick(Sender: TObject);
    procedure BtnRemoveSourceClick(Sender: TObject);
    procedure BtnScanAllSourcesClick(Sender: TObject);
    procedure BtnPrevWallpaperClick(Sender: TObject);
    procedure BtnPauseResumeClick(Sender: TObject);
    procedure BtnNextWallpaperClick(Sender: TObject);
    procedure BtnFavoriteClick(Sender: TObject);
    procedure BtnBlacklistClick(Sender: TObject);
    procedure BtnOpenFavoritesClick(Sender: TObject);
    procedure BtnClearBlacklistClick(Sender: TObject);
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
    procedure TransitionControlChange(Sender: TObject);
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
    FFetchThread: TWallHavenFetchThread;
    FPlaylist: TStringList;
    FHistory: TStringList;
    FHistoryPos: Integer;
    FMonitorImages: TStringList;
    FCurrentIndex: Integer;
    FCurrentSourceImage: string;
    FToggleSlot: Integer;
    FRemainingSeconds: Integer;
    FLastTickTime: TDateTime;
    FLastMinuteRendered: Word;
    FPaused: Boolean;
    FSmartPaused: Boolean;
    FSmartPauseReason: string;
    FLastSmartCheckTime: TDateTime;
    FAllowClose: Boolean;
    FAutoSelectOnReady: Boolean;
    FLoadingUI: Boolean;
    FTransitionToken: Integer;
    FLastDailyRecheckAttemptUtc: Int64;
    FStartupRecheckPending: Boolean;
    FLiveEngineActiveLogged: Boolean;
    FLiveEngineFallbackLogged: Boolean;
    FSequentialTransIdx: Integer;

    procedure LogMsg(const S: string);
    function ShouldUseLiveEngine: Boolean;
    procedure SyncLiveEngineLifecycle(ForceRestartIfFailed: Boolean = False);
    procedure PollLiveEngineStatus;
    procedure SyncChecklistFromConfig;
    procedure LoadUIToConfig;
    procedure ConfigToUI;
    procedure StopAsyncScan;
    procedure StartAsyncScan(SelectFirstOnReady: Boolean);
    procedure PollScanThread;
    procedure StopWallHavenFetch;
    procedure StartWallHavenFetch(SelectFirstOnReady, IsDailyAuto: Boolean);
    procedure PollWallHavenFetch;
    procedure CheckDailySourceRecheck(ForceStartupCheck: Boolean = False);
    procedure CheckSmartPause;
    procedure ScheduleNextTick;
    function IsCandidateEligible(const Candidate: string; out Stats: TLuminanceStats): Boolean;
    procedure PickDistinctMonitorImages(const PrimaryPath: string; TargetList: TStrings);
    procedure RecordHistory(const FilePath: string);
    procedure NavigatePrevious;
    procedure AdvanceWallpaper(Step: Integer; AddToHistory: Boolean = True);
    procedure ApplyCurrentImageWithOverlay;
    procedure ApplyWallpaperWithTransition(const PrevSourceImage: string;
      PrevMonList: TStrings);
    procedure SaveCurrentFavorite;
    procedure BlacklistCurrentWallpaper;
    procedure UpdateBlacklistButton;
    procedure UpdateCurrentStatusUI;
    procedure UpdateLuminanceLabels;
    procedure PopulateSystemFonts;
    procedure SelectFontInCombo(CB: TComboBox; const FontName: string);
    function GetSelectedFontName(CB: TComboBox; const Fallback: string): string;
    function GetWallHavenCategoriesStr: string;
    function GetWallHavenPurityStr: string;
    function ResolveScreenMinRes: string;
    procedure SelectMinResInUI(const Val: string);
    function GetMinResFromUI: string;
    procedure SelectRatioInUI(const Val: string);
    function GetRatioFromUI: string;
    procedure UpdateWallHavenInfoActions;
    procedure OpenCurrentWallHavenPage;
    procedure SetPausedState(APaused: Boolean);
    procedure LoadAppAndTrayIcon;
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

procedure TMainForm.SelectMinResInUI(const Val: string);
var
  LowVal: string;
  I: Integer;
begin
  LowVal := LowerCase(Trim(Val));
  if (LowVal = '') or (LowVal = 'any') then
  begin
    ComboMinRes.ItemIndex := 1;
    Exit;
  end;
  if LowVal = 'auto' then
  begin
    ComboMinRes.ItemIndex := 0;
    Exit;
  end;
  for I := 2 to ComboMinRes.Items.Count - 1 do
  begin
    if SameText(ComboMinRes.Items[I], LowVal) then
    begin
      ComboMinRes.ItemIndex := I;
      Exit;
    end;
  end;
  ComboMinRes.ItemIndex := 0;
end;

function TMainForm.GetMinResFromUI: string;
begin
  if ComboMinRes.ItemIndex <= 0 then
    Result := 'auto'
  else if ComboMinRes.ItemIndex = 1 then
    Result := 'any'
  else
    Result := ComboMinRes.Items[ComboMinRes.ItemIndex];
end;

procedure TMainForm.SelectRatioInUI(const Val: string);
var
  LowVal: string;
  I: Integer;
begin
  LowVal := LowerCase(Trim(Val));
  if (LowVal = '') or (LowVal = 'any') then
  begin
    ComboRatio.ItemIndex := 0;
    Exit;
  end;
  for I := 1 to ComboRatio.Items.Count - 1 do
  begin
    if SameText(ComboRatio.Items[I], LowVal) then
    begin
      ComboRatio.ItemIndex := I;
      Exit;
    end;
  end;
  ComboRatio.ItemIndex := 0;
end;

function TMainForm.GetRatioFromUI: string;
begin
  if ComboRatio.ItemIndex <= 0 then
    Result := ''
  else
    Result := ComboRatio.Items[ComboRatio.ItemIndex];
end;

function TMainForm.ResolveScreenMinRes: string;
var
  W, H: Integer;
begin
  if SameText(FConfig.WallHavenAtLeast, 'any') then Exit('');
  if not SameText(FConfig.WallHavenAtLeast, 'auto') then
    Exit(FConfig.WallHavenAtLeast);

  W := 0;
  H := 0;
  if Assigned(Screen) then
  begin
    if Assigned(Screen.PrimaryMonitor) then
    begin
      W := Screen.PrimaryMonitor.Width;
      H := Screen.PrimaryMonitor.Height;
    end;
    if (W <= 0) or (H <= 0) then
    begin
      W := Screen.Width;
      H := Screen.Height;
    end;
  end;
  if (W >= 800) and (H >= 600) then
    Result := Format('%dx%d', [W, H])
  else
    Result := '1920x1080';
end;

function TMainForm.ShouldUseLiveEngine: Boolean;
begin
  Result := FConfig.UseOpenGLEngine or (FConfig.LinuxBackend = lbOpenGLLayer);
end;

procedure TMainForm.SyncLiveEngineLifecycle(ForceRestartIfFailed: Boolean);
var
  St: TLiveEngineStatus;
  Msg: string;
begin
  St := GetLiveEngineStatus(Msg);
  if ShouldUseLiveEngine then
  begin
    if (St = lesFailed) and ForceRestartIfFailed then
    begin
      StopLiveWallpaperEngine;
      St := lesStopped;
    end;
    if St = lesStopped then
    begin
      FLiveEngineActiveLogged := False;
      FLiveEngineFallbackLogged := False;
      StartLiveWallpaperEngine;
    end;
  end
  else
  begin
    if St <> lesStopped then
    begin
      StopLiveWallpaperEngine;
      LogMsg('OpenGL 3.3 Live Engine stopped (using classic OS wallpaper backend).');
    end;
    FLiveEngineActiveLogged := False;
    FLiveEngineFallbackLogged := False;
  end;
end;

procedure TMainForm.PollLiveEngineStatus;
var
  St: TLiveEngineStatus;
  Msg: string;
begin
  if not ShouldUseLiveEngine then Exit;
  St := GetLiveEngineStatus(Msg);
  if (St = lesReady) and (not FLiveEngineActiveLogged) then
  begin
    FLiveEngineActiveLogged := True;
    LogMsg('OpenGL 3.3 Live Engine active: ' + Msg);
  end
  else if (St = lesFailed) and (not FLiveEngineFallbackLogged) then
  begin
    FLiveEngineFallbackLogged := True;
    LogMsg('OpenGL 3.3 Live Engine unavailable (' + Msg + ') — using classic OS backend fallback.');
  end;
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
  FFetchThread := nil;
  FPlaylist := TStringList.Create;
  FHistory := TStringList.Create;
  FHistoryPos := -1;
  FMonitorImages := TStringList.Create;
  FCurrentIndex := -1;
  FToggleSlot := 0;
  FRemainingSeconds := FConfig.IntervalMinutes * 60;
  FLastTickTime := Now;
  FLastMinuteRendered := 99;
  FPaused := False;
  FSmartPaused := False;
  FSmartPauseReason := '';
  FLastSmartCheckTime := 0;
  FAllowClose := False;
  FAutoSelectOnReady := False;
  FLoadingUI := False;
  FTransitionToken := 0;
  FLastDailyRecheckAttemptUtc := 0;
  FStartupRecheckPending := True;
  FLiveEngineActiveLogged := False;
  FLiveEngineFallbackLogged := False;

  Randomize;
  PopulateSystemFonts;
  ConfigToUI;
  LblDetectedDE.Caption := 'Detected environment: ' + DetectDesktopEnvironment(FConfig.LinuxBackend);

  SyncLiveEngineLifecycle;

  LoadAppAndTrayIcon;
  TrayIcon1.Hint := 'WallCycle — Click: next wallpaper';
  TrayIcon1.Visible := True;
  UpdateWallHavenInfoActions;
  UpdateBlacklistButton;

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
  StopWallHavenFetch;
  StopAsyncScan;
  StopLiveWallpaperEngine;
  FMonitorImages.Free;
  FHistory.Free;
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

procedure TMainForm.LoadAppAndTrayIcon;
var
  AppDir, IcoPath, PngPath: string;
  Candidates: array[0..4] of string;
  Idx: Integer;
  Pic: TPicture;
  TempBmp: TBitmap;
  IL: TImageList;
begin
  if Application.Icon.Empty then
  begin
    try
      Application.Icon.LoadFromResourceName(HInstance, 'MAINICON');
    except
    end;
  end;

  AppDir := ExtractFilePath(ParamStr(0));
  if Application.Icon.Empty then
  begin
    IcoPath := AppDir + 'WallCycle.ico';
    if not FileExists(IcoPath) then
      IcoPath := ExpandFileName(AppDir + '..' + DirectorySeparator + 'WallCycle.ico');
    if FileExists(IcoPath) then
    begin
      try
        Application.Icon.LoadFromFile(IcoPath);
      except
      end;
    end;
  end;

  if Application.Icon.Empty then
  begin
    Candidates[0] := AppDir + 'wallcycle.png';
    Candidates[1] := ExpandFileName(AppDir + '..' + DirectorySeparator + 'wallcycle.png');
    Candidates[2] := ExpandFileName(AppDir + '..' + DirectorySeparator + 'share' +
      DirectorySeparator + 'icons' + DirectorySeparator + 'hicolor' +
      DirectorySeparator + '512x512' + DirectorySeparator + 'apps' +
      DirectorySeparator + 'wallcycle.png');
    Candidates[3] := '/usr/share/icons/hicolor/512x512/apps/wallcycle.png';
    Candidates[4] := '/usr/share/pixmaps/wallcycle.png';

    PngPath := '';
    for Idx := Low(Candidates) to High(Candidates) do
    begin
      if FileExists(Candidates[Idx]) then
      begin
        PngPath := Candidates[Idx];
        Break;
      end;
    end;

    if PngPath <> '' then
    begin
      Pic := TPicture.Create;
      TempBmp := TBitmap.Create;
      try
        try
          Pic.LoadFromFile(PngPath);
          if (Pic.Width > 0) and (Pic.Height > 0) then
          begin
            TempBmp.Assign(Pic.Graphic);
            IL := TImageList.CreateSize(TempBmp.Width, TempBmp.Height);
            try
              IL.Add(TempBmp, nil);
              IL.GetIcon(0, Application.Icon);
            finally
              IL.Free;
            end;
          end;
        except
        end;
      finally
        TempBmp.Free;
        Pic.Free;
      end;
    end;
  end;

  if Application.Icon.Empty then
  begin
    try
      LoadEmbeddedAppIcon(Application.Icon);
    except
    end;
  end;

  if not Application.Icon.Empty then
  begin
    Self.Icon.Assign(Application.Icon);
    TrayIcon1.Icon.Assign(Application.Icon);
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

procedure TMainForm.UpdateBlacklistButton;
begin
  BtnClearBlacklist.Caption := Format('Clear Blacklist (%d)', [FConfig.BlacklistedItems.Count]);
  BtnClearBlacklist.Enabled := FConfig.BlacklistedItems.Count > 0;
end;

procedure TMainForm.UpdateCurrentStatusUI;
var
  BaseLabel, TooltipText: string;
begin
  if (FCurrentSourceImage = '') then
    BaseLabel := 'Active wallpaper: none'
  else if (FMonitorImages.Count > 1) and (FConfig.MultiMonitorMode = mmIndependent) then
    BaseLabel := Format('Active (%d monitors): %s', [FMonitorImages.Count, ExtractFileName(FCurrentSourceImage)])
  else
    BaseLabel := 'Active wallpaper: ' + ExtractFileName(FCurrentSourceImage);

  if ShouldUseLiveEngine and IsLiveEngineReady then
    BaseLabel := BaseLabel + '  [OpenGL 3.3]';

  if FPaused then
    BaseLabel := BaseLabel + '  [Paused]'
  else if FSmartPaused then
    BaseLabel := BaseLabel + '  [Smart Pause: ' + FSmartPauseReason + ']';

  LblCurrentFile.Caption := BaseLabel;

  if FCurrentSourceImage <> '' then
    TooltipText := 'WallCycle — ' + ExtractFileName(FCurrentSourceImage)
  else
    TooltipText := 'WallCycle — Click: next wallpaper';

  if FPaused then
    TooltipText := TooltipText + ' [Paused]'
  else if FSmartPaused then
    TooltipText := TooltipText + ' [Smart Pause]';

  if Length(TooltipText) > 120 then
    TooltipText := Copy(TooltipText, 1, 117) + '...';
  TrayIcon1.Hint := TooltipText;
end;

procedure TMainForm.ConfigToUI;
begin
  FLoadingUI := True;
  try
    SyncChecklistFromConfig;
    ChkSubfolders.Checked := FConfig.IncludeSubfolders;
    ChkShuffle.Checked := FConfig.ShuffleOrder;
    SpinIntervalMin.Value := FConfig.IntervalMinutes;
    ComboTransition.ItemIndex := EnsureRange(Ord(FConfig.TransitionStyle), 0, ComboTransition.Items.Count - 1);
    SpinTransitionMs.Value := EnsureRange(FConfig.TransitionDurationMs,
      SpinTransitionMs.MinValue, SpinTransitionMs.MaxValue);
    ComboMultiMonitor.ItemIndex := EnsureRange(Ord(FConfig.MultiMonitorMode), 0, ComboMultiMonitor.Items.Count - 1);
    ChkDailyRecheck.Checked := FConfig.DailySourceRecheck;

    EditApiKey.Text := FConfig.WallHavenApiKey;
    if ComboSorting.Items.Count > 0 then ComboSorting.ItemIndex := 0;
    SelectMinResInUI(FConfig.WallHavenAtLeast);
    SelectRatioInUI(FConfig.WallHavenRatio);
    ChkCatGeneral.Checked := (Length(FConfig.WallHavenCategories) < 1) or (FConfig.WallHavenCategories[1] = '1');
    ChkCatAnime.Checked := (Length(FConfig.WallHavenCategories) >= 2) and (FConfig.WallHavenCategories[2] = '1');
    ChkCatPeople.Checked := (Length(FConfig.WallHavenCategories) >= 3) and (FConfig.WallHavenCategories[3] = '1');
    ChkPurSFW.Checked := (Length(FConfig.WallHavenPurity) < 1) or (FConfig.WallHavenPurity[1] = '1');
    ChkPurSketchy.Checked := (Length(FConfig.WallHavenPurity) >= 2) and (FConfig.WallHavenPurity[2] = '1');
    ChkPurNSFW.Checked := (Length(FConfig.WallHavenPurity) >= 3) and (FConfig.WallHavenPurity[3] = '1');
    SpinMaxPages.Value := EnsureRange(FConfig.WallHavenMaxPages, SpinMaxPages.MinValue, SpinMaxPages.MaxValue);
    SpinMaxCached.Value := EnsureRange(FConfig.WallHavenMaxCached, SpinMaxCached.MinValue, SpinMaxCached.MaxValue);

    ChkDarkFilter.Checked := FConfig.DarkFilterEnabled;
    TrackMaxLum.Position := Round(FConfig.MaxLuminance * 100);
    ChkIconZone.Checked := FConfig.CheckIconZone;
    TrackIconLum.Position := Round(FConfig.IconZoneMaxLuminance * 100);
    UpdateLuminanceLabels;

    ChkOverlayEnabled.Checked := FConfig.OverlayEnabled;
    RadioCorner.ItemIndex := EnsureRange(Ord(FConfig.OverlayCorner), 0, RadioCorner.Items.Count - 1);
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

    ComboBackend.ItemIndex := EnsureRange(Ord(FConfig.LinuxBackend), 0, ComboBackend.Items.Count - 1);
    ChkUseOpenGLEngine.Checked := FConfig.UseOpenGLEngine;
    ChkStartMinimized.Checked := FConfig.StartMinimized;
    ChkAutoStart.Checked := IsAutoStartEnabled or FConfig.AutoStart;
    ChkSmartPauseFullscreen.Checked := FConfig.SmartPauseFullscreen;
    ChkSmartPauseBattery.Checked := FConfig.SmartPauseOnBattery;
    UpdateBlacklistButton;
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
  if ComboTransition.ItemIndex >= 0 then
    FConfig.TransitionStyle := TWallpaperTransition(ComboTransition.ItemIndex);
  FConfig.TransitionDurationMs := SpinTransitionMs.Value;
  if ComboMultiMonitor.ItemIndex >= 0 then
    FConfig.MultiMonitorMode := TMultiMonitorMode(ComboMultiMonitor.ItemIndex);
  FConfig.DailySourceRecheck := ChkDailyRecheck.Checked;

  FConfig.WallHavenApiKey := Trim(EditApiKey.Text);
  FConfig.WallHavenAtLeast := GetMinResFromUI;
  FConfig.WallHavenRatio := GetRatioFromUI;
  FConfig.WallHavenCategories := GetWallHavenCategoriesStr;
  FConfig.WallHavenPurity := GetWallHavenPurityStr;
  FConfig.WallHavenMaxPages := SpinMaxPages.Value;
  FConfig.WallHavenMaxCached := SpinMaxCached.Value;

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
  FConfig.UseOpenGLEngine := ChkUseOpenGLEngine.Checked;
  FConfig.StartMinimized := ChkStartMinimized.Checked;
  FConfig.AutoStart := ChkAutoStart.Checked;
  FConfig.SmartPauseFullscreen := ChkSmartPauseFullscreen.Checked;
  FConfig.SmartPauseOnBattery := ChkSmartPauseBattery.Checked;
end;

procedure TMainForm.UpdateLuminanceLabels;
begin
  LblMaxLum.Caption := Format('Global max luminance: %d%%', [TrackMaxLum.Position]);
  LblIconLum.Caption := Format('Icon-zone max luminance (24%%): %d%%', [TrackIconLum.Position]);
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

procedure TMainForm.CheckSmartPause;
var
  ShouldPause: Boolean;
  NewReason: string;
begin
  if (not FConfig.SmartPauseFullscreen) and (not FConfig.SmartPauseOnBattery) then
  begin
    if FSmartPaused then
    begin
      FSmartPaused := False;
      FSmartPauseReason := '';
      FLastTickTime := Now;
      UpdateCurrentStatusUI;
      LogMsg('Smart Pause disabled.');
    end;
    Exit;
  end;

  if (FLastSmartCheckTime > 0) and (((Now - FLastSmartCheckTime) * 86400.0) < 3.5) then
    Exit;
  FLastSmartCheckTime := Now;

  ShouldPause := False;
  NewReason := '';

  if FConfig.SmartPauseFullscreen and IsFullscreenAppActive then
  begin
    ShouldPause := True;
    NewReason := 'Fullscreen app/game';
  end
  else if FConfig.SmartPauseOnBattery and IsRunningOnBattery then
  begin
    ShouldPause := True;
    NewReason := 'Battery power';
  end;

  if ShouldPause <> FSmartPaused then
  begin
    FSmartPaused := ShouldPause;
    FSmartPauseReason := NewReason;
    FLastTickTime := Now;
    UpdateCurrentStatusUI;
    if FSmartPaused then
      LogMsg('Smart Pause engaged (' + FSmartPauseReason + ').')
    else
    begin
      LogMsg('Smart Pause released — resuming slideshow & overlay.');
      if (FCurrentSourceImage <> '') and FConfig.OverlayEnabled then
        ApplyCurrentImageWithOverlay;
    end;
  end;
end;

procedure TMainForm.ScheduleNextTick;
var
  H, M, S, MS: Word;
  MsToNextMinute, MsToNextSlide, NextInterval: Int64;
  EffectivePaused: Boolean;
begin
  TickTimer.Enabled := False;

  if (FScanThread <> nil) or (FFetchThread <> nil) then
  begin
    TickTimer.Interval := 200;
    TickTimer.Enabled := True;
    Exit;
  end;

  EffectivePaused := FPaused or FSmartPaused;

  if FConfig.OverlayEnabled and FConfig.OverlayShowSeconds and (not FSmartPaused) then
  begin
    TickTimer.Interval := 1000;
    TickTimer.Enabled := True;
    Exit;
  end;

  if FSmartPaused and (FConfig.SmartPauseFullscreen or FConfig.SmartPauseOnBattery) then
  begin
    TickTimer.Interval := 4000;
    TickTimer.Enabled := True;
    Exit;
  end;

  if (not FConfig.OverlayEnabled) or FSmartPaused then
  begin
    if EffectivePaused then Exit;
    MsToNextSlide := Int64(Max(1, FRemainingSeconds)) * 1000;
    if FConfig.SmartPauseFullscreen or FConfig.SmartPauseOnBattery then
      MsToNextSlide := Min(MsToNextSlide, Int64(5000))
    else if MsToNextSlide > 3600000 then
      MsToNextSlide := 3600000;
    TickTimer.Interval := Integer(MsToNextSlide);
    TickTimer.Enabled := True;
    Exit;
  end;

  DecodeTime(Now, H, M, S, MS);
  MsToNextMinute := (Int64(60 - S) * 1000) - Int64(MS) + 50;
  if MsToNextMinute < 250 then
    Inc(MsToNextMinute, 60000);

  if not EffectivePaused then
  begin
    MsToNextSlide := Int64(Max(1, FRemainingSeconds)) * 1000;
    NextInterval := Min(MsToNextMinute, MsToNextSlide);
  end
  else
    NextInterval := MsToNextMinute;

  if (FConfig.SmartPauseFullscreen or FConfig.SmartPauseOnBattery) and (NextInterval > 5000) then
    NextInterval := 5000;

  if NextInterval < 250 then NextInterval := 250;
  TickTimer.Interval := Integer(NextInterval);
  TickTimer.Enabled := True;
end;

procedure TMainForm.StartAsyncScan(SelectFirstOnReady: Boolean);
begin
  StopAsyncScan;
  FAutoSelectOnReady := SelectFirstOnReady;
  FScanThread := TPlaylistScanThread.Create(FConfig, FLuminanceCache);
  ScheduleNextTick;
  LogMsg('Background source scan started...');
end;

procedure TMainForm.PollScanThread;
var
  State: TScanState;
  NewList: TStringList;
begin
  if FScanThread = nil then Exit;

  NewList := TStringList.Create;
  try
    if FScanThread.ConsumeDiscoveredList(NewList) then
    begin
      FPlaylist.Assign(NewList);
      FCurrentIndex := -1;
      LogMsg(Format('Found %d files in active sources (indexing luminance in background).',
        [FPlaylist.Count]));

      if FAutoSelectOnReady and (FPlaylist.Count > 0) then
      begin
        FAutoSelectOnReady := False;
        AdvanceWallpaper(1, True);
      end;
    end;

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
      LogMsg(Format('Indexing complete: %d eligible, skipped too bright (%d local PC, %d WallHaven).',
        [FPlaylist.Count, State.RejectedLocal, State.RejectedWallHaven]));

    FScanThread.WaitFor;
    FreeAndNil(FScanThread);
    ScheduleNextTick;
    if FStartupRecheckPending then
    begin
      FStartupRecheckPending := False;
      CheckDailySourceRecheck(True);
    end;
  end;
end;

function TMainForm.IsCandidateEligible(const Candidate: string;
  out Stats: TLuminanceStats): Boolean;
begin
  Result := False;
  if (Trim(Candidate) = '') or (not FileExists(Candidate)) then Exit;
  if FConfig.IsBlacklisted(Candidate) then Exit;

  if FConfig.DarkFilterEnabled then
  begin
    if not IsImageDarkEnough(Candidate, FConfig.MaxLuminance,
      FConfig.IconZoneMaxLuminance, FConfig.CheckIconZone, Stats, FLuminanceCache) then
    begin
      if not Stats.Valid then
        LogMsg(Format('Skipped corrupted image (%s): %s',
          [Stats.ErrorReason, ExtractFileName(Candidate)]))
      else
        LogMsg(Format('Skipped image too bright (Avg=%.0f%%, Icon=%.0f%%): %s',
          [Stats.AverageLuminance * 100, Stats.IconZoneLuminance * 100, ExtractFileName(Candidate)]));
      Exit;
    end;
  end
  else
  begin
    if not FLuminanceCache.TryGet(Candidate, Stats) then
    begin
      Stats := AnalyzeImageLuminance(Candidate);
      if Stats.Valid then FLuminanceCache.Put(Candidate, Stats);
    end;
    if not Stats.Valid then
    begin
      LogMsg(Format('Skipped corrupted image (%s): %s',
        [Stats.ErrorReason, ExtractFileName(Candidate)]));
      Exit;
    end;
  end;
  Result := True;
end;

procedure TMainForm.PickDistinctMonitorImages(const PrimaryPath: string;
  TargetList: TStrings);
var
  MonCount, NeedMore, StartIdx, I, TryIdx: Integer;
  Cand: string;
  Stats: TLuminanceStats;
begin
  TargetList.Clear;
  if PrimaryPath = '' then Exit;
  TargetList.Add(PrimaryPath);

  MonCount := 1;
  if Assigned(Screen) then
    MonCount := Max(1, Screen.MonitorCount);

  if (FConfig.MultiMonitorMode <> mmIndependent) or (MonCount <= 1) then
    Exit;

  NeedMore := MonCount - 1;
  StartIdx := FPlaylist.IndexOf(PrimaryPath);
  if StartIdx < 0 then StartIdx := 0;

  for I := 1 to FPlaylist.Count do
  begin
    if TargetList.Count >= MonCount then Break;
    if FConfig.ShuffleOrder then
      TryIdx := Random(FPlaylist.Count)
    else
      TryIdx := (StartIdx + I) mod FPlaylist.Count;

    Cand := FPlaylist[TryIdx];
    if TargetList.IndexOf(Cand) >= 0 then Continue;
    if IsCandidateEligible(Cand, Stats) then
      TargetList.Add(Cand);
  end;

  if TargetList.Count < MonCount then
  begin
    for I := 0 to FPlaylist.Count - 1 do
    begin
      if TargetList.Count >= MonCount then Break;
      Cand := FPlaylist[I];
      if TargetList.IndexOf(Cand) >= 0 then Continue;
      if IsCandidateEligible(Cand, Stats) then
        TargetList.Add(Cand);
    end;
  end;

  while TargetList.Count < NeedMore + 1 do
    TargetList.Add(PrimaryPath);
end;

procedure TMainForm.ApplyCurrentImageWithOverlay;
var
  RenderDir: string;
  Res: TBackendResult;
  H, M, S, MS: Word;
  MonPaths: array of string;
  OutPaths: TStringList;
  I: Integer;
  PerMonFiles: Boolean;
  NextBmp: TBitmap;
  NextTex: TShaderTextureData;
begin
  if (FCurrentSourceImage = '') or (not FileExists(FCurrentSourceImage)) then Exit;

  DecodeTime(Now, H, M, S, MS);
  FLastMinuteRendered := M;
  UpdateWallHavenInfoActions;

  if FMonitorImages.Count = 0 then
    FMonitorImages.Add(FCurrentSourceImage);

  SetLength(MonPaths, FMonitorImages.Count);
  for I := 0 to FMonitorImages.Count - 1 do
    MonPaths[I] := FMonitorImages[I];

  // Live OpenGL 3.3 GPU path (skip 1s clock redraw while an animated shader is mid-flight)
  if ShouldUseLiveEngine and WaitForLiveEngineReady(400) and IsLiveEngineReady then
  begin
    if IsLiveEngineTransitioning then Exit;
    NextBmp := CreateMultiMonitorCompositeBitmap(MonPaths, FConfig.MultiMonitorMode, FConfig);
    if NextBmp = nil then
    begin
      LogMsg('Overlay rendering error on: ' + FCurrentSourceImage);
      Exit;
    end;
    try
      NextTex := BitmapToShaderTexture(NextBmp);
    finally
      NextBmp.Free;
    end;
    if Length(NextTex.RGB) > 0 then
    begin
      LivePresentImmediate(NextTex);
      UpdateCurrentStatusUI;
      Exit;
    end;
  end
  else
    PollLiveEngineStatus;

  // Classic OS wallpaper backend fallback
  RenderDir := IncludeTrailingPathDelimiter(GetAppConfigDir(False)) + 'rendered';
  PerMonFiles := (FConfig.MultiMonitorMode = mmIndependent) and
                 Assigned(Screen) and (Screen.MonitorCount > 1) and
                 BackendSupportsPerMonitorFiles(FConfig.LinuxBackend);

  OutPaths := nil;
  if not RenderMultiMonitorWallpapers(MonPaths, RenderDir, FConfig, PerMonFiles,
    FToggleSlot, OutPaths) then
  begin
    if OutPaths <> nil then OutPaths.Free;
    LogMsg('Overlay rendering error on: ' + FCurrentSourceImage);
    Exit;
  end;

  try
    if OutPaths.Count > 1 then
      Res := ApplySystemMultiMonitorWallpapers(OutPaths, FConfig.LinuxBackend,
        FConfig.MultiMonitorMode, wtNone, 0)
    else
      Res := ApplySystemWallpaper(OutPaths[0], FConfig.LinuxBackend,
        wtNone, 0, FConfig.MultiMonitorMode);

    if Res.Success then
      UpdateCurrentStatusUI
    else
      LogMsg('Backend error [' + Res.BackendName + ']: ' + Res.Message);
  finally
    OutPaths.Free;
  end;
end;

procedure TMainForm.ApplyWallpaperWithTransition(const PrevSourceImage: string;
  PrevMonList: TStrings);
var
  RenderDir, RenderedPath: string;
  Res: TBackendResult;
  H, M, S, MS: Word;
  NextBmp, PrevBmp: TBitmap;
  NextTex, PrevTex: TShaderTextureData;
  ActiveTrans: TWallpaperTransition;
  Steps, StepDelay, I, MyToken: Integer;
  Progress, Eased: Double;
  UseFastBMP, PerMonFiles: Boolean;
  CurMonArr, PrevMonArr: array of string;
  OutPaths: TStringList;
begin
  if (FCurrentSourceImage = '') or (not FileExists(FCurrentSourceImage)) then Exit;

  Inc(FTransitionToken);
  MyToken := FTransitionToken;

  DecodeTime(Now, H, M, S, MS);
  FLastMinuteRendered := M;
  UpdateWallHavenInfoActions;

  if FMonitorImages.Count = 0 then
    FMonitorImages.Add(FCurrentSourceImage);

  SetLength(CurMonArr, FMonitorImages.Count);
  for I := 0 to FMonitorImages.Count - 1 do
    CurMonArr[I] := FMonitorImages[I];

  // Primary GPU path: OpenGL 3.3 Core GLSL Shader Engine (60 FPS)
  if ShouldUseLiveEngine and WaitForLiveEngineReady(2500) and IsLiveEngineReady then
  begin
    NextBmp := CreateMultiMonitorCompositeBitmap(CurMonArr, FConfig.MultiMonitorMode, FConfig);
    if NextBmp = nil then
    begin
      LogMsg('Overlay rendering error on: ' + FCurrentSourceImage);
      Exit;
    end;
    try
      NextTex := BitmapToShaderTexture(NextBmp);
    finally
      NextBmp.Free;
    end;

    if Length(NextTex.RGB) > 0 then
    begin
      ActiveTrans := FConfig.TransitionStyle;
      if (ActiveTrans = wtRandom) or (ActiveTrans = wtSequential) then
      begin
        if ActiveTrans = wtRandom then
          I := Random(15)
        else
        begin
          I := FSequentialTransIdx mod 15;
          FSequentialTransIdx := (FSequentialTransIdx + 1) mod 15;
        end;
        case I of
          0: ActiveTrans := wtFade;
          1: ActiveTrans := wtWipe;
          2: ActiveTrans := wtLeft;
          3: ActiveTrans := wtRight;
          4: ActiveTrans := wtCenter;
          5: ActiveTrans := wtFilmBurn;
          6: ActiveTrans := wtNaturalWave;
          7: ActiveTrans := wtRainMelt;
          8: ActiveTrans := wtInkDissolve;
          9: ActiveTrans := wtPrismWipe;
          10: ActiveTrans := wtEarthquakeCollapse;
          11: ActiveTrans := wtPuzzleBuild;
          12: ActiveTrans := wtKaleidoPrism;
          13: ActiveTrans := wtBioluminescentSpores;
        else
          ActiveTrans := wtShatteredGlass;
        end;
      end;

      if (ActiveTrans = wtNone) or (PrevSourceImage = '') or
         SameFileName(PrevSourceImage, FCurrentSourceImage) or (not FileExists(PrevSourceImage)) then
      begin
        LivePresentImmediate(NextTex);
        UpdateCurrentStatusUI;
        Exit;
      end;

      PrevTex.Width := 0;
      PrevTex.Height := 0;
      SetLength(PrevTex.RGB, 0);
      if not HasLiveEnginePreviousFrame then
      begin
        if (PrevMonList <> nil) and (PrevMonList.Count > 0) then
        begin
          SetLength(PrevMonArr, PrevMonList.Count);
          for I := 0 to PrevMonList.Count - 1 do
            PrevMonArr[I] := PrevMonList[I];
        end
        else
        begin
          SetLength(PrevMonArr, 1);
          PrevMonArr[0] := PrevSourceImage;
        end;
        PrevBmp := CreateMultiMonitorCompositeBitmap(PrevMonArr, FConfig.MultiMonitorMode, FConfig);
        if PrevBmp <> nil then
        try
          PrevTex := BitmapToShaderTexture(PrevBmp);
        finally
          PrevBmp.Free;
        end;
      end;

      LiveTransitionTo(NextTex, PrevTex, TransitionToShaderName(ActiveTrans),
        FConfig.TransitionDurationMs);
      UpdateCurrentStatusUI;
      Exit;
    end;
  end
  else
    PollLiveEngineStatus;

  // Classic OS wallpaper backend fallback (per-monitor / awww / gsettings / Win32)
  RenderDir := IncludeTrailingPathDelimiter(GetAppConfigDir(False)) + 'rendered';
  PerMonFiles := (FConfig.MultiMonitorMode = mmIndependent) and
                 Assigned(Screen) and (Screen.MonitorCount > 1) and
                 BackendSupportsPerMonitorFiles(FConfig.LinuxBackend);

  if PerMonFiles then
  begin
    OutPaths := nil;
    if not RenderMultiMonitorWallpapers(CurMonArr, RenderDir, FConfig, True,
      FToggleSlot, OutPaths) then
    begin
      if OutPaths <> nil then OutPaths.Free;
      LogMsg('Overlay rendering error on: ' + FCurrentSourceImage);
      Exit;
    end;
    try
      if BackendHasNativeTransition(FConfig.LinuxBackend) and (FConfig.TransitionStyle <> wtNone) then
        Res := ApplySystemMultiMonitorWallpapers(OutPaths, FConfig.LinuxBackend,
          FConfig.MultiMonitorMode, FConfig.TransitionStyle, FConfig.TransitionDurationMs)
      else
        Res := ApplySystemMultiMonitorWallpapers(OutPaths, FConfig.LinuxBackend,
          FConfig.MultiMonitorMode, wtNone, 0);

      if Res.Success then
        UpdateCurrentStatusUI
      else
        LogMsg('Backend error [' + Res.BackendName + ']: ' + Res.Message);
    finally
      OutPaths.Free;
    end;
    Exit;
  end;

  NextBmp := CreateMultiMonitorCompositeBitmap(CurMonArr, FConfig.MultiMonitorMode, FConfig);
  if NextBmp = nil then
  begin
    LogMsg('Overlay rendering error on: ' + FCurrentSourceImage);
    Exit;
  end;

  try
    if (FConfig.TransitionStyle = wtNone) or (PrevSourceImage = '') or
       SameFileName(PrevSourceImage, FCurrentSourceImage) or (not FileExists(PrevSourceImage)) then
    begin
      if RenderWallpaperFromBitmap(NextBmp, RenderDir, False, FToggleSlot, RenderedPath) then
      begin
        Res := ApplySystemWallpaper(RenderedPath, FConfig.LinuxBackend,
          wtNone, 0, FConfig.MultiMonitorMode);
        if Res.Success then
          UpdateCurrentStatusUI
        else
          LogMsg('Backend error [' + Res.BackendName + ']: ' + Res.Message);
      end;
      Exit;
    end;

    if BackendHasNativeTransition(FConfig.LinuxBackend) then
    begin
      if RenderWallpaperFromBitmap(NextBmp, RenderDir, False, FToggleSlot, RenderedPath) then
      begin
        Res := ApplySystemWallpaper(RenderedPath, FConfig.LinuxBackend,
          FConfig.TransitionStyle, FConfig.TransitionDurationMs, FConfig.MultiMonitorMode);
        if Res.Success then
          UpdateCurrentStatusUI
        else
          LogMsg('Backend error [' + Res.BackendName + ']: ' + Res.Message);
      end;
      Exit;
    end;

    if (Int64(NextBmp.Width) * Int64(NextBmp.Height)) > (4096 * 2160) then
    begin
      if RenderWallpaperFromBitmap(NextBmp, RenderDir, False, FToggleSlot, RenderedPath) then
      begin
        Res := ApplySystemWallpaper(RenderedPath, FConfig.LinuxBackend,
          wtNone, 0, FConfig.MultiMonitorMode);
        if Res.Success then
          UpdateCurrentStatusUI
        else
          LogMsg('Backend error [' + Res.BackendName + ']: ' + Res.Message);
      end;
      Exit;
    end;

    ActiveTrans := FConfig.TransitionStyle;
    if ActiveTrans = wtRandom then
      ActiveTrans := TWallpaperTransition(Ord(wtFade) + Random(5))
    else if ActiveTrans = wtSequential then
    begin
      ActiveTrans := TWallpaperTransition(Ord(wtFade) + (FSequentialTransIdx mod 5));
      FSequentialTransIdx := (FSequentialTransIdx + 1) mod 5;
    end;

    if (PrevMonList <> nil) and (PrevMonList.Count > 0) then
    begin
      SetLength(PrevMonArr, PrevMonList.Count);
      for I := 0 to PrevMonList.Count - 1 do
        PrevMonArr[I] := PrevMonList[I];
    end
    else
    begin
      SetLength(PrevMonArr, 1);
      PrevMonArr[0] := PrevSourceImage;
    end;

    PrevBmp := CreateMultiMonitorCompositeBitmap(PrevMonArr, FConfig.MultiMonitorMode, FConfig);
    try
      if PrevBmp <> nil then
      begin
        Steps := RecommendedSoftwareTransitionSteps(FConfig.LinuxBackend);
        StepDelay := Max(25, FConfig.TransitionDurationMs div Steps);
        {$IFDEF WINDOWS}
        UseFastBMP := True;
        {$ELSE}
        UseFastBMP := False;
        {$ENDIF}

        for I := 1 to Steps - 1 do
        begin
          if (MyToken <> FTransitionToken) or Application.Terminated then Exit;
          Progress := I / Steps;
          Eased := Progress * Progress * (3.0 - 2.0 * Progress);
          if RenderTransitionStep(PrevBmp, NextBmp, ActiveTrans, Eased, RenderDir,
               UseFastBMP, FToggleSlot, RenderedPath) then
            ApplySystemWallpaper(RenderedPath, FConfig.LinuxBackend,
              wtNone, 0, FConfig.MultiMonitorMode);
          Application.ProcessMessages;
          if (MyToken <> FTransitionToken) or Application.Terminated then Exit;
          Sleep(StepDelay);
        end;
      end;
    finally
      PrevBmp.Free;
    end;

    if (MyToken <> FTransitionToken) or Application.Terminated then Exit;
    if RenderWallpaperFromBitmap(NextBmp, RenderDir, False, FToggleSlot, RenderedPath) then
    begin
      Res := ApplySystemWallpaper(RenderedPath, FConfig.LinuxBackend,
        wtNone, 0, FConfig.MultiMonitorMode);
      if Res.Success then
        UpdateCurrentStatusUI
      else
        LogMsg('Backend error [' + Res.BackendName + ']: ' + Res.Message);
    end;
  finally
    NextBmp.Free;
  end;
end;

procedure TMainForm.RecordHistory(const FilePath: string);
begin
  if FilePath = '' then Exit;
  while (FHistoryPos >= 0) and (FHistory.Count - 1 > FHistoryPos) do
    FHistory.Delete(FHistory.Count - 1);

  if (FHistory.Count = 0) or (not SameFileName(FHistory[FHistory.Count - 1], FilePath)) then
    FHistory.Add(FilePath);

  while FHistory.Count > 200 do
    FHistory.Delete(0);

  FHistoryPos := FHistory.Count - 1;
end;

procedure TMainForm.NavigatePrevious;
var
  PrevIdx, Idx: Integer;
  Target, PrevImg: string;
  PrevMons: TStringList;
  Stats: TLuminanceStats;
begin
  PrevIdx := FHistoryPos - 1;
  while PrevIdx >= 0 do
  begin
    Target := FHistory[PrevIdx];
    if IsCandidateEligible(Target, Stats) then
    begin
      FHistoryPos := PrevIdx;
      PrevImg := FCurrentSourceImage;
      PrevMons := TStringList.Create;
      try
        PrevMons.Assign(FMonitorImages);
        FCurrentSourceImage := Target;
        Idx := FPlaylist.IndexOf(Target);
        if Idx >= 0 then FCurrentIndex := Idx;
        PickDistinctMonitorImages(Target, FMonitorImages);
        FRemainingSeconds := Max(1, FConfig.IntervalMinutes) * 60;
        FLastTickTime := Now;
        ApplyWallpaperWithTransition(PrevImg, PrevMons);
      finally
        PrevMons.Free;
      end;
      ScheduleNextTick;
      LogMsg('Restored previous wallpaper: ' + ExtractFileName(Target));
      Exit;
    end;
    Dec(PrevIdx);
  end;

  AdvanceWallpaper(-1, False);
end;

procedure TMainForm.AdvanceWallpaper(Step: Integer; AddToHistory: Boolean);
var
  Attempts: Integer;
  Candidate, PrevImg: string;
  PrevMons: TStringList;
  Stats: TLuminanceStats;
begin
  if FPlaylist.Count = 0 then
  begin
    if FScanThread = nil then
      StartAsyncScan(True);
    Exit;
  end;

  Attempts := 0;
  while Attempts < FPlaylist.Count do
  begin
    if FCurrentIndex < 0 then
      FCurrentIndex := 0
    else
      FCurrentIndex := (FCurrentIndex + Step + FPlaylist.Count) mod FPlaylist.Count;

    Candidate := FPlaylist[FCurrentIndex];
    Inc(Attempts);

    if not IsCandidateEligible(Candidate, Stats) then Continue;

    PrevImg := FCurrentSourceImage;
    PrevMons := TStringList.Create;
    try
      PrevMons.Assign(FMonitorImages);
      FCurrentSourceImage := Candidate;
      if AddToHistory then
        RecordHistory(Candidate);
      PickDistinctMonitorImages(Candidate, FMonitorImages);
      FRemainingSeconds := Max(1, FConfig.IntervalMinutes) * 60;
      FLastTickTime := Now;
      ApplyWallpaperWithTransition(PrevImg, PrevMons);
    finally
      PrevMons.Free;
    end;
    ScheduleNextTick;
    LogMsg('Applied wallpaper: ' + ExtractFileName(Candidate));
    Exit;
  end;

  LogMsg('No eligible images found in active sources (all exceed luminance filter or are blacklisted).');
end;

procedure TMainForm.TickTimerTimer(Sender: TObject);
var
  H, M, S, MS: Word;
  ElapsedSec: Integer;
begin
  PollLiveEngineStatus;
  PollScanThread;
  PollWallHavenFetch;
  CheckSmartPause;

  if FScanThread <> nil then
  begin
    DecodeTime(Now, H, M, S, MS);
    if (FCurrentSourceImage <> '') and FConfig.OverlayEnabled and
       (not FSmartPaused) and (M <> FLastMinuteRendered) then
      ApplyCurrentImageWithOverlay;
    Exit;
  end;

  if (not FPaused) and (not FSmartPaused) then
  begin
    ElapsedSec := Max(0, Round((Now - FLastTickTime) * 86400.0));
    FLastTickTime := Now;
    Dec(FRemainingSeconds, ElapsedSec);
    if FRemainingSeconds <= 0 then
    begin
      AdvanceWallpaper(1, True);
      Exit;
    end;
  end
  else
    FLastTickTime := Now;

  DecodeTime(Now, H, M, S, MS);
  if (FCurrentSourceImage <> '') and FConfig.OverlayEnabled and (not FSmartPaused) then
  begin
    if FConfig.OverlayShowSeconds or (M <> FLastMinuteRendered) then
      ApplyCurrentImageWithOverlay;
  end;

  if (FScanThread = nil) and (FFetchThread = nil) and (not FStartupRecheckPending) and
     (not FSmartPaused) then
    CheckDailySourceRecheck(False);

  ScheduleNextTick;
end;

procedure TMainForm.CheckListSourcesClick(Sender: TObject);
var
  Idx, SIdx: Integer;
  Src: TWallpaperSource;
begin
  Idx := CheckListSources.ItemIndex;
  if (Idx < 0) or (Idx >= FConfig.Sources.Count) then Exit;
  Src := FConfig.GetSource(Idx);
  if Src.Kind <> skWallHaven then Exit;

  EditQuery.Text := Src.Target;
  SIdx := ComboSorting.Items.IndexOf(Src.Sorting);
  if SIdx >= 0 then
    ComboSorting.ItemIndex := SIdx;
  ChkCatGeneral.Checked := (Length(Src.Categories) < 1) or (Src.Categories[1] = '1');
  ChkCatAnime.Checked := (Length(Src.Categories) >= 2) and (Src.Categories[2] = '1');
  ChkCatPeople.Checked := (Length(Src.Categories) >= 3) and (Src.Categories[3] = '1');
  ChkPurSFW.Checked := (Length(Src.Purity) < 1) or (Src.Purity[1] = '1');
  ChkPurSketchy.Checked := (Length(Src.Purity) >= 2) and (Src.Purity[2] = '1');
  ChkPurNSFW.Checked := (Length(Src.Purity) >= 3) and (Src.Purity[3] = '1');
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
    LogMsg('Note: WallHaven NSFW filter requires a valid API Key.');

  FConfig.AddWallHavenSource(Trim(EditQuery.Text), SortStr, CatStr, PurStr, True);
  FConfig.Save;
  SyncChecklistFromConfig;
  LogMsg(Format('Saved WallHaven.cc source: "%s" (%s · Cat:%s · Pur:%s)',
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
  TransitionControlChange(nil);
  NavigatePrevious;
end;

procedure TMainForm.BtnNextWallpaperClick(Sender: TObject);
begin
  TransitionControlChange(nil);
  AdvanceWallpaper(1, True);
end;

procedure TMainForm.SaveCurrentFavorite;
var
  DestPath, ErrMsg: string;
begin
  if (FCurrentSourceImage = '') or (not FileExists(FCurrentSourceImage)) then
  begin
    LogMsg('No active wallpaper to save to Favorites.');
    Exit;
  end;

  if FConfig.SaveFavorite(FCurrentSourceImage, DestPath, ErrMsg) then
  begin
    FConfig.Save;
    LogMsg('Saved to Favorites: ' + DestPath);
  end
  else
    LogMsg('Failed to save Favorite: ' + ErrMsg);
end;

procedure TMainForm.BtnFavoriteClick(Sender: TObject);
begin
  SaveCurrentFavorite;
end;

procedure TMainForm.BlacklistCurrentWallpaper;
var
  TargetPath: string;
  DeletedFromCache: Boolean;
  I: Integer;
begin
  TargetPath := FCurrentSourceImage;
  if Trim(TargetPath) = '' then
  begin
    LogMsg('No active wallpaper to blacklist.');
    Exit;
  end;

  if not FConfig.AddToBlacklist(TargetPath, DeletedFromCache) then Exit;
  FConfig.Save;
  UpdateBlacklistButton;

  for I := FPlaylist.Count - 1 downto 0 do
    if SameFileName(FPlaylist[I], TargetPath) or FConfig.IsBlacklisted(FPlaylist[I]) then
      FPlaylist.Delete(I);

  for I := FHistory.Count - 1 downto 0 do
    if SameFileName(FHistory[I], TargetPath) or FConfig.IsBlacklisted(FHistory[I]) then
    begin
      FHistory.Delete(I);
      if I <= FHistoryPos then
        Dec(FHistoryPos);
    end;
  if FHistoryPos >= FHistory.Count then
    FHistoryPos := FHistory.Count - 1;

  FCurrentIndex := Min(FCurrentIndex, FPlaylist.Count - 1);
  if DeletedFromCache then
    LogMsg('Blacklisted permanently and deleted from cache: ' + ExtractFileName(TargetPath))
  else
    LogMsg('Blacklisted permanently: ' + ExtractFileName(TargetPath));

  if FPlaylist.Count > 0 then
    AdvanceWallpaper(1, True)
  else
  begin
    FCurrentSourceImage := '';
    FMonitorImages.Clear;
    UpdateWallHavenInfoActions;
    UpdateCurrentStatusUI;
  end;
end;

procedure TMainForm.BtnBlacklistClick(Sender: TObject);
begin
  BlacklistCurrentWallpaper;
end;

procedure TMainForm.BtnOpenFavoritesClick(Sender: TObject);
begin
  if Trim(FConfig.FavoritesDir) = '' then
    FConfig.FavoritesDir := FConfig.GetDefaultFavoritesDir;
  ForceDirectories(FConfig.FavoritesDir);
  if not OpenURL(FConfig.FavoritesDir) then
    LogMsg('Favorites folder: ' + FConfig.FavoritesDir);
end;

procedure TMainForm.BtnClearBlacklistClick(Sender: TObject);
var
  OldCount: Integer;
begin
  OldCount := FConfig.BlacklistedItems.Count;
  if OldCount = 0 then Exit;
  FConfig.ClearBlacklist;
  FConfig.Save;
  UpdateBlacklistButton;
  LogMsg(Format('Cleared permanent blacklist (%d item(s) restored).', [OldCount]));
  StartAsyncScan(False);
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
    BtnPauseResume.Caption := 'Resume Slideshow';
    MnuPause.Caption := 'Resume Slideshow';
    LogMsg('Slideshow paused.');
  end
  else
  begin
    BtnPauseResume.Caption := 'Pause Slideshow';
    MnuPause.Caption := 'Pause Slideshow';
    LogMsg('Slideshow resumed.');
  end;
  UpdateCurrentStatusUI;
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
    DateStr := 'Mon 23 Nov 2026';
  end;

  TimeFontName := GetSelectedFontName(ComboTimeFont, 'Sans');
  DateFontName := GetSelectedFontName(ComboDateFont, 'Sans');

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

procedure TMainForm.StopWallHavenFetch;
begin
  if FFetchThread <> nil then
  begin
    FFetchThread.Terminate;
    FFetchThread.WaitFor;
    FreeAndNil(FFetchThread);
  end;
  BtnFetchWallHaven.Enabled := True;
  BtnFetchWallHaven.Caption := 'Fetch Active Feeds';
  MnuFetchWH.Enabled := True;
end;

procedure TMainForm.StartWallHavenFetch(SelectFirstOnReady, IsDailyAuto: Boolean);
var
  I, EnabledWH, MaxPerSrc: Integer;
  SortStr, CatStr, PurStr, ResolvedRes, ResLabel: string;
begin
  if FFetchThread <> nil then
  begin
    if not IsDailyAuto then
      LogMsg('A WallHaven background fetch is already running.');
    Exit;
  end;

  if not IsDailyAuto then
  begin
    LoadUIToConfig;
    CatStr := GetWallHavenCategoriesStr;
    PurStr := GetWallHavenPurityStr;
  end
  else
  begin
    CatStr := FConfig.WallHavenCategories;
    PurStr := FConfig.WallHavenPurity;
  end;

  EnabledWH := 0;
  for I := 0 to FConfig.Sources.Count - 1 do
    if (FConfig.GetSource(I).Kind = skWallHaven) and FConfig.GetSource(I).Enabled then
      Inc(EnabledWH);

  if EnabledWH = 0 then
  begin
    if (not IsDailyAuto) and (Trim(EditQuery.Text) <> '') then
    begin
      if ComboSorting.ItemIndex >= 0 then
        SortStr := ComboSorting.Items[ComboSorting.ItemIndex]
      else
        SortStr := 'toplist';
      FConfig.AddWallHavenSource(Trim(EditQuery.Text), SortStr, CatStr, PurStr, True);
      SyncChecklistFromConfig;
      LogMsg(Format('No WallHaven source checked: automatically enabled "%s" (%s · Cat:%s · Pur:%s).',
        [Trim(EditQuery.Text), SortStr, CatStr, PurStr]));
    end
    else
    begin
      if not IsDailyAuto then
        LogMsg('No active WallHaven.cc source in checklist. Add or check at least one source.');
      Exit;
    end;
  end;

  if (not IsDailyAuto) and (Copy(PurStr, 3, 1) = '1') and (Trim(FConfig.WallHavenApiKey) = '') then
    LogMsg('Warning: NSFW purity selected without API Key; WallHaven may return empty results or HTTP 401.');

  if not IsDailyAuto then
    FConfig.Save;

  BtnFetchWallHaven.Enabled := False;
  BtnFetchWallHaven.Caption := 'Fetching...';
  MnuFetchWH.Enabled := False;

  ResolvedRes := ResolveScreenMinRes;
  if ResolvedRes = '' then
    ResLabel := 'any'
  else
    ResLabel := ResolvedRes;
  LogMsg(Format('Fetching WallHaven.cc feeds in background (%d pg, max %d cached, res=%s)...',
    [FConfig.WallHavenMaxPages, FConfig.WallHavenMaxCached, ResLabel]));

  MaxPerSrc := Min(Max(12, FConfig.WallHavenMaxPages * 3), Max(5, FConfig.WallHavenMaxCached));
  FFetchThread := TWallHavenFetchThread.Create(FConfig, MaxPerSrc, FLuminanceCache,
    SelectFirstOnReady, IsDailyAuto, FCurrentSourceImage, ResolvedRes);
  ScheduleNextTick;
end;

procedure TMainForm.PollWallHavenFetch;
var
  State: TWallHavenFetchState;
  Stats: TWallHavenFetchStats;
  Files, Logs: TStringList;
  I: Integer;
  aSelectFirst, IsDailyAuto: Boolean;
  PrevImg: string;
  PrevMons: TStringList;
begin
  if FFetchThread = nil then Exit;

  Logs := TStringList.Create;
  try
    FFetchThread.ConsumeLogs(Logs);
    for I := 0 to Logs.Count - 1 do
      LogMsg(Logs[I]);
  finally
    Logs.Free;
  end;

  State := FFetchThread.GetState;
  if State.Running then Exit;

  Files := TStringList.Create;
  try
    FFetchThread.ConsumeResult(Stats, Files, aSelectFirst, IsDailyAuto);
    FFetchThread.WaitFor;
    FreeAndNil(FFetchThread);

    BtnFetchWallHaven.Enabled := True;
    BtnFetchWallHaven.Caption := 'Fetch Active Feeds';
    MnuFetchWH.Enabled := True;

    if Stats.LastError <> '' then
      LogMsg(Stats.LastError);

    LogMsg(Format('WallHaven (%d pg.): %d examined, %d skipped (palette), %d skipped (pixels), %d ready.',
      [Stats.PagesScanned, Stats.CandidatesExamined, Stats.RejectedByPalette, Stats.RejectedByPixels, Stats.DownloadedCount]));

    if Stats.PrunedCount > 0 then
      LogMsg(Format('Cache cleanup: removed %d oldest file(s) by creation date (limit: %d).',
        [Stats.PrunedCount, FConfig.WallHavenMaxCached]));

    if (Stats.DownloadedCount = 0) and (Stats.CandidatesExamined > 0) and
       ((Stats.RejectedByPalette + Stats.RejectedByPixels) >= Stats.CandidatesExamined) then
      LogMsg('Tip: all examined images exceeded the luminance threshold (try raising thresholds or disabling the filter).');

    if (Stats.DownloadedCount > 0) or (Stats.LastError = '') then
    begin
      FConfig.LastDailyRecheckUtc := DateTimeToUnix(Now);
      FConfig.Save;
    end;

    if aSelectFirst and (Files.Count > 0) then
    begin
      PrevImg := FCurrentSourceImage;
      PrevMons := TStringList.Create;
      try
        PrevMons.Assign(FMonitorImages);
        FCurrentSourceImage := Files[0];
        RecordHistory(Files[0]);
        PickDistinctMonitorImages(Files[0], FMonitorImages);
        FRemainingSeconds := Max(1, FConfig.IntervalMinutes) * 60;
        FLastTickTime := Now;
        ApplyWallpaperWithTransition(PrevImg, PrevMons);
      finally
        PrevMons.Free;
      end;
    end;
    StartAsyncScan(FCurrentSourceImage = '');
    ScheduleNextTick;
  finally
    Files.Free;
  end;
end;

procedure TMainForm.CheckDailySourceRecheck(ForceStartupCheck: Boolean);
var
  NowUtc: Int64;
  I, EnabledWH, EnabledLocal: Integer;
begin
  if not FConfig.DailySourceRecheck then Exit;
  if (FFetchThread <> nil) or (FScanThread <> nil) then Exit;

  NowUtc := DateTimeToUnix(Now);
  if (FConfig.LastDailyRecheckUtc > 0) and ((NowUtc - FConfig.LastDailyRecheckUtc) < 86400) then
    Exit;
  if (FLastDailyRecheckAttemptUtc > 0) and ((NowUtc - FLastDailyRecheckAttemptUtc) < 3600) then
    Exit;

  EnabledWH := 0;
  EnabledLocal := 0;
  for I := 0 to FConfig.Sources.Count - 1 do
  begin
    if not FConfig.GetSource(I).Enabled then Continue;
    if FConfig.GetSource(I).Kind = skWallHaven then
      Inc(EnabledWH)
    else
      Inc(EnabledLocal);
  end;

  if (EnabledWH = 0) and (EnabledLocal = 0) then Exit;

  FLastDailyRecheckAttemptUtc := NowUtc;
  if EnabledWH > 0 then
  begin
    LogMsg('Daily source recheck: fetching active WallHaven.cc feeds in background...');
    StartWallHavenFetch(FCurrentSourceImage = '', True);
  end
  else
  begin
    FConfig.LastDailyRecheckUtc := NowUtc;
    FConfig.Save;
    if not ForceStartupCheck then
    begin
      LogMsg('Daily source recheck: rescanning local PC folders in background...');
      StartAsyncScan(FCurrentSourceImage = '');
    end;
  end;
end;

procedure TMainForm.BtnFetchWallHavenClick(Sender: TObject);
begin
  StartWallHavenFetch(True, False);
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

procedure TMainForm.TransitionControlChange(Sender: TObject);
begin
  if FLoadingUI then Exit;
  if ComboTransition.ItemIndex >= 0 then
    FConfig.TransitionStyle := TWallpaperTransition(ComboTransition.ItemIndex);
  FConfig.TransitionDurationMs := EnsureRange(SpinTransitionMs.Value,
    SpinTransitionMs.MinValue, SpinTransitionMs.MaxValue);
end;

procedure TMainForm.BtnSavePrefsClick(Sender: TObject);
var
  AutoMsg: string;
  OldMultiMode: TMultiMonitorMode;
  OldBackend: TLinuxBackendMode;
  OldUseGL: Boolean;
begin
  OldMultiMode := FConfig.MultiMonitorMode;
  OldBackend := FConfig.LinuxBackend;
  OldUseGL := FConfig.UseOpenGLEngine;

  LoadUIToConfig;
  SetAutoStartEnabled(FConfig.AutoStart, AutoMsg);
  FConfig.Save;
  FRemainingSeconds := Min(FRemainingSeconds, Max(1, FConfig.IntervalMinutes) * 60);
  LblDetectedDE.Caption := 'Detected environment: ' + DetectDesktopEnvironment(FConfig.LinuxBackend);

  SyncLiveEngineLifecycle((OldBackend <> FConfig.LinuxBackend) or (OldUseGL <> FConfig.UseOpenGLEngine) or ShouldUseLiveEngine);
  CheckSmartPause;
  if (OldMultiMode <> FConfig.MultiMonitorMode) and (FCurrentSourceImage <> '') then
    PickDistinctMonitorImages(FCurrentSourceImage, FMonitorImages);
  StartAsyncScan(False);
  ApplyCurrentImageWithOverlay;
  ScheduleNextTick;
  if AutoMsg <> '' then LogMsg(AutoMsg);
  LogMsg('Preferences saved to ' + FConfig.GetConfigFilePath);
end;

procedure TMainForm.UpdateWallHavenInfoActions;
var
  WhId: string;
  HasId: Boolean;
begin
  HasId := ExtractWallHavenIdFromPath(FCurrentSourceImage, WhId);
  MnuOpenWallHavenPage.Enabled := HasId;
  BtnOpenWallHavenPage.Enabled := HasId;
  BtnOpenWallHavenPage.Caption := 'WallHaven.cc Info';
  if HasId then
  begin
    MnuOpenWallHavenPage.Caption := Format('Open Info on WallHaven.cc (%s)', [WhId]);
    BtnOpenWallHavenPage.Hint := 'Open https://wallhaven.cc/w/' + WhId;
    BtnOpenWallHavenPage.ShowHint := True;
  end
  else
  begin
    MnuOpenWallHavenPage.Caption := 'Open Info on WallHaven.cc';
    BtnOpenWallHavenPage.Hint := 'Available when active wallpaper is from WallHaven.cc';
    BtnOpenWallHavenPage.ShowHint := False;
  end;
end;

procedure TMainForm.OpenCurrentWallHavenPage;
var
  WhId, Url: string;
begin
  if Trim(FCurrentSourceImage) = '' then
  begin
    LogMsg('No active wallpaper at the moment: cannot determine WallHaven ID.');
    Exit;
  end;

  if not ExtractWallHavenIdFromPath(FCurrentSourceImage, WhId) then
  begin
    LogMsg('Active wallpaper is not from WallHaven.cc: ' + ExtractFileName(FCurrentSourceImage));
    Exit;
  end;

  Url := 'https://wallhaven.cc/w/' + WhId;
  if OpenURL(Url) then
    LogMsg('Opening WallHaven.cc info page: ' + Url)
  else
    LogMsg('Failed to launch browser to open: ' + Url);
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
  TransitionControlChange(nil);
  AdvanceWallpaper(1, True);
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
    LogMsg('Second instance detected (TUniqueInstance): window brought to front.');
    Exit;
  end;

  for I := Low(Args) to High(Args) do
  begin
    Arg := LowerCase(Trim(Args[I]));
    if (Arg = '--next') or (Arg = '-n') then
    begin
      LogMsg('CLI command: ' + Arg);
      AdvanceWallpaper(1, True);
    end
    else if (Arg = '--previous') or (Arg = '--prev') or (Arg = '-p') then
    begin
      LogMsg('CLI command: ' + Arg);
      NavigatePrevious;
    end
    else if Arg = '--pause' then
      SetPausedState(True)
    else if Arg = '--resume' then
      SetPausedState(False)
    else if Arg = '--toggle-pause' then
      SetPausedState(not FPaused)
    else if (Arg = '--favorite') or (Arg = '-f') then
      SaveCurrentFavorite
    else if (Arg = '--blacklist') or (Arg = '-b') then
      BlacklistCurrentWallpaper
    else if (Arg = '--apply') or (Arg = '--refresh') then
    begin
      LogMsg('CLI command: ' + Arg);
      ApplyCurrentImageWithOverlay;
    end
    else if Arg = '--fetch' then
      BtnFetchWallHavenClick(nil)
    else if (Arg = '--info') or (Arg = '--wallhaven-info') or
            (Arg = '--open-wallhaven') or (Arg = '-i') then
    begin
      LogMsg('CLI command: ' + Arg);
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
      LogMsg('Ignored CLI argument: ' + Args[I]);
  end;
end;

procedure TMainForm.UniqueInstance1OtherInstance(Sender: TObject;
  ParamCount: Integer; const Parameters: array of string);
begin
  HandleCommandArgs(Parameters, True);
end;

end.
