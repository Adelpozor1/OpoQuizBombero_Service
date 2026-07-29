-- ============================================================
-- Seed amplio de convocatorias 2026-2027: CCAA + consorcios + cabildos +
-- ayuntamientos por toda Espana.
-- NOTA: datos plausibles basados en organismos convocantes reales, pero
-- NO son boletin oficial. Reemplazar por ingesta real cuando este lista.
-- Idempotente: (nombre, anio) es UNIQUE en convocatorias.
-- ============================================================

-- Entidades convocantes
INSERT INTO entidades (nombre) VALUES
  -- Andalucia
  ('Consorcio Provincial Cadiz'),
  ('Consorcio Provincial Almeria'),
  ('Consorcio Provincial Cordoba'),
  ('Consorcio Provincial Huelva'),
  ('Ayuntamiento de Granada'),
  -- Aragon
  ('Ayuntamiento de Zaragoza'),
  -- Asturias
  ('SEPA Asturias'),
  ('Ayuntamiento de Oviedo'),
  ('Ayuntamiento de Gijon'),
  -- Baleares
  ('Consell de Mallorca'),
  ('Ayuntamiento de Palma'),
  ('Consell d Eivissa'),
  -- Canarias
  ('Cabildo de Tenerife'),
  ('Ayuntamiento de Las Palmas GC'),
  -- Cantabria
  ('Ayuntamiento de Santander'),
  ('Gobierno de Cantabria (SEIS)'),
  -- Castilla y Leon
  ('Consorcio Provincial Valladolid'),
  ('Consorcio Provincial Leon'),
  ('Consorcio Provincial Salamanca'),
  ('Consorcio Provincial Burgos'),
  ('Ayuntamiento de Valladolid'),
  -- Castilla-La Mancha
  ('Consorcio Provincial Toledo'),
  ('Consorcio Provincial Guadalajara'),
  ('Ayuntamiento de Albacete'),
  -- Cataluna
  ('Ayuntamiento de Barcelona'),
  ('Ayuntamiento de L Hospitalet'),
  -- Ceuta / Melilla
  ('Ciudad Autonoma de Ceuta'),
  ('Ciudad Autonoma de Melilla'),
  -- Comunidad Valenciana
  ('Consorcio Provincial Alicante'),
  ('Consorcio Provincial Castellon'),
  ('Ayuntamiento de Valencia'),
  -- Extremadura
  ('SEPEI Diputacion de Caceres'),
  ('Diputacion de Badajoz'),
  -- Galicia
  ('Consorcio Provincial A Coruna'),
  ('Ayuntamiento de Vigo'),
  ('Ayuntamiento de Santiago de Compostela'),
  -- La Rioja
  ('Ayuntamiento de Logrono'),
  ('Consorcio La Rioja 112'),
  -- Madrid
  ('Comunidad de Madrid (CUE)'),
  ('Ayuntamiento de Alcorcon'),
  -- Murcia
  ('Consorcio Bomberos Region Murcia'),
  ('Ayuntamiento de Murcia'),
  ('Ayuntamiento de Cartagena'),
  -- Navarra
  ('Bomberos de Navarra'),
  ('Ayuntamiento de Pamplona'),
  -- Pais Vasco
  ('Ayuntamiento de Bilbao'),
  ('Ayuntamiento de Vitoria-Gasteiz'),
  ('Ayuntamiento de San Sebastian')
ON CONFLICT DO NOTHING;

-- Convocatorias (usa CTEs para resolver ids)
WITH
  bombero AS (SELECT id FROM escalas WHERE nombre='Bombero'),
  -- CCAA
  ca_an AS (SELECT id FROM comunidades_autonomas WHERE codigo_iso='ES-AN'),
  ca_ar AS (SELECT id FROM comunidades_autonomas WHERE codigo_iso='ES-AR'),
  ca_as AS (SELECT id FROM comunidades_autonomas WHERE codigo_iso='ES-AS'),
  ca_ib AS (SELECT id FROM comunidades_autonomas WHERE codigo_iso='ES-IB'),
  ca_cn AS (SELECT id FROM comunidades_autonomas WHERE codigo_iso='ES-CN'),
  ca_cb AS (SELECT id FROM comunidades_autonomas WHERE codigo_iso='ES-CB'),
  ca_cl AS (SELECT id FROM comunidades_autonomas WHERE codigo_iso='ES-CL'),
  ca_cm AS (SELECT id FROM comunidades_autonomas WHERE codigo_iso='ES-CM'),
  ca_ct AS (SELECT id FROM comunidades_autonomas WHERE codigo_iso='ES-CT'),
  ca_ce AS (SELECT id FROM comunidades_autonomas WHERE codigo_iso='ES-CE'),
  ca_vc AS (SELECT id FROM comunidades_autonomas WHERE codigo_iso='ES-VC'),
  ca_ex AS (SELECT id FROM comunidades_autonomas WHERE codigo_iso='ES-EX'),
  ca_ga AS (SELECT id FROM comunidades_autonomas WHERE codigo_iso='ES-GA'),
  ca_ri AS (SELECT id FROM comunidades_autonomas WHERE codigo_iso='ES-RI'),
  ca_md AS (SELECT id FROM comunidades_autonomas WHERE codigo_iso='ES-MD'),
  ca_ml AS (SELECT id FROM comunidades_autonomas WHERE codigo_iso='ES-ML'),
  ca_mc AS (SELECT id FROM comunidades_autonomas WHERE codigo_iso='ES-MC'),
  ca_nc AS (SELECT id FROM comunidades_autonomas WHERE codigo_iso='ES-NC'),
  ca_pv AS (SELECT id FROM comunidades_autonomas WHERE codigo_iso='ES-PV')
INSERT INTO convocatorias (nombre, comunidad_id, escala_id, entidad_id, anio, plazas)
SELECT v.nombre, ca.id, (SELECT id FROM bombero), en.id, v.anio, v.plazas
FROM (VALUES
  -- (codigo_iso, entidad, nombre, anio, plazas)
  -- Andalucia
  ('ES-AN','Ayuntamiento de Sevilla',         'Ayto. Sevilla Bombero 2026',          2026::smallint, 60),
  ('ES-AN','Consorcio Provincial Malaga',     'Consorcio Malaga Bombero 2026',       2026, 80),
  ('ES-AN','Consorcio Provincial Cadiz',      'Consorcio Cadiz Bombero 2026',        2026, 40),
  ('ES-AN','Ayuntamiento de Granada',         'Ayto. Granada Bombero 2026',          2026, 30),
  ('ES-AN','Consorcio Provincial Almeria',    'Consorcio Almeria Bombero 2026',      2026, 25),
  ('ES-AN','Consorcio Provincial Cordoba',    'Consorcio Cordoba Bombero 2027',      2027, 35),
  ('ES-AN','Consorcio Provincial Huelva',     'Consorcio Huelva Bombero 2026',       2026, 20),
  -- Aragon
  ('ES-AR','Consorcio Provincial Zaragoza',   'Consorcio Zaragoza Bombero 2026',     2026, 40),
  ('ES-AR','Ayuntamiento de Zaragoza',        'Ayto. Zaragoza Bombero 2026',         2026, 50),
  -- Asturias
  ('ES-AS','SEPA Asturias',                   'SEPA Asturias Bombero 2026',          2026, 30),
  ('ES-AS','Ayuntamiento de Oviedo',          'Ayto. Oviedo Bombero 2026',           2026, 15),
  ('ES-AS','Ayuntamiento de Gijon',           'Ayto. Gijon Bombero 2026',            2026, 18),
  -- Baleares
  ('ES-IB','Consell de Mallorca',             'Bombers Mallorca 2026',               2026, 35),
  ('ES-IB','Ayuntamiento de Palma',           'Ayto. Palma Bombero 2027',            2027, 25),
  ('ES-IB','Consell d Eivissa',               'Bombers Eivissa 2026',                2026, 10),
  -- Canarias
  ('ES-CN','Consorcio Emergencias Gran Canaria','Emergencias Gran Canaria 2026',     2026, 35),
  ('ES-CN','Cabildo de Tenerife',             'Cabildo Tenerife Bombero 2026',       2026, 30),
  ('ES-CN','Ayuntamiento de Las Palmas GC',   'Ayto. Las Palmas GC Bombero 2027',    2027, 20),
  -- Cantabria
  ('ES-CB','Ayuntamiento de Santander',       'Ayto. Santander Bombero 2026',        2026, 18),
  ('ES-CB','Gobierno de Cantabria (SEIS)',    'SEIS Cantabria Bombero 2026',         2026, 25),
  -- Castilla y Leon
  ('ES-CL','Consorcio Provincial Valladolid', 'Consorcio Valladolid Bombero 2026',   2026, 30),
  ('ES-CL','Consorcio Provincial Leon',       'Consorcio Leon Bombero 2026',         2026, 25),
  ('ES-CL','Ayuntamiento de Valladolid',      'Ayto. Valladolid Bombero 2026',       2026, 18),
  ('ES-CL','Consorcio Provincial Salamanca',  'Consorcio Salamanca Bombero 2027',    2027, 22),
  ('ES-CL','Consorcio Provincial Burgos',     'Consorcio Burgos Bombero 2026',       2026, 20),
  -- Castilla-La Mancha
  ('ES-CM','Consorcio Provincial Toledo',     'Consorcio Toledo Bombero 2026',       2026, 25),
  ('ES-CM','Consorcio Provincial Guadalajara','Consorcio Guadalajara Bombero 2026',  2026, 18),
  ('ES-CM','Ayuntamiento de Albacete',        'Ayto. Albacete Bombero 2027',         2027, 15),
  -- Cataluna
  ('ES-CT','Ayuntamiento de Barcelona',       'Ayto. Barcelona Bombers 2026',        2026, 60),
  ('ES-CT','Ayuntamiento de L Hospitalet',    'Ayto. L Hospitalet Bombers 2027',     2027, 20),
  -- Ceuta / Melilla
  ('ES-CE','Ciudad Autonoma de Ceuta',        'Ciudad Ceuta Bombero 2027',           2027, 10),
  ('ES-ML','Ciudad Autonoma de Melilla',      'Ciudad Melilla Bombero 2027',         2027, 10),
  -- Comunidad Valenciana
  ('ES-VC','Consorcio Provincial Alicante',   'Consorcio Alicante Bombero 2026',     2026, 60),
  ('ES-VC','Consorcio Provincial Castellon',  'Consorcio Castellon Bombero 2026',    2026, 30),
  ('ES-VC','Ayuntamiento de Valencia',        'Ayto. Valencia Bombero 2026',         2026, 45),
  -- Extremadura
  ('ES-EX','SEPEI Diputacion de Caceres',     'SEPEI Caceres Bombero 2026',          2026, 30),
  ('ES-EX','Diputacion de Badajoz',           'Diputacion Badajoz Bombero 2027',     2027, 25),
  -- Galicia
  ('ES-GA','Consorcio Provincial A Coruna',   'Consorcio A Coruna Bombero 2026',     2026, 35),
  ('ES-GA','Ayuntamiento de Vigo',            'Ayto. Vigo Bombero 2026',             2026, 20),
  ('ES-GA','Ayuntamiento de Santiago de Compostela','Ayto. Santiago Bombero 2027',   2027, 15),
  -- La Rioja
  ('ES-RI','Ayuntamiento de Logrono',         'Ayto. Logrono Bombero 2026',          2026, 18),
  ('ES-RI','Consorcio La Rioja 112',          'Consorcio La Rioja 112 Bombero 2027', 2027, 20),
  -- Madrid
  ('ES-MD','Comunidad de Madrid (CUE)',       'Comunidad Madrid CUE Bombero 2026',   2026, 100),
  ('ES-MD','Ayuntamiento de Alcorcon',        'Ayto. Alcorcon Bombero 2027',         2027, 15),
  -- Murcia
  ('ES-MC','Consorcio Bomberos Region Murcia','Consorcio Region Murcia Bombero 2026',2026, 40),
  ('ES-MC','Ayuntamiento de Murcia',          'Ayto. Murcia Bombero 2027',           2027, 20),
  ('ES-MC','Ayuntamiento de Cartagena',       'Ayto. Cartagena Bombero 2026',        2026, 18),
  -- Navarra
  ('ES-NC','Bomberos de Navarra',             'Bomberos de Navarra 2026',            2026, 30),
  ('ES-NC','Ayuntamiento de Pamplona',        'Ayto. Pamplona Bombero 2027',         2027, 15),
  -- Pais Vasco
  ('ES-PV','Ayuntamiento de Bilbao',          'Ayto. Bilbao Bombero 2026',           2026, 25),
  ('ES-PV','Ayuntamiento de Vitoria-Gasteiz', 'Ayto. Vitoria Bombero 2027',          2027, 20),
  ('ES-PV','Ayuntamiento de San Sebastian',   'Ayto. San Sebastian Bombero 2026',    2026, 22)
) AS v(codigo_iso, entidad_nombre, nombre, anio, plazas)
JOIN comunidades_autonomas ca ON ca.codigo_iso = v.codigo_iso
JOIN entidades en             ON en.nombre     = v.entidad_nombre
ON CONFLICT (nombre, anio) DO NOTHING;
