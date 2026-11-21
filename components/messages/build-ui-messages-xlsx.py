"""Genera el Excel de importacion de MessageUcoLab con los textos de interfaz (UI###) del Frontend.

Fuente unica: GestioAsistenciaFrontend/docs/messages/mensajes-ui-messageucolab.psv (lo regenera
`npm run sync:mensajes-ui-catalogo` en el Frontend). Reutiliza write_xlsx de build-message-catalog.py.
La importacion solo crea mensajes nuevos: use --solo con los codigos que faltan en el ambiente
(los que `GET /api/v1/public/mensajes-interfaz/{codigo}` responde 404).

Uso:
  python build-ui-messages-xlsx.py --psv <mensajes-ui-messageucolab.psv> --template <plantilla-solo-encabezados.xlsx> \
      --xlsx <salida.xlsx> [--application-id <uuid>] [--solo UI121,UI122,...]
"""
import argparse
import importlib.util
import os

aqui = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("bmc", os.path.join(aqui, "build-message-catalog.py"))
bmc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bmc)

p = argparse.ArgumentParser()
p.add_argument("--psv", required=True)
p.add_argument("--template", required=True)
p.add_argument("--xlsx", required=True)
p.add_argument("--application-id")
p.add_argument("--solo", help="codigos remotos UI### separados por coma")
a = p.parse_args()
wanted = set(a.solo.split(",")) if a.solo else None
records = []
for line in open(a.psv, encoding="utf-8"):
    if line.startswith("#") or not line.strip():
        continue
    _canon, remoto, tipo, categoria, titulo, contenido = line.rstrip("\n").split("|", 5)
    if wanted is None or remoto in wanted:
        records.append((remoto, "Mensajes institucionales", tipo, categoria, "Activo", titulo, contenido))
bmc.write_xlsx(a.template, a.xlsx, records, a.application_id)
print(f"filas en el Excel: {len(records)}")
