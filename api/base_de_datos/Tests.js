import express from "express";
import db from "../../db.js";
import { authRequired } from "./_tokens.js";

const router = express.Router();

// GET /Tests -> listado
router.get("/Tests", authRequired, async (req, res) => {
  try {
    const r = await db.query("SELECT * FROM sp_tests_listado()");
    res.json({ tests: r.rows });
  } catch (error) {
    console.error("Error en GET /Tests:", error);
    res.status(500).json({ msg: "Error interno del servidor" });
  }
});

// GET /Test/:id -> cabecera + preguntas
router.get("/Test/:id", authRequired, async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id) || id <= 0) {
    return res.status(400).json({ msg: "Id de test invalido" });
  }
  try {
    const rCab = await db.query("SELECT * FROM sp_test_por_id($1)", [id]);
    if (rCab.rows.length === 0) {
      return res.status(404).json({ msg: "Test no encontrado" });
    }
    const rPre = await db.query("SELECT * FROM sp_test_preguntas($1)", [id]);
    res.json({
      test: rCab.rows[0],
      preguntas: rPre.rows.map((row) => ({
        id: row.pregunta_id,
        orden: row.orden,
        texto: row.texto,
        opciones: row.opciones ?? [],
      })),
    });
  } catch (error) {
    console.error("Error en GET /Test/:id:", error);
    res.status(500).json({ msg: "Error interno del servidor" });
  }
});

// POST /Test/:id/corregir -> corrige server-side
// Body: { respuestas: [{ pregunta_id, opcion_id }] }
router.post("/Test/:id/corregir", authRequired, async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id) || id <= 0) {
    return res.status(400).json({ msg: "Id de test invalido" });
  }
  const respuestas = Array.isArray(req.body?.respuestas) ? req.body.respuestas : null;
  if (!respuestas || respuestas.length === 0 || respuestas.length > 500) {
    return res.status(400).json({ msg: "Respuestas invalidas" });
  }

  try {
    // Obtenemos las preguntas del test una vez para saber cuantas hay y para
    // validar que las preguntas del cliente pertenecen al test.
    const rPre = await db.query("SELECT pregunta_id FROM sp_test_preguntas($1)", [id]);
    if (rPre.rows.length === 0) {
      return res.status(404).json({ msg: "Test no encontrado" });
    }
    const preguntasValidas = new Set(rPre.rows.map((r) => r.pregunta_id));

    const detalles = [];
    let aciertos = 0;

    for (const r of respuestas) {
      const pid = Number(r?.pregunta_id);
      const oid = Number(r?.opcion_id);
      if (!Number.isInteger(pid) || !Number.isInteger(oid)) continue;
      if (!preguntasValidas.has(pid)) continue;

      const rc = await db.query(
        "SELECT * FROM sp_test_corregir_respuesta($1, $2)",
        [pid, oid]
      );
      const fila = rc.rows[0];
      if (!fila) continue;

      if (fila.correcta) aciertos += 1;
      detalles.push({
        pregunta_id: pid,
        opcion_elegida_id: oid,
        correcta: fila.correcta,
        opcion_correcta_id: fila.opcion_correcta_id,
        opcion_correcta_texto: fila.opcion_correcta_txt,
        explicacion: fila.explicacion,
      });
    }

    const total = preguntasValidas.size;
    const puntuacion = total > 0 ? Number(((aciertos / total) * 10).toFixed(2)) : 0;
    const aprobado = puntuacion >= 5;

    res.json({
      test_id: id,
      total,
      aciertos,
      fallos: total - aciertos,
      puntuacion,
      aprobado,
      detalles,
    });
  } catch (error) {
    console.error("Error en POST /Test/:id/corregir:", error);
    res.status(500).json({ msg: "Error interno del servidor" });
  }
});

export default router;
