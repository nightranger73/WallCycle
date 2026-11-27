unit uWinWallpaper;

{$mode objfpc}{$H+}

interface

{$IFDEF WINDOWS}
uses
  Windows, SysUtils, GL, GLExt;

function InitWindowsWorkerWSurface(out AWidth, AHeight: Integer): Boolean;
function GetWindowsSurfaceSize(out AWidth, AHeight: Integer): Boolean;
function GetWinWallpaperLastError: string;
procedure SwapWindowsGLBuffers;
function PlatformPollEvents: Boolean;
procedure ShutdownWindowsWorkerW;
{$ENDIF}

implementation

{$IFDEF WINDOWS}
const
  WM_SPAWN_WORKER = $052C;

var
  GWorkerW: HWND = 0;
  GHostWnd: HWND = 0;
  GHDC: HDC = 0;
  GHRC: HGLRC = 0;
  GLastError: string = '';

function GetWinWallpaperLastError: string;
begin
  Result := GLastError;
end;

function EnumWindowsProc(Wnd: HWND; lParam: LPARAM): BOOL; stdcall;
var
  ShellView: HWND;
begin
  ShellView := FindWindowEx(Wnd, 0, 'SHELLDLL_DefView', nil);
  if ShellView <> 0 then
    GWorkerW := FindWindowEx(0, Wnd, 'WorkerW', nil);
  Result := True;
end;

function WndProc(Wnd: HWND; Msg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;
begin
  if Msg = WM_DESTROY then
  begin
    PostQuitMessage(0);
    Exit(0);
  end;
  Result := DefWindowProc(Wnd, Msg, wParam, lParam);
end;

function InitWindowsWorkerWSurface(out AWidth, AHeight: Integer): Boolean;
var
  Progman: HWND;
  DummyRes: DWORD_PTR;
  WC: WNDCLASSEX;
  PFD: PIXELFORMATDESCRIPTOR;
  PixFmt: Integer;
begin
  Result := False;
  GLastError := '';
  GWorkerW := 0;
  GHostWnd := 0;
  GHDC := 0;
  GHRC := 0;

  Progman := FindWindow('Progman', nil);
  if Progman = 0 then
  begin
    GLastError := 'Progman desktop window not found';
    Exit;
  end;

  // Ask Windows Explorer to spawn WorkerW behind desktop icons
  SendMessageTimeout(Progman, WM_SPAWN_WORKER, 0, 0, SMTO_NORMAL, 1000, @DummyRes);
  EnumWindows(@EnumWindowsProc, 0);
  if GWorkerW = 0 then
  begin
    GLastError := 'WorkerW window handle not created';
    Exit;
  end;

  AWidth := GetSystemMetrics(SM_CXVIRTUALSCREEN);
  AHeight := GetSystemMetrics(SM_CYVIRTUALSCREEN);
  if AWidth <= 0 then AWidth := GetSystemMetrics(SM_CXSCREEN);
  if AHeight <= 0 then AHeight := GetSystemMetrics(SM_CYSCREEN);
  if AWidth <= 0 then AWidth := 1920;
  if AHeight <= 0 then AHeight := 1080;

  FillChar(WC, SizeOf(WC), 0);
  WC.cbSize := SizeOf(WC);
  WC.style := CS_OWNDC;
  WC.lpfnWndProc := @WndProc;
  WC.hInstance := HInstance;
  WC.lpszClassName := 'WallCycle_GLWorkerSurface';
  RegisterClassEx(WC);

  GHostWnd := CreateWindowEx(
    WS_EX_NOACTIVATE or WS_EX_TOOLWINDOW,
    'WallCycle_GLWorkerSurface',
    'WallCycleGL',
    WS_CHILD or WS_VISIBLE,
    0, 0, AWidth, AHeight,
    GWorkerW, 0, HInstance, nil
  );
  if GHostWnd = 0 then
  begin
    GLastError := 'CreateWindowEx child of WorkerW failed';
    Exit;
  end;

  SetWindowPos(GHostWnd, 0, 0, 0, AWidth, AHeight, SWP_NOZORDER or SWP_NOACTIVATE);

  GHDC := GetDC(GHostWnd);
  FillChar(PFD, SizeOf(PFD), 0);
  PFD.nSize := SizeOf(PFD);
  PFD.nVersion := 1;
  PFD.dwFlags := PFD_DRAW_TO_WINDOW or PFD_SUPPORT_OPENGL or PFD_DOUBLEBUFFER;
  PFD.iPixelType := PFD_TYPE_RGBA;
  PFD.cColorBits := 32;
  PFD.iLayerType := PFD_MAIN_PLANE;

  PixFmt := ChoosePixelFormat(GHDC, @PFD);
  if (PixFmt = 0) or (not SetPixelFormat(GHDC, PixFmt, @PFD)) then
  begin
    GLastError := 'ChoosePixelFormat / SetPixelFormat failed';
    ShutdownWindowsWorkerW;
    Exit;
  end;

  GHRC := wglCreateContext(GHDC);
  if (GHRC = 0) or (not wglMakeCurrent(GHDC, GHRC)) then
  begin
    GLastError := 'wglCreateContext / wglMakeCurrent failed';
    ShutdownWindowsWorkerW;
    Exit;
  end;

  Load_GL_version_3_3();
  if (Pointer(glCreateShader) = nil) or (Pointer(glCreateProgram) = nil) or
     (Pointer(glGenVertexArrays) = nil) or (Pointer(glGenBuffers) = nil) or
     (Pointer(glActiveTexture) = nil) then
  begin
    GLastError := 'OpenGL 3.3 Core entry points not available in driver';
    ShutdownWindowsWorkerW;
    Exit;
  end;

  glViewport(0, 0, AWidth, AHeight);
  Result := True;
end;

function GetWindowsSurfaceSize(out AWidth, AHeight: Integer): Boolean;
begin
  AWidth := GetSystemMetrics(SM_CXVIRTUALSCREEN);
  AHeight := GetSystemMetrics(SM_CYVIRTUALSCREEN);
  if AWidth <= 0 then AWidth := GetSystemMetrics(SM_CXSCREEN);
  if AHeight <= 0 then AHeight := GetSystemMetrics(SM_CYSCREEN);
  Result := (GHostWnd <> 0) and (AWidth > 0) and (AHeight > 0);
  if Result then
    SetWindowPos(GHostWnd, 0, 0, 0, AWidth, AHeight, SWP_NOZORDER or SWP_NOACTIVATE);
end;

procedure SwapWindowsGLBuffers;
begin
  if GHDC <> 0 then
    SwapBuffers(GHDC);
end;

function PlatformPollEvents: Boolean;
var
  Msg: TMsg;
begin
  Result := True;
  while PeekMessage(Msg, 0, 0, 0, PM_REMOVE) do
  begin
    if Msg.message = WM_QUIT then Exit(False);
    TranslateMessage(Msg);
    DispatchMessage(Msg);
  end;
end;

procedure ShutdownWindowsWorkerW;
begin
  wglMakeCurrent(0, 0);
  if GHRC <> 0 then
  begin
    wglDeleteContext(GHRC);
    GHRC := 0;
  end;
  if (GHDC <> 0) and (GHostWnd <> 0) then
  begin
    ReleaseDC(GHostWnd, GHDC);
    GHDC := 0;
  end;
  if GHostWnd <> 0 then
  begin
    DestroyWindow(GHostWnd);
    GHostWnd := 0;
  end;
  GWorkerW := 0;
end;
{$ENDIF}

end.
