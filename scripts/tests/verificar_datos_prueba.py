"""Verificacion por rol de los datos de prueba variados (solo lectura).

Inicia sesion como lo hace el navegador (PKCE contra el cliente de la SPA) con un usuario de cada caso del conjunto
GestioAsistenciaDB/scripts/datos-prueba y comprueba que cada rol ve lo que le corresponde y nada mas.
Requiere el backend en http://127.0.0.1:8080, el laboratorio de Seguridad (lab.env) y ASISTENCIAS_DATASET_PASSWORD.
Uso: python -X utf8 verificar_datos_prueba.py [--backend-repo <ruta GestioAsistenciaBackend>] [--api http://127.0.0.1:8080/api/v1]
Codigo de salida 1 si algun caso no coincide.
"""
import argparse
import json
import os
import sys
import urllib.error
import urllib.request
import uuid

HERE = os.path.dirname(os.path.abspath(__file__))
parser = argparse.ArgumentParser()
parser.add_argument("--backend-repo", default=os.path.join(HERE, "..", "..", "..", "GestioAsistenciaBackend"))
parser.add_argument("--api", default="http://127.0.0.1:8080/api/v1")
args = parser.parse_args()
sys.path.insert(0, os.path.join(os.path.abspath(args.backend_repo), "infra", "security-baseline", "scripts"))
import lab_pdp as L  # noqa: E402
import spa_token  # noqa: E402

NS = uuid.UUID("6f1c2a7e-3b4d-4c5e-9f60-a1b2c3d4e5f6")  # mismo espacio que generar_datos_prueba.py
PW = os.environ.get("ASISTENCIAS_DATASET_PASSWORD")
if not PW:
    raise SystemExit("Defina ASISTENCIAS_DATASET_PASSWORD (contraseña común de laboratorio, AGENTS.md seccion 7).")
env = L.read_env()
GRUPO = {k: str(uuid.uuid5(NS, f"grupo:{k}")) for k in ("PRG-1", "BDA-1")}
_tokens = {}
fallos = []


def token(user):
    if user not in _tokens:
        try:
            _tokens[user] = spa_token.get_token(env, user, PW)["access_token"]
        except (SystemExit, RuntimeError, KeyError):
            _tokens[user] = None
    return _tokens[user]


def get(user, path):
    t = token(user)
    if not t:
        return "sin sesion", None
    req = urllib.request.Request(args.api + path, headers={"Authorization": "Bearer " + t})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status, json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        return e.code, None


def total(body):
    data = (body or {}).get("data", body)
    if isinstance(data, list):
        return len(data)
    if isinstance(data, dict):
        if "totalElementos" in data:
            return data["totalElementos"]
        for k in ("elementos", "content", "items"):
            if isinstance(data.get(k), list):
                return len(data[k])
    return None


def caso(texto, user, path, estado=200, cantidad=None):
    s, body = get(user, path)
    n = total(body)
    ok = s == estado and (cantidad is None or n == cantidad)
    if not ok:
        fallos.append(texto)
    esperado = f"HTTP {estado}" + (f", {cantidad}" if cantidad is not None else "")
    print(f"{'OK' if ok else 'XX'}  {texto:<60} {user:<20} HTTP {s}{'' if n is None else ', ' + str(n)}   (esperado {esperado})")


print("Administrador")
caso("ve las facultades", "uco-administrador", "/admin/facultades")
caso("ve los decanos", "uco-administrador", "/admin/decanos")
print("Decanos (solo su facultad)")
caso("Ingeniería: coordinadores de su facultad", "uco-decano", "/decano/coordinadores", cantidad=4)
caso("Ingeniería: estudiantes (Sistemas, Industrial, Tec. Software)", "uco-decano", "/decano/estudiantes", cantidad=20)
caso("Sociales: estudiantes con grupos de Psicología", "hernan.valencia", "/decano/estudiantes", cantidad=5)
caso("Salud (facultad sin programas): programas", "paula.zuluaga", "/decano/programas")
caso("decano sin facultad no tiene alcance", "andres.ospina", "/decano/programas", estado=403)
print("Coordinadores (solo su programa)")
caso("Sistemas: sus 8 estudiantes", "uco-coordinador", "/coordinador/estudiantes", cantidad=8)
caso("Sistemas: propuesta de cancelación de Santiago", "uco-coordinador", "/coordinador/revisiones-cancelacion", cantidad=1)
caso("Sistemas: 2 solicitudes de sesión pendientes", "uco-coordinador", "/coordinador/sesiones/solicitudes", cantidad=2)
caso("Psicología: sus 6 estudiantes", "lina.agudelo", "/coordinador/estudiantes", cantidad=6)
caso("coordinador sin programa no ve estudiantes", "mauricio.quintero", "/coordinador/estudiantes", cantidad=0)
caso("Diana (coordinadora y docente): grupos de coordinación", "diana.londono", "/coordinador/grupos")
caso("Diana (coordinadora y docente): sus asignaturas", "diana.londono", "/docente/asignaturas")
print("Docentes (solo sus grupos)")
caso("María: sus asignaturas", "uco-docente", "/docente/asignaturas")
caso("María: estudiantes de su grupo de Programación I", "uco-docente", f"/grupos/{GRUPO['PRG-1']}/estudiantes")
caso("María: estudiantes de Bases de Datos (grupo ajeno)", "uco-docente", f"/grupos/{GRUPO['BDA-1']}/estudiantes", estado=403)
caso("Alejandro: revisión pendiente de Brayan", "alejandro.cardenas", "/docente/revisiones-cancelacion", cantidad=1)
caso("Julián (sin grupos): asignaturas", "julian.hoyos", "/docente/asignaturas")
print("Estudiantes")
caso("Carlos: materias", "uco-estudiante", "/estudiante/materias")
caso("Carlos: horario", "uco-estudiante", "/estudiante/horarios")
caso("Santiago: alertas de riesgo y pérdida", "santiago.restrepo", "/estudiante/alertas", cantidad=2)
caso("Mateo: alerta de riesgo", "mateo.giraldo", "/estudiante/alertas", cantidad=1)
caso("Miguel (sin grupos): oferta académica", "miguel.rojas", "/estudiante/oferta-academica")
caso("un estudiante no entra a rutas de docente", "uco-estudiante", "/docente/asignaturas", estado=403)
print("Cuenta inactiva")
inactivo = token("esteban.rendon") is None
if not inactivo:
    fallos.append("cuenta inactiva")
print(f"{'OK' if inactivo else 'XX'}  Esteban (coordinador inactivo) no puede iniciar sesión")
print(f"\n{len(fallos)} diferencias" + (": " + "; ".join(fallos) if fallos else ""))
sys.exit(1 if fallos else 0)
