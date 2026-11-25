program WallCycle;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  clocale,
  {$ENDIF}
  Interfaces, // LCL widgetset (GTK2/Qt5 on Linux, Win32 on Windows)
  Forms,
  uConfig,
  uLuminanceFilter,
  uPlaylistScanner,
  uImageOverlay,
  uWallpaperBackend,
  uWallHavenClient,
  uMainForm;

{$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Title := 'WallCycle';
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
