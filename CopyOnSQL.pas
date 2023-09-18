unit CopyOnSQL;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls,
  Dialogs, ExtCtrls, StdCtrls, DB, DateUtils, Contnrs, ADODB, DBCtrls,
  Math, IniFiles, ActiveX, ComCtrls;

type
  ThreadCopyData = class(TThread)
  private
    { Private declarations }
  protected
    procedure Execute; override;
    procedure WriteIntoSQL(text, devname :string; count :integer);
end;



implementation

uses MainServiceThread, SQLite3,{ SQLite3Utils,} SQLite3Wrap;

procedure ThreadCopyData.Execute;
var



  lastTime:string;
  ini:TIniFile;
  countNewStr,i:integer;
  DB: TSQLite3Database;
  Stmt: TSQLite3Statement;
  insertText:string;
  DeveuiList:TStringList;
begin
CoInitialize(nil);
try
  try
    ini:=TIniFile.Create(PathToEXE+'Devices.ini');
    DeveuiList:=TStringList.Create;
    ini.ReadSections(DeveuiList); //���������� ���� ������ (=deveui)

    //��������� �� ���� �����������, ��������� � ini �����
    for i:=0 to DeveuiList.Count-1 do begin
    //���� � ��� ������� ����� ��������
    if (ini.ReadInteger(DeveuiList[i],'status',0)=1) then begin
    countNewStr:=0;
    lasttime:='0';
    //������, ���� ��������
    insertText:='Insert into '+ini.ReadString(DeveuiList[i],'namedb','null')+' VALUES';
      try
      //��������� ���� � �������
        DB := TSQLite3Database.Create;
        try
          DB.Open(PathToDB+'yourDB.db');
          //�������� ������ ������
          Stmt := DB.Prepare('SELECT HEX(data), time from datafromdev where '+
          '(time>'''+ini.ReadString(DeveuiList[i],'time','0')+''') '+   //����� ��������� ������
          'and (deveui='''+DeveuiList[i]+''') '+   //��� ����������
          'and (data is not null) '+
          ' ORDER BY time ');

          try
            //��������� �� ������� � ������� ����� �������
            while Stmt.Step = SQLITE_ROW do begin
                insertText:=insertText+',('+
                'DATEADD(millisecond, '+intToStr(Stmt.Columnint64(1) mod 1000)+', DATEADD(s, '+
                intToStr(Stmt.Columnint64(1) div 1000)+', ''1970-01-01''))'+
                ','+IntToStr(StrToInt('$'+ trim(copy(Stmt.ColumnText(0),31,2)+copy(Stmt.ColumnText(0),29,2))))+')';
                lasttime:=Stmt.ColumnText(1);
                countNewStr:=countNewStr+1;
                //���� ��������� ��� 100 ������� ��� �������, �� ������� ��
                //������� ����� �����, ������ ������� ������ ������� �
                //��������� �������� ������
                if (countNewStr Mod 100)=0 then begin
                  WriteIntoSQL(insertText, DeveuiList[i], countNewStr);
                  insertText:= 'Insert into '+ini.ReadString(DeveuiList[i],'namedb','null')+' VALUES';
                  countNewStr:=0;
                  try
                    //������� ����� ���������� ����������� ���������
                    ini.WriteString(DeveuiList[i],'time',lasttime);
                  except
                    on e:exception do begin
                      today := Now;
                      WriteLog(DateToStr(today)+'  '+TimeToStr(today)+' : �� ������� �������� ������ � ������� � ini ����: '+e.Message);
                    end; //on exp
                  end;//try write ini
                end; //if str=100
            end; //while
          finally
            Stmt.Free;
          end; //try while
            //����� ��������� �������� ������ ��� ����������, ���� ���� �������
            //������, �� �������� ��
            if (countNewStr<>0) then begin

              WriteIntoSQL(insertText, DeveuiList[i], countNewStr);
              try
                ini.WriteString(DeveuiList[i],'time',lasttime);
              except
                on e:exception do begin
                  today := Now;
                  WriteLog(DateToStr(today)+'  '+TimeToStr(today)+' : �� ������� �������� ������ � ������� � ini ����: '+e.Message);
                end;
              end;
            //end else begin
              //today := Now;
              //WriteLog(DateToStr(today)+'  '+TimeToStr(today)+' : ��� ����� ������� ��� '+DeveuiList[i]);
            end;//if count<>0
        finally
          DB.Free;
        end; //try db open
      except
        on e:exception do begin
          today := Now;
          WriteLog(DateToStr(today)+'  '+TimeToStr(today)+' : �� ������� ������������ � ���� ������: '+e.Message);
        end;
      end;
    end;
    end;
    ini.Free;
    DeveuiList.Free;

  except
    on e:exception do begin
      today := Now;
      WriteLog(DateToStr(today)+'  '+TimeToStr(today)+' : �� ������� ��������� ������ �� ini �����: '+e.Message);
    end;
  end;
finally
  CoUnInitialize;
end;
end;

procedure ThreadCopyData.WriteIntoSQL(text, devname :string; count :integer);
begin
  ADOQuery1 := TADOQuery.Create(nil);
  //��������� ���������
  with ADOQuery1 do begin
    ConnectionString := 'FILE NAME=' + PathToEXE + 'Connection.udl';
    CommandTimeout := 3;
    CommandTimeout := 3;
    CursorLocation := clUseClient;
    Tag := 0;
  end;
  ADOQuery1.Close;
  Delete(text, Pos('VALUES',text)+6, 1);
  text:=text+'; select 1;';
  ADOQuery1.SQL.Clear;
  ADOQuery1.SQL.Text:= text;
  try
    ADOQuery1.Open;
    ADOQuery1.Close;
  except
    on e:exception do begin
      today := Now;
      WriteLog(DateToStr(today)+'  '+TimeToStr(today)+' : ������ ������ ������: '+e.Message);
    end;
  end;

end;

end.
