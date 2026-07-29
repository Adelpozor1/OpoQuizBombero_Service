-- ============================================================
-- 005 - Dominio estudio / examen (modelo rico para tests reales)
-- Basado en el briefing de Martin: modos estudio/examen, 4 tipos de
-- correccion, estados extendidos, bloqueos de posicion, explicaciones
-- por respuesta + global, revision, codigo_id, penalizaciones,
-- preguntas anuladas por test, estadisticas usuario/pregunta.
-- Todo aditivo (ADD COLUMN IF NOT EXISTS) para no romper datos previos.
-- ============================================================

-- 1) Estados de preguntas ampliados.
--    Antes: activa / inactiva / revision.
--    Ahora: valida / anulada / desactualizada / anulada_funcional.
--    Se conservan los previos como alias para no romper seeds antiguos.
INSERT INTO estados_preguntas (nombre) VALUES
  ('valida'),
  ('anulada'),
  ('desactualizada'),
  ('anulada_funcional')
ON CONFLICT (nombre) DO NOTHING;

-- 2) Ampliar tabla preguntas.
ALTER TABLE preguntas
  ADD COLUMN IF NOT EXISTS es_pregunta_negativa BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS revisada             BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS revisada_at          TIMESTAMP,
  ADD COLUMN IF NOT EXISTS orden                INT,
  ADD COLUMN IF NOT EXISTS titulo_url           VARCHAR(200),
  ADD COLUMN IF NOT EXISTS url                  TEXT,
  ADD COLUMN IF NOT EXISTS explicacion_estado   TEXT,
  ADD COLUMN IF NOT EXISTS explicacion_global   TEXT;

-- 3) Ampliar opciones_pregunta.
--    posicion_bloqueada NULL = orden libre; entero = posicion fija (1..N).
--    explicacion_especifica = mensaje al usuario si elige esta opcion.
ALTER TABLE opciones_pregunta
  ADD COLUMN IF NOT EXISTS posicion_bloqueada   INT,
  ADD COLUMN IF NOT EXISTS explicacion_especifica TEXT,
  ADD COLUMN IF NOT EXISTS orden_original       INT;

-- 4) Ampliar tabla test con reglas de calificacion y codigo estructurado.
ALTER TABLE test
  ADD COLUMN IF NOT EXISTS codigo_id                VARCHAR(20) UNIQUE,
  ADD COLUMN IF NOT EXISTS tipo_correccion          VARCHAR(24)
    DEFAULT 'rojo_verde_explicacion'
    CHECK (tipo_correccion IN (
      'sin_correccion',
      'solo_rojo_verde',
      'rojo_verde_explicacion',
      'rojo_verde_global_y_especifica'
    )),
  ADD COLUMN IF NOT EXISTS num_preguntas_reserva    INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS tiempo_minutos           INT,
  ADD COLUMN IF NOT EXISTS nota_apto                DECIMAL(5,2) DEFAULT 5.00,
  ADD COLUMN IF NOT EXISTS nota_maxima              DECIMAL(5,2) DEFAULT 10.00,
  ADD COLUMN IF NOT EXISTS penalizacion_fallo       DECIMAL(5,3) DEFAULT 0.000,
  ADD COLUMN IF NOT EXISTS penalizacion_no_contestada DECIMAL(5,3) DEFAULT 0.000,
  ADD COLUMN IF NOT EXISTS observaciones            TEXT;

-- 5) Preguntas anuladas por test especifico (casos puntuales).
--    Cuando una pregunta se anula solo para un test concreto (no globalmente).
CREATE TABLE IF NOT EXISTS test_preguntas_anuladas (
  test_id     INT NOT NULL REFERENCES test(id)      ON DELETE CASCADE,
  pregunta_id INT NOT NULL REFERENCES preguntas(id) ON DELETE CASCADE,
  motivo      TEXT,
  anulada_at  TIMESTAMP DEFAULT NOW(),
  PRIMARY KEY (test_id, pregunta_id)
);

-- 6) Estadisticas usuario/pregunta (autodiagnostico).
--    Se actualiza en cada respuesta corregida.
CREATE TABLE IF NOT EXISTS usuario_pregunta_stats (
  usuario_id     INT NOT NULL REFERENCES usuarios(id)  ON DELETE CASCADE,
  pregunta_id    INT NOT NULL REFERENCES preguntas(id) ON DELETE CASCADE,
  vistas         INT DEFAULT 0,
  aciertos       INT DEFAULT 0,
  fallos         INT DEFAULT 0,
  no_contestadas INT DEFAULT 0,
  ultima_at      TIMESTAMP,
  PRIMARY KEY (usuario_id, pregunta_id)
);

CREATE INDEX IF NOT EXISTS idx_ups_usuario_fallos
  ON usuario_pregunta_stats (usuario_id, fallos DESC);

-- 7) Modo de la sesion (estudio | examen) y tiempo consumido.
ALTER TABLE sesiones_examen
  ADD COLUMN IF NOT EXISTS modo           VARCHAR(12)
    DEFAULT 'examen'
    CHECK (modo IN ('estudio','examen')),
  ADD COLUMN IF NOT EXISTS tiempo_total_ms BIGINT;

-- 8) Respuestas del usuario: guardamos si estaba en reserva y si contaba.
ALTER TABLE respuestas_usuario
  ADD COLUMN IF NOT EXISTS es_reserva     BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS penalizada     BOOLEAN DEFAULT FALSE;

-- 9) Marcar todos los estados existentes en preguntas como validos por defecto.
--    Si la pregunta esta con estado 'activa' -> mapear a 'valida'.
DO $$
DECLARE
  v_id_valida INT;
  v_id_activa INT;
BEGIN
  SELECT id INTO v_id_valida FROM estados_preguntas WHERE nombre='valida';
  SELECT id INTO v_id_activa FROM estados_preguntas WHERE nombre='activa';
  IF v_id_valida IS NOT NULL AND v_id_activa IS NOT NULL THEN
    UPDATE preguntas SET estado_id = v_id_valida WHERE estado_id = v_id_activa;
  END IF;
END $$;
