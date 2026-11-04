"""Genera, desde el seed de BD, el catalogo de mensajes de usuario listo para MessageUcoLab.

Fuente unica: GestioAsistenciaDB/schema/seed/04_mensaje.sql (primer MERGE = mensajes de usuario).

Salidas:
  * --psv   catalogo canonico|codigo remoto|tipo|categoria|titulo|contenido (fixture de pruebas del Backend)
  * --yaml  bloque `code-aliases` para application.yml (solo codigos que no caben en 10 caracteres)
  * --xlsx  copia de la plantilla oficial de importacion con las filas cargadas (sin tocar la plantilla de origen)

Reglas (limites vigentes de MessageUcoLab):
  * codigo remoto: 1..10 letras/numeros, sin "_". Si el canonico sin "_" cabe, se usa tal cual (VAL_001 -> VAL001).
    Si no cabe, se asigna ERR### / SUC### segun el prefijo, por orden del seed (estable mientras el seed no reordene).
  * titulo: 10..50. Contiene el nombre canonico para poder buscarlo: "<CANONICO> - <descripcion>" y, si el canonico
    es largo (>30), solo el canonico.
  * contenido: tal cual el seed. La plantilla vigente admite hasta 100; los mas largos se marcan con --limite.

Uso:
  python build-message-catalog.py --seed <04_mensaje.sql> --template <plantilla.xlsx> \
      --psv <salida.psv> --yaml <salida.yml> --xlsx <salida.xlsx> [--application-id <uuid>] [--limite 100]
"""
import argparse
import re
import sys
import zipfile
from xml.sax.saxutils import escape

SEP = "|"
MAX_REMOTE, TITLE_MIN, TITLE_MAX, CONTENT_MIN = 10, 10, 50, 10
TYPE_MAP = {  # tipoMensaje del seed -> (Tipo, Categoria) de la plantilla
    "BUSINESS_ERROR": ("Funcional", "Error"),
    "SYSTEM_ERROR": ("Técnico", "Error"),
    "SUCCESS": ("Funcional", "Confirmación"),
}
PREFIX_FOR_LONG = {"ERR_": "ERR", "SUC_": "SUC"}


def read_seed(path):
    sql = open(path, encoding="utf-8-sig").read().split("MERGE INTO")[1]
    rows = re.findall(r"\('([A-Z0-9_]+)',\s*'([A-Z_]+)',\s*'([A-Z]+)',\s*'((?:[^']|'')*)'\)", sql)
    return [(c, t, s, x.replace("''", "'")) for c, t, s, x in rows]


def remote_codes(rows):
    counters, out, used = {}, {}, set()
    for code, *_ in rows:
        plain = re.sub(r"[^A-Za-z0-9]", "", code)
        if len(plain) <= MAX_REMOTE:
            remote = plain
        else:
            prefix = next((v for k, v in PREFIX_FOR_LONG.items() if code.startswith(k)), None)
            if prefix is None:
                sys.exit(f"Codigo largo sin prefijo conocido: {code}")
            counters[prefix] = counters.get(prefix, 0) + 1
            remote = f"{prefix}{counters[prefix]:03d}"
        if remote in used:
            sys.exit(f"Codigo remoto duplicado: {remote} ({code})")
        used.add(remote)
        out[code] = remote
    return out


def title_for(code, content):
    if len(code) > 30:
        return code
    description = content.replace("{}", "…").replace("{0}", "…").replace("{1}", "…")
    room = TITLE_MAX - len(code) - 3
    if len(description) > room:
        description = description[:room - 1].rsplit(" ", 1)[0].rstrip(" ,.;:") + "…"
    return f"{code} - {description}"


def cell(ref, text):
    return f'<c r="{ref}" t="inlineStr"><is><t xml:space="preserve">{escape(text)}</t></is></c>'


def write_xlsx(template, target, records, application_id):
    zin = zipfile.ZipFile(template)
    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as zout:
        for item in zin.infolist():
            data = zin.read(item.filename)
            if item.filename == "xl/worksheets/sheet1.xml":
                xml = data.decode("utf-8")
                body = "".join(
                    f'<row r="{i}">' + "".join(cell(f"{col}{i}", value) for col, value in zip("ABCDEFG", values)) + "</row>"
                    for i, values in enumerate(records, start=2))
                xml = re.sub(r"<sheetData>.*</sheetData>",
                             lambda m: m.group(0).replace("</sheetData>", body + "</sheetData>"), xml, flags=re.S)
                xml = re.sub(r'<dimension ref="[^"]*"/>', f'<dimension ref="A1:G{len(records) + 1}"/>', xml)
                data = xml.encode("utf-8")
            elif application_id and item.filename == "xl/sharedStrings.xml":
                text = data.decode("utf-8")
                text = re.sub(r"(<t>MESSAGEUCOLAB_IMPORT_V2</t></si><si><t>)[0-9a-f-]{36}(</t>)",
                              lambda m: m.group(1) + application_id + m.group(2), text)
                data = text.encode("utf-8")
            zout.writestr(item, data)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--seed", required=True)
    p.add_argument("--template")
    p.add_argument("--psv")
    p.add_argument("--yaml")
    p.add_argument("--xlsx")
    p.add_argument("--application-id")
    p.add_argument("--limite", type=int, default=100)
    p.add_argument("--solo", help="codigos remotos separados por coma: limita el Excel a esas filas (pruebas parciales)")
    p.add_argument("--hasta-contenido", type=int, help="omite del Excel los mensajes con mas caracteres que este valor")
    a = p.parse_args()

    rows = read_seed(a.seed)
    remote = remote_codes(rows)
    records, psv, aliases, over = [], [], [], []
    for code, tipo_seed, _severity, content in rows:
        tipo, categoria = TYPE_MAP[tipo_seed]
        title = title_for(code, content)
        assert TITLE_MIN <= len(title) <= TITLE_MAX, (code, title, len(title))
        assert len(content) >= CONTENT_MIN, (code, content)
        assert "|" not in content and "\n" not in content, code
        records.append((remote[code], "Mensajes institucionales", tipo, categoria, "Activo", title, content))
        psv.append(SEP.join((code, remote[code], tipo, categoria, title, content)))
        if remote[code] != re.sub(r"[^A-Za-z0-9]", "", code):
            aliases.append((code, remote[code]))
        if len(content) > a.limite:
            over.append((code, len(content)))

    if a.psv:
        with open(a.psv, "w", encoding="utf-8", newline="\n") as f:
            f.write("# canonico|codigo remoto|tipo|categoria|titulo|contenido -- generado por "
                    "AsistenciasUCO-Infra/components/messages/build-message-catalog.py desde 04_mensaje.sql\n")
            f.write("\n".join(psv) + "\n")
    if a.yaml:
        with open(a.yaml, "w", encoding="utf-8", newline="\n") as f:
            for code, short in aliases:
                f.write(f'        "[{code}]": {short}\n')
    if a.xlsx:
        selected = records
        if a.solo:
            wanted = set(a.solo.split(","))
            selected = [r for r in selected if r[0] in wanted]
        if a.hasta_contenido:
            selected = [r for r in selected if len(r[6]) <= a.hasta_contenido]
        write_xlsx(a.template, a.xlsx, selected, a.application_id)
        print(f"filas en el Excel: {len(selected)}")
    print(f"mensajes={len(rows)} alias={len(aliases)} sobre-limite({a.limite})={over}")


if __name__ == "__main__":
    main()
