"""Validacao independente do esquema SPDX oficial, sem inferir cobertura."""
import argparse
import hashlib
import json
from pathlib import Path
from urllib.request import urlopen
from jsonschema import Draft7Validator

parser = argparse.ArgumentParser()
parser.add_argument("document", type=Path)
args = parser.parse_args()
url = "https://raw.githubusercontent.com/spdx/spdx-spec/v2.2.2/schemas/spdx-schema.json"
with urlopen(url, timeout=30) as response:
    content = response.read(1_000_000)
schema = json.loads(content)
Draft7Validator.check_schema(schema)
document = json.loads(args.document.read_text(encoding="utf-8"))
Draft7Validator(schema).validate(document)
print("PASS esquema SPDX 2.2 oficial; sha256 do esquema:", hashlib.sha256(content).hexdigest())
