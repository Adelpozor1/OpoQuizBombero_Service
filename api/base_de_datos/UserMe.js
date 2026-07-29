import express from "express";
import db from "../../db.js";
import { authRequired } from "./_tokens.js";

const router = express.Router();

// Devuelve el perfil publico del usuario autenticado, con su CCAA preferida.
router.get("/UserMe", authRequired, async (req, res) => {
  try {
    const r = await db.query(
      "SELECT * FROM sp_usuario_publico_por_id_con_comunidad($1)",
      [req.usuario.id]
    );
    const usuario = r.rows[0];
    if (!usuario) return res.status(404).json({ msg: "Usuario no encontrado" });
    res.json({ usuario });
  } catch (error) {
    console.error("Error en GET /UserMe:", error);
    res.status(500).json({ msg: "Error interno del servidor" });
  }
});

export default router;
