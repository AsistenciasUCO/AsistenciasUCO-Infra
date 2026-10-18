# 🗺️ Mapa de Relación de Archivos y Arquitectura End-to-End

Este documento detalla la interconexión y flujo de llamadas exacto entre los archivos de las 3 capas del ecosistema **Gestión de Asistencia UCO**:
1. **Frontend (Angular 19 / Signals)**
2. **Backend (Spring Boot 4 / Clean Architecture & Hexagonal)**
3. **Base de Datos (SQL Server 2022+ / Stored Procedures & Vistas)**

---

## 1. Visión Macro: Flujo Canónico Hexagonal

El sistema sigue de forma estricta el patrón de **Puertos y Adaptadores (Arquitectura Hexagonal)**. Toda interacción transaccional atraviesa las capas sin saltos indebidos ni dependencias circulares:

```mermaid
flowchart LR
    subgraph FRONTEND["Frontend Angular 19"]
        direction TB
        COMP["Componentes .component.ts<br/>OnPush y Signals"]
        SERV["Servicios *.service.ts<br/>HttpClient"]
        COMP --> SERV
    end

    subgraph BACKEND["Backend Spring Boot 4.0.6"]
        direction TB
        subgraph INFRA_IN["Infrastructure - Primary"]
            CTRL["Controller.java<br/>RestController"]
        end

        subgraph CORE["Application Core"]
            PORT_IN["PrimaryPort Port.java<br/>Contrato Entrada"]
            UC["UseCaseImpl.java<br/>Lógica de Negocio"]
            PORT_OUT["SecondaryPort Port.java<br/>Contrato Persistencia"]
            
            PORT_IN --> UC
            UC --> PORT_OUT
        end

        subgraph INFRA_OUT["Infrastructure - Secondary"]
            REPO["RepositorySqlServer*Adapter.java<br/>Spring Data JPA / JDBC legacy"]
        end

        CTRL --> PORT_IN
        PORT_OUT --> REPO
    end

    subgraph DB["Base de Datos SQL Server"]
        direction TB
        SP["Stored Procedures usp_*<br/>Transaccionalidad y ACID"]
        VISTA["Vistas uv_*<br/>Lecturas consolidadas"]
        TABLA["Tablas Físicas<br/>DDL"]
        
        SP --> TABLA
        VISTA --> TABLA
    end

    SERV -->|HTTP REST JSON| CTRL
    REPO -->|EXEC usp_*| SP
    REPO -->|SELECT uv_*| VISTA
```

---

## 2. Diagrama Detallado: Módulo de Asistencias y Control de Sesión

Este módulo gestiona la toma de asistencia manual, el registro de novedades, el auto-registro de estudiantes y la justificación de inasistencias.

```mermaid
flowchart TD
    %% FRONTEND
    subgraph FE_ASISTENCIA["Frontend: Attendance Module"]
        AC_COMP["attendance-control.component.ts"]
        ACT_COMP["attendance-control-table.component.ts"]
        AEX_COMP["attendance-excuse-modal.component.ts"]
        AS_SERV["attendance.service.ts"]
        SS_SERV["session.service.ts"]
        
        AC_COMP --> ACT_COMP
        AC_COMP --> AEX_COMP
        ACT_COMP --> AS_SERV
        AC_COMP --> SS_SERV
    end

    %% BACKEND
    subgraph BE_ASISTENCIA["Backend: Asistencia y Sesion"]
        subgraph BE_CTRL["Controladores REST"]
            A_CTRL["AttendanceController.java"]
            S_CTRL["SessionController.java"]
        end

        subgraph BE_CORE["Casos de Uso Application Core"]
            R_PORT["RegistrarAsistenciasSesionPort.java"]
            R_UC["RegistrarAsistenciasSesionUseCaseImpl.java"]
            R_SEC["AttendanceRepositoryPort.java"]
            
            CS_PORT["CrearSesionPort.java"]
            CS_UC["CrearSesionUseCaseImpl.java"]
            CS_SEC["SessionRepositoryPort.java"]

            R_PORT --> R_UC
            R_UC --> R_SEC
            CS_PORT --> CS_UC
            CS_UC --> CS_SEC
        end

        subgraph BE_ADAPT["Adaptadores de Persistencia"]
            A_ADAPTER["AttendanceRepositorySqlServerAdapter.java"]
            S_ADAPTER["SessionRepositorySqlServerAdapter.java"]
        end

        A_CTRL --> R_PORT
        S_CTRL --> CS_PORT
        R_SEC --> A_ADAPTER
        CS_SEC --> S_ADAPTER
    end

    %% BASE DE DATOS
    subgraph DB_ASISTENCIA["SQL Server: Persistencia y Reglas"]
        SP_REG_MASIVO["usp_registrar_asistencias_sesion.sql"]
        SP_REG_INDIV["usp_registrar_asistencia_estudiante.sql"]
        SP_CREAR_SESION["usp_crear_sesion.sql"]
        
        T_ASISTENCIA["Tabla: Asistencia"]
        T_SESION["Tabla: Sesion"]
        V_ASISTENCIA["Vista: uv_asistencia_sesion.sql"]
        V_SESION["Vista: uv_sesion.sql"]

        A_ADAPTER -->|EXEC| SP_REG_MASIVO
        SP_REG_MASIVO -->|Llama| SP_REG_INDIV
        SP_REG_INDIV -->|INSERT / UPDATE| T_ASISTENCIA

        S_ADAPTER -->|EXEC| SP_CREAR_SESION
        SP_CREAR_SESION -->|INSERT| T_SESION
        
        A_ADAPTER -->|SELECT| V_ASISTENCIA
        S_ADAPTER -->|SELECT| V_SESION
        V_ASISTENCIA --> T_ASISTENCIA
        V_SESION --> T_SESION
    end

    AS_SERV -->|POST asistencias por sesion| A_CTRL
    SS_SERV -->|POST sesiones| S_CTRL
```

---

## 3. Diagrama Detallado: Módulo de Docente y Gestión de Grupos

Mapea la administración de grupos, generación de sesiones semanales, proyección de códigos QR dinámicos y reportes de sábana.

```mermaid
flowchart TD
    %% FRONTEND
    subgraph FE_DOCENTE["Frontend: Teacher Module"]
        TG_COMP["teacher-grupos.component.ts"]
        TGH_COMP["teacher-grupo-hub.component.ts"]
        TGS_COMP["teacher-grupo-sesiones.component.ts"]
        TGQR_COMP["teacher-proyeccion-qr-modal.component.ts"]
        
        CRS_SERV["course.service.ts"]
        GRP_SERV["group.service.ts"]
        SES_SERV["session.service.ts"]

        TG_COMP --> TGH_COMP
        TGH_COMP --> TGS_COMP
        TGH_COMP --> TGQR_COMP
        
        TG_COMP --> CRS_SERV
        TGS_COMP --> SES_SERV
        TG_COMP --> GRP_SERV
    end

    %% BACKEND
    subgraph BE_DOCENTE["Backend: Docente y Grupo"]
        subgraph BE_PORTAL_CTRL["Controladores Docente"]
            DP_CTRL["DocentePortalController.java"]
            GRP_CTRL["GrupoController.java"]
        end

        subgraph BE_PORTAL_CORE["Logica de Negocio"]
            GDP_PORT["ConsultarGruposDocentePort.java"]
            GDP_UC["ConsultarGruposDocenteUseCaseImpl.java"]
            GDP_SEC["DocentePortalRepositoryPort.java"]

            GEN_PORT["GenerarSesionesGrupoPort.java"]
            GEN_UC["GenerarSesionesGrupoUseCaseImpl.java"]
            GEN_SEC["GrupoRepositoryPort.java"]

            GDP_PORT --> GDP_UC
            GDP_UC --> GDP_SEC
            GEN_PORT --> GEN_UC
            GEN_UC --> GEN_SEC
        end

        subgraph BE_PORTAL_ADAPT["Adaptadores SQL"]
            DP_ADAPTER["DocentePortalRepositorySqlServerAdapter.java"]
            GRP_ADAPTER["GrupoRepositorySqlServerAdapter.java"]
        end

        DP_CTRL --> GDP_PORT
        GRP_CTRL --> GEN_PORT
        GDP_SEC --> DP_ADAPTER
        GEN_SEC --> GRP_ADAPTER
    end

    %% BASE DE DATOS
    subgraph DB_DOCENTE["SQL Server: Grupos y Sesiones"]
        SP_GEN_SES["usp_generar_sesiones_grupo.sql"]
        SP_ACT_GRP["usp_actualizar_grupo.sql"]
        
        T_GRUPO["Tabla: Grupo"]
        T_HORARIO["Tabla: HorarioGrupo"]
        T_SESIONES["Tabla: Sesion"]
        
        V_GRP_DOC["Vista: uv_grupo_docente_portal.sql"]
        V_ESTADISTICA["Vista: uv_estadistica_grupo.sql"]

        GRP_ADAPTER -->|EXEC| SP_GEN_SES
        GRP_ADAPTER -->|EXEC| SP_ACT_GRP
        DP_ADAPTER -->|SELECT| V_GRP_DOC
        DP_ADAPTER -->|SELECT| V_ESTADISTICA

        SP_GEN_SES -->|Inserta semanas| T_SESIONES
        SP_ACT_GRP -->|Actualiza grupo| T_GRUPO
    end

    CRS_SERV -->|GET docente-portal grupos| DP_CTRL
    GRP_SERV -->|POST generar sesiones| GRP_CTRL
```

---

## 4. Diagrama Detallado: Módulo de Coordinación y Matrícula

Mapea la administración de programas, asignaturas, matrícula de alumnos y validaciones de cruce de horario.

```mermaid
flowchart TD
    %% FRONTEND
    subgraph FE_COORD["Frontend: Coordinator Module"]
        CD_COMP["coordinator-docentes.component.ts"]
        CS_COMP["coordinator-students.component.ts"]
        CSP_COMP["coordinator-study-plans.component.ts"]
        
        COORD_SERV["coordinator-management.service.ts"]
        
        CD_COMP --> COORD_SERV
        CS_COMP --> COORD_SERV
        CSP_COMP --> COORD_SERV
    end

    %% BACKEND
    subgraph BE_COORD["Backend: Coordinacion"]
        C_CTRL["CoordinadorPortalController.java"]
        
        subgraph BE_COORD_UC["Casos de Uso"]
            REG_EST_PORT["RegistrarEstudianteGrupoPort.java"]
            REG_EST_UC["RegistrarEstudianteGrupoUseCaseImpl.java"]
            REG_EST_SEC["CoordinadorRepositoryPort.java"]

            REG_EST_PORT --> REG_EST_UC
            REG_EST_UC --> REG_EST_SEC
        end

        C_ADAPTER["CoordinadorPortalRepositorySqlServerAdapter.java"]

        C_CTRL --> REG_EST_PORT
        REG_EST_SEC --> C_ADAPTER
    end

    %% BASE DE DATOS
    subgraph DB_COORD["SQL Server: Coordinacion"]
        SP_MATRICULA["usp_registrar_estudiante_en_grupo.sql"]
        SP_VAL_CRUCE["usp_validar_cruce_horario_estudiante_interno.sql"]
        SP_VAL_CUPO["usp_validar_cupo_disponible_grupo_interno.sql"]
        
        T_EST_GRUPO["Tabla: EstudianteGrupo"]
        V_COORD_PROG["Vista: uv_coordinador_programas.sql"]

        C_ADAPTER -->|EXEC| SP_MATRICULA
        SP_MATRICULA --> SP_VAL_CUPO
        SP_MATRICULA --> SP_VAL_CRUCE
        SP_MATRICULA -->|INSERT| T_EST_GRUPO
        C_ADAPTER -->|SELECT| V_COORD_PROG
    end

    COORD_SERV -->|POST coordinador matriculas| C_CTRL
```

---

## 5. Diagrama Detallado: Autenticación, Seguridad y Realtime SSE

Muestra la sincronización de sesión, validación de JWT, suscripción reactiva a Server-Sent Events y trazabilidad OTLP.

```mermaid
flowchart TD
    %% FRONTEND
    subgraph FE_AUTH["Frontend: Core Services e Interceptors"]
        AUTH_SERV["auth.service.ts<br/>Signals en memoria"]
        AUTH_INT["auth.interceptor.ts<br/>Bearer Token y withCredentials"]
        SSE_SERV["realtime.service.ts<br/>EventSource reactivo"]
        ERR_INT["error.interceptor.ts<br/>Manejo 401 y 403"]
    end

    %% BACKEND
    subgraph BE_SECURITY["Backend: Security y Observability"]
        JWT_FILTER["JwtAuthenticationFilter.java<br/>Valida Claims y Perfiles"]
        CORR_FILTER["CorrelationIdFilter.java<br/>Inyecta X-Correlation-Id"]
        SSE_CTRL["RealtimeSseController.java<br/>realtime stream"]
        SCOPE_SRV["UserScopeService.java<br/>Valida jurisdiccion del rol"]
        OTEL_CTX["CorrelationIdContext.java<br/>Trazabilidad distribuida"]
    end

    %% BASE DE DATOS
    subgraph DB_AUTH["SQL Server: Seguridad RBAC"]
        SP_RBAC["usp_validar_permiso_rbac_usuario_interno.sql"]
        SP_TITULAR["usp_validar_titularidad_jerarquica_interno.sql"]
        T_USUARIO["Tabla: Usuario"]
        T_PERFIL["Tabla: Perfil"]

        SP_RBAC --> T_PERFIL
        SP_RBAC --> T_USUARIO
    end

    AUTH_INT -->|HTTP Request con Bearer JWT| CORR_FILTER
    CORR_FILTER --> OTEL_CTX
    CORR_FILTER --> JWT_FILTER
    JWT_FILTER --> SCOPE_SRV
    SSE_SERV -->|SSE Stream Connection| SSE_CTRL
    SCOPE_SRV -.->|Verificacion de permiso| SP_RBAC
```

---

## 6. Convenciones de Nomenclatura del Sistema

| Capa | Artefacto | Convención de Nombre | Ejemplo Real |
| :--- | :--- | :--- | :--- |
| **Frontend** | Componente UI | `<nombre>.component.ts` | `attendance-control.component.ts` |
| **Frontend** | Servicio API | `<entidad>.service.ts` | `attendance.service.ts` |
| **Backend** | Controlador REST | `<Entidad>Controller.java` | `AttendanceController.java` |
| **Backend** | Puerto Primario | `<Accion><Entidad>Port.java` | `RegistrarAsistenciasSesionPort.java` |
| **Backend** | Caso de Uso | `<Accion><Entidad>UseCaseImpl.java` | `RegistrarAsistenciasSesionUseCaseImpl.java` |
| **Backend** | Puerto Secundario | `<Entidad>RepositoryPort.java` | `AttendanceRepositoryPort.java` |
| **Backend** | Adaptador SQL | `<Entidad>RepositorySqlServerAdapter.java` | `AttendanceRepositorySqlServerAdapter.java` |
| **DB** | Stored Procedure Público | `usp_<accion>_<entidad>.sql` | `usp_registrar_asistencias_sesion.sql` |
| **DB** | Stored Procedure Interno | `usp_<accion>_<entidad>_interno.sql` | `usp_validar_cupo_disponible_grupo_interno.sql` |
| **DB** | Vista Consolidada | `uv_<entidad>.sql` | `uv_asistencia_sesion.sql` |
| **DB** | Tabla Física | `<Entidad>.sql` (PascalCase) | `Asistencia.sql`, `Sesion.sql` |
