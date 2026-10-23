# Delphi Seguro — laboratórios da primeira edição

Exemplos de **Delphi Seguro: Do código ao deploy: segurança para aplicações empresariais**, de **Régys Borges da Silveira**. Licença Apache License 2.0; o livro e suas imagens não fazem parte desta licença. Referência da edição: tag `edicao-1-piloto-2026-10-23.1`.

## Ambiente e execução

Delphi 13 Florence, compilador Win64 37.0, Windows e Python 3.11 ou posterior. A biblioteca padrão do Python atende ao servidor e aos testes. Não é necessário instalar pacotes Python para esses testes. A validação adicional do esquema SPDX usa um ambiente isolado com as dependências de `requirements-validation.txt`. Os exemplos usam RTL, FireDAC e SQLite estático fornecidos pelo RAD Studio; sua instalação licenciada deve conter essas bibliotecas. O repositório distribui os nossos fontes, não o compilador nem suas bibliotecas.

```powershell
powershell -ExecutionPolicy Bypass -File scripts/test-delphi.ps1 -StudioRoot 'C:\Program Files (x86)\Embarcadero\Studio\37.0'
python scripts/check-literal.py
python -m unittest discover -s service -p 'test_*.py' -v
python -m unittest discover -s scripts -p 'test_*.py' -v
powershell -ExecutionPolicy Bypass -File scripts/test-update.ps1
```

O primeiro comando compila seis projetos e executa cinco. O teste `test_delphi_client` inicia um servidor temporário e executa o sexto, `HttpClientLab.exe`, contra ele. Sem o executável compilado, esse teste fica explicitamente ignorado; isso não conta como aceitação da integração. Os executáveis e relatórios são gerados em diretórios ignorados pelo Git.

## Percurso e evidências

| Laboratório | Capítulos | O que é executado |
|---|---|---|
| `ExposureLab.dpr` e `scripts/check-literal.py` | 3 | recuperação de literal fictício no binário, sem executar o arquivo |
| `DpapiLab.dpr` e `SecureCompany.Secrets.pas` | 3–4 | proteção no usuário atual, persistência, recuperação e adulteração rejeitada |
| `DataAccessLab.dpr` | 5 | SQLite em memória via FireDAC, parâmetros, apóstrofo, Unicode, entrada adversarial e rollback |
| `CryptoLab.dpr` | 6 | aleatoriedade do Windows, HMAC-SHA256 e vetor público da RFC 4231 |
| `RulesLab.dpr` e `SecureCompany.Rules.pas` | 8 e 16 | política por empresa, permissão, limite, estado e sessão; log por campos aprovados |
| `HttpClientLab.dpr`, `service/lab_api.py` e testes | 7–9 | processos separados, autenticação local, token temporário, autorização no servidor e idempotência concorrente |
| `scripts/release_inventory.py` e testes | 11–14 | SPDX 2.2 com hashes, arquivos novos/modificados rejeitados e reconciliação com drop |
| `scripts/test-update.ps1` | 14–15 | assinatura RSA de bytes de teste e política de canal, sequência e expiração |

Os dados são fixos e fictícios: Alice pertence à empresa 42, Bob à empresa 77; a cobrança 9817 pertence à 42 e a 9818 à 77. Senhas de laboratório são `FICTICIA-alice-2026` e `FICTICIA-bob-2026`. Nunca substituir essas fixtures por dados de produção.

## Fronteiras demonstradas

O cliente Delphi é um processo separado do servidor Python. O servidor deriva empresa e permissão da sessão; não aceita `tenant_id` ou `role` no comando do cliente. Os testes usam HTTP exclusivamente em `127.0.0.1`, porta efêmera, sem publicar serviços externos. A exceção de transporte deste executável de laboratório não deve entrar no cliente de produção, que exige HTTPS com validação de certificado. O cliente bloqueia redirecionamentos e limita a resposta a 64 KiB.

O login local demonstra autenticação com derivação PBKDF2, comparação pelo mecanismo da biblioteca, limitação de tentativas e tokens opacos aleatórios. O custo de 100.000 iterações é uma fixture para tempo previsível de teste, não recomendação de parâmetro de produção. Este servidor não implementa OAuth, OIDC, MFA, recuperação de conta, renovação de tokens ou gestão de usuários. Para produção, integrar um provedor compatível conforme o capítulo 7. Não expor este servidor à rede: ele usa memória, fixtures, fila de eventos não persistente e políticas deliberadamente pequenas.

`RulesLab` testa a função pura; a autorização efetiva da integração é aplicada pelo servidor, não pelo cliente. A política correspondente é repetida no servidor para que o leitor possa comparar as decisões entre ambientes. A eliminação de arrays reduz exposição, mas não comprova remoção forense de cópias gerenciadas, da memória ou da mídia.

O inventário local verifica correspondência do drop e não substitui um validador completo de esquema SPDX. Ele não descobre automaticamente bibliotecas ligadas estaticamente: essas entradas exigem manifesto complementar, inspeção do compilador e análise de licença. A SBOM gerada deve ficar fora do drop para não incluir a si própria. Usar SHA-1 no campo de verificação de pacote atende ao formato SPDX 2.2; a comparação de segurança dos arquivos usa também SHA-256.

```powershell
python scripts/release_inventory.py generate build/win64 reports/manifest.spdx.json
python scripts/release_inventory.py validate build/win64 reports/manifest.spdx.json
```

Para verificar também o esquema oficial SPDX, execute `python -m venv .venv`, `.venv/Scripts/python.exe -m pip install -r requirements-validation.txt` e `.venv/Scripts/python.exe scripts/validate_spdx_schema.py reports/manifest.spdx.json`. Essa etapa usa rede para obter o esquema oficial; o script informa seu SHA-256. O validador local de correspondência de arquivos e o validador de esquema atendem a critérios diferentes.

`test-update.ps1` usa chaves RSA efêmeras apenas em memória e verifica os bytes antes de interpretar o JSON. Não instala certificados nem constitui um atualizador ou protocolo de produção. O teste do inventário simula a mudança de bytes entre candidato e final; não executa Authenticode. Assinar binários de produção exige identidade real de publicador, SignTool, cadeia, carimbo e verificação independente, como ensinam os capítulos 14–15.

## Critério de aceitação da edição

Aceitar o incremento quando todos os projetos compilarem, os cinco programas locais concluírem, os sete testes do servidor passarem sem `skip`, os dois testes de inventário passarem e o teste de atualização concluir. O objetivo é produzir evidência pequena e repetível para cada controle; isto não certifica um ERP pronto para produção.

As fontes oficiais das APIs e formatos e a interpretação de seus limites estão nas referências do livro. O código de criptografia usa implementações da RTL, Windows e .NET; não implementa primitivas próprias.
