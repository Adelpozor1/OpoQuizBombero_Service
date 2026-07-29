-- ============================================================
-- Procedimientos almacenados: dominio tests / preguntas
-- Todos idempotentes (CREATE OR REPLACE).
-- ============================================================

-- Listado publico de tests disponibles.
CREATE OR REPLACE FUNCTION sp_tests_listado()
RETURNS TABLE (
  id            INT,
  nombre        VARCHAR,
  descripcion   TEXT,
  tipo          VARCHAR,
  anio          SMALLINT,
  num_preguntas INT
)
LANGUAGE sql
STABLE
AS $$
  SELECT t.id, t.nombre, t.descripcion, t.tipo, t.anio, t.num_preguntas
  FROM test t
  WHERE t.publicado = TRUE
  ORDER BY t.anio DESC NULLS LAST, t.id;
$$;

-- Cabecera de un test (sin las preguntas).
CREATE OR REPLACE FUNCTION sp_test_por_id(p_id INT)
RETURNS TABLE (
  id            INT,
  nombre        VARCHAR,
  descripcion   TEXT,
  tipo          VARCHAR,
  anio          SMALLINT,
  num_preguntas INT
)
LANGUAGE sql
STABLE
AS $$
  SELECT t.id, t.nombre, t.descripcion, t.tipo, t.anio, t.num_preguntas
  FROM test t
  WHERE t.id = p_id
    AND t.publicado = TRUE;
$$;

-- Preguntas de un test con sus opciones. Devuelve la lista de opciones
-- como JSON sin el flag es_correcta (no se filtra al cliente).
CREATE OR REPLACE FUNCTION sp_test_preguntas(p_test_id INT)
RETURNS TABLE (
  pregunta_id INT,
  orden       SMALLINT,
  texto       TEXT,
  opciones    JSON
)
LANGUAGE sql
STABLE
AS $$
  SELECT
    p.id AS pregunta_id,
    tp.orden,
    p.texto,
    (
      SELECT json_agg(json_build_object('id', o.id, 'texto', o.texto) ORDER BY o.id)
      FROM opciones_pregunta o
      WHERE o.pregunta_id = p.id
    ) AS opciones
  FROM test_preguntas tp
  JOIN preguntas p ON p.id = tp.pregunta_id
  WHERE tp.test_id = p_test_id
  ORDER BY tp.orden;
$$;

-- Correccion server-side de UNA respuesta. Devuelve si fue correcta,
-- la opcion correcta (id + texto) y la explicacion de la pregunta.
-- Si la opcion no pertenece a la pregunta, correcta = FALSE.
CREATE OR REPLACE FUNCTION sp_test_corregir_respuesta(
  p_pregunta_id INT,
  p_opcion_id   INT
)
RETURNS TABLE (
  correcta            BOOLEAN,
  opcion_correcta_id  INT,
  opcion_correcta_txt TEXT,
  explicacion         TEXT
)
LANGUAGE sql
STABLE
AS $$
  SELECT
    COALESCE(
      (SELECT o.es_correcta
       FROM opciones_pregunta o
       WHERE o.id = p_opcion_id AND o.pregunta_id = p_pregunta_id),
      FALSE
    ) AS correcta,
    ok.id   AS opcion_correcta_id,
    ok.texto AS opcion_correcta_txt,
    p.explicacion
  FROM preguntas p
  LEFT JOIN opciones_pregunta ok
    ON ok.pregunta_id = p.id AND ok.es_correcta = TRUE
  WHERE p.id = p_pregunta_id;
$$;
