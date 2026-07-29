-- ============================================================
-- Seed: convocatorias demo por CCAA para poblar el mapa.
-- Idempotente por (nombre, anio) gracias al UNIQUE en convocatorias.
-- ============================================================

-- Entidades convocantes que faltan
INSERT INTO entidades (nombre) VALUES
  ('Generalitat de Catalunya'),
  ('Consorcio Provincial Malaga'),
  ('Consorcio Provincial Valencia'),
  ('AXEGA - Xunta de Galicia'),
  ('Gobierno Vasco'),
  ('Consorcio Emergencias Gran Canaria'),
  ('Consorcio Provincial Zaragoza'),
  ('Ayuntamiento de Sevilla')
ON CONFLICT DO NOTHING;

-- Bloque unico WITH para insertar convocatorias en varias CCAA.
WITH
  bombero  AS (SELECT id FROM escalas WHERE nombre='Bombero'),
  cm_ct    AS (SELECT id FROM comunidades_autonomas WHERE codigo_iso='ES-CT'),
  cm_an    AS (SELECT id FROM comunidades_autonomas WHERE codigo_iso='ES-AN'),
  cm_vc    AS (SELECT id FROM comunidades_autonomas WHERE codigo_iso='ES-VC'),
  cm_ga    AS (SELECT id FROM comunidades_autonomas WHERE codigo_iso='ES-GA'),
  cm_pv    AS (SELECT id FROM comunidades_autonomas WHERE codigo_iso='ES-PV'),
  cm_cn    AS (SELECT id FROM comunidades_autonomas WHERE codigo_iso='ES-CN'),
  cm_ar    AS (SELECT id FROM comunidades_autonomas WHERE codigo_iso='ES-AR'),
  cm_md    AS (SELECT id FROM comunidades_autonomas WHERE codigo_iso='ES-MD')
INSERT INTO convocatorias (nombre, comunidad_id, escala_id, entidad_id, anio, plazas, url_oficial)
VALUES
  ('Bombers Generalitat 2026',        (SELECT id FROM cm_ct), (SELECT id FROM bombero),
   (SELECT id FROM entidades WHERE nombre='Generalitat de Catalunya'),
   2026, 250, 'https://www.gencat.cat/'),

  ('Consorcio Malaga Bombero 2025',   (SELECT id FROM cm_an), (SELECT id FROM bombero),
   (SELECT id FROM entidades WHERE nombre='Consorcio Provincial Malaga'),
   2025, 120, 'https://www.cpbmalaga.es/'),

  ('Ayuntamiento Sevilla Bombero 2025',(SELECT id FROM cm_an), (SELECT id FROM bombero),
   (SELECT id FROM entidades WHERE nombre='Ayuntamiento de Sevilla'),
   2025, 60,  'https://www.sevilla.org/'),

  ('Consorcio Valencia Bombero 2025', (SELECT id FROM cm_vc), (SELECT id FROM bombero),
   (SELECT id FROM entidades WHERE nombre='Consorcio Provincial Valencia'),
   2025, 90,  'https://www.dival.es/'),

  ('AXEGA Bombero forestal 2026',     (SELECT id FROM cm_ga), (SELECT id FROM bombero),
   (SELECT id FROM entidades WHERE nombre='AXEGA - Xunta de Galicia'),
   2026, 80,  'https://axega.xunta.gal/'),

  ('Osakidetza Bombero 2026',          (SELECT id FROM cm_pv), (SELECT id FROM bombero),
   (SELECT id FROM entidades WHERE nombre='Gobierno Vasco'),
   2026, 45,  'https://www.euskadi.eus/'),

  ('Emergencias Gran Canaria Bombero 2025', (SELECT id FROM cm_cn), (SELECT id FROM bombero),
   (SELECT id FROM entidades WHERE nombre='Consorcio Emergencias Gran Canaria'),
   2025, 35,  'https://www.emergenciasgc.es/'),

  ('Consorcio Zaragoza Bombero 2025', (SELECT id FROM cm_ar), (SELECT id FROM bombero),
   (SELECT id FROM entidades WHERE nombre='Consorcio Provincial Zaragoza'),
   2025, 40,  'https://www.dpz.es/'),

  ('Ayuntamiento Madrid Bombero 2026',(SELECT id FROM cm_md), (SELECT id FROM bombero),
   (SELECT id FROM entidades WHERE nombre='Ayuntamiento de Madrid'),
   2026, 200, 'https://www.madrid.es/')
ON CONFLICT (nombre, anio) DO NOTHING;
