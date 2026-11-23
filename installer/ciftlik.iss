; Çiftliğim 3D — Windows kurulum betiği (Inno Setup 6).
; Derleme: tools/build.sh çağırır:  ISCC.exe /DAppVer=0.2.0 installer\ciftlik.iss
; Önce build.sh ../surumler/Ciftligim3D klasörünü hazırlar; kurulum o klasörü paketler.

#ifndef AppVer
  #define AppVer "0.0.0"
#endif

[Setup]
AppId={{6F3B2C1A-9E47-4D2B-8C55-3A1F7E0C9D21}
AppName=Çiftliğim 3D
AppVersion={#AppVer}
AppVerName=Çiftliğim 3D {#AppVer} (Erken Erişim)
AppPublisher=Çiftliğim 3D
AppPublisherURL=https://github.com/fehmikalmaoglu-svg/ciftlik
AppSupportURL=https://github.com/fehmikalmaoglu-svg/ciftlik/issues
AppUpdatesURL=https://github.com/fehmikalmaoglu-svg/ciftlik/releases
VersionInfoVersion={#AppVer}.0
DefaultDirName={autopf}\Ciftligim3D
DefaultGroupName=Çiftliğim 3D
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
OutputDir=..\..\surumler
OutputBaseFilename=Ciftligim3D-Kurulum-v{#AppVer}
SetupIconFile=Ciftligim3D.ico
UninstallDisplayIcon={app}\Ciftligim3D.ico
UninstallDisplayName=Çiftliğim 3D
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=yes

[Languages]
Name: "tr"; MessagesFile: "compiler:Languages\Turkish.isl"

[Tasks]
Name: "desktopicon"; Description: "Masaüstüne kısayol oluştur"; GroupDescription: "Kısayollar:"

[Files]
Source: "..\..\surumler\Ciftligim3D\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "Ciftligim3D.ico"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\Çiftliğim 3D"; Filename: "{app}\Ciftligim3D.exe"; IconFilename: "{app}\Ciftligim3D.ico"
Name: "{group}\Sürüm notları"; Filename: "{app}\SURUM_NOTLARI.txt"
Name: "{group}\Çiftliğim 3D'yi kaldır"; Filename: "{uninstallexe}"
Name: "{autodesktop}\Çiftliğim 3D"; Filename: "{app}\Ciftligim3D.exe"; IconFilename: "{app}\Ciftligim3D.ico"; Tasks: desktopicon

[Run]
Filename: "{app}\Ciftligim3D.exe"; Description: "Çiftliğim 3D'yi başlat"; Flags: nowait postinstall skipifsilent

[Messages]
tr.WelcomeLabel2=Bu sihirbaz Çiftliğim 3D {#AppVer} (Erken Erişim) sürümünü bilgisayarınıza kuracak.%n%nKariyerleriniz ayrı bir klasörde saklanır; güncelleme ya da kaldırma onları silmez.
