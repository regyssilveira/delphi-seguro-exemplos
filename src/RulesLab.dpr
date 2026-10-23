program RulesLab;
{$APPTYPE CONSOLE}
uses System.SysUtils, System.DateUtils, System.JSON,
  SecureCompany.Rules in 'SecureCompany.Rules.pas';
procedure Check(Value: Boolean; const Name: string);
begin
  if not Value then raise Exception.Create(Name);
  Writeln('PASS ', Name);
end;
var Session: TSession; Charge: TCharge; CurrentTime: TDateTime;
  EventText: string; Event: TJSONValue;
begin
  try
    CurrentTime := Now;
    Session := Default(TSession);
    Session.UserId := 17;
    Session.TenantId := 42;
    Session.CanCancel := True;
    Session.CancellationLimit := 500;
    Session.ExpiresAt := IncMinute(CurrentTime, 5);
    Charge.Id := 9817;
    Charge.TenantId := 42;
    Charge.Amount := 150;
    Charge.IsOpen := True;
    Check(MayCancel(Session, Charge, CurrentTime), 'autorizacao permitida');
    Charge.TenantId := 77;
    Check(not MayCancel(Session, Charge, CurrentTime), 'outro tenant negado');
    Charge.TenantId := 42;
    Charge.Amount := 501;
    Check(not MayCancel(Session, Charge, CurrentTime), 'limite negado');
    Charge.Amount := 150;
    Charge.IsOpen := False;
    Check(not MayCancel(Session, Charge, CurrentTime), 'estado fechado negado');
    Charge.IsOpen := True;
    Session.CanCancel := False;
    Check(not MayCancel(Session, Charge, CurrentTime), 'permissao ausente negada');
    Session.CanCancel := True;
    Session.ExpiresAt := CurrentTime;
    Check(not MayCancel(Session, Charge, CurrentTime), 'expiracao negada');
    EventText := BillingLog('correlacao' + #13#10 + 'linha-falsa', 'denied');
    Event := TJSONObject.ParseJSONValue(EventText);
    try
      Check(Assigned(Event), 'log permanece JSON valido');
      Check(not EventText.Contains(#10), 'quebra de linha escapada');
      Check(not EventText.Contains('password'), 'campo senha ausente');
      Check(not EventText.Contains('Authorization'), 'cabecalho ausente');
    finally Event.Free; end;
  except
    on E: Exception do
    begin
      Writeln(ErrOutput, E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
