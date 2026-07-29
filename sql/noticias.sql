-- ============================================================
-- Procedimientos almacenados: dominio noticias
-- ============================================================

-- Listado de noticias para el feed. Si p_comunidad_id es NULL devuelve las
-- nacionales (sin comunidad asignada); si tiene valor devuelve las de esa
-- CCAA + las nacionales. Limita a p_limit.
CREATE OR REPLACE FUNCTION sp_noticias_feed(
  p_comunidad_id INT,
  p_limit        INT
)
RETURNS TABLE (
  id            INT,
  titulo        TEXT,
  resumen       TEXT,
  url           TEXT,
  imagen_url    TEXT,
  publicada_at  TIMESTAMP,
  comunidad_id  INT,
  comunidad     VARCHAR,
  fuente        VARCHAR
)
LANGUAGE sql
STABLE
AS $$
  SELECT
    n.id,
    n.titulo,
    n.resumen,
    n.url,
    n.imagen_url,
    n.publicada_at,
    n.comunidad_id,
    ca.nombre AS comunidad,
    fn.nombre AS fuente
  FROM noticias n
  LEFT JOIN comunidades_autonomas ca ON ca.id = n.comunidad_id
  LEFT JOIN fuentes_noticias      fn ON fn.id = n.fuente_id
  WHERE (
    p_comunidad_id IS NULL
    OR n.comunidad_id = p_comunidad_id
    OR n.comunidad_id IS NULL
  )
  ORDER BY n.publicada_at DESC, n.id DESC
  LIMIT COALESCE(p_limit, 30);
$$;

-- Fuentes activas para el job de ingesta.
CREATE OR REPLACE FUNCTION sp_fuentes_activas()
RETURNS TABLE (
  id           INT,
  nombre       VARCHAR,
  url_rss      TEXT,
  tipo         VARCHAR,
  comunidad_id INT,
  keywords     TEXT
)
LANGUAGE sql
STABLE
AS $$
  SELECT f.id, f.nombre, f.url_rss, f.tipo, f.comunidad_id, f.keywords
  FROM fuentes_noticias f
  WHERE f.activa = TRUE
  ORDER BY f.id;
$$;

-- Insertar noticia. Idempotente por (fuente_id, guid). Devuelve id si inserto,
-- NULL si ya existia (conflict do nothing).
CREATE OR REPLACE FUNCTION sp_noticia_insertar(
  p_fuente_id    INT,
  p_comunidad_id INT,
  p_titulo       TEXT,
  p_resumen      TEXT,
  p_url          TEXT,
  p_imagen_url   TEXT,
  p_guid         TEXT,
  p_publicada_at TIMESTAMP
)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
  v_id INT;
BEGIN
  INSERT INTO noticias (
    fuente_id, comunidad_id, titulo, resumen, url,
    imagen_url, guid, publicada_at
  )
  VALUES (
    p_fuente_id, p_comunidad_id, p_titulo, p_resumen, p_url,
    p_imagen_url, p_guid, p_publicada_at
  )
  ON CONFLICT (fuente_id, guid) DO NOTHING
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

-- Marca la ultima lectura de una fuente (para monitorizar la ingesta).
CREATE OR REPLACE FUNCTION sp_fuente_marcar_lectura(p_fuente_id INT)
RETURNS VOID
LANGUAGE sql
AS $$
  UPDATE fuentes_noticias
  SET ultima_lectura = NOW()
  WHERE id = p_fuente_id;
$$;

-- Cambia la CCAA preferida del usuario.
CREATE OR REPLACE FUNCTION sp_usuario_set_comunidad(
  p_usuario_id INT,
  p_comunidad_id INT
)
RETURNS VOID
LANGUAGE sql
AS $$
  UPDATE usuarios
  SET comunidad_id = p_comunidad_id
  WHERE id = p_usuario_id;
$$;

-- Devuelve el usuario publico incluyendo su comunidad preferida.
CREATE OR REPLACE FUNCTION sp_usuario_publico_por_id_con_comunidad(p_id INT)
RETURNS TABLE (
  id           INT,
  nombre       VARCHAR,
  email        VARCHAR,
  comunidad_id INT,
  comunidad    VARCHAR
)
LANGUAGE sql
STABLE
AS $$
  SELECT u.id, u.nombre, u.email, u.comunidad_id, ca.nombre AS comunidad
  FROM usuarios u
  LEFT JOIN comunidades_autonomas ca ON ca.id = u.comunidad_id
  WHERE u.id = p_id
    AND u.activo = TRUE;
$$;

-- Listado de CCAA para el selector.
CREATE OR REPLACE FUNCTION sp_comunidades_listado()
RETURNS TABLE (
  id         INT,
  nombre     VARCHAR,
  codigo_iso VARCHAR
)
LANGUAGE sql
STABLE
AS $$
  SELECT c.id, c.nombre, c.codigo_iso
  FROM comunidades_autonomas c
  ORDER BY c.nombre;
$$;
