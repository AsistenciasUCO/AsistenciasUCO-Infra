"""Empuja al Catalogo de Parametros los valores que los datos de prueba fijan solo en la BD (INT-004).

Con el Catalogo como fuente de verdad, el Backend reconcilia dbo.CatalogoParametro contra el al arrancar y por evento Pulsar.
Un UPDATE de datos-prueba (p. ej. RED.CIDRS_CAMPUS con los rangos de Docker) que no exista en el Catalogo se revertiria solo.
Este script lee esos UPDATE de GestioAsistenciaDB/scripts/datos-prueba/01_estructura.sql y, si el valor del Catalogo
(aplicacion AsistenciasUCO, ambiente Desarrollo) es otro, lo actualiza por la API administrativa del Catalogo; el evento
MetadataUpdated hace que el Backend lo aplique a la BD en segundos. Idempotente. Solo laboratorio local.

Credenciales: la sesion web de lab-pdp-admin sale de %USERPROFILE%\\.asistencias-security-lab\\lab.env (via lab_pdp.py del
Backend); nunca se imprimen claves ni tokens.

Uso: python -X utf8 -I sincronizar_catalogo_parametros.py --backend-repo <ruta> --db-repo <ruta> [--simular]
     python -X utf8 -I sincronizar_catalogo_parametros.py --backend-repo <ruta> --establecer GRUPO.CLAVE=VALOR
       (cambia un solo metadato en el Catalogo y escribe `ANTES=<valor previo>`; lo usan las pruebas de eventos)
Codigos de salida: 0 todo alineado (o aplicado), 1 error, 2 el Catalogo no esta disponible (se omite sin fallar el flujo).
"""
import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.request

APLICACION = "AsistenciasUCO"
AMBIENTE = "Desarrollo"
BASE = "http://localhost:8081/catalogo-parametros/api/v1"
PATRON = re.compile(
    r"UPDATE\s+dbo\.CatalogoParametro\s+SET\s+valor\s*=\s*N'((?:[^']|'')*)'\s*WHERE\s+grupo\s*=\s*N'([^']+)'\s+AND\s+clave\s*=\s*N'([^']+)'",
    re.IGNORECASE)


def sobrescrituras(db_repo):
    """{ 'GRUPO.CLAVE': valor } con los UPDATE de dbo.CatalogoParametro de los datos de prueba."""
    ruta = os.path.join(db_repo, "scripts", "datos-prueba", "01_estructura.sql")
    with open(ruta, encoding="utf-8-sig") as f:
        texto = f.read()
    return {f"{g}.{c}": v.replace("''", "'") for v, g, c in PATRON.findall(texto)}


def catalogo_disponible():
    try:
        with urllib.request.urlopen("http://localhost:8081/actuator/health", timeout=8) as r:
            return r.status == 200
    except (urllib.error.URLError, OSError):
        return False


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--backend-repo", required=True)
    ap.add_argument("--db-repo")
    ap.add_argument("--establecer", metavar="GRUPO.CLAVE=VALOR")
    ap.add_argument("--simular", action="store_true")
    a = ap.parse_args()

    modo_establecer = bool(a.establecer)
    if modo_establecer:
        if "=" not in a.establecer:
            print("--establecer espera GRUPO.CLAVE=VALOR")
            return 1
        nombre, valor = a.establecer.split("=", 1)
        deseadas = {nombre: valor}
    else:
        if not a.db_repo:
            print("--db-repo es obligatorio")
            return 1
        deseadas = sobrescrituras(a.db_repo)
    if not deseadas:
        print("catalogo-parametros: los datos de prueba no sobrescriben parametros; nada que empujar.")
        return 0
    if not catalogo_disponible():
        print("catalogo-parametros: el Catalogo (localhost:8081) no responde; se omite. Con el escenario 'parametros' vuelva a ejecutar `datos-prueba catalogo`.")
        return 2

    sys.path.insert(0, os.path.join(a.backend_repo, "infra", "security-baseline", "scripts"))
    import lab_pdp as L

    env = L.read_env()
    opener, jar, st, _, _ = L.bff_session(env, "lab-pdp-admin", "LAB_USER_LAB_PDP_ADMIN_PASSWORD")
    if st != 200:
        print(f"catalogo-parametros: no se pudo abrir la sesion de lab-pdp-admin (HTTP {st}).")
        return 1
    cab = L.xsrf_headers(jar)

    def llamar(metodo, ruta, cuerpo=None):
        s, _, raw = L.http(opener, metodo, BASE + ruta, cuerpo, headers=cab)
        try:
            return s, json.loads(raw or b"{}")
        except ValueError:
            return s, {}

    s, b = llamar("GET", "/aplicaciones")
    app = next((x for x in b.get("aplicaciones", []) if x.get("nombre") == APLICACION), None)
    if s != 200 or not app:
        print(f"catalogo-parametros: la aplicacion {APLICACION} no existe en el Catalogo (HTTP {s}).")
        return 1
    s, b = llamar("GET", f"/aplicaciones/{app['id']}/administracion")
    if s != 200:
        print(f"catalogo-parametros: no se pudo leer la administracion de {APLICACION} (HTTP {s}).")
        return 1
    cat = b["catalogo"]
    amb = next((x["id"] for x in cat["ambientes"] if x["nombre"] == AMBIENTE), None)
    por_nombre = {p["id"]: p["nombre"] for p in cat["parametros"]}
    meta = {por_nombre[m["idParametro"]]: m for m in cat["metadatos"] if m["idAmbiente"] == amb and m["idParametro"] in por_nombre}

    cambios = errores = 0
    for nombre, valor in sorted(deseadas.items()):
        m = meta.get(nombre)
        if m is None:
            print(f"  ?? {nombre}: no tiene metadato en {AMBIENTE}; no se toca.")
            errores += 1
        elif modo_establecer:
            print("ANTES=" + m["valor"])
            # Siempre hace PUT (aunque el valor sea igual): el Catalogo publica el evento y se prueba la idempotencia del Backend.
            s, r = llamar("PUT", f"/metadatos/{m['id']}", {"idAmbiente": m["idAmbiente"], "idParametro": m["idParametro"],
                                                         "idTipoMetadato": m["idTipoMetadato"], "valor": valor})
            print(f"  {'OK' if s == 200 else 'XX'} {nombre}: PUT HTTP {s}")
            cambios += 1
            errores += 0 if s == 200 else 1
        elif m["valor"] == valor:
            print(f"  == {nombre}: el Catalogo ya tiene el valor de los datos de prueba.")
        elif a.simular:
            print(f"  -> {nombre}: el Catalogo difiere (se actualizaria; simulacion).")
            cambios += 1
        else:
            s, r = llamar("PUT", f"/metadatos/{m['id']}", {"idAmbiente": m["idAmbiente"], "idParametro": m["idParametro"],
                                                         "idTipoMetadato": m["idTipoMetadato"], "valor": valor})
            if s == 200:
                print(f"  OK {nombre}: Catalogo actualizado a {valor}")
                cambios += 1
            else:
                print(f"  XX {nombre}: PUT HTTP {s}")
                errores += 1
    print(f"catalogo-parametros: {len(deseadas)} parametro(s) de datos de prueba, {cambios} {'por actualizar' if a.simular else 'actualizado(s)'}, {errores} con error.")
    return 1 if errores else 0


if __name__ == "__main__":
    sys.exit(main())
