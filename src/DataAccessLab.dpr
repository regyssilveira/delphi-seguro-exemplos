program DataAccessLab;
{$APPTYPE CONSOLE}
uses
  System.SysUtils, Data.DB, FireDAC.Comp.Client, FireDAC.Stan.Def, FireDAC.Stan.Param,
  FireDAC.Stan.Async, FireDAC.DApt, FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteWrapper.Stat;
var
  Connection: TFDConnection;
  Query: TFDQuery;
  function CountName(const Name: string): Integer;
  begin
    Query.Close;
    Query.SQL.Text := '''
      SELECT COUNT(*) AS TOTAL
      FROM CLIENTES
      WHERE NOME = :NOME
      ''';
    Query.ParamByName('NOME').AsWideString := Name;
    Query.Open;
    Result := Query.FieldByName('TOTAL').AsInteger;
  end;
begin
  Connection := nil;
  Query := nil;
  try
    try
      Connection := TFDConnection.Create(nil);
      Connection.DriverName := 'SQLite';
      Connection.Params.Values['Database'] := ':memory:';
      Connection.LoginPrompt := False;
      Connection.Connected := True;
      Query := TFDQuery.Create(nil);
      Query.Connection := Connection;
      Query.ExecSQL('CREATE TABLE CLIENTES (ID INTEGER PRIMARY KEY, NOME TEXT NOT NULL)');
      Query.SQL.Text := 'INSERT INTO CLIENTES(ID, NOME) VALUES (:ID, :NOME)';
      Query.ParamByName('ID').AsInteger := 1;
      Query.ParamByName('NOME').AsWideString := 'D''Ávila';
      Query.ExecSQL;
      if CountName('D''Ávila') <> 1 then raise Exception.Create('Apostrofo/Unicode');
      if CountName('Ausente') <> 0 then raise Exception.Create('Ausencia');
      if CountName('x'' OR ''1''=''1') <> 0 then raise Exception.Create('Entrada mudou SQL');
      Writeln('PASS FireDAC: apostrofo, Unicode, ausencia e entrada adversarial');
      Connection.StartTransaction;
      try
        Query.ExecSQL('DELETE FROM CLIENTES');
        Connection.Rollback;
      except
        if Connection.InTransaction then Connection.Rollback;
        raise;
      end;
      if CountName('D''Ávila') <> 1 then raise Exception.Create('Rollback');
      Writeln('PASS FireDAC: rollback preserva a linha');
    finally
      Query.Free;
      Connection.Free;
    end;
  except
    on E: Exception do
    begin
      Writeln(ErrOutput, E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
