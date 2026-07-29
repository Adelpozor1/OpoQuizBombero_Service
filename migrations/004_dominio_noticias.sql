-- ============================================================
-- 004 - Dominio noticias (feed del opositor)
-- ============================================================

-- Preferencia del usuario: comunidad autonoma sobre la que quiere el feed.
ALTER TABLE usuarios
  ADD COLUMN IF NOT EXISTS comunidad_id INT REFERENCES comunidades_autonomas(id) ON DELETE SET NULL;

-- Fuentes RSS/scraper que se agregan al feed. Se dan de alta en admin.
CREATE TABLE IF NOT EXISTS fuentes_noticias (
  id           SERIAL PRIMARY KEY,
  nombre       VARCHAR(150) NOT NULL,
  url_rss      TEXT NOT NULL UNIQUE,
  tipo         VARCHAR(20) NOT NULL
    CHECK (tipo IN ('boe','autonomico','ayuntamiento','agregador','manual')),
  comunidad_id INT REFERENCES comunidades_autonomas(id) ON DELETE SET NULL,
  keywords     TEXT,             -- Filtro de relevancia opcional (separado por comas).
  activa       BOOLEAN DEFAULT TRUE,
  ultima_lectura TIMESTAMP,
  created_at   TIMESTAMP DEFAULT NOW()
);

-- Noticias individuales. guid unico por fuente para dedup en la ingesta.
CREATE TABLE IF NOT EXISTS noticias (
  id            SERIAL PRIMARY KEY,
  fuente_id     INT REFERENCES fuentes_noticias(id) ON DELETE SET NULL,
  comunidad_id  INT REFERENCES comunidades_autonomas(id) ON DELETE SET NULL,
  titulo        TEXT NOT NULL,
  resumen       TEXT,
  url           TEXT NOT NULL,
  imagen_url    TEXT,
  guid          TEXT NOT NULL,
  publicada_at  TIMESTAMP NOT NULL,
  created_at    TIMESTAMP DEFAULT NOW(),
  UNIQUE (fuente_id, guid)
);

CREATE INDEX IF NOT EXISTS idx_noticias_comunidad_fecha
  ON noticias (comunidad_id, publicada_at DESC);

CREATE INDEX IF NOT EXISTS idx_noticias_fecha
  ON noticias (publicada_at DESC);
