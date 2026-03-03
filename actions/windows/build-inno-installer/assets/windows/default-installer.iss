#ifndef AppName
#define AppName "Aiden"
#endif

#ifndef AppVersion
#define AppVersion "0.0.0"
#endif

#ifndef SourceDir
#define SourceDir "."
#endif

#ifndef OutputDir
#define OutputDir "."
#endif

#ifndef InstallerFilename
#define InstallerFilename "Aiden-Setup-0.0.0-win-x64"
#endif

#ifndef TrayExeName
#define TrayExeName "Aiden.TrayMonitor.exe"
#endif

#ifndef AgentExeName
#define AgentExeName "Aiden.RuntimeAgent.exe"
#endif

#ifndef PostInstallLaunchExeName
#define PostInstallLaunchExeName "Aiden.TrayMonitor.exe"
#endif

#ifndef AutoRunExeName
#define AutoRunExeName "Aiden.RuntimeAgent.exe"
#endif

#ifndef SetupIconName
#define SetupIconName "aiden.ico"
#endif

[Setup]
AppName={#AppName}
AppVersion={#AppVersion}
DefaultDirName={localappdata}\{#AppName}
DefaultGroupName={#AppName}
SetupIconFile={#SourceDir}\{#SetupIconName}
OutputDir={#OutputDir}
OutputBaseFilename={#InstallerFilename}
DisableProgramGroupPage=no
Compression=lzma
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64
PrivilegesRequired=lowest
UninstallDisplayIcon={app}\{#TrayExeName}
CloseApplications=yes
ForceCloseApplications=yes
RestartApplications=no

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Tasks]
Name: desktopicon; Description: Create a desktop icon; GroupDescription: Additional icons; Flags: unchecked

[Icons]
Name: "{group}\{#AppName} Tray Monitor"; Filename: "{app}\{#TrayExeName}"; IconFilename: "{app}\{#SetupIconName}"
Name: "{commondesktop}\{#AppName} Tray Monitor"; Filename: "{app}\{#TrayExeName}"; Tasks: desktopicon; IconFilename: "{app}\{#SetupIconName}"

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "{#AppName}RuntimeAgent"; ValueData: """{app}\{#AutoRunExeName}"""; Flags: uninsdeletevalue

[Run]
Filename: "pwsh.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\scripts\install-runtime-deps.ps1"" -InstallDir ""{app}"""; StatusMsg: "Downloading runtime dependencies (VictoriaMetrics and OpenTelemetry Collector)..."; Flags: waituntilterminated

[Run]
Filename: "{app}\{#PostInstallLaunchExeName}"; Description: Launch {#AppName}; Flags: nowait postinstall skipifsilent
