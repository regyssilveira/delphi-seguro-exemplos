program DpapiLab;
{$APPTYPE CONSOLE}
uses
  System.SysUtils, System.Classes, System.IOUtils,
  SecureCompany.Secrets in 'SecureCompany.Secrets.pas';
var
  PlainBytes, ProtectedBytes, RecoveredBytes, ReloadedBytes: TBytes;
  Directory, FileName: string;
  Rejected: Boolean;
begin
  try
    Directory := TPath.Combine(TPath.GetTempPath,
      'SecureCompany-' + TGUID.NewGuid.ToString);
    ForceDirectories(Directory);
    FileName := TPath.Combine(Directory, 'session.dpapi');
    try
      // Fixture artificial: nunca colocar um token real neste fonte.
      PlainBytes := TEncoding.UTF8.GetBytes('TOKEN-FICTICIO-DESCARTAVEL');
      ProtectedBytes := ProtectForCurrentUser(PlainBytes);
      TFile.WriteAllBytes(FileName, ProtectedBytes);
      ReloadedBytes := TFile.ReadAllBytes(FileName);
      RecoveredBytes := UnprotectForCurrentUser(ReloadedBytes);
      if (Length(PlainBytes) <> Length(RecoveredBytes)) or
        not CompareMem(@PlainBytes[0], @RecoveredBytes[0], Length(PlainBytes)) then
        raise Exception.Create('Round-trip divergente');
      Writeln('PASS DPAPI: persistencia e recuperacao no usuario atual');
      ClearBytes(RecoveredBytes);
      ReloadedBytes[High(ReloadedBytes)] := ReloadedBytes[High(ReloadedBytes)] xor $01;
      Rejected := False;
      try
        RecoveredBytes := UnprotectForCurrentUser(ReloadedBytes);
      except
        on E: EOSError do Rejected := True;
      end;
      if not Rejected then
        raise Exception.Create('Bloco adulterado nao foi rejeitado');
      Writeln('PASS DPAPI: adulteracao rejeitada');
    finally
      ClearBytes(PlainBytes);
      ClearBytes(ProtectedBytes);
      ClearBytes(RecoveredBytes);
      ClearBytes(ReloadedBytes);
      if TFile.Exists(FileName) then TFile.Delete(FileName);
      if TDirectory.Exists(Directory) then TDirectory.Delete(Directory);
    end;
  except
    on E: Exception do
    begin
      Writeln(ErrOutput, E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
