import express from "express";
import db from "../../db.js";
import { authRequired } from "./_tokens.js";

const router = express.Router();

// ------------------------------------------------------------
// Helpers
// ------------------------------------------------------------

function idValido(x) {
  const n = Number(x);
  return Number.isInteger(n) && n > 0 ? n : null;
}

async function cargarSesion(sesionId, usuarioId) {
  const r = await db.query("SELECT * FROM sp_sesion_cabecera($1, $2)", [
    sesionId,
    usuarioId,
  ]);
  const s = r.rows[0];
  if (!s) return { estado: "no_encontrada" };
  if (!s.es_propietario) return { estado: "no_autorizada" };
  return { estado: "ok", sesion: s };
}

async function cargarTestConfig(testId) {
  const r = await db.query("SELECT * FROM sp_test_config($1)", [testId]);
  return r.rows[0] ?? null;
}

async function cargarPreguntas(testId, semilla) {
  const r = await db.query("SELECT * FROM sp_test_preguntas_estudio($1, $2)", [
    testId,
    semilla,
  ]);
  return r.rows.map((row) => ({
    id: row.pregunta_id,
    orden: row.orden,
    texto: row.texto,
    imagen_url: row.imagen_url,
    es_pregunta_negativa: row.es_pregunta_negativa,
    estado: row.estado,
    explicacion_estado: row.explicacion_estado,
    titulo_url: row.titulo_url,
    url: row.url,
    tematicas: row.tematicas ?? [],
    opciones: row.opciones ?? [],
    anulada_en_test: row.anulada_en_test,
    anulada_motivo: row.anulada_motivo,
  }));
}

// ------------------------------------------------------------
// POST /EstudioSesion  — inicia sesion + devuelve preguntas
// body: { test_id, modo: 'estudio'|'examen' }
// ------------------------------------------------------------
router.post("/EstudioSesion", authRequired, async (req, res) => {
  const testId = idValido(req.body?.test_id);
  const modo = req.body?.modo === "estudio" ? "estudio" : "examen";
  if (!testId) return res.status(400).json({ msg: "test_id invalido" });

  try {
    const test = await cargarTestConfig(testId);
    if (!test) return res.status(404).json({ msg: "Test no encontrado" });

    const rInit = await db.query("SELECT * FROM sp_sesion_iniciar($1, $2, $3)", [
      req.usuario.id,
      testId,
      modo,
    ]);
    const { sesion_id, semilla } = rInit.rows[0];
    const preguntas = await cargarPreguntas(testId, semilla);

    res.json({ sesion_id, semilla, modo, test, preguntas });
  } catch (error) {
    console.error("Error POST /EstudioSesion:", error);
    res.status(500).json({ msg: "Error interno del servidor" });
  }
});

// ------------------------------------------------------------
// GET /EstudioSesion/:id  — recargar sesion (por si F5)
// ------------------------------------------------------------
router.get("/EstudioSesion/:id", authRequired, async (req, res) => {
  const sesionId = idValido(req.params.id);
  if (!sesionId) return res.status(400).json({ msg: "id invalido" });

  try {
    const { estado, sesion } = await cargarSesion(sesionId, req.usuario.id);
    if (estado === "no_encontrada") return res.status(404).json({ msg: "Sesion no encontrada" });
    if (estado === "no_autorizada") return res.status(403).json({ msg: "Sesion de otro usuario" });

    const test = await cargarTestConfig(sesion.test_id);
    const preguntas = await cargarPreguntas(sesion.test_id, sesion.semilla);

    const respuestas = await db.query(
      "SELECT pregunta_id FROM sp_sesion_preguntas_respondidas($1)",
      [sesionId]
    );

    res.json({
      sesion_id: sesion.id,
      modo: sesion.modo,
      iniciada_at: sesion.iniciada_at,
      finalizada_at: sesion.finalizada_at,
      test,
      preguntas,
      respuestas: respuestas.rows,
    });
  } catch (error) {
    console.error("Error GET /EstudioSesion/:id:", error);
    res.status(500).json({ msg: "Error interno del servidor" });
  }
});

// ------------------------------------------------------------
// POST /EstudioSesion/:id/respuesta
// body: { pregunta_id, opcion_id (null si no contesta), tiempo_ms? }
// Modo estudio → devuelve correccion inmediata segun tipo_correccion.
// Modo examen  → solo guarda; sin filtracion de correcta.
// ------------------------------------------------------------
router.post("/EstudioSesion/:id/respuesta", authRequired, async (req, res) => {
  const sesionId = idValido(req.params.id);
  const preguntaId = idValido(req.body?.pregunta_id);
  const opcionIdRaw = req.body?.opcion_id;
  const opcionId = opcionIdRaw == null ? null : idValido(opcionIdRaw);
  const tiempoMs = Number.isInteger(req.body?.tiempo_ms) ? req.body.tiempo_ms : null;

  if (!sesionId || !preguntaId) {
    return res.status(400).json({ msg: "Datos invalidos" });
  }
  if (opcionIdRaw != null && opcionId == null) {
    return res.status(400).json({ msg: "opcion_id invalido" });
  }

  try {
    const { estado, sesion } = await cargarSesion(sesionId, req.usuario.id);
    if (estado === "no_encontrada") return res.status(404).json({ msg: "Sesion no encontrada" });
    if (estado === "no_autorizada") return res.status(403).json({ msg: "Sesion de otro usuario" });
    if (sesion.finalizada_at) return res.status(409).json({ msg: "Sesion ya finalizada" });

    let esCorrecta = false;
    if (opcionId) {
      const r = await db.query("SELECT sp_opcion_verificar($1, $2) AS es_correcta", [
        preguntaId,
        opcionId,
      ]);
      const val = r.rows[0]?.es_correcta;
      if (val === null || val === undefined) {
        return res.status(400).json({ msg: "opcion_id no pertenece a la pregunta" });
      }
      esCorrecta = !!val;
    }

    await db.query("SELECT sp_respuesta_guardar($1, $2, $3, $4, $5)", [
      sesionId,
      preguntaId,
      opcionId,
      esCorrecta,
      tiempoMs,
    ]);

    // Actualiza estadisticas del usuario (autodiagnostico).
    await db.query(
      "SELECT sp_usuario_stats_registrar($1, $2, $3, $4)",
      [req.usuario.id, preguntaId, esCorrecta, opcionId != null]
    );

    if (sesion.modo === "estudio") {
      // Correccion inmediata segun tipo_correccion del test.
      const r = await db.query(
        "SELECT * FROM sp_test_corregir_respuesta_v2($1, $2, $3)",
        [sesion.test_id, preguntaId, opcionId]
      );
      const fila = r.rows[0] ?? {};
      return res.json({
        guardada: true,
        modo: "estudio",
        correcta: !!fila.correcta,
        tipo_correccion: fila.tipo_correccion,
        anulada_en_test: !!fila.anulada_en_test,
        opcion_correcta_id: fila.opcion_correcta_id,
        opcion_correcta_texto: fila.opcion_correcta_texto,
        explicacion_global: fila.explicacion_global,
        explicacion_especifica: fila.explicacion_especifica,
        explicacion_correcta: fila.explicacion_correcta,
      });
    }

    // Modo examen: no reveles nada mas.
    res.json({ guardada: true, modo: "examen" });
  } catch (error) {
    console.error("Error POST /EstudioSesion/:id/respuesta:", error);
    res.status(500).json({ msg: "Error interno del servidor" });
  }
});

// ------------------------------------------------------------
// POST /EstudioSesion/:id/finalizar
// body: { tiempo_total_ms? }
// Calcula puntuacion con las reglas del test y persiste.
// ------------------------------------------------------------
router.post("/EstudioSesion/:id/finalizar", authRequired, async (req, res) => {
  const sesionId = idValido(req.params.id);
  if (!sesionId) return res.status(400).json({ msg: "id invalido" });

  try {
    const { estado, sesion } = await cargarSesion(sesionId, req.usuario.id);
    if (estado === "no_encontrada") return res.status(404).json({ msg: "Sesion no encontrada" });
    if (estado === "no_autorizada") return res.status(403).json({ msg: "Sesion de otro usuario" });
    if (sesion.finalizada_at) return res.status(409).json({ msg: "Sesion ya finalizada" });

    const test = await cargarTestConfig(sesion.test_id);
    const rDet = await db.query("SELECT * FROM sp_sesion_examen_detalle($1)", [sesionId]);
    const detalles = rDet.rows;

    // Estadisticas para preguntas que no contesto (no habran quedado guardadas).
    const respondidas = new Set(
      (await db.query(
        "SELECT pregunta_id FROM sp_sesion_preguntas_respondidas($1)",
        [sesionId]
      )).rows.map((r) => r.pregunta_id)
    );
    for (const d of detalles) {
      if (!respondidas.has(d.pregunta_id) && !d.anulada_en_test) {
        await db.query(
          "SELECT sp_usuario_stats_registrar($1, $2, $3, $4)",
          [req.usuario.id, d.pregunta_id, false, false]
        );
      }
    }

    // Reglas de calificacion (con defensa por si el test viene sin config).
    const notaMaxima = Number(test?.nota_maxima ?? 10);
    const notaApto = Number(test?.nota_apto ?? 5);
    const penalFallo = Number(test?.penalizacion_fallo ?? 0);
    const penalNC = Number(test?.penalizacion_no_contestada ?? 0);

    const validas = detalles.filter((d) => !d.anulada_en_test);
    const totalEfectivo = validas.length;
    let aciertos = 0, fallos = 0, sinContestar = 0;
    for (const d of validas) {
      if (!d.contestada) sinContestar += 1;
      else if (d.correcta) aciertos += 1;
      else fallos += 1;
    }
    const anuladas = detalles.length - validas.length;

    const notaPregunta = totalEfectivo > 0 ? notaMaxima / totalEfectivo : 0;
    const puntos = aciertos * notaPregunta
                 - fallos * notaPregunta * penalFallo
                 - sinContestar * notaPregunta * penalNC;
    const puntuacion = Number(Math.max(0, puntos).toFixed(2));
    const aprobado = puntuacion >= notaApto;

    const tiempoTotalMs = Number.isInteger(req.body?.tiempo_total_ms)
      ? req.body.tiempo_total_ms
      : null;

    await db.query("SELECT sp_sesion_finalizar($1, $2, $3, $4)", [
      sesionId,
      puntuacion,
      aprobado,
      tiempoTotalMs,
    ]);

    res.json({
      sesion_id: sesionId,
      modo: sesion.modo,
      total: detalles.length,
      total_efectivo: totalEfectivo,
      aciertos,
      fallos,
      sin_contestar: sinContestar,
      anuladas,
      nota_apto: notaApto,
      nota_maxima: notaMaxima,
      puntuacion,
      aprobado,
      tipo_correccion: test?.tipo_correccion ?? "rojo_verde_explicacion",
      detalles,
    });
  } catch (error) {
    console.error("Error POST /EstudioSesion/:id/finalizar:", error);
    res.status(500).json({ msg: "Error interno del servidor" });
  }
});

// ------------------------------------------------------------
// GET /EstudioStats — autodiagnostico del usuario.
// ------------------------------------------------------------
router.get("/EstudioStats", authRequired, async (req, res) => {
  try {
    const totalesQ = await db.query("SELECT * FROM sp_usuario_stats_totales($1)", [
      req.usuario.id,
    ]);
    const sesionesQ = await db.query("SELECT * FROM sp_usuario_sesiones_resumen($1)", [
      req.usuario.id,
    ]);
    const topFallos = await db.query(
      "SELECT * FROM sp_usuario_stats_top_fallos($1, $2)",
      [req.usuario.id, 10]
    );

    res.json({
      totales: totalesQ.rows[0],
      sesiones: sesionesQ.rows[0],
      top_fallos: topFallos.rows,
    });
  } catch (error) {
    console.error("Error GET /EstudioStats:", error);
    res.status(500).json({ msg: "Error interno del servidor" });
  }
});

// ------------------------------------------------------------
// PATCH /Backoffice/Preguntas/:id/revisada — Martin marca revisada
// body: { revisada: boolean }
// TODO: restringir a rol admin cuando exista.
// ------------------------------------------------------------
router.patch("/Backoffice/Preguntas/:id/revisada", authRequired, async (req, res) => {
  const preguntaId = idValido(req.params.id);
  if (!preguntaId) return res.status(400).json({ msg: "id invalido" });
  const revisada = req.body?.revisada === true;

  try {
    await db.query("SELECT sp_pregunta_marcar_revisada($1, $2)", [preguntaId, revisada]);
    res.json({ pregunta_id: preguntaId, revisada });
  } catch (error) {
    console.error("Error PATCH /Backoffice/Preguntas/:id/revisada:", error);
    res.status(500).json({ msg: "Error interno del servidor" });
  }
});

export default router;
