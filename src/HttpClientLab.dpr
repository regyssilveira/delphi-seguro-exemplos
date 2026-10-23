program HttpClientLab;
{$APPTYPE CONSOLE}
uses System.SysUtils, System.Classes, System.JSON,
  System.Net.HttpClient, System.Net.URLClient;
type
  TBoundedStream = class(TMemoryStream)
    function Write(const Buffer; Count: Longint): Longint; override;
  end;
function TBoundedStream.Write(const Buffer; Count: Longint): Longint;
begin
  if (Count < 0) or (Position > 65536 - Count) then
    raise EStreamError.Create('Resposta excede 64 KiB');
  Result := inherited Write(Buffer, Count);
end;
var Port: Integer;
function Request(const Method, Path, Token, Body, Key: string;
  out Status: Integer): string;
var Client: THTTPClient; Input: TStringStream; Output: TBoundedStream;
  Response: IHTTPResponse; Headers: TNetHeaders; Url: string; Bytes: TBytes;
begin
  // Exceção de transporte restrita ao laboratório em loopback.
  Url := 'http://127.0.0.1:' + Port.ToString + Path;
  Client := THTTPClient.Create;
  Input := TStringStream.Create(Body, TEncoding.UTF8);
  Output := TBoundedStream.Create;
  try
    Client.ConnectionTimeout := 2000;
    Client.ResponseTimeout := 5000;
    Client.HandleRedirects := False;
    Headers := [TNameValuePair.Create('Accept', 'application/json'),
      TNameValuePair.Create('Content-Type', 'application/json')];
    if Token <> '' then
    begin
      SetLength(Headers, Length(Headers) + 1);
      Headers[High(Headers)] := TNameValuePair.Create('Authorization', 'Bearer ' + Token);
    end;
    if Key <> '' then
    begin
      SetLength(Headers, Length(Headers) + 1);
      Headers[High(Headers)] := TNameValuePair.Create('Idempotency-Key', Key);
    end;
    if Method = 'GET' then
      Response := Client.Get(Url, Output, Headers)
    else
      Response := Client.Post(Url, Input, Output, Headers);
    Status := Response.StatusCode;
    SetLength(Result, 0);
    if Output.Size > 0 then
    begin
      SetLength(Bytes, Output.Size);
      Move(Output.Memory^, Bytes[0], Output.Size);
      Result := TEncoding.UTF8.GetString(Bytes);
    end;
  finally
    Output.Free;
    Input.Free;
    Client.Free;
  end;
end;
procedure Check(Actual, Expected: Integer; const Name: string);
begin
  if Actual <> Expected then
    raise Exception.CreateFmt('%s: esperado %d, observado %d', [Name, Expected, Actual]);
  Writeln('PASS HTTP: ', Name);
end;
var Status: Integer; Text, Token, Key: string; Json: TJSONValue;
begin
  try
    if (ParamCount <> 1) or not TryStrToInt(ParamStr(1), Port) then
      raise EArgumentException.Create('Informe a porta do servidor local');
    if (Port < 1) or (Port > 65535) then raise EArgumentException.Create('Porta invalida');
    Request('GET', '/v1/cobrancas/9817', '', '', '', Status);
    Check(Status, 401, 'sem sessao');
    Text := Request('POST', '/session', '', '''
      {"user":"alice","password":"FICTICIA-alice-2026"}
      ''', '', Status);
    Check(Status, 200, 'autenticacao no servico');
    Json := TJSONObject.ParseJSONValue(Text);
    try
      if not (Json is TJSONObject) then raise Exception.Create('Resposta de sessao invalida');
      Token := Json.GetValue<string>('access_token');
    finally Json.Free; end;
    Text := '';
    Request('GET', '/v1/cobrancas/9817', Token, '', '', Status);
    Check(Status, 200, 'tenant correto');
    Request('GET', '/v1/cobrancas/9818', Token, '', '', Status);
    Check(Status, 404, 'outro tenant negado');
    Key := TGUID.NewGuid.ToString.Replace('{', '').Replace('}', '');
    Request('POST', '/v1/cobrancas/9817/cancelar', Token,
      '{"reason_code":"CUSTOMER_REQUEST","tenant_id":77}', Key, Status);
    Check(Status, 400, 'tenant enviado pelo cliente rejeitado');
    Request('POST', '/v1/cobrancas/9817/cancelar', Token,
      '{"reason_code":"CUSTOMER_REQUEST"}', Key, Status);
    Check(Status, 200, 'cancelamento autorizado');
    Request('POST', '/v1/cobrancas/9817/cancelar', Token,
      '{"reason_code":"CUSTOMER_REQUEST"}', Key, Status);
    Check(Status, 200, 'mesma intencao nao duplica efeito');
    Request('POST', '/v1/cobrancas/9817/cancelar', Token,
      '{"reason_code":"CUSTOMER_REQUEST"}', Key + 'new', Status);
    Check(Status, 409, 'nova intencao em cobranca fechada');
    Token := '';
  except
    on E: Exception do
    begin
      Writeln(ErrOutput, E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
