-- ============================================================
-- Seed inicial: fuentes plantilla + noticias mock por CCAA.
-- Reemplazar por ingesta real (POST /admin/ingesta/run) cuando
-- se den de alta fuentes con URL_RSS validas.
-- ============================================================

-- Fuente "manual" para las noticias mock. Sin url_rss real, desactivada.
INSERT INTO fuentes_noticias (nombre, url_rss, tipo, activa, keywords)
VALUES ('Redaccion OpoQuiz', 'https://opoquizbombero.local/mock', 'manual', FALSE, NULL)
ON CONFLICT (url_rss) DO NOTHING;

-- Noticias mock. guid unico por noticia, imagenes vacias.
WITH f AS (SELECT id FROM fuentes_noticias WHERE url_rss='https://opoquizbombero.local/mock')
INSERT INTO noticias (fuente_id, comunidad_id, titulo, resumen, url, guid, publicada_at)
SELECT (SELECT id FROM f), ca.id, n.titulo, n.resumen, n.url, n.guid, n.fecha::timestamp
FROM (VALUES
  (
    'ES-MD',
    'Ayto. Madrid convoca 200 plazas de bombero para 2026',
    'El Ayuntamiento de Madrid ha aprobado la oferta publica de empleo con 200 plazas para bombero. Las bases se publicaran en el BOAM en las proximas semanas.',
    'https://opoquizbombero.local/mock/madrid-200-plazas',
    'mock-madrid-200-plazas',
    '2026-07-24 09:15:00'
  ),
  (
    'ES-CT',
    'Bombers de la Generalitat: 250 plazas de bombero de acceso libre',
    'La Generalitat de Catalunya publica la convocatoria de 250 plazas para la escala de bombero, con pruebas fisicas y teoricas previstas para el ultimo trimestre.',
    'https://opoquizbombero.local/mock/generalitat-250',
    'mock-generalitat-250',
    '2026-07-22 12:00:00'
  ),
  (
    'ES-AN',
    'Consorcio de Malaga saca 120 plazas de bombero conductor',
    'El Consorcio Provincial de Bomberos de Malaga publica las bases de la convocatoria de 120 plazas de bombero conductor. Plazo de inscripcion en septiembre.',
    'https://opoquizbombero.local/mock/malaga-120',
    'mock-malaga-120',
    '2026-07-21 10:30:00'
  ),
  (
    'ES-VC',
    'Consorcio Provincial de Valencia: 90 plazas de bombero',
    'El Consorcio Provincial de Valencia ha aprobado la convocatoria de 90 plazas de bombero. Se preven pruebas fisicas en octubre y examen teorico en noviembre.',
    'https://opoquizbombero.local/mock/valencia-90',
    'mock-valencia-90',
    '2026-07-19 16:45:00'
  ),
  (
    'ES-GA',
    'AXEGA anuncia proceso selectivo para bombero forestal en 2026',
    'La Axencia Galega de Emerxencias abrira proceso selectivo para bombero forestal en el ultimo trimestre. Se cubriran plazas fijas y de refuerzo estacional.',
    'https://opoquizbombero.local/mock/axega-forestal',
    'mock-axega-forestal',
    '2026-07-17 08:00:00'
  ),
  (
    'ES-PV',
    'Osakidetza refuerza el temario de emergencias en la oposicion vasca',
    'El nuevo temario del proceso selectivo de bombero-conductor incluye un modulo especifico sobre coordinacion con Osakidetza y protocolos SEM.',
    'https://opoquizbombero.local/mock/euskadi-temario',
    'mock-euskadi-temario',
    '2026-07-15 11:20:00'
  ),
  (
    'ES-CN',
    'Consorcio de Emergencias de Gran Canaria abre bolsa de bombero',
    'El Consorcio de Emergencias de Gran Canaria abre bolsa de trabajo para bombero. Requisitos y pruebas fisicas ajustadas al RD 288/2018.',
    'https://opoquizbombero.local/mock/gran-canaria-bolsa',
    'mock-gran-canaria-bolsa',
    '2026-07-13 09:00:00'
  ),
  (
    NULL,
    'Modificacion nacional del temario comun de oposiciones a bombero',
    'Publicada en el BOE una actualizacion del temario comun para oposiciones a bombero: se incorporan bloques de nuevas tecnologias y drones de rescate.',
    'https://opoquizbombero.local/mock/boe-temario-comun',
    'mock-boe-temario-comun',
    '2026-07-10 07:30:00'
  )
) AS n(codigo_iso, titulo, resumen, url, guid, fecha)
LEFT JOIN comunidades_autonomas ca ON ca.codigo_iso = n.codigo_iso
ON CONFLICT (fuente_id, guid) DO NOTHING;
