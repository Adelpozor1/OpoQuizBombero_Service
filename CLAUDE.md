# CLAUDE.md — OpoQuizBombero_Service (backend)

Reglas de trabajo para cualquier agente que abra este repo. Se mantienen aquí las decisiones no derivables del código.

## Contexto

- Backend Node.js + Express 5 + Postgres 16 en Docker (`docker-compose.yml`).
- Repo del frontend: `https://github.com/Adelpozor1/OpoQuizBombero.git`.
- Ramas: `stg` = desarrollo, `main` = producción. **Nunca push a `main` sin petición explícita** ("sube a producción", "pasa a main", etc.).
- Idioma: **español** para código, comentarios, commits y PRs.

## Regla — Acceso a la base de datos

**Prohibido** escribir sentencias SQL inline dentro de handlers de Express o scripts (`seed.js`, etc.). Todas las consultas van como **procedimientos almacenados** (funciones PostgreSQL) en `sql/<dominio>.sql`.

- Convención: nombre con prefijo `sp_`, agrupados por dominio (`usuarios.sql`, `preguntas.sql`, `refresh_tokens.sql`, `noticias.sql`…).
- Idempotentes con `CREATE OR REPLACE FUNCTION`.
- Errores de negocio: `RAISE EXCEPTION` con `ERRCODE` estándar de Postgres (`23505` unique_violation, etc.) y detección de `err.code` en el JS.
- Solo devolver usuarios/registros válidos: p.ej. `sp_usuario_buscar_por_email` filtra `activo = TRUE`.
- La carpeta `sql/` está montada como `3-sql` en el `docker-entrypoint-initdb.d` y se aplica automáticamente en primer arranque vía `00_run_subdirs.sh`. En BDs ya inicializadas, reaplicar manualmente:
  ```bash
  docker exec -i opoquiz_db psql -U opoquiz_user -d opoquiz < sql/<archivo>.sql
  ```

Uso desde el JS:
- Function que devuelve filas: `db.query("SELECT * FROM sp_xxx($1, ...)", [...])`.
- Function que devuelve valor único / hace acción: `db.query("SELECT sp_xxx($1, ...)", [...])`.

## Regla — Seguridad de endpoints públicos

Endpoints públicos (login/register) endurecidos:

- **`helmet()`** aplicado globalmente (CSP, HSTS, X-Frame-Options, X-Content-Type…).
- **CORS** configurable por env (`CORS_ORIGIN`), nunca hardcodeado; `credentials: true` para que la cookie refresh viaje cross-origin.
- **`express.json({ limit: "10kb" })`** contra payload DoS.
- **`trust proxy`** por env (`TRUST_PROXY`) para que el rate limit vea IP real detrás de reverse proxy.
- **`express-rate-limit`**: login 5/15min por IP; register 5/1h por IP. Handler devuelve 429 con mensaje genérico y loguea.
- **Validación estricta** en `api/base_de_datos/_seguridad.js`: email regex + normalización a lowercase, password 8-128, nombre 1-100, tipos.
- **Anti user-enumeration**: en login, `bcrypt.compare` se ejecuta **siempre** contra un hash dummy si el usuario no existe, y hay delay mínimo constante (~250ms). Mensajes idénticos ("Credenciales incorrectas") para "no existe" y "password mal".
- **Bcrypt** con cost configurable por env (`BCRYPT_COST`, por defecto 12).
- **Nunca** revelar diferencias entre "usuario no existe" y "password mal" en respuestas de login.

Variables de entorno documentadas en `.env.example`.

## Regla — Sesión / autenticación

Sesión basada en JWT + refresh cookie. El backend nunca acepta tokens en `localStorage`; solo `Authorization: Bearer` (access) y cookie HTTPOnly (refresh).

- **Access token JWT** (HS256, expira en `JWT_ACCESS_EXPIRES`, default `15m`). Firmado y verificado en `api/base_de_datos/_tokens.js`.
- **Refresh token opaco** (48 bytes aleatorios, `base64url`). En **cookie HTTPOnly** (`refresh_token`), `SameSite=Strict`, `Secure` en prod (`COOKIE_SECURE=true`), `Path=/api/base_de_datos`. En la BD solo se guarda el **hash SHA256**.
- **Rotación en cada `/UserRefresh`**: se revoca el anterior y se emite uno nuevo. Reuso de un token viejo → 401.
- **Logout**: `/UserLogout` revoca el refresh de esa sesión y borra la cookie.
- Endpoints protegidos: usar el middleware `authRequired` de `api/base_de_datos/_tokens.js`.
- Variables de entorno obligatorias: `JWT_SECRET` (≥32 chars, generar con `crypto.randomBytes(48)`), `COOKIE_SECURE`, `COOKIE_SAMESITE`.

## Ingesta de noticias (feed portal)

- Fuentes RSS/scraper viven en `fuentes_noticias`. Ingesta manual: `POST /admin/ingesta/run`.
- Servicio: `services/ingesta_noticias.js` con `rss-parser`. Filtra por `keywords` opcional de la fuente y hace dedup por `(fuente_id, guid)`.
- Añadir fuentes nuevas dando de alta filas en `fuentes_noticias` (por seed o por endpoint admin cuando exista).

## Convocatoria rápida — hacer y no hacer

**Hacer**
- Añadir procedures nuevos en `sql/<dominio>.sql` antes de tocar el router.
- Añadir rate limit y validación a cualquier endpoint público nuevo.
- Reusar `_seguridad.js` y `_tokens.js` para no duplicar reglas.

**No hacer**
- SQL inline en JS.
- Password/secretos en el código (van a `.env`).
- Push a `main` sin autorización explícita.
- Revelar en respuestas de login si el email existe.
