-- ============================================================
-- Procedimientos almacenados: dominio estudio / examen.
-- ============================================================

-- Semilla por sesion para que las opciones se desordenen igual
-- aunque el usuario recargue. Aditivo por si aun no existe.
ALTER TABLE sesiones_examen
  ADD COLUMN IF NOT EXISTS semilla VARCHAR(32);

-- El CHECK inicial dimensiono tipo_correccion a 24; algunos valores
-- del enum superan ese limite. Ampliamos por seguridad.
ALTER TABLE test ALTER COLUMN tipo_correccion TYPE VARCHAR(40);

-- Postgres no permite CREATE OR REPLACE si cambia el nombre de las
-- columnas de salida. Dropeamos primero para que la recreacion
-- siempre sea limpia (funciones dependientes se recrean detras).
DROP FUNCTION IF EXISTS sp_test_preguntas_estudio(INT, VARCHAR);
DROP FUNCTION IF EXISTS sp_pregunta_opciones_desordenadas(INT, VARCHAR);

-- ------------------------------------------------------------
-- Utilidad: generar codigo_id de un test siguiendo la convencion
-- de Martin (ver briefing):
--   1CHR   Proceso (digito 1-8)
--   2-4CHR Puesto  (3 letras, ej. BOM, CAB, SAR)
--   5CHR   Entidad (digito 1-5)
--   6CHR   separador '-'
--   7-11CHR Lugar (5 chars, ej. MDMAD para Madrid capital)
--   12-13CHR Año (2 ultimos digitos)
--   14-15CHR Test (T0/T1/T2)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_test_codigo_id_generar(
  p_proceso  SMALLINT,
  p_puesto   VARCHAR,
  p_entidad  SMALLINT,
  p_lugar    VARCHAR,
  p_anio     SMALLINT,
  p_test     VARCHAR
)
RETURNS VARCHAR
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT
    LPAD(p_proceso::text, 1, '0') ||
    UPPER(LPAD(SUBSTRING(p_puesto FROM 1 FOR 3), 3, 'X')) ||
    LPAD(p_entidad::text, 1, '0') ||
    '-' ||
    UPPER(LPAD(SUBSTRING(p_lugar FROM 1 FOR 5), 5, 'X')) ||
    LPAD((p_anio % 100)::text, 2, '0') ||
    UPPER(LPAD(p_test, 2, 'X'));
$$;

-- ------------------------------------------------------------
-- Devuelve las opciones de una pregunta desordenadas respetando
-- posicion_bloqueada. Semilla por sesion para reproducibilidad.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_pregunta_opciones_desordenadas(
  p_pregunta_id INT,
  p_semilla     VARCHAR
)
RETURNS TABLE (
  opcion_id       INT,
  opcion_texto    TEXT,
  opcion_posicion INT
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_total INT;
BEGIN
  SELECT COUNT(*) INTO v_total
    FROM opciones_pregunta
   WHERE pregunta_id = p_pregunta_id;

  RETURN QUERY
  WITH bloqueadas AS (
    SELECT o.id AS oid, o.texto::text AS otxt, o.posicion_bloqueada AS pos
    FROM opciones_pregunta o
    WHERE o.pregunta_id = p_pregunta_id
      AND o.posicion_bloqueada IS NOT NULL
  ),
  libres_ord AS (
    SELECT o.id AS oid, o.texto::text AS otxt,
      ROW_NUMBER() OVER (ORDER BY md5(o.id::text || COALESCE(p_semilla,'')))::int AS rn
    FROM opciones_pregunta o
    WHERE o.pregunta_id = p_pregunta_id
      AND o.posicion_bloqueada IS NULL
  ),
  huecos AS (
    SELECT h AS pos
    FROM generate_series(1, v_total) AS h
    WHERE h NOT IN (SELECT pos FROM bloqueadas)
  ),
  huecos_ord AS (
    SELECT pos, ROW_NUMBER() OVER (ORDER BY pos)::int AS rn FROM huecos
  ),
  libres_asignadas AS (
    SELECT l.oid, l.otxt, h.pos
    FROM libres_ord l
    JOIN huecos_ord h ON h.rn = l.rn
  )
  SELECT t.oid, t.otxt, t.pos
  FROM (
    SELECT oid, otxt, pos FROM bloqueadas
    UNION ALL
    SELECT oid, otxt, pos FROM libres_asignadas
  ) t
  ORDER BY t.pos;
END;
$$;

-- ------------------------------------------------------------
-- Preguntas de un test para MODO ESTUDIO / EXAMEN con opciones
-- desordenadas por semilla. Incluye titulo_url para "de donde
-- viene la pregunta", tematica principal, estado y flags.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_test_preguntas_estudio(
  p_test_id INT,
  p_semilla VARCHAR
)
RETURNS TABLE (
  pregunta_id           INT,
  orden                 SMALLINT,
  texto                 TEXT,
  imagen_url            TEXT,
  es_pregunta_negativa  BOOLEAN,
  estado                VARCHAR,
  explicacion_estado    TEXT,
  titulo_url            VARCHAR,
  url                   TEXT,
  tematicas             JSON,
  opciones              JSON,
  anulada_en_test       BOOLEAN,
  anulada_motivo        TEXT
)
LANGUAGE sql
STABLE
AS $$
  SELECT
    p.id                                                       AS pregunta_id,
    tp.orden,
    p.texto,
    p.imagen_url,
    COALESCE(p.es_pregunta_negativa, FALSE)                    AS es_pregunta_negativa,
    ep.nombre                                                  AS estado,
    p.explicacion_estado,
    p.titulo_url,
    p.url,
    (SELECT COALESCE(json_agg(json_build_object('id', t.id, 'nombre', t.nombre)), '[]'::json)
       FROM tematicas_preguntas tpx
       JOIN tematicas t ON t.id = tpx.tematica_id
      WHERE tpx.pregunta_id = p.id)                             AS tematicas,
    (SELECT COALESCE(json_agg(json_build_object(
              'id', o.opcion_id,
              'texto', o.opcion_texto,
              'posicion', o.opcion_posicion) ORDER BY o.opcion_posicion), '[]'::json)
       FROM sp_pregunta_opciones_desordenadas(p.id, p_semilla) o) AS opciones,
    EXISTS (
      SELECT 1 FROM test_preguntas_anuladas a
      WHERE a.test_id = tp.test_id AND a.pregunta_id = p.id
    )                                                          AS anulada_en_test,
    (SELECT a.motivo FROM test_preguntas_anuladas a
      WHERE a.test_id = tp.test_id AND a.pregunta_id = p.id)   AS anulada_motivo
  FROM test_preguntas tp
  JOIN preguntas          p  ON p.id = tp.pregunta_id
  LEFT JOIN estados_preguntas ep ON ep.id = p.estado_id
  WHERE tp.test_id = p_test_id
  ORDER BY tp.orden;
$$;

-- ------------------------------------------------------------
-- Correccion server-side de UNA respuesta con nivel de detalle
-- segun tipo_correccion del test.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_test_corregir_respuesta_v2(
  p_test_id     INT,
  p_pregunta_id INT,
  p_opcion_id   INT
)
RETURNS TABLE (
  correcta                BOOLEAN,
  tipo_correccion         VARCHAR,
  anulada_en_test         BOOLEAN,
  opcion_correcta_id      INT,
  opcion_correcta_texto   TEXT,
  explicacion_global      TEXT,
  explicacion_especifica  TEXT,
  explicacion_correcta    TEXT
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_tipo VARCHAR;
BEGIN
  SELECT t.tipo_correccion INTO v_tipo FROM test t WHERE t.id = p_test_id;

  RETURN QUERY
  SELECT
    COALESCE(
      (SELECT o.es_correcta FROM opciones_pregunta o
        WHERE o.id = p_opcion_id AND o.pregunta_id = p_pregunta_id),
      FALSE
    )                                                         AS correcta,
    v_tipo                                                    AS tipo_correccion,
    EXISTS (SELECT 1 FROM test_preguntas_anuladas a
             WHERE a.test_id = p_test_id AND a.pregunta_id = p_pregunta_id)
                                                              AS anulada_en_test,
    ok.id                                                     AS opcion_correcta_id,
    ok.texto                                                  AS opcion_correcta_texto,
    p.explicacion_global                                      AS explicacion_global,
    (SELECT o.explicacion_especifica FROM opciones_pregunta o
      WHERE o.id = p_opcion_id AND o.pregunta_id = p_pregunta_id)
                                                              AS explicacion_especifica,
    ok.explicacion_especifica                                 AS explicacion_correcta
  FROM preguntas p
  LEFT JOIN opciones_pregunta ok
    ON ok.pregunta_id = p.id AND ok.es_correcta = TRUE
  WHERE p.id = p_pregunta_id;
END;
$$;

-- ------------------------------------------------------------
-- Marca una pregunta como revisada/no revisada (Martin).
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_pregunta_marcar_revisada(
  p_pregunta_id INT,
  p_revisada    BOOLEAN
)
RETURNS VOID
LANGUAGE sql
AS $$
  UPDATE preguntas
     SET revisada    = p_revisada,
         revisada_at = CASE WHEN p_revisada THEN NOW() ELSE NULL END
   WHERE id = p_pregunta_id;
$$;

-- ------------------------------------------------------------
-- Estadisticas usuario: upsert por respuesta.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_usuario_stats_registrar(
  p_usuario_id  INT,
  p_pregunta_id INT,
  p_acertada    BOOLEAN,
  p_contestada  BOOLEAN
)
RETURNS VOID
LANGUAGE sql
AS $$
  INSERT INTO usuario_pregunta_stats
    (usuario_id, pregunta_id, vistas, aciertos, fallos, no_contestadas, ultima_at)
  VALUES
    (p_usuario_id, p_pregunta_id, 1,
     CASE WHEN p_contestada AND     p_acertada THEN 1 ELSE 0 END,
     CASE WHEN p_contestada AND NOT p_acertada THEN 1 ELSE 0 END,
     CASE WHEN p_contestada THEN 0 ELSE 1 END,
     NOW())
  ON CONFLICT (usuario_id, pregunta_id) DO UPDATE
    SET vistas         = usuario_pregunta_stats.vistas + 1,
        aciertos       = usuario_pregunta_stats.aciertos       + EXCLUDED.aciertos,
        fallos         = usuario_pregunta_stats.fallos         + EXCLUDED.fallos,
        no_contestadas = usuario_pregunta_stats.no_contestadas + EXCLUDED.no_contestadas,
        ultima_at      = NOW();
$$;

-- ------------------------------------------------------------
-- Top preguntas mas falladas por un usuario.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_usuario_stats_top_fallos(
  p_usuario_id INT,
  p_limit      INT
)
RETURNS TABLE (
  pregunta_id INT,
  texto       TEXT,
  fallos      INT,
  aciertos    INT,
  ultima_at   TIMESTAMP
)
LANGUAGE sql
STABLE
AS $$
  SELECT p.id, p.texto, s.fallos, s.aciertos, s.ultima_at
  FROM usuario_pregunta_stats s
  JOIN preguntas p ON p.id = s.pregunta_id
  WHERE s.usuario_id = p_usuario_id
    AND s.fallos > 0
  ORDER BY s.fallos DESC, s.ultima_at DESC
  LIMIT COALESCE(p_limit, 20);
$$;

-- ------------------------------------------------------------
-- Iniciar sesion de estudio o examen. Devuelve id + semilla.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_sesion_iniciar(
  p_usuario_id INT,
  p_test_id    INT,
  p_modo       VARCHAR
)
RETURNS TABLE (
  sesion_id INT,
  semilla   VARCHAR
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_id      INT;
  v_semilla VARCHAR;
BEGIN
  v_semilla := md5(random()::text || clock_timestamp()::text);
  INSERT INTO sesiones_examen (usuario_id, test_id, modo, semilla, total_preguntas)
  SELECT p_usuario_id, p_test_id, COALESCE(p_modo,'examen'), v_semilla, t.num_preguntas
    FROM test t WHERE t.id = p_test_id
  RETURNING id INTO v_id;

  RETURN QUERY SELECT v_id, v_semilla;
END;
$$;

-- ------------------------------------------------------------
-- Detalle completo de una sesion de examen para su correccion final.
-- Devuelve una fila por cada pregunta del test con la respuesta del
-- usuario (si contesto) y el desglose necesario segun tipo_correccion.
-- El calculo de puntuacion final se hace en JS con estas filas y las
-- reglas del test (penalizaciones, nota_apto, nota_maxima).
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_sesion_examen_detalle(p_sesion_id INT)
RETURNS TABLE (
  pregunta_id            INT,
  orden                  SMALLINT,
  pregunta_texto         TEXT,
  es_pregunta_negativa   BOOLEAN,
  anulada_en_test        BOOLEAN,
  estado_pregunta        VARCHAR,
  opcion_elegida_id      INT,
  opcion_elegida_texto   TEXT,
  contestada             BOOLEAN,
  correcta               BOOLEAN,
  opcion_correcta_id     INT,
  opcion_correcta_texto  TEXT,
  explicacion_global     TEXT,
  explicacion_elegida    TEXT,
  explicacion_correcta   TEXT,
  tiempo_ms              INT
)
LANGUAGE sql
STABLE
AS $$
  WITH sesion AS (
    SELECT s.id, s.test_id, s.usuario_id
    FROM sesiones_examen s
    WHERE s.id = p_sesion_id
  )
  SELECT
    p.id                                                     AS pregunta_id,
    tp.orden,
    p.texto                                                  AS pregunta_texto,
    COALESCE(p.es_pregunta_negativa, FALSE)                  AS es_pregunta_negativa,
    EXISTS (SELECT 1 FROM test_preguntas_anuladas a
             WHERE a.test_id = (SELECT test_id FROM sesion)
               AND a.pregunta_id = p.id)                     AS anulada_en_test,
    ep.nombre                                                AS estado_pregunta,
    r.opcion_id                                              AS opcion_elegida_id,
    (SELECT o.texto FROM opciones_pregunta o
      WHERE o.id = r.opcion_id)                              AS opcion_elegida_texto,
    (r.opcion_id IS NOT NULL)                                AS contestada,
    COALESCE(r.es_correcta, FALSE)                           AS correcta,
    ok.id                                                    AS opcion_correcta_id,
    ok.texto                                                 AS opcion_correcta_texto,
    p.explicacion_global                                     AS explicacion_global,
    (SELECT o.explicacion_especifica FROM opciones_pregunta o
      WHERE o.id = r.opcion_id)                              AS explicacion_elegida,
    ok.explicacion_especifica                                AS explicacion_correcta,
    r.tiempo_ms
  FROM test_preguntas tp
  JOIN preguntas p ON p.id = tp.pregunta_id
  LEFT JOIN estados_preguntas ep ON ep.id = p.estado_id
  LEFT JOIN opciones_pregunta ok
    ON ok.pregunta_id = p.id AND ok.es_correcta = TRUE
  LEFT JOIN respuestas_usuario r
    ON r.sesion_id = p_sesion_id AND r.pregunta_id = p.id
  WHERE tp.test_id = (SELECT test_id FROM sesion)
  ORDER BY tp.orden;
$$;

-- ------------------------------------------------------------
-- Guarda (o reemplaza) la respuesta del usuario a una pregunta
-- dentro de una sesion. La sesion permite una unica respuesta por
-- pregunta: si el usuario cambia, se reescribe.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_respuesta_guardar(
  p_sesion_id   INT,
  p_pregunta_id INT,
  p_opcion_id   INT,
  p_es_correcta BOOLEAN,
  p_tiempo_ms   INT
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
  DELETE FROM respuestas_usuario
   WHERE sesion_id = p_sesion_id AND pregunta_id = p_pregunta_id;
  INSERT INTO respuestas_usuario
    (sesion_id, pregunta_id, opcion_id, es_correcta, tiempo_ms)
  VALUES
    (p_sesion_id, p_pregunta_id, p_opcion_id, p_es_correcta, p_tiempo_ms);
END;
$$;

-- ------------------------------------------------------------
-- Verifica que una opcion pertenezca a una pregunta y devuelve
-- si es correcta. Usado por el service para el modo estudio.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_opcion_verificar(
  p_pregunta_id INT,
  p_opcion_id   INT
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
AS $$
  SELECT es_correcta FROM opciones_pregunta
   WHERE id = p_opcion_id AND pregunta_id = p_pregunta_id;
$$;

-- ------------------------------------------------------------
-- Preguntas ya respondidas en una sesion. Usado al finalizar
-- para registrar como "no contestada" a las que faltan.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_sesion_preguntas_respondidas(p_sesion_id INT)
RETURNS TABLE (pregunta_id INT)
LANGUAGE sql
STABLE
AS $$
  SELECT pregunta_id FROM respuestas_usuario WHERE sesion_id = p_sesion_id;
$$;

-- ------------------------------------------------------------
-- Cabecera de una sesion validada por propietario. Devuelve
-- info basica + comprueba que pertenece al usuario indicado.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_sesion_cabecera(
  p_sesion_id INT,
  p_usuario_id INT
)
RETURNS TABLE (
  id             INT,
  usuario_id     INT,
  test_id        INT,
  modo           VARCHAR,
  semilla        VARCHAR,
  iniciada_at    TIMESTAMP,
  finalizada_at  TIMESTAMP,
  es_propietario BOOLEAN
)
LANGUAGE sql
STABLE
AS $$
  SELECT s.id, s.usuario_id, s.test_id, s.modo, s.semilla,
         s.iniciada_at, s.finalizada_at,
         (s.usuario_id = p_usuario_id) AS es_propietario
  FROM sesiones_examen s
  WHERE s.id = p_sesion_id;
$$;

-- ------------------------------------------------------------
-- Totales agregados de un usuario (autodiagnostico).
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_usuario_stats_totales(p_usuario_id INT)
RETURNS TABLE (
  vistas          INT,
  aciertos        INT,
  fallos          INT,
  no_contestadas  INT,
  preguntas_unicas INT
)
LANGUAGE sql
STABLE
AS $$
  SELECT
    COALESCE(SUM(vistas),0)::int         AS vistas,
    COALESCE(SUM(aciertos),0)::int       AS aciertos,
    COALESCE(SUM(fallos),0)::int         AS fallos,
    COALESCE(SUM(no_contestadas),0)::int AS no_contestadas,
    COUNT(DISTINCT pregunta_id)::int     AS preguntas_unicas
  FROM usuario_pregunta_stats
  WHERE usuario_id = p_usuario_id;
$$;

CREATE OR REPLACE FUNCTION sp_usuario_sesiones_resumen(p_usuario_id INT)
RETURNS TABLE (
  total     INT,
  aprobados INT
)
LANGUAGE sql
STABLE
AS $$
  SELECT COUNT(*)::int,
         COUNT(*) FILTER (WHERE aprobado)::int
    FROM sesiones_examen
   WHERE usuario_id = p_usuario_id AND finalizada_at IS NOT NULL;
$$;

-- ------------------------------------------------------------
-- Finalizar sesion: escribe puntuacion, aprobado, finalizada_at.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_sesion_finalizar(
  p_sesion_id     INT,
  p_puntuacion    DECIMAL,
  p_aprobado      BOOLEAN,
  p_tiempo_ms     BIGINT
)
RETURNS VOID
LANGUAGE sql
AS $$
  UPDATE sesiones_examen
     SET puntuacion      = p_puntuacion,
         aprobado        = p_aprobado,
         finalizada_at   = NOW(),
         tiempo_total_ms = p_tiempo_ms
   WHERE id = p_sesion_id;
$$;

-- ------------------------------------------------------------
-- Configuracion de un test (cabecera + reglas de calificacion).
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_test_config(p_id INT)
RETURNS TABLE (
  id                          INT,
  nombre                      VARCHAR,
  descripcion                 TEXT,
  codigo_id                   VARCHAR,
  tipo                        VARCHAR,
  anio                        SMALLINT,
  num_preguntas               INT,
  num_preguntas_reserva       INT,
  tiempo_minutos              INT,
  nota_apto                   DECIMAL,
  nota_maxima                 DECIMAL,
  penalizacion_fallo          DECIMAL,
  penalizacion_no_contestada  DECIMAL,
  tipo_correccion             VARCHAR,
  observaciones               TEXT
)
LANGUAGE sql
STABLE
AS $$
  SELECT t.id, t.nombre, t.descripcion, t.codigo_id, t.tipo, t.anio,
         t.num_preguntas, COALESCE(t.num_preguntas_reserva, 0),
         t.tiempo_minutos, t.nota_apto, t.nota_maxima,
         t.penalizacion_fallo, t.penalizacion_no_contestada,
         t.tipo_correccion, t.observaciones
  FROM test t
  WHERE t.id = p_id
    AND t.publicado = TRUE;
$$;
