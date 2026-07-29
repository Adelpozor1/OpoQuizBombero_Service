import express from "express";
import bcrypt from "bcryptjs";
import db from "../../db.js";
import {
  validarEmail,
  validarPassword,
  normalizarEmail,
  rateLimitLogin,
  esperarMs,
} from "./_seguridad.js";
import {
  firmarAccessToken,
  emitirRefreshToken,
  opcionesCookieRefresh,
  COOKIE_REFRESH_NAME,
} from "./_tokens.js";

const router = express.Router();

const MSG_CREDENCIALES = "Credenciales incorrectas";
const MSG_DATOS_INVALIDOS = "Email o contraseña no validos";
const DELAY_FALLO_MS = 250;

router.post("/UserLogin", rateLimitLogin, async (req, res) => {
  const inicio = Date.now();
  try {
    const { email, password } = req.body ?? {};

    if (!validarEmail(email) || !validarPassword(password)) {
      await esperarMs(DELAY_FALLO_MS);
      return res.status(400).json({ msg: MSG_DATOS_INVALIDOS });
    }

    const emailNorm = normalizarEmail(email);

    const result = await db.query(
      "SELECT * FROM sp_usuario_buscar_por_email($1)",
      [emailNorm]
    );

    const usuario = result.rows[0];

    // Se hashea siempre para uniformar tiempos (mitiga user enumeration por timing).
    const hashComparar =
      usuario?.password ??
      "$2b$12$invalido.invalido.invalido.invalido.invalido.invalido.hash";
    const coincide = await bcrypt.compare(password, hashComparar);

    if (!usuario || !coincide) {
      const transcurrido = Date.now() - inicio;
      if (transcurrido < DELAY_FALLO_MS) {
        await esperarMs(DELAY_FALLO_MS - transcurrido);
      }
      console.warn(
        "[login] fallido ip=%s email=%s existe=%s",
        req.ip,
        emailNorm,
        Boolean(usuario)
      );
      return res.status(401).json({ msg: MSG_CREDENCIALES });
    }

    const usuarioPublico = {
      id: usuario.id,
      nombre: usuario.nombre,
      email: usuario.email,
    };

    const accessToken = firmarAccessToken(usuarioPublico);
    const { token: refreshToken } = await emitirRefreshToken(usuarioPublico.id);
    res.cookie(COOKIE_REFRESH_NAME, refreshToken, opcionesCookieRefresh());

    res.json({
      msg: "Login correcto",
      accessToken,
      usuario: usuarioPublico,
    });
  } catch (error) {
    console.error("Error en UserLogin:", error);
    res.status(500).json({ msg: "Error interno del servidor" });
  }
});

export default router;
