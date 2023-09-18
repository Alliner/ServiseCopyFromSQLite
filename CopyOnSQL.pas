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
    ini.ReadSections(DeveuiList); //считывание имен секций (=deveui)

    //пройдемс€ по всем устройствам, указанным в ini файле
    for i:=0 to DeveuiList.Count-1 do begin
    //если у них включен режим слежени€
    if (ini.ReadInteger(DeveuiList[i],'status',0)=1) then begin
    countNewStr:=0;
    lasttime:='0';
    //читаем, куда записать
    insertText:='Insert into '+ini.ReadString(DeveuiList[i],'namedb','null')+' VALUES';
      try
      //открываем базу с данными
        DB := TSQLite3Database.Create;
        try
          DB.Open(PathToDB+'yourDB.db');
          //отбираем нужные записи
          Stmt := DB.Prepare('SELECT HEX(data), time from datafromdev where '+
          '(time>'''+ini.ReadString(DeveuiList[i],'time','0')+''') '+   //врем€ последней записи
          'and (deveui='''+DeveuiList[i]+''') '+   //им€ устройства
          'and (data is not null) '+
          ' ORDER BY time ');

          try
            //пройдемс€ по запис€м и соберем текст запроса
            while Stmt.Step = SQLITE_ROW do begin
                insertText:=insertText+',('+
                'DATEADD(millisecond, '+intToStr(Stmt.Columnint64(1) mod 1000)+', DATEADD(s, '+
                intToStr(Stmt.Columnint64(1) div 1000)+', ''1970-01-01''))'+
                ','+IntToStr(StrToInt('$'+ trim(copy(Stmt.ColumnText(0),31,2)+copy(Stmt.ColumnText(0),29,2))))+')';
                lasttime:=Stmt.ColumnText(1);
                countNewStr:=countNewStr+1;
                //если набралось уже 100 записей дл€ вставки, то запишем их
                //обнулим число строк, заново сделаем начало запроса и
                //продолжим набирать записи
                if (countNewStr Mod 100)=0 then begin
                  WriteIntoSQL(insertText, DeveuiList[i], countNewStr);
                  insertText:= 'Insert into '+ini.ReadString(DeveuiList[i],'namedb','null')+' VALUES';
                  countNewStr:=0;
                  try
                    //запишем врем€ последнего записанного сообщени€
                    ini.WriteString(DeveuiList[i],'time',lasttime);
                  except
                    on e:exception do begin
                      today := Now;
                      WriteLog(DateToStr(today)+'  '+TimeToStr(today)+' : Ќе удалось записать данные о времени в ini файл: '+e.Message);
                    end; //on exp
                  end;//try write ini
                end; //if str=100
            end; //while
          finally
            Stmt.Free;
          end; //try while
            //когда закончили собирать запрос дл€ устройства, если были найдены
            //записи, то отправим их
            if (countNewStr<>0) then begin

              WriteIntoSQL(insertText, DeveuiList[i], countNewStr);
              try
                ini.WriteString(DeveuiList[i],'time',lasttime);
              except
                on e:exception do begin
                  today := Now;
                  WriteLog(DateToStr(today)+'  '+TimeToStr(today)+' : Ќе удалось записать данные о времени в ini файл: '+e.Message);
                end;
              end;
            //end else begin
              //today := Now;
              //WriteLog(DateToStr(today)+'  '+TimeToStr(today)+' : Ќет новых записей дл€ '+DeveuiList[i]);
            end;//if count<>0
        finally
          DB.Free;
        end; //try db open
      except
        on e:exception do begin
          today := Now;
          WriteLog(DateToStr(today)+'  '+TimeToStr(today)+' : Ќе удалось подключитьс€ к базе данных: '+e.Message);
        end;
      end;
    end;
    end;
    ini.Free;
    DeveuiList.Free;

  except
    on e:exception do begin
      today := Now;
      WriteLog(DateToStr(today)+'  '+TimeToStr(today)+' : Ќе удалось прочитать данные из ini файла: '+e.Message);
    end;
  end;
finally
  CoUnInitialize;
end;
end;

procedure ThreadCopyData.WriteIntoSQL(text, devname :string; count :integer);
begin
  ADOQuery1 := TADOQuery.Create(nil);
  //установим параметры
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
      WriteLog(DateToStr(today)+'  '+TimeToStr(today)+' : ќшибка записи данных: '+e.Message);
    end;
  end;

end;

end.
