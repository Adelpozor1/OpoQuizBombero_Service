-- ============================================================
-- 001 - Tablas base (estructura original adaptada a PostgreSQL)
-- ============================================================

CREATE TABLE IF NOT EXISTS tematicas (
  id          SERIAL PRIMARY KEY,
  nombre      VARCHAR(100) NOT NULL,
  descripcion TEXT
);

CREATE TABLE IF NOT EXISTS categorias (
  id          SERIAL PRIMARY KEY,
  nombre      VARCHAR(100) NOT NULL,
  descripcion TEXT
);

CREATE TABLE IF NOT EXISTS entidades (
  id     SERIAL PRIMARY KEY,
  nombre VARCHAR(150) NOT NULL
);

CREATE TABLE IF NOT EXISTS fuentes (
  id     SERIAL PRIMARY KEY,
  nombre VARCHAR(150) NOT NULL,
  url    TEXT
);

CREATE TABLE IF NOT EXISTS estados_preguntas (
  id     SERIAL PRIMARY KEY,
  nombre VARCHAR(50) NOT NULL UNIQUE
);

INSERT INTO estados_preguntas (nombre) VALUES
  ('activa'),
  ('inactiva'),
  ('revision')
ON CONFLICT (nombre) DO NOTHING;

CREATE TABLE IF NOT EXISTS supuestos (
  id           SERIAL PRIMARY KEY,
  titulo       VARCHAR(200),
  descripcion  TEXT,
  categoria_id INT REFERENCES categorias(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS procesos (
  id          SERIAL PRIMARY KEY,
  nombre      VARCHAR(200) NOT NULL,
  anio        SMALLINT,
  entidad_id  INT REFERENCES entidades(id) ON DELETE SET NULL,
  created_at  TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS preguntas (
  id          SERIAL PRIMARY KEY,
  texto       TEXT NOT NULL,
  imagen_url  TEXT,
  dificultad  SMALLINT DEFAULT 1 CHECK (dificultad BETWEEN 1 AND 3),
  estado_id   INT REFERENCES estados_preguntas(id) ON DELETE SET NULL,
  fuente_id   INT REFERENCES fuentes(id) ON DELETE SET NULL,
  supuesto_id INT REFERENCES supuestos(id) ON DELETE SET NULL,
  proceso_id  INT REFERENCES procesos(id) ON DELETE SET NULL,
  created_at  TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS opciones_pregunta (
  id          SERIAL PRIMARY KEY,
  pregunta_id INT NOT NULL REFERENCES preguntas(id) ON DELETE CASCADE,
  texto       TEXT NOT NULL,
  es_correcta BOOLEAN DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS test (
  id             SERIAL PRIMARY KEY,
  nombre         VARCHAR(200) NOT NULL,
  descripcion    TEXT,
  proceso_id     INT REFERENCES procesos(id) ON DELETE SET NULL,
  num_preguntas  INT DEFAULT 30,
  created_at     TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS tematicas_preguntas (
  tematica_id INT NOT NULL REFERENCES tematicas(id) ON DELETE CASCADE,
  pregunta_id INT NOT NULL REFERENCES preguntas(id) ON DELETE CASCADE,
  PRIMARY KEY (tematica_id, pregunta_id)
);
