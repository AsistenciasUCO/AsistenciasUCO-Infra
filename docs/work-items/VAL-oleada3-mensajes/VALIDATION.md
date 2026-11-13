# VAL-oleada3-mensajes (Infra) - VALIDATION

Fecha: 2026-11-13.

| Prueba | Resultado |
| :--- | :--- |
| Script original sobre los seeds actuales | `KeyError` por `VALIDATION_ERROR` (causa del fixture desactualizado) |
| Script con `TYPE_MAP` ampliado, sin `--previo` | 291 mensajes; difiere del fixture en `ERR021..ERR023` (renumeración) |
| Con `--previo` sobre los seeds + semilla 62 | `mensajes=398 alias=26`; los 134 códigos remotos previos se conservan; alias idénticos a `application.yml` del backend |
| `--check` contra el fixture regenerado | `OK ... coincide con los seeds (398 mensajes)` |
| `MessageUcoLabCatalogoTest` (backend) | Verde con 398 |
