-- ============================================================
-- 002 - Tablas nuevas (usuarios, autenticación, exámenes)
-- ============================================================

CREATE TABLE IF NOT EXISTS usuarios (
  id         SERIAL PRIMARY KEY,
  nombre     VARCHAR(100) NOT NULL,
  email      VARCHAR(150) UNIQUE NOT NULL,
  password   VARCHAR(255) NOT NULL,
  activo     BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS refresh_tokens (
  id         SERIAL PRIMARY KEY,
  usuario_id INT NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
  token      TEXT UNIQUE NOT NULL,
  expires_at TIMESTAMP NOT NULL,
  revocado   BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS sesiones_examen (
  id               SERIAL PRIMARY KEY,
  usuario_id       INT NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
  test_id          INT REFERENCES test(id) ON DELETE SET NULL,
  iniciada_at      TIMESTAMP DEFAULT NOW(),
  finalizada_at    TIMESTAMP,
  puntuacion       DECIMAL(5,2),
  total_preguntas  INT,
  aprobado         BOOLEAN
);

CREATE TABLE IF NOT EXISTS respuestas_usuario (
  id            SERIAL PRIMARY KEY,
  sesion_id     INT NOT NULL REFERENCES sesiones_examen(id) ON DELETE CASCADE,
  pregunta_id   INT NOT NULL REFERENCES preguntas(id) ON DELETE CASCADE,
  opcion_id     INT REFERENCES opciones_pregunta(id) ON DELETE SET NULL,
  es_correcta   BOOLEAN,
  tiempo_ms     INT,
  respondida_at TIMESTAMP DEFAULT NOW()
);
