import rateLimit from "express-rate-limit";

// Formato de email razonable (no exhaustivo, pero suficiente para rechazar basura).
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;

const MAX_EMAIL_LEN = 150;
const MAX_NOMBRE_LEN = 100;
const MIN_PASSWORD_LEN = 8;
const MAX_PASSWORD_LEN = 128;

export function validarEmail(email) {
  if (typeof email !== "string") return false;
  const e = email.trim().toLowerCase();
  if (e.length === 0 || e.length > MAX_EMAIL_LEN) return false;
  return EMAIL_RE.test(e);
}

export function normalizarEmail(email) {
  return String(email).trim().toLowerCase();
}

export function validarPassword(password) {
  if (typeof password !== "string") return false;
  if (password.length < MIN_PASSWORD_LEN) return false;
  if (password.length > MAX_PASSWORD_LEN) return false;
  return true;
}

export function validarNombre(nombre) {
  if (typeof nombre !== "string") return false;
  const n = nombre.trim();
  if (n.length === 0 || n.length > MAX_NOMBRE_LEN) return false;
  return true;
}

const MENSAJE_LIMITE =
  "Demasiados intentos. Vuelve a intentarlo en unos minutos.";

// Login: 5 intentos por IP cada 15 min.
export const rateLimitLogin = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5,
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res) => {
    console.warn(
      "[rate-limit] login bloqueado ip=%s email=%s",
      req.ip,
      req.body?.email ?? "?"
    );
    res.status(429).json({ msg: MENSAJE_LIMITE });
  },
});

// Registro: 5 altas por IP por hora.
export const rateLimitRegister = rateLimit({
  windowMs: 60 * 60 * 1000,
  max: 5,
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res) => {
    console.warn("[rate-limit] register bloqueado ip=%s", req.ip);
    res.status(429).json({ msg: MENSAJE_LIMITE });
  },
});

// Retardo constante minimo para responder credenciales invalidas.
// Reduce timing attacks entre "usuario no existe" y "password mal".
export function esperarMs(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
