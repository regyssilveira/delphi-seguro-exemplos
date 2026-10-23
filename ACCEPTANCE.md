# Evidência da edição — 23/10/2026

Ambiente: Windows, Delphi 13 Florence Win64, compilador 37.0, RTL/FireDAC da instalação 37.0; Python 3.14 e Windows PowerShell 5.1.

- Seis projetos Delphi compilados com build completo.
- Exposição: literal fictício localizado nos bytes do executável sem executá-lo.
- DPAPI: recuperação no contexto atual e adulteração rejeitada.
- FireDAC: apóstrofo/Unicode, ausência, entrada adversarial e rollback aprovados.
- HMAC: vetor RFC 4231 aprovado; alteração produz marca distinta; CNG executado.
- Política: permissão, empresa, limite, estado e expiração exercitados; serialização de log e ausência de campos sensíveis verificadas.
- Integração: sete testes Python aprovados sem testes ignorados, incluindo execução real do cliente Delphi, expiração, credenciais, limitação, isolamento, permissão, idempotência concorrente e ausência de segredos em eventos.
- Inventário: dois testes aprovados, incluindo mudança do candidato/final, arquivo extra e hash divergente.
- SPDX: inventário dos binários locais reconciliado e validado contra o esquema oficial 2.2.2 usando jsonschema 4.25.1; SHA-256 do esquema c8328d14c33621a6be917569ad4c323d370220412edbaddc37ccf1e93e3ca88a.
- Atualização: RSA/assinatura, alteração, canal, sequência e expiração exercitados.

Não foram exercitados nesta bancada: provedor OIDC externo, TLS real, conta Windows diferente para recuperação DPAPI, certificado Authenticode de produção, instalação privilegiada, máquinas offline ou restauro de banco empresarial. O livro distingue esses testes de aceitação específicos do laboratório das verificações exigidas para publicar um produto.
