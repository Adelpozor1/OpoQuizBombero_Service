-- ============================================================
-- Procedimientos almacenados: dominio refresh_tokens
-- Nota: siempre se guarda el HASH SHA256 del token en columna 'token',
--       nunca el token plano. Asi, si se filtra la BD, no se comprometen
--       sesiones activas.
-- ============================================================

-- Registra un nuevo refresh token para un usuario. Devuelve el id insertado.
CREATE OR REPLACE FUNCTION sp_refresh_token_crear(
  p_usuario_id INT,
  p_token_hash TEXT,
  p_expires_at TIMESTAMP
)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
  v_id INT;
BEGIN
  INSERT INTO refresh_tokens (usuario_id, token, expires_at)
  VALUES (p_usuario_id, p_token_hash, p_expires_at)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

-- Valida un refresh token por hash: devuelve usuario_id si el token
-- existe, no esta revocado y no ha expirado. Vacio en caso contrario.
CREATE OR REPLACE FUNCTION sp_refresh_token_validar(p_token_hash TEXT)
RETURNS TABLE (
  id         INT,
  usuario_id INT
)
LANGUAGE sql
STABLE
AS $$
  SELECT rt.id, rt.usuario_id
  FROM refresh_tokens rt
  WHERE rt.token = p_token_hash
    AND rt.revocado = FALSE
    AND rt.expires_at > NOW();
$$;

-- Revoca un refresh token concreto (logout de una sesion).
CREATE OR REPLACE FUNCTION sp_refresh_token_revocar(p_token_hash TEXT)
RETURNS VOID
LANGUAGE sql
AS $$
  UPDATE refresh_tokens
  SET revocado = TRUE
  WHERE token = p_token_hash
    AND revocado = FALSE;
$$;

-- Revoca todas las sesiones de un usuario (logout global / cambio de password).
CREATE OR REPLACE FUNCTION sp_refresh_token_revocar_por_usuario(p_usuario_id INT)
RETURNS VOID
LANGUAGE sql
AS $$
  UPDATE refresh_tokens
  SET revocado = TRUE
  WHERE usuario_id = p_usuario_id
    AND revocado = FALSE;
$$;
