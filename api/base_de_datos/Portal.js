import express from "express";
import db from "../../db.js";
import { authRequired } from "./_tokens.js";

const router = express.Router();

// GET /Comunidades -> listado para el selector
router.get("/Comunidades", authRequired, async (_req, res) => {
  try {
    const r = await db.query("SELECT * FROM sp_comunidades_listado()");
    res.json({ comunidades: r.rows });
  } catch (error) {
    console.error("Error en GET /Comunidades:", error);
    res.status(500).json({ msg: "Error interno del servidor" });
  }
});

// GET /Noticias?comunidad_id=X&limit=N -> feed
router.get("/Noticias", authRequired, async (req, res) => {
  const comunidadIdRaw = req.query.comunidad_id;
  const limitRaw = req.query.limit;

  let comunidadId = null;
  if (comunidadIdRaw !== undefined && comunidadIdRaw !== "" && comunidadIdRaw !== "null") {
    const n = Number(comunidadIdRaw);
    if (!Number.isInteger(n) || n <= 0) {
      return res.status(400).json({ msg: "comunidad_id invalido" });
    }
    comunidadId = n;
  }

  let limit = 30;
  if (limitRaw !== undefined) {
    const n = Number(limitRaw);
    if (Number.isInteger(n) && n > 0 && n <= 100) limit = n;
  }

  try {
    const r = await db.query("SELECT * FROM sp_noticias_feed($1, $2)", [
      comunidadId,
      limit,
    ]);
    res.json({ noticias: r.rows });
  } catch (error) {
    console.error("Error en GET /Noticias:", error);
    res.status(500).json({ msg: "Error interno del servidor" });
  }
});

// POST /UserComunidad -> cambia la CCAA preferida del usuario
router.post("/UserComunidad", authRequired, async (req, res) => {
  const raw = req.body?.comunidad_id;
  let comunidadId = null;
  if (raw !== null && raw !== undefined) {
    const n = Number(raw);
    if (!Number.isInteger(n) || n <= 0) {
      return res.status(400).json({ msg: "comunidad_id invalido" });
    }
    comunidadId = n;
  }

  try {
    await db.query("SELECT sp_usuario_set_comunidad($1, $2)", [
      req.usuario.id,
      comunidadId,
    ]);
    const r = await db.query(
      "SELECT * FROM sp_usuario_publico_por_id_con_comunidad($1)",
      [req.usuario.id]
    );
    res.json({ usuario: r.rows[0] });
  } catch (error) {
    console.error("Error en POST /UserComunidad:", error);
    res.status(500).json({ msg: "Error interno del servidor" });
  }
});

// GET /Mapa -> recuento de convocatorias por CCAA (todas)
router.get("/Mapa", authRequired, async (_req, res) => {
  try {
    const r = await db.query(
      "SELECT * FROM sp_convocatorias_recuento_por_comunidad()"
    );
    res.json({ comunidades: r.rows });
  } catch (error) {
    console.error("Error en GET /Mapa:", error);
    res.status(500).json({ msg: "Error interno del servidor" });
  }
});

// GET /Convocatorias/:comunidadId -> detalle
router.get("/Convocatorias/:comunidadId", authRequired, async (req, res) => {
  const id = Number(req.params.comunidadId);
  if (!Number.isInteger(id) || id <= 0) {
    return res.status(400).json({ msg: "comunidad_id invalido" });
  }
  try {
    const r = await db.query(
      "SELECT * FROM sp_convocatorias_de_comunidad($1)",
      [id]
    );
    res.json({ convocatorias: r.rows });
  } catch (error) {
    console.error("Error en GET /Convocatorias/:comunidadId:", error);
    res.status(500).json({ msg: "Error interno del servidor" });
  }
});

export default router;
