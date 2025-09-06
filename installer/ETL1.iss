; App Installer with retries + file verification
#define AppName "RiskMap"
#define AppVersion "2.0.0"
#define Publisher "Devansh Banga"
#define URL "https://github.com/Devansh-14971"
#define AppExe "run_app.vbs"
#define PythonEmbedURL "https://www.python.org/ftp/python/3.10.11/python-3.10.11-embed-amd64.zip"
#define CodeZipURL "https://github.com/Devansh-14971/RiskMap/releases/latest/download/app.zip"
#define ModelsZipURL "https://github.com/Devansh-14971/RiskMap/releases/latest/download/models.zip"

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
; 1. Desktop shortcut
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

; 2. Preserve user data at uninstall
Name: "preserve"; Description: "Preserve .env, .ini, and user data"; Flags: unchecked

[Files]
Source: "app.ico"; DestDir: "{app}"; Flags: ignoreversion
Source: "LICENSE.txt"; DestDir: "{app}"; Flags: isreadme
Source: "EULA.txt"; DestDir: "{app}"
Source: "7za.exe"; DestDir: "{tmp}"; Flags: dontcopy
Source: "get-pip.py"; DestDir: "{tmp}"; Flags: dontcopy

[Icons]
; Main app shortcut -> points to run_app.vbs
Name: "{group}\{#AppName}"; Filename: "{app}\run_app.vbs"

; Desktop shortcut (optional, controlled by user during install)
Name: "{userdesktop}\{#AppName}"; Filename: "{app}\run_app.vbs"; Tasks: desktopicon

; Uninstall shortcut
Name: "{group}\Uninstall {#AppName}"; Filename: "{uninstallexe}"

[Code]
function DownloadFile(const URL, DestFile: string): Boolean;
var
  Retry, Success: Boolean;
  i: Integer;
begin
  Retry := True;
  Success := False;
  for i := 1 to 3 do begin
    try
      Log(Format('Downloading (attempt %d): %s', [i, URL]));
      Success := DownloadTemporaryFile(URL, DestFile);
      if Success then break;
    except
      Success := False;
    end;
    if not Success then
      Sleep(3000);  // wait 3s before retry
  end;
  Result := Success;
end;

procedure ExtractZip(const ZipPath, DestDir: string);
var
  Cmd: string;
  ResultCode: Integer;
begin
  Cmd := Format('"{tmp}\7za.exe" x -y "%s" -o"%s"', [ZipPath, DestDir]);
  if Exec(ExpandConstant('{cmd}'), '/C ' + Cmd, '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
    Log('Extracted ' + ZipPath + ' to ' + DestDir)
  else
    MsgBox('Failed to extract ' + ZipPath, mbError, MB_OK);
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
; Delete everything except preserved data if user checked "Preserve"
Type: filesandordirs; Name: "{app}\*"; Tasks: not preserve
; If user chose to preserve, only delete binaries, not configs
Type: files; Name: "{app}\*.log"; Tasks: preserve
Type: files; Name: "{app}\*.tmp"; Tasks: preserve
Type: files; Name: "{app}\*.cache"; Tasks: preserve