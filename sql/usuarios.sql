-- ============================================================
-- Procedimientos almacenados: dominio usuarios
-- Definidos como funciones (PostgreSQL) idempotentes.
-- Convencion: prefijo sp_ para llamadas desde el service.
-- ============================================================

-- Devuelve la fila del usuario por email (id, nombre, email, password).
-- Solo devuelve usuarios activos: los desactivados no pueden loguearse.
-- El service compara el hash con bcrypt en Node.
CREATE OR REPLACE FUNCTION sp_usuario_buscar_por_email(p_email VARCHAR)
RETURNS TABLE (
  id       INT,
  nombre   VARCHAR,
  email    VARCHAR,
  password VARCHAR
)
LANGUAGE sql
STABLE
AS $$
  SELECT u.id, u.nombre, u.email, u.password
  FROM usuarios u
  WHERE u.email = p_email
    AND u.activo = TRUE;
$$;

-- Devuelve datos publicos del usuario por id, solo si esta activo.
-- Se usa desde el refresh para reconstruir el payload del JWT.
CREATE OR REPLACE FUNCTION sp_usuario_publico_por_id(p_id INT)
RETURNS TABLE (
  id     INT,
  nombre VARCHAR,
  email  VARCHAR
)
LANGUAGE sql
STABLE
AS $$
  SELECT u.id, u.nombre, u.email
  FROM usuarios u
  WHERE u.id = p_id
    AND u.activo = TRUE;
$$;

-- Actualiza el password de un usuario existente por email.
-- Devuelve TRUE si actualizo alguna fila, FALSE si el email no existe.
CREATE OR REPLACE FUNCTION sp_usuario_actualizar_password_por_email(
  p_email    VARCHAR,
  p_password VARCHAR
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
  v_filas INT;
BEGIN
  UPDATE usuarios
     SET password = p_password
   WHERE email = p_email;
  GET DIAGNOSTICS v_filas = ROW_COUNT;
  RETURN v_filas > 0;
END;
$$;

-- Inserta un usuario nuevo y devuelve su id.
-- Si el email ya existe, levanta EXCEPTION con SQLSTATE '23505' (unique_violation).
CREATE OR REPLACE FUNCTION sp_usuario_registrar(
  p_nombre   VARCHAR,
  p_email    VARCHAR,
  p_password VARCHAR
)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
  v_id INT;
BEGIN
  INSERT INTO usuarios (nombre, email, password)
  VALUES (p_nombre, p_email, p_password)
  RETURNING id INTO v_id;

  RETURN v_id;
EXCEPTION
  WHEN unique_violation THEN
    RAISE EXCEPTION 'usuario_email_duplicado' USING ERRCODE = '23505';
END;
$$;
