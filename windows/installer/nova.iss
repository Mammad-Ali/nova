; Nova installer for Windows (Inno Setup 6).
;
; Installs into the user's own folder, so it needs no administrator rights
; and raises no UAC prompt — a real simplification for an unsigned build.
;
; Build:  ISCC.exe windows\installer\nova.iss
; Output: build\windows\installer\Nova-Setup.exe

#define AppName "Nova"
; The version comes from pubspec.yaml: CI passes /DAppVersion=x.y.z. The
; fallback only covers a hand-run build without the switch.
#ifndef AppVersion
  #define AppVersion "0.0.0-dev"
#endif
#define AppPublisher "Mammad-Ali"
#define AppExe "Nova.exe"
; Path to the built application, relative to this file.
#define BuildDir "..\..\build\windows\x64\runner\Release"

[Setup]
; Never change this id: it is how upgrades and uninstalls find the previous
; installation.
AppId={{021C8CB6-98EE-4744-913B-5407B4C4DD4F}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
; Per-user installation: no administrator rights, no UAC prompt.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
OutputDir=..\..\build\windows\installer
OutputBaseFilename=Nova-Setup
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; \
    GroupDescription: "{cm:AdditionalIcons}"

[Files]
; Everything the build produces: the exe, its libraries and the data folder —
; they only work together.
Source: "{#BuildDir}\*"; DestDir: "{app}"; \
    Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; \
    Tasks: desktopicon

[Run]
; Offer to launch straight after installing.
Filename: "{app}\{#AppExe}"; \
    Description: "{cm:LaunchProgram,{#AppName}}"; \
    Flags: nowait postinstall skipifsilent
