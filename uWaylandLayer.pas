unit uWaylandLayer;

{$mode objfpc}{$H+}
{$packrecords c}

interface

{$IFDEF LINUX}
uses
  SysUtils, ctypes, dynlibs, GL, GLExt;

{ Initializes a native Wayland EGL surface via zwlr_layer_shell_v1 on the
  BACKGROUND layer (-1 exclusive zone), isolated on its own wl_display socket
  so it stays 100% compatible with GTK2 / Qt5 / Qt6 main-thread LCL UI.
  Returns False cleanly on X11 or compositors without wlr-layer-shell (e.g. GNOME). }
function InitWaylandBackgroundSurface(out AWidth, AHeight: Integer): Boolean;
function GetWaylandSurfaceSize(out AWidth, AHeight: Integer): Boolean;
function GetWaylandLastError: string;
procedure SwapWaylandEGLBuffers;
function PlatformPollEvents: Boolean;
procedure ShutdownWaylandLayer;
{$ENDIF}

implementation

{$IFDEF LINUX}
type
  Pwl_interface = ^Twl_interface;
  PPwl_interface = ^Pwl_interface;
  Pwl_message = ^Twl_message;

  Twl_message = record
    name: PChar;
    signature: PChar;
    types: PPwl_interface;
  end;

  Twl_interface = record
    name: PChar;
    version: cint;
    method_count: cint;
    methods: Pwl_message;
    event_count: cint;
    events: Pwl_message;
  end;

  Pwl_argument = ^Twl_argument;
  Twl_argument = record
    case Integer of
      0: (i: cint32);
      1: (u: cuint32);
      2: (f: cint32);
      3: (s: PChar);
      4: (o: Pointer);
      5: (n: cuint32);
      6: (a: Pointer);
      7: (h: cint32);
  end;

  Pwl_display = Pointer;
  Pwl_proxy = Pointer;
  Pwl_egl_window = Pointer;
  TEGLDisplay = Pointer;
  TEGLSurface = Pointer;
  TEGLContext = Pointer;
  TEGLConfig = Pointer;

  Twl_registry_listener = record
    global: procedure(data: Pointer; registry: Pwl_proxy; name: cuint32;
      iface: PChar; version: cuint32); cdecl;
    global_remove: procedure(data: Pointer; registry: Pwl_proxy; name: cuint32); cdecl;
  end;

  Tzwlr_layer_surface_listener = record
    configure: procedure(data: Pointer; layer_surface: Pwl_proxy;
      serial, width, height: cuint32); cdecl;
    closed: procedure(data: Pointer; layer_surface: Pwl_proxy); cdecl;
  end;

const
  WL_DISPLAY_GET_REGISTRY = 1;
  WL_REGISTRY_BIND = 0;
  WL_COMPOSITOR_CREATE_SURFACE = 0;
  WL_SURFACE_DESTROY = 0;
  WL_SURFACE_COMMIT = 6;

  ZWLR_LAYER_SHELL_GET_LAYER_SURFACE = 0;
  ZWLR_LAYER_SURFACE_SET_SIZE = 0;
  ZWLR_LAYER_SURFACE_SET_ANCHOR = 1;
  ZWLR_LAYER_SURFACE_SET_EXCLUSIVE_ZONE = 2;
  ZWLR_LAYER_SURFACE_SET_KEYBOARD_INTERACTIVITY = 4;
  ZWLR_LAYER_SURFACE_ACK_CONFIGURE = 6;
  ZWLR_LAYER_SURFACE_DESTROY = 7;

  ZWLR_LAYER_SHELL_V1_LAYER_BACKGROUND = 0;
  ZWLR_LAYER_SURFACE_V1_ANCHOR_ALL = $0F;

var
  LibWL: TLibHandle = NilHandle;
  LibWLEGL: TLibHandle = NilHandle;
  LibEGL: TLibHandle = NilHandle;
  GWLDisplay: Pwl_display = nil;
  GWLRegistry: Pwl_proxy = nil;
  GWLCompositor: Pwl_proxy = nil;
  GWLSurface: Pwl_proxy = nil;
  GWLLayerShell: Pwl_proxy = nil;
  GWLLayerSurface: Pwl_proxy = nil;
  GWLEglWin: Pwl_egl_window = nil;
  GEGLDisplay: TEGLDisplay = nil;
  GEGLSurface: TEGLSurface = nil;
  GEGLContext: TEGLContext = nil;

  GConfigured: Boolean = False;
  GClosedRequested: Boolean = False;
  GConfiguredWidth: Integer = 1920;
  GConfiguredHeight: Integer = 1080;
  GLastError: string = '';

  wl_registry_interface: Pwl_interface = nil;
  wl_compositor_interface: Pwl_interface = nil;
  wl_surface_interface: Pwl_interface = nil;
  wl_output_interface: Pwl_interface = nil;

  zwlr_layer_shell_v1_interface: Twl_interface;
  zwlr_layer_surface_v1_interface: Twl_interface;
  LayerShellMethods: array[0..1] of Twl_message;
  LayerSurfaceMethods: array[0..8] of Twl_message;
  LayerSurfaceEvents: array[0..1] of Twl_message;
  GetLayerSurfaceTypes: array[0..4] of Pwl_interface;

  GRegistryListener: Twl_registry_listener;
  GLayerSurfaceListener: Tzwlr_layer_surface_listener;

  wl_display_connect: function(name: PChar): Pwl_display; cdecl;
  wl_display_disconnect: procedure(dpy: Pwl_display); cdecl;
  wl_display_dispatch_pending: function(dpy: Pwl_display): cint; cdecl;
  wl_display_flush: function(dpy: Pwl_display): cint; cdecl;
  wl_display_roundtrip: function(dpy: Pwl_display): cint; cdecl;
  wl_proxy_add_listener: function(proxy: Pwl_proxy; impl: Pointer; data: Pointer): cint; cdecl;
  wl_proxy_destroy: procedure(proxy: Pwl_proxy); cdecl;

  // Non-variadic libwayland-client marshaling (ABI safe on x86_64/aarch64)
  wl_proxy_marshal_array: procedure(proxy: Pwl_proxy; opcode: cuint32;
    args: Pwl_argument); cdecl;
  wl_proxy_marshal_array_constructor: function(proxy: Pwl_proxy; opcode: cuint32;
    args: Pwl_argument; iface: Pwl_interface): Pwl_proxy; cdecl;
  wl_proxy_marshal_array_constructor_versioned: function(proxy: Pwl_proxy;
    opcode: cuint32; args: Pwl_argument; iface: Pwl_interface;
    version: cuint32): Pwl_proxy; cdecl;

  wl_egl_window_create: function(surface: Pwl_proxy; w, h: cint): Pwl_egl_window; cdecl;
  wl_egl_window_destroy: procedure(win: Pwl_egl_window); cdecl;
  wl_egl_window_resize: procedure(win: Pwl_egl_window; w, h, dx, dy: cint); cdecl;

  eglGetDisplay: function(native_dpy: Pointer): TEGLDisplay; cdecl;
  eglInitialize: function(dpy: TEGLDisplay; major, minor: PInteger): cint; cdecl;
  eglBindAPI: function(api: LongWord): cint; cdecl;
  eglChooseConfig: function(dpy: TEGLDisplay; attrib: PInteger; cfg: PPointer;
    sz: cint; num: PInteger): cint; cdecl;
  eglCreateContext: function(dpy: TEGLDisplay; cfg: TEGLConfig; share: TEGLContext;
    attrib: PInteger): TEGLContext; cdecl;
  eglCreateWindowSurface: function(dpy: TEGLDisplay; cfg: TEGLConfig; win: Pointer;
    attrib: PInteger): TEGLSurface; cdecl;
  eglMakeCurrent: function(dpy: TEGLDisplay; draw, read: TEGLSurface;
    ctx: TEGLContext): cint; cdecl;
  eglDestroySurface: function(dpy: TEGLDisplay; surf: TEGLSurface): cint; cdecl;
  eglDestroyContext: function(dpy: TEGLDisplay; ctx: TEGLContext): cint; cdecl;
  eglTerminate: function(dpy: TEGLDisplay): cint; cdecl;
  eglSwapInterval: function(dpy: TEGLDisplay; interval: cint): cint; cdecl;
  eglSwapBuffers: function(dpy: TEGLDisplay; surf: TEGLSurface): cint; cdecl;
  eglGetProcAddress: function(procname: PChar): Pointer; cdecl;

function GetWaylandLastError: string;
begin
  Result := GLastError;
end;

procedure InitLayerShellInterfaces;
begin
  GetLayerSurfaceTypes[0] := @zwlr_layer_surface_v1_interface;
  GetLayerSurfaceTypes[1] := wl_surface_interface;
  GetLayerSurfaceTypes[2] := wl_output_interface;
  GetLayerSurfaceTypes[3] := nil;
  GetLayerSurfaceTypes[4] := nil;

  LayerShellMethods[0].name := 'get_layer_surface';
  LayerShellMethods[0].signature := 'no?ous';
  LayerShellMethods[0].types := @GetLayerSurfaceTypes[0];
  LayerShellMethods[1].name := 'destroy';
  LayerShellMethods[1].signature := '';
  LayerShellMethods[1].types := nil;

  zwlr_layer_shell_v1_interface.name := 'zwlr_layer_shell_v1';
  zwlr_layer_shell_v1_interface.version := 4;
  zwlr_layer_shell_v1_interface.method_count := 2;
  zwlr_layer_shell_v1_interface.methods := @LayerShellMethods[0];
  zwlr_layer_shell_v1_interface.event_count := 0;
  zwlr_layer_shell_v1_interface.events := nil;

  LayerSurfaceMethods[0].name := 'set_size';
  LayerSurfaceMethods[0].signature := 'uu';
  LayerSurfaceMethods[0].types := nil;
  LayerSurfaceMethods[1].name := 'set_anchor';
  LayerSurfaceMethods[1].signature := 'u';
  LayerSurfaceMethods[1].types := nil;
  LayerSurfaceMethods[2].name := 'set_exclusive_zone';
  LayerSurfaceMethods[2].signature := 'i';
  LayerSurfaceMethods[2].types := nil;
  LayerSurfaceMethods[3].name := 'set_margin';
  LayerSurfaceMethods[3].signature := 'iiii';
  LayerSurfaceMethods[3].types := nil;
  LayerSurfaceMethods[4].name := 'set_keyboard_interactivity';
  LayerSurfaceMethods[4].signature := 'u';
  LayerSurfaceMethods[4].types := nil;
  LayerSurfaceMethods[5].name := 'get_popup';
  LayerSurfaceMethods[5].signature := 'o';
  LayerSurfaceMethods[5].types := nil;
  LayerSurfaceMethods[6].name := 'ack_configure';
  LayerSurfaceMethods[6].signature := 'u';
  LayerSurfaceMethods[6].types := nil;
  LayerSurfaceMethods[7].name := 'destroy';
  LayerSurfaceMethods[7].signature := '';
  LayerSurfaceMethods[7].types := nil;
  LayerSurfaceMethods[8].name := 'set_layer';
  LayerSurfaceMethods[8].signature := '2u';
  LayerSurfaceMethods[8].types := nil;

  LayerSurfaceEvents[0].name := 'configure';
  LayerSurfaceEvents[0].signature := 'uuu';
  LayerSurfaceEvents[0].types := nil;
  LayerSurfaceEvents[1].name := 'closed';
  LayerSurfaceEvents[1].signature := '';
  LayerSurfaceEvents[1].types := nil;

  zwlr_layer_surface_v1_interface.name := 'zwlr_layer_surface_v1';
  zwlr_layer_surface_v1_interface.version := 4;
  zwlr_layer_surface_v1_interface.method_count := 9;
  zwlr_layer_surface_v1_interface.methods := @LayerSurfaceMethods[0];
  zwlr_layer_surface_v1_interface.event_count := 2;
  zwlr_layer_surface_v1_interface.events := @LayerSurfaceEvents[0];
end;

function RegistryBind(ARegistry: Pwl_proxy; AName: cuint32;
  AIface: Pwl_interface; AVersion: cuint32): Pwl_proxy;
var
  Args: array[0..3] of Twl_argument;
begin
  FillChar(Args, SizeOf(Args), 0);
  Args[0].u := AName;
  Args[1].s := AIface^.name;
  Args[2].u := AVersion;
  Args[3].n := 0;
  Result := wl_proxy_marshal_array_constructor_versioned(
    ARegistry, WL_REGISTRY_BIND, @Args[0], AIface, AVersion
  );
end;

procedure OnRegistryGlobal(data: Pointer; registry: Pwl_proxy; name: cuint32;
  iface: PChar; version: cuint32); cdecl;
var
  Ver: cuint32;
begin
  if iface = nil then Exit;
  if StrComp(iface, 'wl_compositor') = 0 then
  begin
    if version > 4 then Ver := 4 else Ver := version;
    GWLCompositor := RegistryBind(registry, name, wl_compositor_interface, Ver);
  end
  else if StrComp(iface, 'zwlr_layer_shell_v1') = 0 then
  begin
    if version > 4 then Ver := 4 else Ver := version;
    GWLLayerShell := RegistryBind(registry, name, @zwlr_layer_shell_v1_interface, Ver);
  end;
end;

procedure OnRegistryGlobalRemove(data: Pointer; registry: Pwl_proxy; name: cuint32); cdecl;
begin
end;

procedure OnLayerSurfaceConfigure(data: Pointer; layer_surface: Pwl_proxy;
  serial, width, height: cuint32); cdecl;
var
  Args: array[0..0] of Twl_argument;
begin
  FillChar(Args, SizeOf(Args), 0);
  Args[0].u := serial;
  wl_proxy_marshal_array(layer_surface, ZWLR_LAYER_SURFACE_ACK_CONFIGURE, @Args[0]);

  if width > 0 then GConfiguredWidth := Integer(width);
  if height > 0 then GConfiguredHeight := Integer(height);
  GConfigured := True;
  if GWLEglWin <> nil then
    wl_egl_window_resize(GWLEglWin, GConfiguredWidth, GConfiguredHeight, 0, 0);
end;

procedure OnLayerSurfaceClosed(data: Pointer; layer_surface: Pwl_proxy); cdecl;
begin
  GClosedRequested := True;
end;

function InitWaylandBackgroundSurface(out AWidth, AHeight: Integer): Boolean;
const
  EGL_OPENGL_API = $30A2;
  CfgAttribs: array[0..10] of Integer = (
    $3033, $0004, // EGL_SURFACE_TYPE = EGL_WINDOW_BIT
    $3040, $0008, // EGL_RENDERABLE_TYPE = EGL_OPENGL_BIT
    $3024, 8,     // EGL_RED_SIZE
    $3023, 8,     // EGL_GREEN_SIZE
    $3022, 8,     // EGL_BLUE_SIZE
    $3038         // EGL_NONE
  );
  CtxAttribs: array[0..4] of Integer = (
    $3098, 3,     // EGL_CONTEXT_MAJOR_VERSION = 3
    $30FB, 3,     // EGL_CONTEXT_MINOR_VERSION = 3
    $3038         // EGL_NONE
  );
var
  Cfg: TEGLConfig;
  NumCfg: Integer;
  Args: array[0..4] of Twl_argument;

  function LoadSym(ALib: TLibHandle; const AName: PChar): Pointer;
  begin
    Result := GetProcedureAddress(ALib, AName);
  end;

begin
  Result := False;
  GLastError := '';
  GConfigured := False;
  GClosedRequested := False;
  GConfiguredWidth := 1920;
  GConfiguredHeight := 1080;

  if Trim(GetEnvironmentVariable('WAYLAND_DISPLAY')) = '' then
  begin
    GLastError := 'Not a Wayland session (WAYLAND_DISPLAY is empty)';
    Exit;
  end;

  LibWL := LoadLibrary('libwayland-client.so.0');
  LibWLEGL := LoadLibrary('libwayland-egl.so.1');
  LibEGL := LoadLibrary('libEGL.so.1');
  if (LibWL = NilHandle) or (LibWLEGL = NilHandle) or (LibEGL = NilHandle) then
  begin
    GLastError := 'Missing libwayland-client.so.0 / libwayland-egl.so.1 / libEGL.so.1';
    Exit;
  end;

  Pointer(wl_display_connect) := LoadSym(LibWL, 'wl_display_connect');
  Pointer(wl_display_disconnect) := LoadSym(LibWL, 'wl_display_disconnect');
  Pointer(wl_display_dispatch_pending) := LoadSym(LibWL, 'wl_display_dispatch_pending');
  Pointer(wl_display_flush) := LoadSym(LibWL, 'wl_display_flush');
  Pointer(wl_display_roundtrip) := LoadSym(LibWL, 'wl_display_roundtrip');
  Pointer(wl_proxy_add_listener) := LoadSym(LibWL, 'wl_proxy_add_listener');
  Pointer(wl_proxy_destroy) := LoadSym(LibWL, 'wl_proxy_destroy');

  Pointer(wl_proxy_marshal_array) := LoadSym(LibWL, 'wl_proxy_marshal_array');
  Pointer(wl_proxy_marshal_array_constructor) := LoadSym(LibWL, 'wl_proxy_marshal_array_constructor');
  Pointer(wl_proxy_marshal_array_constructor_versioned) := LoadSym(LibWL, 'wl_proxy_marshal_array_constructor_versioned');

  wl_registry_interface := Pwl_interface(LoadSym(LibWL, 'wl_registry_interface'));
  wl_compositor_interface := Pwl_interface(LoadSym(LibWL, 'wl_compositor_interface'));
  wl_surface_interface := Pwl_interface(LoadSym(LibWL, 'wl_surface_interface'));
  wl_output_interface := Pwl_interface(LoadSym(LibWL, 'wl_output_interface'));

  Pointer(wl_egl_window_create) := LoadSym(LibWLEGL, 'wl_egl_window_create');
  Pointer(wl_egl_window_destroy) := LoadSym(LibWLEGL, 'wl_egl_window_destroy');
  Pointer(wl_egl_window_resize) := LoadSym(LibWLEGL, 'wl_egl_window_resize');

  Pointer(eglGetDisplay) := LoadSym(LibEGL, 'eglGetDisplay');
  Pointer(eglInitialize) := LoadSym(LibEGL, 'eglInitialize');
  Pointer(eglBindAPI) := LoadSym(LibEGL, 'eglBindAPI');
  Pointer(eglChooseConfig) := LoadSym(LibEGL, 'eglChooseConfig');
  Pointer(eglCreateContext) := LoadSym(LibEGL, 'eglCreateContext');
  Pointer(eglCreateWindowSurface) := LoadSym(LibEGL, 'eglCreateWindowSurface');
  Pointer(eglMakeCurrent) := LoadSym(LibEGL, 'eglMakeCurrent');
  Pointer(eglDestroySurface) := LoadSym(LibEGL, 'eglDestroySurface');
  Pointer(eglDestroyContext) := LoadSym(LibEGL, 'eglDestroyContext');
  Pointer(eglTerminate) := LoadSym(LibEGL, 'eglTerminate');
  Pointer(eglSwapInterval) := LoadSym(LibEGL, 'eglSwapInterval');
  Pointer(eglSwapBuffers) := LoadSym(LibEGL, 'eglSwapBuffers');
  Pointer(eglGetProcAddress) := LoadSym(LibEGL, 'eglGetProcAddress');

  if (not Assigned(wl_display_connect)) or (not Assigned(wl_display_disconnect)) or
     (not Assigned(wl_proxy_add_listener)) or (not Assigned(wl_proxy_destroy)) or
     (not Assigned(wl_proxy_marshal_array)) or (not Assigned(wl_proxy_marshal_array_constructor)) or
     (not Assigned(wl_proxy_marshal_array_constructor_versioned)) or
     (wl_registry_interface = nil) or (wl_compositor_interface = nil) or
     (wl_surface_interface = nil) or (wl_output_interface = nil) or
     (not Assigned(wl_egl_window_create)) or (not Assigned(eglGetDisplay)) or
     (not Assigned(eglGetProcAddress)) then
  begin
    GLastError := 'Incomplete Wayland / EGL symbol resolution';
    Exit;
  end;

  InitLayerShellInterfaces;

  GWLDisplay := wl_display_connect(nil);
  if GWLDisplay = nil then
  begin
    GLastError := 'Failed to connect to Wayland display socket';
    Exit;
  end;

  FillChar(Args, SizeOf(Args), 0);
  Args[0].n := 0;
  GWLRegistry := wl_proxy_marshal_array_constructor(
    GWLDisplay, WL_DISPLAY_GET_REGISTRY, @Args[0], wl_registry_interface
  );
  if GWLRegistry = nil then
  begin
    GLastError := 'Failed to obtain wl_registry';
    ShutdownWaylandLayer;
    Exit;
  end;

  GRegistryListener.global := @OnRegistryGlobal;
  GRegistryListener.global_remove := @OnRegistryGlobalRemove;
  wl_proxy_add_listener(GWLRegistry, @GRegistryListener, nil);
  wl_display_roundtrip(GWLDisplay);

  if (GWLCompositor = nil) or (GWLLayerShell = nil) then
  begin
    GLastError := 'Compositor does not expose zwlr_layer_shell_v1';
    ShutdownWaylandLayer;
    Exit;
  end;

  FillChar(Args, SizeOf(Args), 0);
  Args[0].n := 0;
  GWLSurface := wl_proxy_marshal_array_constructor(
    GWLCompositor, WL_COMPOSITOR_CREATE_SURFACE, @Args[0], wl_surface_interface
  );
  if GWLSurface = nil then
  begin
    GLastError := 'Failed to create wl_surface';
    ShutdownWaylandLayer;
    Exit;
  end;

  FillChar(Args, SizeOf(Args), 0);
  Args[0].n := 0;
  Args[1].o := GWLSurface;
  Args[2].o := nil;
  Args[3].u := ZWLR_LAYER_SHELL_V1_LAYER_BACKGROUND;
  Args[4].s := PChar('wallcycle');
  GWLLayerSurface := wl_proxy_marshal_array_constructor(
    GWLLayerShell, ZWLR_LAYER_SHELL_GET_LAYER_SURFACE, @Args[0], @zwlr_layer_surface_v1_interface
  );
  if GWLLayerSurface = nil then
  begin
    GLastError := 'Failed to create zwlr_layer_surface_v1';
    ShutdownWaylandLayer;
    Exit;
  end;

  GLayerSurfaceListener.configure := @OnLayerSurfaceConfigure;
  GLayerSurfaceListener.closed := @OnLayerSurfaceClosed;
  wl_proxy_add_listener(GWLLayerSurface, @GLayerSurfaceListener, nil);

  FillChar(Args, SizeOf(Args), 0);
  Args[0].u := 0;
  Args[1].u := 0;
  wl_proxy_marshal_array(GWLLayerSurface, ZWLR_LAYER_SURFACE_SET_SIZE, @Args[0]);

  FillChar(Args, SizeOf(Args), 0);
  Args[0].u := ZWLR_LAYER_SURFACE_V1_ANCHOR_ALL;
  wl_proxy_marshal_array(GWLLayerSurface, ZWLR_LAYER_SURFACE_SET_ANCHOR, @Args[0]);

  FillChar(Args, SizeOf(Args), 0);
  Args[0].i := -1;
  wl_proxy_marshal_array(GWLLayerSurface, ZWLR_LAYER_SURFACE_SET_EXCLUSIVE_ZONE, @Args[0]);

  FillChar(Args, SizeOf(Args), 0);
  Args[0].u := 0;
  wl_proxy_marshal_array(GWLLayerSurface, ZWLR_LAYER_SURFACE_SET_KEYBOARD_INTERACTIVITY, @Args[0]);

  wl_proxy_marshal_array(GWLSurface, WL_SURFACE_COMMIT, nil);
  wl_display_roundtrip(GWLDisplay);

  GEGLDisplay := eglGetDisplay(GWLDisplay);
  if (GEGLDisplay = nil) or (eglInitialize(GEGLDisplay, nil, nil) = 0) then
  begin
    GLastError := 'eglInitialize failed on Wayland display';
    ShutdownWaylandLayer;
    Exit;
  end;

  if eglBindAPI(EGL_OPENGL_API) = 0 then
  begin
    GLastError := 'eglBindAPI(EGL_OPENGL_API) failed';
    ShutdownWaylandLayer;
    Exit;
  end;

  NumCfg := 0;
  Cfg := nil;
  if (eglChooseConfig(GEGLDisplay, @CfgAttribs[0], @Cfg, 1, @NumCfg) = 0) or (NumCfg = 0) then
  begin
    GLastError := 'No compatible OpenGL EGL config found';
    ShutdownWaylandLayer;
    Exit;
  end;

  AWidth := GConfiguredWidth;
  AHeight := GConfiguredHeight;
  GWLEglWin := wl_egl_window_create(GWLSurface, AWidth, AHeight);
  if GWLEglWin = nil then
  begin
    GLastError := 'wl_egl_window_create returned nil';
    ShutdownWaylandLayer;
    Exit;
  end;

  GEGLSurface := eglCreateWindowSurface(GEGLDisplay, Cfg, GWLEglWin, nil);
  if GEGLSurface = nil then
  begin
    GLastError := 'eglCreateWindowSurface returned nil';
    ShutdownWaylandLayer;
    Exit;
  end;

  GEGLContext := eglCreateContext(GEGLDisplay, Cfg, nil, @CtxAttribs[0]);
  if GEGLContext = nil then
  begin
    GLastError := 'eglCreateContext (GL 3.3) returned nil';
    ShutdownWaylandLayer;
    Exit;
  end;

  if eglMakeCurrent(GEGLDisplay, GEGLSurface, GEGLSurface, GEGLContext) = 0 then
  begin
    GLastError := 'eglMakeCurrent failed';
    ShutdownWaylandLayer;
    Exit;
  end;

  if Assigned(eglSwapInterval) then
    eglSwapInterval(GEGLDisplay, 1);

  Load_GL_version_3_3();
  // On Wayland EGL, Load_GL_version_3_3 (glX-based) leaves pointers nil:
  // resolve all required OpenGL 3.3 Core entry points via eglGetProcAddress.
  if Pointer(glCreateShader) = nil then Pointer(glCreateShader) := eglGetProcAddress('glCreateShader');
  if Pointer(glShaderSource) = nil then Pointer(glShaderSource) := eglGetProcAddress('glShaderSource');
  if Pointer(glCompileShader) = nil then Pointer(glCompileShader) := eglGetProcAddress('glCompileShader');
  if Pointer(glGetShaderiv) = nil then Pointer(glGetShaderiv) := eglGetProcAddress('glGetShaderiv');
  if Pointer(glDeleteShader) = nil then Pointer(glDeleteShader) := eglGetProcAddress('glDeleteShader');
  if Pointer(glCreateProgram) = nil then Pointer(glCreateProgram) := eglGetProcAddress('glCreateProgram');
  if Pointer(glAttachShader) = nil then Pointer(glAttachShader) := eglGetProcAddress('glAttachShader');
  if Pointer(glLinkProgram) = nil then Pointer(glLinkProgram) := eglGetProcAddress('glLinkProgram');
  if Pointer(glDeleteProgram) = nil then Pointer(glDeleteProgram) := eglGetProcAddress('glDeleteProgram');
  if Pointer(glUseProgram) = nil then Pointer(glUseProgram) := eglGetProcAddress('glUseProgram');
  if Pointer(glGetUniformLocation) = nil then Pointer(glGetUniformLocation) := eglGetProcAddress('glGetUniformLocation');
  if Pointer(glUniform1i) = nil then Pointer(glUniform1i) := eglGetProcAddress('glUniform1i');
  if Pointer(glUniform1f) = nil then Pointer(glUniform1f) := eglGetProcAddress('glUniform1f');
  if Pointer(glUniform2f) = nil then Pointer(glUniform2f) := eglGetProcAddress('glUniform2f');
  if Pointer(glActiveTexture) = nil then Pointer(glActiveTexture) := eglGetProcAddress('glActiveTexture');
  if Pointer(glGenVertexArrays) = nil then Pointer(glGenVertexArrays) := eglGetProcAddress('glGenVertexArrays');
  if Pointer(glBindVertexArray) = nil then Pointer(glBindVertexArray) := eglGetProcAddress('glBindVertexArray');
  if Pointer(glDeleteVertexArrays) = nil then Pointer(glDeleteVertexArrays) := eglGetProcAddress('glDeleteVertexArrays');
  if Pointer(glGenBuffers) = nil then Pointer(glGenBuffers) := eglGetProcAddress('glGenBuffers');
  if Pointer(glBindBuffer) = nil then Pointer(glBindBuffer) := eglGetProcAddress('glBindBuffer');
  if Pointer(glBufferData) = nil then Pointer(glBufferData) := eglGetProcAddress('glBufferData');
  if Pointer(glDeleteBuffers) = nil then Pointer(glDeleteBuffers) := eglGetProcAddress('glDeleteBuffers');
  if Pointer(glEnableVertexAttribArray) = nil then Pointer(glEnableVertexAttribArray) := eglGetProcAddress('glEnableVertexAttribArray');
  if Pointer(glVertexAttribPointer) = nil then Pointer(glVertexAttribPointer) := eglGetProcAddress('glVertexAttribPointer');

  if (Pointer(glCreateShader) = nil) or (Pointer(glCreateProgram) = nil) or
     (Pointer(glGenVertexArrays) = nil) or (Pointer(glGenBuffers) = nil) or
     (Pointer(glActiveTexture) = nil) then
  begin
    GLastError := 'Failed to resolve OpenGL 3.3 Core entry points via eglGetProcAddress';
    ShutdownWaylandLayer;
    Exit;
  end;

  glViewport(0, 0, AWidth, AHeight);
  Result := True;
end;

function GetWaylandSurfaceSize(out AWidth, AHeight: Integer): Boolean;
begin
  AWidth := GConfiguredWidth;
  AHeight := GConfiguredHeight;
  Result := (GWLEglWin <> nil) and (AWidth > 0) and (AHeight > 0);
end;

procedure SwapWaylandEGLBuffers;
begin
  if (GEGLDisplay <> nil) and (GEGLSurface <> nil) then
    eglSwapBuffers(GEGLDisplay, GEGLSurface);
  if (GWLDisplay <> nil) and Assigned(wl_display_flush) then
    wl_display_flush(GWLDisplay);
end;

function PlatformPollEvents: Boolean;
begin
  if (GWLDisplay = nil) or (not Assigned(wl_display_dispatch_pending)) then
    Exit(False);
  Result := (not GClosedRequested) and (wl_display_dispatch_pending(GWLDisplay) >= 0);
end;

procedure ShutdownWaylandLayer;
begin
  if (GEGLDisplay <> nil) and Assigned(eglMakeCurrent) then
    eglMakeCurrent(GEGLDisplay, nil, nil, nil);
  if (GEGLDisplay <> nil) and (GEGLContext <> nil) and Assigned(eglDestroyContext) then
    eglDestroyContext(GEGLDisplay, GEGLContext);
  if (GEGLDisplay <> nil) and (GEGLSurface <> nil) and Assigned(eglDestroySurface) then
    eglDestroySurface(GEGLDisplay, GEGLSurface);
  if (GEGLDisplay <> nil) and Assigned(eglTerminate) then
    eglTerminate(GEGLDisplay);
  GEGLContext := nil;
  GEGLSurface := nil;
  GEGLDisplay := nil;

  if (GWLEglWin <> nil) and Assigned(wl_egl_window_destroy) then
  begin
    wl_egl_window_destroy(GWLEglWin);
    GWLEglWin := nil;
  end;
  if (GWLLayerSurface <> nil) and Assigned(wl_proxy_marshal_array) and Assigned(wl_proxy_destroy) then
  begin
    wl_proxy_marshal_array(GWLLayerSurface, ZWLR_LAYER_SURFACE_DESTROY, nil);
    wl_proxy_destroy(GWLLayerSurface);
    GWLLayerSurface := nil;
  end;
  if (GWLSurface <> nil) and Assigned(wl_proxy_marshal_array) and Assigned(wl_proxy_destroy) then
  begin
    wl_proxy_marshal_array(GWLSurface, WL_SURFACE_DESTROY, nil);
    wl_proxy_destroy(GWLSurface);
    GWLSurface := nil;
  end;
  if (GWLRegistry <> nil) and Assigned(wl_proxy_destroy) then
  begin
    wl_proxy_destroy(GWLRegistry);
    GWLRegistry := nil;
  end;
  if (GWLCompositor <> nil) and Assigned(wl_proxy_destroy) then
  begin
    wl_proxy_destroy(GWLCompositor);
    GWLCompositor := nil;
  end;
  if (GWLLayerShell <> nil) and Assigned(wl_proxy_destroy) then
  begin
    wl_proxy_destroy(GWLLayerShell);
    GWLLayerShell := nil;
  end;
  if (GWLDisplay <> nil) and Assigned(wl_display_disconnect) then
  begin
    wl_display_disconnect(GWLDisplay);
    GWLDisplay := nil;
  end;
end;
{$ENDIF}

end.
