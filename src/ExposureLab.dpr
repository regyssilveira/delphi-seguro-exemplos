program ExposureLab;
{$APPTYPE CONSOLE}
// Antipadrao intencional: somente fixture publica, sem uso operacional.
const EmbeddedFixture = 'FICTICIO-NAO-USAR-EM-PRODUCAO';
begin
  Writeln('Fixture publica do antipadrao: ', EmbeddedFixture);
end.
