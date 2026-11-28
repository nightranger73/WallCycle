program WallCycle;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  clocale,
  {$ENDIF}
  Interfaces, // LCL widgetset (GTK2/Qt5/Qt6 on Linux, Win32 on Windows)
  Forms,
  uConfig,
  uLuminanceFilter,
  uPlaylistScanner,
  uImageOverlay,
  uWallpaperBackend,
  uWallHavenClient,
  uEmbeddedIcon,
  uShaderEngine,
  {$IFDEF WINDOWS}
  uWinWallpaper,
  {$ENDIF}
  {$IFDEF LINUX}
  uWaylandLayer,
  {$ENDIF}
  uLiveWallpaper,
  uMainForm;

{$R *.res}
{$IFDEF WINDOWS}
{$R WallCycleIcon.res}
{$ENDIF}

begin
  RequireDerivedFormResource := True;
  Application.Scaled:=True;
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
