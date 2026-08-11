; Установщик Nova для Windows (Inno Setup 6).
;
; Ставит приложение в папку пользователя, поэтому НЕ требует прав
; администратора и не показывает запрос UAC — для сборки без сертификата
; это заметно упрощает установку.
;
; Сборка: ISCC.exe windows\installer\nova.iss
; Результат: build\windows\installer\Nova-Setup.exe

#define AppName "Nova"
#define AppVersion "1.0.0"
#define AppPublisher "Mammad-Ali"
#define AppExe "Nova.exe"
; Путь к собранному приложению относительно этого файла.
#define BuildDir "..\..\build\windows\x64\runner\Release"

[Setup]
; Идентификатор менять нельзя — по нему находится прошлая версия
; при обновлении и удалении.
AppId={{021C8CB6-98EE-4744-913B-5407B4C4DD4F}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
; Ставим для текущего пользователя: без прав администратора и без UAC.
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
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; \
    GroupDescription: "{cm:AdditionalIcons}"

[Files]
; Всё содержимое сборки: exe, библиотеки и папка data — они нужны вместе.
Source: "{#BuildDir}\*"; DestDir: "{app}"; \
    Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; \
    Tasks: desktopicon

[Run]
; Предлагаем запустить сразу после установки.
Filename: "{app}\{#AppExe}"; \
    Description: "{cm:LaunchProgram,{#AppName}}"; \
    Flags: nowait postinstall skipifsilent
