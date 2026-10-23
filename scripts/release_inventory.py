"""SBOM SPDX 2.2 dos arquivos de um drop fechado e verificacao de cobertura.

Nao infere componentes ligados estaticamente; o manifesto complementar e a
analise de licencas sao tarefas distintas. Nao implementa validacao de assinatura.
"""
from __future__ import annotations
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import uuid


def files_in(drop):
    result = {}
    for path in sorted(drop.rglob("*")):
        if path.is_symlink():
            raise ValueError("Links nao sao admitidos no drop")
        if path.is_file():
            content = path.read_bytes()
            result[path.relative_to(drop).as_posix()] = {
                "SHA1": hashlib.sha1(content).hexdigest(),
                "SHA256": hashlib.sha256(content).hexdigest(),
            }
    if not result:
        raise ValueError("Drop vazio")
    return result


def generate(drop):
    entries = files_in(drop)
    files, relations = [], [{"spdxElementId": "SPDXRef-DOCUMENT", "relationshipType": "DESCRIBES", "relatedSpdxElement": "SPDXRef-Package-ERP"}]
    for index, (name, hashes) in enumerate(entries.items(), 1):
        identifier = f"SPDXRef-File-{index}"
        files.append({"fileName": "./" + name, "SPDXID": identifier, "checksums": [{"algorithm": key, "checksumValue": value} for key, value in hashes.items()], "licenseConcluded": "NOASSERTION", "licenseInfoInFiles": ["NOASSERTION"], "copyrightText": "NOASSERTION"})
        relations.append({"spdxElementId": "SPDXRef-Package-ERP", "relationshipType": "CONTAINS", "relatedSpdxElement": identifier})
    verification = hashlib.sha1("".join(sorted(h["SHA1"] for h in entries.values())).encode("ascii")).hexdigest()
    return {"spdxVersion": "SPDX-2.2", "dataLicense": "CC0-1.0", "SPDXID": "SPDXRef-DOCUMENT", "name": "SecureCompany-laboratorio-4.8.2-Win64", "documentNamespace": "https://securecompany.example/sbom/" + str(uuid.uuid4()), "creationInfo": {"created": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"), "creators": ["Tool: SecureCompany-Lab-1.0"]}, "packages": [{"name": "SecureCompany-Lab", "SPDXID": "SPDXRef-Package-ERP", "versionInfo": "4.8.2", "downloadLocation": "NOASSERTION", "filesAnalyzed": True, "packageVerificationCode": {"packageVerificationCodeValue": verification}, "licenseConcluded": "NOASSERTION", "licenseDeclared": "NOASSERTION", "copyrightText": "NOASSERTION"}], "files": files, "relationships": relations}


def validate(drop, document):
    expected = generate(drop)
    if document["spdxVersion"] != "SPDX-2.2":
        raise ValueError("Formato inesperado")
    if document["files"] != expected["files"] or document["packages"] != expected["packages"] or document["relationships"] != expected["relationships"]:
        raise ValueError("Arquivos, metadados ou hashes divergem do drop")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=["generate", "validate"])
    parser.add_argument("drop", type=Path)
    parser.add_argument("document", type=Path)
    args = parser.parse_args()
    if args.document.resolve().is_relative_to(args.drop.resolve()):
        parser.error("Documento deve ficar fora do drop para evitar auto-inclusao")
    if args.mode == "generate":
        args.document.parent.mkdir(parents=True, exist_ok=True)
        args.document.write_text(json.dumps(generate(args.drop), indent=2) + "\n", encoding="utf-8")
    else:
        validate(args.drop, json.loads(args.document.read_text(encoding="utf-8")))
    print("PASS inventario", args.mode)
