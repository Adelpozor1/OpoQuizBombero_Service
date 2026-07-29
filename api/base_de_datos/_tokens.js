import crypto from "crypto";
import jwt from "jsonwebtoken";
import db from "../../db.js";

const JWT_SECRET = process.env.JWT_SECRET;
if (!JWT_SECRET || JWT_SECRET.length < 32) {
  throw new Error(
    "JWT_SECRET obligatorio y de al menos 32 caracteres (define uno en .env)."
  );
}

const ACCESS_EXPIRES = process.env.JWT_ACCESS_EXPIRES || "15m";
const REFRESH_EXPIRES_DAYS = Number(process.env.JWT_REFRESH_EXPIRES_DAYS) || 30;

export const COOKIE_REFRESH_NAME = "refresh_token";
export const COOKIE_REFRESH_PATH = "/api/base_de_datos";

// Hash SHA256 en hex. Lo que se guarda en la BD.
function hashToken(token) {
  return crypto.createHash("sha256").update(token).digest("hex");
}

export function firmarAccessToken(usuario) {
  return jwt.sign(
    { sub: usuario.id, nombre: usuario.nombre, email: usuario.email },
    JWT_SECRET,
    { expiresIn: ACCESS_EXPIRES }
  );
}

export function verificarAccessToken(token) {
  return jwt.verify(token, JWT_SECRET);
}

// Emite un refresh token nuevo, lo persiste (hash) y devuelve el token plano
// para colocarlo en cookie.
export async function emitirRefreshToken(usuarioId) {
  const plano = crypto.randomBytes(48).toString("base64url");
  const hash = hashToken(plano);
  const expiresAt = new Date(Date.now() + REFRESH_EXPIRES_DAYS * 24 * 3600 * 1000);
  await db.query("SELECT sp_refresh_token_crear($1, $2, $3)", [
    usuarioId,
    hash,
    expiresAt,
  ]);
  return { token: plano, expiresAt };
}

// Devuelve usuario_id si el token plano es valido; null si no.
export async function validarRefreshToken(tokenPlano) {
  if (!tokenPlano) return null;
  const hash = hashToken(tokenPlano);
  const r = await db.query("SELECT * FROM sp_refresh_token_validar($1)", [hash]);
  return r.rows[0] ?? null;
}

export async function revocarRefreshToken(tokenPlano) {
  if (!tokenPlano) return;
  const hash = hashToken(tokenPlano);
  await db.query("SELECT sp_refresh_token_revocar($1)", [hash]);
}

export function opcionesCookieRefresh() {
  const secure = String(process.env.COOKIE_SECURE || "false") === "true";
  const sameSite = process.env.COOKIE_SAMESITE || "strict";
  return {
    httpOnly: true,
    secure,
    sameSite,
    path: COOKIE_REFRESH_PATH,
    maxAge: REFRESH_EXPIRES_DAYS * 24 * 3600 * 1000,
  };
}

// Middleware: verifica el Authorization: Bearer <access>. Deja req.usuario listo.
export function authRequired(req, res, next) {
  const header = req.headers.authorization || "";
  const match = header.match(/^Bearer (.+)$/);
  if (!match) {
    return res.status(401).json({ msg: "No autenticado" });
  }
  try {
    const payload = verificarAccessToken(match[1]);
    req.usuario = { id: payload.sub, nombre: payload.nombre, email: payload.email };
    next();
  } catch {
    return res.status(401).json({ msg: "Sesión expirada" });
  }
}
