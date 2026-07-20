-- ============================================================
-- 003 - Dominio bomberos
-- ============================================================

CREATE TABLE IF NOT EXISTS comunidades_autonomas (
  id          SERIAL PRIMARY KEY,
  nombre      VARCHAR(80) NOT NULL UNIQUE,
  codigo_iso  VARCHAR(6)  NOT NULL UNIQUE   -- ES-MD, ES-CT, ES-AN...
);

CREATE TABLE IF NOT EXISTS escalas (
  id     SERIAL PRIMARY KEY,
  nombre VARCHAR(60) NOT NULL UNIQUE,
  orden  SMALLINT NOT NULL                  -- 1=bombero, 2=cabo, 3=sargento, 4=oficial...
);

CREATE TABLE IF NOT EXISTS convocatorias (
  id             SERIAL PRIMARY KEY,
  nombre         VARCHAR(200) NOT NULL,      -- "Ayto. Madrid Bombero 2024"
  comunidad_id   INT NOT NULL REFERENCES comunidades_autonomas(id) ON DELETE RESTRICT,
  escala_id      INT NOT NULL REFERENCES escalas(id) ON DELETE RESTRICT,
  entidad_id     INT REFERENCES entidades(id) ON DELETE SET NULL,   -- ayto/consorcio
  anio           SMALLINT NOT NULL,
  plazas         INT,
  url_oficial    TEXT,
  created_at     TIMESTAMP DEFAULT NOW(),
  UNIQUE (nombre, anio)
);

-- Ampliar preguntas: explicacion y comunidad de origen
ALTER TABLE preguntas
  ADD COLUMN IF NOT EXISTS explicacion TEXT,
  ADD COLUMN IF NOT EXISTS convocatoria_id INT REFERENCES convocatorias(id) ON DELETE SET NULL;

-- Ampliar test: vincular a filtros
ALTER TABLE test
  ADD COLUMN IF NOT EXISTS comunidad_id INT REFERENCES comunidades_autonomas(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS escala_id    INT REFERENCES escalas(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS tipo         VARCHAR(20) DEFAULT 'oficial'
    CHECK (tipo IN ('oficial','tematico','aleatorio')),
  ADD COLUMN IF NOT EXISTS anio         SMALLINT,
  ADD COLUMN IF NOT EXISTS publicado    BOOLEAN DEFAULT TRUE;

-- Relacion N:M test <-> preguntas (los tests oficiales tienen preguntas fijas)
CREATE TABLE IF NOT EXISTS test_preguntas (
  test_id     INT NOT NULL REFERENCES test(id) ON DELETE CASCADE,
  pregunta_id INT NOT NULL REFERENCES preguntas(id) ON DELETE CASCADE,
  orden       SMALLINT NOT NULL,
  PRIMARY KEY (test_id, pregunta_id)
);

CREATE INDEX IF NOT EXISTS idx_test_filtros ON test (comunidad_id, escala_id, tipo, anio);
CREATE INDEX IF NOT EXISTS idx_preguntas_convocatoria ON preguntas (convocatoria_id);
CREATE INDEX IF NOT EXISTS idx_tematicas_preguntas_p ON tematicas_preguntas (pregunta_id);
