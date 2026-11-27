#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif

[Setup]
AppId={{8D6E4B72-7D3A-4E9B-9E3C-4A21B88E1C51}
AppName=WallCycle
AppVersion={#AppVersion}
AppPublisher=WallCycle
DefaultDirName={autopf}\WallCycle
DefaultGroupName=WallCycle
AllowNoIcons=yes
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
OutputDir=dist-installer
OutputBaseFilename=WallCycle-Setup-{#AppVersion}-x64
WizardStyle=modern
SetupIconFile=WallCycle.ico
UninstallDisplayIcon={app}\WallCycle.exe

[Languages]
Name: "italian"; MessagesFile: "compiler:Languages\Italian.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "autostart"; Description: "Avvia WallCycle automaticamente all'accesso di Windows (minimizzato nella Tray)"; GroupDescription: "Avvio automatico:"

[Files]
Source: "bin\WallCycle.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "README.md"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\WallCycle"; Filename: "{app}\WallCycle.exe"
Name: "{group}\{cm:UninstallProgram,WallCycle}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\WallCycle"; Filename: "{app}\WallCycle.exe"; Tasks: desktopicon

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "WallCycle"; ValueData: """{app}\WallCycle.exe"" --minimized"; Flags: uninsdeletevalue; Tasks: autostart

[Run]
Filename: "{app}\WallCycle.exe"; Description: "{cm:LaunchProgram,WallCycle}"; Flags: nowait postinstall skipifsilent
