unit MainServiceThread;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, SvcMgr, Dialogs,
  IniFiles, ADODB, CopyOnSQL;

procedure WriteLog(text: string);

type
  TCopyFromSQLite = class(TService)
    procedure ServiceStart(Sender: TService; var Started: Boolean);
    procedure ServiceExecute(Sender: TService);
    procedure ServiceStop(Sender: TService; var Stopped: Boolean);
    procedure ServicePause(Sender: TService; var Paused: Boolean);
    procedure ServiceContinue(Sender: TService; var Continued: Boolean);
  private
    { Private declarations }
  public
    function GetServiceController: TServiceController; override;
    { Public declarations }
  end;

var
  CopyFromSQLite: TCopyFromSQLite;
  today : TDateTime;
  TCopyData: ThreadCopyData;
  PathToDB : String = 'C:\yourFolder\';
  PathToEXE : String = 'C:\yourFolder\';
  timer, timeWrite, timeToSleep: integer;

  ADOQuery1: TADOQuery;

implementation

{$R *.DFM}

procedure ServiceController(CtrlCode: DWord); stdcall;
begin
  CopyFromSQLite.Controller(CtrlCode);
end;

function TCopyFromSQLite.GetServiceController: TServiceController;
begin
  Result := ServiceController;
end;

procedure TCopyFromSQLite.ServiceStart(Sender: TService;
  var Started: Boolean);
var
  ini:TIniFile;
begin
  today := Now;
  WriteLog(DateToStr(today)+'  '+TimeToStr(today)+' : ������ ��������');
  try
    ini:=TIniFile.Create(PathToEXE + 'Params.ini');

    timeWrite:=ini.ReadInteger('SQLRead','timeToReadInSec',300);
    today := Now;
    WriteLog(DateToStr(today)+'  '+TimeToStr(today)+' : ������ ����� ������: '+IntToStr(ini.ReadInteger('SQLRead','timeToReadInSec',300))+'���.');

    timeToSleep:=1000*ini.ReadInteger('SQLRead','timeToSleepInSec',5);
    WriteLog(DateToStr(today)+'  '+TimeToStr(today)+' : ������ ����� ��� ����� ����������: '+IntToStr(ini.ReadInteger('SQLRead','timeToSleepInSec',5))+'���.');

    ini.Free;
  except
    on e:exception do begin
      today := Now;
      WriteLog(DateToStr(today)+'  '+TimeToStr(today)+' : ������ ������ ������� ������ ������: '+e.Message);
    end;
  end;
  timer:=0-round(timeToSleep/1000);
  Started := True;

end;

//����������� ����� start
procedure TCopyFromSQLite.ServiceExecute(Sender: TService);
begin
//���� ������� ������...
  while not Terminated do begin
    try
    //���� ��������� ����� ��� ����������� - ������� ����� ����������� � �������� ������
      timer:=timer+round(timeToSleep/1000);
      if (timer>=timeWrite) then begin
        TCopyData:=ThreadCopyData.Create(False);
        TCopyData.FreeOnTerminate:=True;
        TCopyData.Priority:=tpNormal;
        timer:=0;
      end;
    //����� �������� � ����� ������ � ���
    //����� ��� <> ������� ����� ������ ��� �������� �� �������
      Sleep(timeToSleep);
    //�� ������� ������ ����� ������ ��������� ������ � �� �������
      ServiceThread.ProcessRequests(false);
    except
    end;
  end;
end;

procedure TCopyFromSQLite.ServiceStop(Sender: TService;
  var Stopped: Boolean);
begin
  today := Now;
  WriteLog(DateToStr(today)+'  '+TimeToStr(today)+' : ������ �����������');
  Stopped := True;
end;

procedure TCopyFromSQLite.ServicePause(Sender: TService;
  var Paused: Boolean);
begin
  today := Now;
  WriteLog(DateToStr(today)+'  '+TimeToStr(today)+' : ������ ������ ��������������');
  Paused := True;
end;

procedure TCopyFromSQLite.ServiceContinue(Sender: TService;
  var Continued: Boolean);
begin
  today := Now;
  WriteLog(DateToStr(today)+'  '+TimeToStr(today)+' : ������ ������ ������������');
  Continued := True;
end;

procedure WriteLog(text: string);
var
  f:System.Text;
  hFile, fileSize: Integer;
begin

  try
  //���� �� ���������� - �������
    if not FileExists(PathToEXE+'log1.txt') then begin
      AssignFile(f,PathToEXE+'log1.txt');
      Rewrite(f);
      today := Now;
      WriteLn(f,DateToStr(today)+'  '+TimeToStr(today)+' : ������ log ����');
      CloseFile(f);
    end;
    //��������� ������
    hFile := FileOpen(PathToEXE+'log1.txt', fmOpenRead);
    fileSize := GetFileSize(hFile, nil);
    FileClose(hFile);

    //���� ������ <2��, �� ����� � ����
    if ((fileSize/1024/1024)<2) then begin
      AssignFile(f,PathToEXE+'log1.txt');
      Append(f);
      WriteLn(f,text);
      CloseFile(f);
    end else begin
      //���� >2�� - ������� log2
      //���� �� ���������� - �������
      if not FileExists(PathToEXE+'log2.txt') then begin
        AssignFile(f,PathToEXE+'log2.txt');
        Rewrite(f);
        today := Now;
        WriteLn(f,DateToStr(today)+'  '+TimeToStr(today)+' : ������ log ����');
        CloseFile(f);
      end;
      //��������� ������ log2
      hFile := FileOpen(PathToEXE+'log2.txt', fmOpenRead);
      fileSize := GetFileSize(hFile, nil);
      FileClose(hFile);

      //���� log2<2��, �� ����� � ����
      //����� ������������ ���� log1
      if ((fileSize/1024/1024)<2) then begin
        AssignFile(f,PathToEXE+'log2.txt');
        Append(f);
        WriteLn(f,text);
        CloseFile(f);
      end else begin
        AssignFile(f,PathToEXE+'log1.txt');
        Rewrite(f);
        today := Now;
        WriteLn(f,DateToStr(today)+'  '+TimeToStr(today)+' : ������ log ����');
        CloseFile(f);
      end;
    end;
  except
  end;
end;

end.
