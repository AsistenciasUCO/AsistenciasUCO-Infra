# VAL-oleada3-mensajes (Infra) - PLAN

Fecha: 2026-11-13. Rama `fix/VAL-oleada3-mensajes-catalogo` desde `origin/develop`. Ítem MSG-03 de
`informes/LISTA_CHEQUEO_VALIDACION_2026-11-12.md`: el catálogo de MessageUcoLab tenía 134 códigos y los seeds de la BD 291 (más
107 nuevos de MSG-05 en la semilla 62). Cambio mínimo de herramienta, sin tocar configuración de ambientes.

| Cambio | Archivo |
| :--- | :--- |
| `TYPE_MAP` acepta los tipos que los seeds ya usan (`VALIDATION_ERROR`, `SECURITY_ERROR`, `TECHNICAL_ERROR`, `INFO`); antes el script fallaba con `KeyError` y por eso el fixture del backend no se regeneraba | `components/messages/build-message-catalog.py` |
| `--previo <psv>`: conserva el código remoto ya importado de cada canónico y numera los códigos largos nuevos después del máximo de su prefijo. Sin esto, regenerar renumeraba `ERR022..ERR024` a `ERR021..ERR023` (el hueco de un mensaje retirado) y rompía los alias de `application.yml` y lo ya importado | `components/messages/build-message-catalog.py` |
| Guía: usar `--previo` al regenerar | `docs/hardening/MESSAGE_CATALOG_SWITCH_GUIDE.md` |

Uso con el que se regeneró el fixture del backend (398 mensajes, 26 alias sin cambio):

```
python components/messages/build-message-catalog.py --seed <BD>/schema/seed \
  --previo <BE>/src/test/resources/messageucolab/catalogo-mensajes-usuario.psv \
  --psv <BE>/src/test/resources/messageucolab/catalogo-mensajes-usuario.psv --yaml <tmp>/alias.yml
```

Pendiente operativo (no se hace desde el repositorio): generar el Excel (`--template ... --xlsx`) e importarlo en la instancia de
MessageUcoLab de cada ambiente. `DIS_APP_001` (110 caracteres) queda en la lista "sobre-límite(100)" junto con 14 mensajes previos.
