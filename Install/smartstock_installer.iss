[Setup]
AppName=SmartStock Inventory System
AppVersion=1.0
DefaultDirName={autopf}\SmartStock
DefaultGroupName=SmartStock
OutputDir=installer_output
OutputBaseFilename=SmartStock_Setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
AllowNoIcons=yes
SetupIconFile=app_icon.ico
UninstallDisplayIcon={app}\SmartStock.exe

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional shortcuts:"

[Files]
Source: "dist\SmartStock.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\SmartStock"; Filename: "{app}\SmartStock.exe"
Name: "{autodesktop}\SmartStock"; Filename: "{app}\SmartStock.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\SmartStock.exe"; Description: "Launch SmartStock now"; Flags: nowait postinstall skipifsilent