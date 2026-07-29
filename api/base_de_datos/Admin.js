import express from "express";
import { authRequired } from "./_tokens.js";
import { ejecutarIngesta } from "../../services/ingesta_noticias.js";

const router = express.Router();

// POST /admin/ingesta/run -> ejecuta la ingesta de todas las fuentes activas.
// TODO: en cuanto haya roles, restringir a admin. De momento cualquier
// usuario autenticado puede dispararla para probar durante desarrollo.
router.post("/admin/ingesta/run", authRequired, async (_req, res) => {
  try {
    const resultados = await ejecutarIngesta();
    res.json({ resultados });
  } catch (error) {
    console.error("Error en POST /admin/ingesta/run:", error);
    res.status(500).json({ msg: "Error interno del servidor" });
  }
});

export default router;
