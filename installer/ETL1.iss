; MyApp Installer
#define AppName "MyApp"
#define AppVersion "1.0.0"
#define Publisher "YourName"
#define URL "https://github.com/Devansh-14971"
#define AppExe "run_app.vbs"  ; launcher script
#define PythonEmbedURL "https://www.python.org/ftp/python/3.10.11/python-3.10.11-embed-amd64.zip"
#define CodeZipURL "https://github.com/Devansh-14971/ETL1/releases/latest/download/app.zip"
#define ModelsZipURL "https://github.com/Devansh-14971/ETL1/releases/latest/download/models.zip"

[Setup]
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#Publisher}
AppPublisherURL={#URL}
DefaultDirName={localappdata}\{#AppName}
DefaultGroupName={#AppName}
PrivilegesRequired=lowest
OutputDir=output
OutputBaseFilename=MyAppInstaller
Compression=lzma
SolidCompression=yes
UninstallDisplayIcon={app}\app.ico
SetupLogging=yes
DisableFinishedPage=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"
Name: "preserve"; Description: "Preserve .env, .ini, and user data"; Flags: unchecked

[Files]
; Static files you bundle
Source: "app.ico"; DestDir: "{app}"; Flags: ignoreversion
Source: "LICENSE.txt"; DestDir: "{app}"; Flags: isreadme
Source: "EULA.txt"; DestDir: "{app}"
Source: "7za.exe"; DestDir: "{tmp}"; Flags: dontcopy
Source: "get-pip.py"; DestDir: "{tmp}"; Flags: dontcopy

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{userdesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon
Name: "{group}\Uninstall {#AppName}"; Filename: "{uninstallexe}"

[Code]
function DownloadFile(const URL, DestFile: string): Boolean;
begin
  Log('Downloading: ' + URL);
  try
    Result := DownloadTemporaryFile(URL, DestFile);
  except
    Result := False;
  end;
end;

procedure ExtractZip(const ZipPath, DestDir: string);
var
  Cmd: string;
  ResultCode: Integer;
begin
  Cmd := Format('"{tmp}\7za.exe" x -y "%s" -o"%s"', [ZipPath, DestDir]);
  if Exec(ExpandConstant('{cmd}'), '/C ' + Cmd, '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
    Log('Extracted ' + ZipPath + ' to ' + DestDir);
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  ZipPath: string;
  PythonPath, VenvPath, Cmd: string;
  ResultCode: Integer;
begin
  if CurStep = ssInstall then begin
    Log('== Starting installer steps ==');

    ; 1. Download and extract app.zip
    ZipPath := ExpandConstant('{tmp}\app.zip');
    if DownloadFile('{#CodeZipURL}', ZipPath) then
      ExtractZip(ZipPath, ExpandConstant('{app}'));

    ; 2. Download and extract models.zip
    ZipPath := ExpandConstant('{tmp}\models.zip');
    if DownloadFile('{#ModelsZipURL}', ZipPath) then
      ExtractZip(ZipPath, ExpandConstant('{app}\models'));

    ; 3. Download and extract Python embeddable if needed
    PythonPath := ExpandConstant('{app}\python');
    if not DirExists(PythonPath) then begin
      ZipPath := ExpandConstant('{tmp}\python.zip');
      if DownloadFile('{#PythonEmbedURL}', ZipPath) then
        ExtractZip(ZipPath, PythonPath);
    end;

    ; 4. Create virtual environment
    VenvPath := ExpandConstant('{app}\.venv');
    Cmd := Format('"%s\python.exe" -m venv "%s"', [PythonPath, VenvPath]);
    if Exec(ExpandConstant('{cmd}'), '/C ' + Cmd, '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
      Log('Created venv at ' + VenvPath);

    ; 5. Install requirements
    Cmd := Format('"%s\Scripts\pip.exe" install -r "%s\requirements.txt"', [VenvPath, ExpandConstant('{app}')]);
    if Exec(ExpandConstant('{cmd}'), '/C ' + Cmd, '', SW_SHOW, ewWaitUntilTerminated, ResultCode) then
      Log('Installed requirements.txt');
  end;
end;

[UninstallDelete]
Type: filesandordirs; Name: "{app}\*"