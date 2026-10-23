unit SecureCompany.Rules;
interface
uses System.SysUtils;
type
  TSession = record
    UserId: Int64;
    TenantId: Int64;
    CanCancel: Boolean;
    CancellationLimit: Currency;
    ExpiresAt: TDateTime;
  end;
  TCharge = record
    Id: Int64;
    TenantId: Int64;
    Amount: Currency;
    IsOpen: Boolean;
  end;
function MayCancel(const Session: TSession; const Charge: TCharge;
  CurrentTime: TDateTime): Boolean;
function BillingLog(const CorrelationId, Outcome: string): string;
implementation
uses System.JSON;
function MayCancel(const Session: TSession; const Charge: TCharge;
  CurrentTime: TDateTime): Boolean;
begin
  Result := (Session.UserId > 0) and (Session.TenantId > 0) and
    (CurrentTime < Session.ExpiresAt) and Session.CanCancel and
    (Session.TenantId = Charge.TenantId) and Charge.IsOpen and
    (Charge.Amount >= 0) and (Charge.Amount <= Session.CancellationLimit);
end;
function BillingLog(const CorrelationId, Outcome: string): string;
var Event: TJSONObject;
begin
  if (Length(CorrelationId) = 0) or (Length(CorrelationId) > 80) then
    raise EArgumentException.Create('Correlacao invalida');
  if (Outcome <> 'allowed') and (Outcome <> 'denied') then
    raise EArgumentException.Create('Resultado desconhecido');
  Event := TJSONObject.Create;
  try
    Event.AddPair('event', 'billing.authorization');
    Event.AddPair('correlation_id', CorrelationId);
    Event.AddPair('outcome', Outcome);
    Result := Event.ToJSON;
  finally
    Event.Free;
  end;
end;
end.
