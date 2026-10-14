# PRECHECK SNAPSHOT — LB-001B.4

Fecha: 2026-09-23, zona `America/Bogota`.

## Backend

- Branch: `sergio`
- HEAD: `fa9aa901c73e55ae31071f4e74cfb2245189243a`
- Worktree: sucio, con cambios preexistentes de LB-001B.3; no se revierten.
- `java -version`: Temurin 17.0.18 (PATH del shell; no apto para gate).
- `javac -version`: 17.0.18 (PATH del shell; no apto para gate).
- `mvnw -version`: Maven 3.9.15 usando Oracle Java 25 en `C:\Program Files\Java\jdk-25`.

## Contrato DB encontrado al inicio

- Backend snapshot SHA esperado/actual: `1fd728e43d2bdbdc6b395bc5aad9021105117281c7c18b64afc39a6d45937103` — MATCH.

## Evidencia DB final suministrada por el usuario

- Repo: `C:\Users\josev\OneDrive\Documentos\AsisteciaUco_db\git\gestion-asistencia-db`
- Branch: `feat/db-golden-path-baseline-freeze`
- HEAD: `99190f07436bc64299b7d3a35c8e4486f49f9cd6`
- Contract: `docs/contracts/DB_BASELINE_CONTRACT.md`
- SHA esperado/actual: `45e48c5a0ab321d0c8cbffb55ee224e3b6fd29febc39a62ca723b2b209945aec` — MATCH.
- Limitación: repo DB no limpio; contrato declara `GENERATED_FROM_COMMIT: UNCOMMITTED_WORKTREE`.
- Uso autorizado: lectura documental/snapshot. DB modificada: NO.
