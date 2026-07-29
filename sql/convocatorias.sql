-- ============================================================
-- Procedimientos almacenados: dominio convocatorias (mapa)
-- ============================================================

-- Recuento de convocatorias PROXIMAS por comunidad autonoma. Se consideran
-- proximas las de año >= año actual. Devuelve una fila por cada CCAA (19),
-- con 0 si no hay convocatoria proxima. Se usa para colorear el mapa.
-- TODO cuando existan fechas concretas: filtrar por fecha_examen >= CURRENT_DATE.
CREATE OR REPLACE FUNCTION sp_convocatorias_recuento_por_comunidad()
RETURNS TABLE (
  comunidad_id     INT,
  codigo_iso       VARCHAR,
  nombre           VARCHAR,
  total            INT,
  plazas           INT,
  ultimo_anio      SMALLINT
)
LANGUAGE sql
STABLE
AS $$
  SELECT
    ca.id                         AS comunidad_id,
    ca.codigo_iso,
    ca.nombre,
    COUNT(c.id)::int              AS total,
    COALESCE(SUM(c.plazas), 0)::int AS plazas,
    MAX(c.anio)                    AS ultimo_anio
  FROM comunidades_autonomas ca
  LEFT JOIN convocatorias c
    ON c.comunidad_id = ca.id
   AND c.anio >= EXTRACT(YEAR FROM CURRENT_DATE)::smallint
  GROUP BY ca.id, ca.codigo_iso, ca.nombre
  ORDER BY ca.nombre;
$$;

-- Detalle de convocatorias PROXIMAS de UNA CCAA (para el panel del mapa).
-- Mismo criterio: anio >= año actual.
CREATE OR REPLACE FUNCTION sp_convocatorias_de_comunidad(p_comunidad_id INT)
RETURNS TABLE (
  id           INT,
  nombre       VARCHAR,
  anio         SMALLINT,
  plazas       INT,
  escala       VARCHAR,
  entidad      VARCHAR,
  url_oficial  TEXT
)
LANGUAGE sql
STABLE
AS $$
  SELECT
    c.id,
    c.nombre,
    c.anio,
    c.plazas,
    e.nombre       AS escala,
    en.nombre      AS entidad,
    c.url_oficial
  FROM convocatorias c
  LEFT JOIN escalas   e  ON e.id  = c.escala_id
  LEFT JOIN entidades en ON en.id = c.entidad_id
  WHERE c.comunidad_id = p_comunidad_id
    AND c.anio >= EXTRACT(YEAR FROM CURRENT_DATE)::smallint
  ORDER BY c.anio ASC NULLS LAST, c.id DESC;
$$;
