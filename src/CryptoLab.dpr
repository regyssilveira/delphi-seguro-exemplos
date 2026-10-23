program CryptoLab;
{$APPTYPE CONSOLE}
uses System.SysUtils, System.Hash, SecureCompany.Secrets;
function BCryptGenRandom(Provider: Pointer; Buffer: PByte; Count, Flags: Cardinal): Longint;
  stdcall; external 'bcrypt.dll';
var Key, Tag, Changed: TBytes; Text, Hex: string; Index: Integer;
begin
  try
    Key := nil;
    Tag := nil;
    Changed := nil;
    try
      SetLength(Key, 32);
      if BCryptGenRandom(nil, @Key[0], Length(Key), $2) <> 0 then
        raise Exception.Create('Falha no gerador do Windows');
      // Vetor de teste publico da RFC 4231, caso 1 (nao e chave operacional).
      for Index := 0 to 19 do Key[Index] := $0b;
      SetLength(Key, 20);
      Tag := THashSHA2.GetHMACAsBytes('Hi There', Key);
      Hex := '';
      for Index := 0 to High(Tag) do Hex := Hex + IntToHex(Tag[Index], 2);
      if not SameText(Hex, 'b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7') then
        raise Exception.Create('HMAC divergiu do vetor RFC 4231');
      Writeln('PASS HMAC-SHA256: vetor RFC 4231');
      Text := 'Hi There!';
      Changed := THashSHA2.GetHMACAsBytes(Text, Key);
      if CompareMem(@Tag[0], @Changed[0], Length(Tag)) then
        raise Exception.Create('Alteracao nao mudou a marca');
      Writeln('PASS HMAC-SHA256: alteracao produz outra marca');
      Writeln('PASS CNG: geracao aleatoria de 32 bytes sem chave fixa');
    finally
      ClearBytes(Key);
      ClearBytes(Tag);
      ClearBytes(Changed);
    end;
  except
    on E: Exception do
    begin
      Writeln(ErrOutput, E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
