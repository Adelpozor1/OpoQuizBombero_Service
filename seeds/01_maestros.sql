-- 17 comunidades autonomas + 2 ciudades autonomas
INSERT INTO comunidades_autonomas (nombre, codigo_iso) VALUES
  ('Andalucia','ES-AN'), ('Aragon','ES-AR'), ('Asturias','ES-AS'),
  ('Baleares','ES-IB'), ('Canarias','ES-CN'), ('Cantabria','ES-CB'),
  ('Castilla-La Mancha','ES-CM'), ('Castilla y Leon','ES-CL'),
  ('Cataluna','ES-CT'), ('Comunidad Valenciana','ES-VC'),
  ('Extremadura','ES-EX'), ('Galicia','ES-GA'),
  ('La Rioja','ES-RI'), ('Madrid','ES-MD'), ('Murcia','ES-MC'),
  ('Navarra','ES-NC'), ('Pais Vasco','ES-PV'),
  ('Ceuta','ES-CE'), ('Melilla','ES-ML')
ON CONFLICT (codigo_iso) DO NOTHING;

INSERT INTO escalas (nombre, orden) VALUES
  ('Bombero',1), ('Bombero conductor',2),
  ('Cabo',3), ('Sargento',4), ('Oficial',5)
ON CONFLICT (nombre) DO NOTHING;

INSERT INTO tematicas (nombre, descripcion) VALUES
  ('Legislacion', 'Constitucion, ley de proteccion civil, normativa autonomica'),
  ('Fisica y quimica del fuego', 'Triangulo del fuego, transmision de calor, combustibles'),
  ('Hidraulica', 'Presiones, perdidas de carga, calculo de mangueras'),
  ('Rescate y salvamento', 'Tecnicas de excarcelacion, rescate vertical, en altura'),
  ('Primeros auxilios', 'Soporte vital basico, hemorragias, quemaduras'),
  ('Vehiculos y herramientas', 'Bombas, autoescaleras, EPI'),
  ('Prevencion e intervencion', 'CTE, tacticas de extincion, autoproteccion'),
  ('Mercancias peligrosas', 'ADR, fichas de intervencion, descontaminacion'),
  ('Riesgos naturales', 'Incendios forestales, inundaciones, seismos'),
  ('Construccion', 'Estructuras, patologias, planos')
ON CONFLICT DO NOTHING;
