import copy
import json
from pathlib import Path
import tempfile
import unittest
import release_inventory


class InventoryTests(unittest.TestCase):
    def test_closed_drop_and_mutations(self):
        with tempfile.TemporaryDirectory() as directory:
            drop = Path(directory)
            (drop / "ERP.exe").write_bytes(b"fixture-candidato-nao-executavel")
            before = release_inventory.generate(drop)
            release_inventory.validate(drop, before)
            # Simula apenas a mudanca de bytes entre candidato e final assinado.
            (drop / "ERP.exe").write_bytes(b"fixture-final-nao-executavel")
            with self.assertRaises(ValueError):
                release_inventory.validate(drop, before)
            final = release_inventory.generate(drop)
            release_inventory.validate(drop, final)
            (drop / "unexpected.dll").write_bytes(b"nao-inventariado")
            with self.assertRaises(ValueError):
                release_inventory.validate(drop, final)

    def test_metadata_is_checked(self):
        with tempfile.TemporaryDirectory() as directory:
            drop = Path(directory)
            (drop / "ERP.exe").write_bytes(b"fixture")
            document = release_inventory.generate(drop)
            changed = copy.deepcopy(document)
            changed["files"][0]["checksums"][1]["checksumValue"] = "0" * 64
            with self.assertRaises(ValueError):
                release_inventory.validate(drop, changed)


if __name__ == "__main__":
    unittest.main()
