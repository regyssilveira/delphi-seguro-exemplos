"""Verifica apenas a fixture publica do exemplo propositalmente inseguro."""
from pathlib import Path

path = Path(__file__).resolve().parents[1] / "build/win64/ExposureLab.exe"
data = path.read_bytes()
marker = "FICTICIO-NAO-USAR-EM-PRODUCAO"
if not any(marker.encode(encoding) in data for encoding in ("ascii", "utf-16-le")):
    raise SystemExit("Fixture nao localizada; conferir artefato e compilador")
print("PASS literal ficticio recuperavel no executavel, sem executar o binario")
