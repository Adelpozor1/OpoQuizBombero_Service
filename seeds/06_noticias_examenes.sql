-- ============================================================
-- Seed: noticias sobre EXAMENES (no convocatorias).
-- Reemplaza el mock anterior (03_noticias_demo). Fuente "Redaccion OpoQuiz".
-- Datos plausibles, no oficiales; reemplazar por ingesta real cuando este lista.
-- ============================================================

-- Fuente ya existe (creada en 03_noticias_demo). Aseguramos por si acaso.
INSERT INTO fuentes_noticias (nombre, url_rss, tipo, activa, keywords)
VALUES ('Redaccion OpoQuiz', 'https://opoquizbombero.local/mock', 'manual', FALSE, NULL)
ON CONFLICT (url_rss) DO NOTHING;

-- Limpieza: fuera las mock antiguas (siguen con guid 'mock-...convocatorias').
DELETE FROM noticias
WHERE fuente_id = (SELECT id FROM fuentes_noticias WHERE url_rss='https://opoquizbombero.local/mock');

-- Insertar noticias de examenes
WITH f AS (SELECT id FROM fuentes_noticias WHERE url_rss='https://opoquizbombero.local/mock')
INSERT INTO noticias (fuente_id, comunidad_id, titulo, resumen, url, guid, publicada_at)
SELECT (SELECT id FROM f), ca.id, n.titulo, n.resumen, n.url, n.guid, n.fecha::timestamp
FROM (VALUES
  (
    NULL,
    'Publicado el nuevo temario oficial comun para bombero 2026',
    'El Ministerio del Interior actualiza los bloques de constitucion, prevencion y proteccion civil que forman el temario comun. Se incorporan preguntas sobre nuevas tecnologias de rescate y drones.',
    'https://opoquizbombero.local/mock/temario-comun-2026',
    'mock-temario-comun-2026',
    '2026-07-25 09:00:00'
  ),
  (
    'ES-MD',
    'Ayto. Madrid publica fechas de examen para el proceso 2026',
    'Prueba teorica el 12 de octubre, prueba fisica los dias 18 y 19. La convocatoria ha registrado mas de 8.500 inscritos, un record historico.',
    'https://opoquizbombero.local/mock/madrid-fechas-examen-2026',
    'mock-madrid-fechas-examen-2026',
    '2026-07-22 11:30:00'
  ),
  (
    'ES-CT',
    'El TSJ Catalunya anula parcialmente una prueba fisica de Bombers Barcelona',
    'La sentencia obliga a repetir el circuito de agilidad para 340 opositores tras detectar irregularidades en la medicion de tiempos. Los afectados seran convocados en septiembre.',
    'https://opoquizbombero.local/mock/tsj-anula-fisica-bcn',
    'mock-tsj-anula-fisica-bcn',
    '2026-07-19 16:15:00'
  ),
  (
    'ES-GA',
    'AXEGA publica el listado provisional de admitidos al proceso 2026',
    'La Axencia Galega de Emerxencias abre plazo de 10 dias para reclamaciones antes de emitir el listado definitivo. Se han presentado casi 3.200 solicitudes para 80 plazas.',
    'https://opoquizbombero.local/mock/axega-admitidos-2026',
    'mock-axega-admitidos-2026',
    '2026-07-16 10:00:00'
  ),
  (
    'ES-AN',
    'Cambios en la prueba psicotecnica del Ayto. Sevilla en 2026',
    'La nueva convocatoria incorpora un bloque de razonamiento espacial y elimina las preguntas de personalidad. Los opositores tendran 90 minutos en lugar de 60.',
    'https://opoquizbombero.local/mock/sevilla-psicotecnico-cambio',
    'mock-sevilla-psicotecnico-cambio',
    '2026-07-14 12:45:00'
  ),
  (
    NULL,
    'Guia practica: como preparar la prueba de trepa en la oposicion de bombero',
    'Analisis tecnico de las tres variantes mas comunes (soga lisa, escalera vertical y cuerda con nudos). Errores frecuentes y planificacion de entrenamiento en 12 semanas.',
    'https://opoquizbombero.local/mock/guia-trepa-bombero',
    'mock-guia-trepa-bombero',
    '2026-07-12 08:00:00'
  ),
  (
    'ES-PV',
    'Publicadas las notas del examen teorico del Ayto. Bilbao',
    'De los 1.240 opositores presentados al ejercicio teorico, 480 han superado la nota de corte. La siguiente fase (prueba fisica) esta prevista para octubre.',
    'https://opoquizbombero.local/mock/bilbao-notas-teorico',
    'mock-bilbao-notas-teorico',
    '2026-07-10 17:30:00'
  ),
  (
    'ES-VC',
    'Consorcio Provincial de Valencia adelanta el examen teorico a septiembre',
    'El tribunal ajusta el calendario tras la revision de recursos. El examen tipo test de 100 preguntas se celebrara el 20 de septiembre en el Palacio de Congresos.',
    'https://opoquizbombero.local/mock/cpv-adelanta-teorico',
    'mock-cpv-adelanta-teorico',
    '2026-07-08 13:00:00'
  ),
  (
    NULL,
    'Que esperar en la entrevista personal del proceso selectivo de bombero',
    'La entrevista suele centrarse en motivacion, trabajo en equipo y gestion del estres. Recopilamos las preguntas mas frecuentes de los ultimos procesos y como estructurarlas.',
    'https://opoquizbombero.local/mock/guia-entrevista-personal',
    'mock-guia-entrevista-personal',
    '2026-07-05 09:30:00'
  ),
  (
    'ES-CL',
    'El Consorcio de Valladolid modifica la prueba de arrastre de maniqui',
    'Se sube el peso a 80kg y se acorta la distancia a 30 metros. La medida se justifica por adaptacion a los protocolos operativos actuales de rescate.',
    'https://opoquizbombero.local/mock/valladolid-arrastre-maniqui',
    'mock-valladolid-arrastre-maniqui',
    '2026-07-02 15:20:00'
  )
) AS n(codigo_iso, titulo, resumen, url, guid, fecha)
LEFT JOIN comunidades_autonomas ca ON ca.codigo_iso = n.codigo_iso
ON CONFLICT (fuente_id, guid) DO NOTHING;
