unit SecureCompany.Secrets;

interface

uses System.SysUtils;

function ProtectForCurrentUser(const PlainBytes: TBytes): TBytes;
function UnprotectForCurrentUser(const ProtectedBytes: TBytes): TBytes;
procedure ClearBytes(var Value: TBytes);

implementation

uses Winapi.Windows;

type
  TDataBlob = record
    Size: DWORD;
    Data: PByte;
  end;

function CryptProtectData(var Input: TDataBlob; Description: PWideChar;
  Entropy: Pointer; Reserved: Pointer; Prompt: Pointer; Flags: DWORD;
  out Output: TDataBlob): BOOL; stdcall; external 'crypt32.dll';
function CryptUnprotectData(var Input: TDataBlob; Description: Pointer;
  Entropy: Pointer; Reserved: Pointer; Prompt: Pointer; Flags: DWORD;
  out Output: TDataBlob): BOOL; stdcall; external 'crypt32.dll';

const ProtectUiForbidden = $1;

procedure ClearBytes(var Value: TBytes);
begin
  if Length(Value) > 0 then
    FillChar(Value[0], Length(Value), 0);
  Value := nil;
end;

function Transform(const Value: TBytes; Protect: Boolean): TBytes;
var
  Input, Output: TDataBlob;
  Succeeded: BOOL;
begin
  if Length(Value) = 0 then
    raise EArgumentException.Create('Conteudo vazio');
  Input.Size := Length(Value);
  Input.Data := @Value[0];
  Output.Size := 0;
  Output.Data := nil;
  if Protect then
    Succeeded := CryptProtectData(Input, nil, nil, nil, nil,
      ProtectUiForbidden, Output)
  else
    Succeeded := CryptUnprotectData(Input, nil, nil, nil, nil,
      ProtectUiForbidden, Output);
  if not Succeeded then
    RaiseLastOSError;
  try
    SetLength(Result, Output.Size);
    if Output.Size > 0 then
      Move(Output.Data^, Result[0], Output.Size);
  finally
    if Output.Data <> nil then
    begin
      FillChar(Output.Data^, Output.Size, 0);
      LocalFree(HLOCAL(Output.Data));
    end;
  end;
end;

function ProtectForCurrentUser(const PlainBytes: TBytes): TBytes;
begin
  Result := Transform(PlainBytes, True);
end;

function UnprotectForCurrentUser(const ProtectedBytes: TBytes): TBytes;
begin
  Result := Transform(ProtectedBytes, False);
end;

end.
