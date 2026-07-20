-- Datos demo: 1 convocatoria + 1 test oficial con 3 preguntas de ejemplo.
-- Sirve para validar el flujo end-to-end. Datos reales van en cargas posteriores.

INSERT INTO entidades (nombre) VALUES ('Ayuntamiento de Madrid') ON CONFLICT DO NOTHING;

WITH
  cm AS (SELECT id FROM comunidades_autonomas WHERE codigo_iso='ES-MD'),
  es AS (SELECT id FROM escalas WHERE nombre='Bombero'),
  en AS (SELECT id FROM entidades WHERE nombre='Ayuntamiento de Madrid'),
  ins_conv AS (
    INSERT INTO convocatorias (nombre, comunidad_id, escala_id, entidad_id, anio, plazas)
    VALUES ('Ayto. Madrid Bombero 2024', (SELECT id FROM cm), (SELECT id FROM es), (SELECT id FROM en), 2024, 100)
    ON CONFLICT (nombre, anio) DO UPDATE SET plazas = EXCLUDED.plazas
    RETURNING id
  ),
  ins_test AS (
    INSERT INTO test (nombre, descripcion, comunidad_id, escala_id, tipo, anio, num_preguntas)
    VALUES (
      'Simulacro Madrid Bombero 2024',
      'Test demo con preguntas de ejemplo. Reemplazar por preguntas reales.',
      (SELECT id FROM cm), (SELECT id FROM es), 'oficial', 2024, 3
    )
    RETURNING id
  ),
  estado_activa AS (SELECT id FROM estados_preguntas WHERE nombre='activa'),
  t_leg AS (SELECT id FROM tematicas WHERE nombre='Legislacion'),
  t_fis AS (SELECT id FROM tematicas WHERE nombre='Fisica y quimica del fuego'),
  t_hid AS (SELECT id FROM tematicas WHERE nombre='Hidraulica'),

  p1 AS (
    INSERT INTO preguntas (texto, dificultad, estado_id, convocatoria_id, explicacion)
    VALUES (
      'Segun la Constitucion Espanola, la proteccion civil es competencia:',
      2, (SELECT id FROM estado_activa), (SELECT id FROM ins_conv),
      'La proteccion civil es competencia concurrente: Estado, CCAA y municipios. La ley 17/2015 la coordina.'
    ) RETURNING id
  ),
  p2 AS (
    INSERT INTO preguntas (texto, dificultad, estado_id, convocatoria_id, explicacion)
    VALUES (
      'El triangulo del fuego esta formado por:',
      1, (SELECT id FROM estado_activa), (SELECT id FROM ins_conv),
      'Combustible, comburente y calor. Al anadir la reaccion en cadena se convierte en tetraedro.'
    ) RETURNING id
  ),
  p3 AS (
    INSERT INTO preguntas (texto, dificultad, estado_id, convocatoria_id, explicacion)
    VALUES (
      'La perdida de carga en una manguera aumenta cuando:',
      2, (SELECT id FROM estado_activa), (SELECT id FROM ins_conv),
      'Es proporcional a Q^2 y a la longitud, e inversa al diametro elevado a 5.'
    ) RETURNING id
  )
INSERT INTO opciones_pregunta (pregunta_id, texto, es_correcta)
SELECT (SELECT id FROM p1), t, c FROM (VALUES
  ('Exclusiva del Estado', FALSE),
  ('Exclusiva de las CCAA', FALSE),
  ('Concurrente entre Estado, CCAA y municipios', TRUE),
  ('Exclusiva de los municipios', FALSE)
) AS v(t, c)
UNION ALL
SELECT (SELECT id FROM p2), t, c FROM (VALUES
  ('Oxigeno, humo y calor', FALSE),
  ('Combustible, comburente y calor', TRUE),
  ('Comburente, temperatura y humo', FALSE),
  ('Combustible, chispa y viento', FALSE)
) AS v(t, c)
UNION ALL
SELECT (SELECT id FROM p3), t, c FROM (VALUES
  ('Aumenta el diametro', FALSE),
  ('Disminuye el caudal', FALSE),
  ('Aumenta el caudal y la longitud', TRUE),
  ('Se usa agua salada', FALSE)
) AS v(t, c);

-- Vincular las 3 preguntas al test y a sus tematicas
WITH t AS (SELECT id FROM test WHERE nombre='Simulacro Madrid Bombero 2024')
INSERT INTO test_preguntas (test_id, pregunta_id, orden)
SELECT (SELECT id FROM t), p.id, ROW_NUMBER() OVER (ORDER BY p.id)
FROM preguntas p
WHERE p.convocatoria_id = (SELECT id FROM convocatorias WHERE nombre='Ayto. Madrid Bombero 2024')
ON CONFLICT DO NOTHING;

INSERT INTO tematicas_preguntas (tematica_id, pregunta_id)
SELECT (SELECT id FROM tematicas WHERE nombre='Legislacion'), p.id
FROM preguntas p WHERE p.texto LIKE 'Segun la Constitucion%'
UNION ALL
SELECT (SELECT id FROM tematicas WHERE nombre='Fisica y quimica del fuego'), p.id
FROM preguntas p WHERE p.texto LIKE 'El triangulo del fuego%'
UNION ALL
SELECT (SELECT id FROM tematicas WHERE nombre='Hidraulica'), p.id
FROM preguntas p WHERE p.texto LIKE 'La perdida de carga%'
ON CONFLICT DO NOTHING;
