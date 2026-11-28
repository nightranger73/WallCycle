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
  WGL_CONTEXT_MAJOR_VERSION_ARB = $2091;
  WGL_CONTEXT_MINOR_VERSION_ARB = $2092;
  WGL_CONTEXT_PROFILE_MASK_ARB  = $9126;
  WGL_CONTEXT_CORE_PROFILE_BIT_ARB = $00000001;

type
  TwglCreateContextAttribsARB = function(hDC: HDC; hShareContext: HGLRC;
    attribList: PInteger): HGLRC; stdcall;
  TwglSwapIntervalEXT = function(interval: Integer): BOOL; stdcall;

var
  GWorkerW: HWND = 0;
  GShellParent: HWND = 0;
  GShellView: HWND = 0;
  GHostWnd: HWND = 0;
  GHDC: HDC = 0;
  GHRC: HGLRC = 0;
  GGLModule: HMODULE = 0;
  GLastError: string = '';
  GPrevLocX: Integer = 0;
  GPrevLocY: Integer = 0;
  GPrevW: Integer = 0;
  GPrevH: Integer = 0;

function GetWinWallpaperLastError: string;
begin
  Result := GLastError;
end;

function EnumWindowsProc(Wnd: HWND; lParam: LPARAM): BOOL; stdcall;
var
  SV, Sibling: HWND;
begin
  SV := FindWindowEx(Wnd, 0, 'SHELLDLL_DefView', nil);
  if SV <> 0 then
  begin
    GShellParent := Wnd;
    GShellView := SV;
    Sibling := FindWindowEx(0, Wnd, 'WorkerW', nil);
    if Sibling <> 0 then
    begin
      GWorkerW := Sibling;
      Exit(False);
    end;
  end;
  Result := True;
end;

function WndProc(Wnd: HWND; Msg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;
begin
  case Msg of
    WM_ERASEBKGND: Exit(1);
    WM_MOUSEACTIVATE: Exit(3); // MA_NOACTIVATE
    WM_NCHITTEST: Exit(-1);    // HTTRANSPARENT
    WM_DESTROY:
      begin
        PostQuitMessage(0);
        Exit(0);
      end;
  end;
  Result := DefWindowProc(Wnd, Msg, wParam, lParam);
end;

function ResolveWinGLProc(const AName: PChar): Pointer;
var
  P: Pointer;
begin
  P := wglGetProcAddress(AName);
  // Per Microsoft WGL spec, invalid proc addresses can be 0, 1, 2, 3, or -1
  if (P = nil) or (PtrUInt(P) <= 3) or (PtrInt(P) = -1) then
  begin
    if GGLModule = 0 then
      GGLModule := GetModuleHandle('opengl32.dll');
    if GGLModule <> 0 then
      P := GetProcAddress(GGLModule, AName)
    else
      P := nil;
  end;
  Result := P;
end;

procedure ResolveRequiredGL33Procs;
begin
  Load_GL_version_3_3();
  if Pointer(glCreateShader) = nil then Pointer(glCreateShader) := ResolveWinGLProc('glCreateShader');
  if Pointer(glShaderSource) = nil then Pointer(glShaderSource) := ResolveWinGLProc('glShaderSource');
  if Pointer(glCompileShader) = nil then Pointer(glCompileShader) := ResolveWinGLProc('glCompileShader');
  if Pointer(glGetShaderiv) = nil then Pointer(glGetShaderiv) := ResolveWinGLProc('glGetShaderiv');
  if Pointer(glDeleteShader) = nil then Pointer(glDeleteShader) := ResolveWinGLProc('glDeleteShader');
  if Pointer(glCreateProgram) = nil then Pointer(glCreateProgram) := ResolveWinGLProc('glCreateProgram');
  if Pointer(glAttachShader) = nil then Pointer(glAttachShader) := ResolveWinGLProc('glAttachShader');
  if Pointer(glLinkProgram) = nil then Pointer(glLinkProgram) := ResolveWinGLProc('glLinkProgram');
  if Pointer(glDeleteProgram) = nil then Pointer(glDeleteProgram) := ResolveWinGLProc('glDeleteProgram');
  if Pointer(glUseProgram) = nil then Pointer(glUseProgram) := ResolveWinGLProc('glUseProgram');
  if Pointer(glGetUniformLocation) = nil then Pointer(glGetUniformLocation) := ResolveWinGLProc('glGetUniformLocation');
  if Pointer(glUniform1i) = nil then Pointer(glUniform1i) := ResolveWinGLProc('glUniform1i');
  if Pointer(glUniform1f) = nil then Pointer(glUniform1f) := ResolveWinGLProc('glUniform1f');
  if Pointer(glUniform2f) = nil then Pointer(glUniform2f) := ResolveWinGLProc('glUniform2f');
  if Pointer(glActiveTexture) = nil then Pointer(glActiveTexture) := ResolveWinGLProc('glActiveTexture');
  if Pointer(glGenVertexArrays) = nil then Pointer(glGenVertexArrays) := ResolveWinGLProc('glGenVertexArrays');
  if Pointer(glBindVertexArray) = nil then Pointer(glBindVertexArray) := ResolveWinGLProc('glBindVertexArray');
  if Pointer(glDeleteVertexArrays) = nil then Pointer(glDeleteVertexArrays) := ResolveWinGLProc('glDeleteVertexArrays');
  if Pointer(glGenBuffers) = nil then Pointer(glGenBuffers) := ResolveWinGLProc('glGenBuffers');
  if Pointer(glBindBuffer) = nil then Pointer(glBindBuffer) := ResolveWinGLProc('glBindBuffer');
  if Pointer(glBufferData) = nil then Pointer(glBufferData) := ResolveWinGLProc('glBufferData');
  if Pointer(glDeleteBuffers) = nil then Pointer(glDeleteBuffers) := ResolveWinGLProc('glDeleteBuffers');
  if Pointer(glEnableVertexAttribArray) = nil then Pointer(glEnableVertexAttribArray) := ResolveWinGLProc('glEnableVertexAttribArray');
  if Pointer(glVertexAttribPointer) = nil then Pointer(glVertexAttribPointer) := ResolveWinGLProc('glVertexAttribPointer');
end;

function ComputeHostBounds(out LocX, LocY, W, H: Integer): Boolean;
var
  VirtX, VirtY: Integer;
  Pt: TPoint;
  ParentTarget: HWND;
begin
  VirtX := GetSystemMetrics(SM_XVIRTUALSCREEN);
  VirtY := GetSystemMetrics(SM_YVIRTUALSCREEN);
  W := GetSystemMetrics(SM_CXVIRTUALSCREEN);
  H := GetSystemMetrics(SM_CYVIRTUALSCREEN);
  if W <= 0 then
  begin
    VirtX := 0;
    VirtY := 0;
    W := GetSystemMetrics(SM_CXSCREEN);
  end;
  if H <= 0 then
    H := GetSystemMetrics(SM_CYSCREEN);
  if W <= 0 then W := 1920;
  if H <= 0 then H := 1080;

  if GHostWnd <> 0 then
    ParentTarget := GetParent(GHostWnd)
  else
    ParentTarget := GWorkerW;

  Pt.X := VirtX;
  Pt.Y := VirtY;
  if ParentTarget <> 0 then
    ScreenToClient(ParentTarget, Pt);
  LocX := Pt.X;
  LocY := Pt.Y;
  Result := (W > 0) and (H > 0);
end;

function InitWindowsWorkerWSurface(out AWidth, AHeight: Integer): Boolean;
var
  Progman, HostParent, ChildWorker, InsertAfterWnd: HWND;
  DummyRes: DWORD_PTR;
  WC: WNDCLASSEX;
  PFD: PIXELFORMATDESCRIPTOR;
  PixFmt, LocX, LocY: Integer;
  TempRC, CoreRC: HGLRC;
  CreateAttribs: TwglCreateContextAttribsARB;
  SwapInt: TwglSwapIntervalEXT;
  Attribs: array[0..6] of Integer;
  AttachBehindShellView: Boolean;
begin
  Result := False;
  GLastError := '';
  GWorkerW := 0;
  GShellParent := 0;
  GShellView := 0;
  GHostWnd := 0;
  GHDC := 0;
  GHRC := 0;
  GPrevLocX := 0;
  GPrevLocY := 0;
  GPrevW := 0;
  GPrevH := 0;

  Progman := FindWindow('Progman', nil);
  if Progman = 0 then
  begin
    GLastError := 'Progman desktop window not found';
    Exit;
  end;

  // Trigger Explorer to spawn desktop WorkerW (Win 10 + Win 11 22H2/23H2/24H2)
  SendMessageTimeout(Progman, WM_SPAWN_WORKER, $000D, $0001, SMTO_NORMAL, 1000, @DummyRes);
  SendMessageTimeout(Progman, WM_SPAWN_WORKER, 0, 0, SMTO_NORMAL, 1000, @DummyRes);
  EnumWindows(@EnumWindowsProc, 0);

  if GWorkerW = 0 then
  begin
    Sleep(50);
    EnumWindows(@EnumWindowsProc, 0);
  end;

  AttachBehindShellView := False;
  InsertAfterWnd := 0;

  if GWorkerW <> 0 then
  begin
    // Classic Windows 10 / 11 <= 23H2 sibling WorkerW behind SHELLDLL_DefView
    HostParent := GWorkerW;
    ShowWindow(HostParent, SW_SHOWNA);
  end
  else
  begin
    // Windows 11 24H2 raised desktop: SHELLDLL_DefView & WorkerW live inside Progman.
    // Place GHostWnd inside Progman immediately behind SHELLDLL_DefView.
    HostParent := Progman;
    GWorkerW := Progman;
    ChildWorker := FindWindowEx(Progman, 0, 'WorkerW', nil);
    if (GShellParent = Progman) and (GShellView <> 0) then
    begin
      AttachBehindShellView := True;
      InsertAfterWnd := GShellView;
    end
    else if ChildWorker <> 0 then
    begin
      HostParent := ChildWorker;
      GWorkerW := ChildWorker;
      ShowWindow(HostParent, SW_SHOWNA);
    end
    else
    begin
      GLastError := 'WorkerW / Progman SHELLDLL_DefView hierarchy not found';
      Exit;
    end;
  end;

  ComputeHostBounds(LocX, LocY, AWidth, AHeight);

  FillChar(WC, SizeOf(WC), 0);
  WC.cbSize := SizeOf(WC);
  WC.style := CS_OWNDC;
  WC.lpfnWndProc := @WndProc;
  WC.hInstance := HInstance;
  WC.hbrBackground := 0;
  WC.lpszClassName := 'WallCycle_GLWorkerSurface';
  RegisterClassEx(WC);

  GHostWnd := CreateWindowEx(
    WS_EX_NOACTIVATE or WS_EX_TOOLWINDOW,
    'WallCycle_GLWorkerSurface',
    'WallCycleGL',
    WS_CHILD or WS_VISIBLE or WS_CLIPSIBLINGS,
    LocX, LocY, AWidth, AHeight,
    HostParent, 0, HInstance, nil
  );
  if GHostWnd = 0 then
  begin
    GLastError := 'CreateWindowEx child of desktop layer failed (Err=' + IntToStr(GetLastError) + ')';
    Exit;
  end;

  ComputeHostBounds(LocX, LocY, AWidth, AHeight);
  GPrevLocX := LocX;
  GPrevLocY := LocY;
  GPrevW := AWidth;
  GPrevH := AHeight;

  if AttachBehindShellView and (InsertAfterWnd <> 0) then
    SetWindowPos(GHostWnd, InsertAfterWnd, LocX, LocY, AWidth, AHeight, SWP_NOACTIVATE or SWP_SHOWWINDOW)
  else
    SetWindowPos(GHostWnd, 0, LocX, LocY, AWidth, AHeight, SWP_NOZORDER or SWP_NOACTIVATE or SWP_SHOWWINDOW);

  GHDC := GetDC(GHostWnd);
  FillChar(PFD, SizeOf(PFD), 0);
  PFD.nSize := SizeOf(PFD);
  PFD.nVersion := 1;
  PFD.dwFlags := PFD_DRAW_TO_WINDOW or PFD_SUPPORT_OPENGL or PFD_DOUBLEBUFFER;
  PFD.iPixelType := PFD_TYPE_RGBA;
  PFD.cColorBits := 32;
  PFD.cAlphaBits := 8;
  PFD.iLayerType := PFD_MAIN_PLANE;

  PixFmt := ChoosePixelFormat(GHDC, @PFD);
  if (PixFmt = 0) or (not SetPixelFormat(GHDC, PixFmt, @PFD)) then
  begin
    GLastError := 'ChoosePixelFormat / SetPixelFormat failed';
    ShutdownWindowsWorkerW;
    Exit;
  end;

  TempRC := wglCreateContext(GHDC);
  if (TempRC = 0) or (not wglMakeCurrent(GHDC, TempRC)) then
  begin
    GLastError := 'wglCreateContext / wglMakeCurrent failed';
    if TempRC <> 0 then wglDeleteContext(TempRC);
    ShutdownWindowsWorkerW;
    Exit;
  end;

  GHRC := TempRC;
  Pointer(CreateAttribs) := wglGetProcAddress('wglCreateContextAttribsARB');
  if Assigned(CreateAttribs) then
  begin
    Attribs[0] := WGL_CONTEXT_MAJOR_VERSION_ARB; Attribs[1] := 3;
    Attribs[2] := WGL_CONTEXT_MINOR_VERSION_ARB; Attribs[3] := 3;
    Attribs[4] := WGL_CONTEXT_PROFILE_MASK_ARB;  Attribs[5] := WGL_CONTEXT_CORE_PROFILE_BIT_ARB;
    Attribs[6] := 0;
    CoreRC := CreateAttribs(GHDC, 0, @Attribs[0]);
    if (CoreRC <> 0) and wglMakeCurrent(GHDC, CoreRC) then
    begin
      wglDeleteContext(TempRC);
      GHRC := CoreRC;
    end
    else if CoreRC <> 0 then
      wglDeleteContext(CoreRC);
  end;

  ResolveRequiredGL33Procs;
  if (Pointer(glCreateShader) = nil) or (Pointer(glCreateProgram) = nil) or
     (Pointer(glGenVertexArrays) = nil) or (Pointer(glGenBuffers) = nil) or
     (Pointer(glActiveTexture) = nil) then
  begin
    GLastError := 'OpenGL 3.3 Core entry points not available in Windows GPU driver';
    ShutdownWindowsWorkerW;
    Exit;
  end;

  Pointer(SwapInt) := wglGetProcAddress('wglSwapIntervalEXT');
  if Assigned(SwapInt) then
    SwapInt(1);

  glViewport(0, 0, AWidth, AHeight);
  Result := True;
end;

function GetWindowsSurfaceSize(out AWidth, AHeight: Integer): Boolean;
var
  LocX, LocY: Integer;
begin
  Result := False;
  if GHostWnd = 0 then Exit;
  if not ComputeHostBounds(LocX, LocY, AWidth, AHeight) then Exit;
  Result := True;
  if (LocX <> GPrevLocX) or (LocY <> GPrevLocY) or (AWidth <> GPrevW) or (AHeight <> GPrevH) then
  begin
    GPrevLocX := LocX;
    GPrevLocY := LocY;
    GPrevW := AWidth;
    GPrevH := AHeight;
    if (GShellParent <> 0) and (GShellView <> 0) and (GetParent(GHostWnd) = GShellParent) then
      SetWindowPos(GHostWnd, GShellView, LocX, LocY, AWidth, AHeight, SWP_NOACTIVATE)
    else
      SetWindowPos(GHostWnd, 0, LocX, LocY, AWidth, AHeight, SWP_NOZORDER or SWP_NOACTIVATE);
  end;
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
  GShellParent := 0;
  GShellView := 0;
end;
{$ENDIF}

end.
