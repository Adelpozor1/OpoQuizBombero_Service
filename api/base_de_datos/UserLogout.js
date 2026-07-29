import express from "express";
import {
  revocarRefreshToken,
  COOKIE_REFRESH_NAME,
  COOKIE_REFRESH_PATH,
} from "./_tokens.js";

const router = express.Router();

router.post("/UserLogout", async (req, res) => {
  try {
    const token = req.cookies?.[COOKIE_REFRESH_NAME];
    await revocarRefreshToken(token);
    res.clearCookie(COOKIE_REFRESH_NAME, { path: COOKIE_REFRESH_PATH });
    res.json({ msg: "Sesión cerrada" });
  } catch (error) {
    console.error("Error en UserLogout:", error);
    res.status(500).json({ msg: "Error interno del servidor" });
  }
});

export default router;
