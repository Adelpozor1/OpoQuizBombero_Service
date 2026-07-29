import express from "express";
import db from "../../db.js";
import {
  firmarAccessToken,
  emitirRefreshToken,
  validarRefreshToken,
  revocarRefreshToken,
  opcionesCookieRefresh,
  COOKIE_REFRESH_NAME,
  COOKIE_REFRESH_PATH,
} from "./_tokens.js";

const router = express.Router();

router.post("/UserRefresh", async (req, res) => {
  try {
    const tokenAnterior = req.cookies?.[COOKIE_REFRESH_NAME];
    const registro = await validarRefreshToken(tokenAnterior);

    if (!registro) {
      res.clearCookie(COOKIE_REFRESH_NAME, { path: COOKIE_REFRESH_PATH });
      return res.status(401).json({ msg: "Sesión no válida" });
    }

    // Rotación: revocar el anterior y emitir uno nuevo.
    await revocarRefreshToken(tokenAnterior);

    const r = await db.query(
      "SELECT * FROM sp_usuario_publico_por_id($1)",
      [registro.usuario_id]
    );
    const usuarioPublico = r.rows[0];
    if (!usuarioPublico) {
      res.clearCookie(COOKIE_REFRESH_NAME, { path: COOKIE_REFRESH_PATH });
      return res.status(401).json({ msg: "Sesión no válida" });
    }

    const accessToken = firmarAccessToken(usuarioPublico);
    const { token: refreshNuevo } = await emitirRefreshToken(usuarioPublico.id);
    res.cookie(COOKIE_REFRESH_NAME, refreshNuevo, opcionesCookieRefresh());

    res.json({ accessToken, usuario: usuarioPublico });
  } catch (error) {
    console.error("Error en UserRefresh:", error);
    res.status(500).json({ msg: "Error interno del servidor" });
  }
});

export default router;
