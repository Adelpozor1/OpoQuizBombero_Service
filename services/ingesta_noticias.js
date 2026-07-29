import Parser from "rss-parser";
import db from "../db.js";

const parser = new Parser({
  timeout: 15000,
  headers: {
    "User-Agent":
      "OpoQuizBomberoBot/1.0 (+https://opoquizbombero.local; contacto@opoquizbombero.local)",
  },
});

// Devuelve TRUE si el item pasa el filtro de keywords de la fuente.
// Si la fuente no tiene keywords, todo pasa.
function pasaFiltro(item, keywordsCsv) {
  if (!keywordsCsv) return true;
  const kws = keywordsCsv
    .split(",")
    .map((k) => k.trim().toLowerCase())
    .filter(Boolean);
  if (kws.length === 0) return true;
  const heno = `${item.title || ""} ${item.contentSnippet || item.content || ""}`.toLowerCase();
  return kws.some((k) => heno.includes(k));
}

function resumenDeItem(item) {
  const bruto = item.contentSnippet || item.summary || item.content || "";
  const limpio = bruto.replace(/\s+/g, " ").trim();
  return limpio.length > 600 ? limpio.slice(0, 597) + "…" : limpio;
}

async function ingestarFuente(fuente) {
  const feed = await parser.parseURL(fuente.url_rss);
  let insertadas = 0;
  let leidas = 0;

  for (const item of feed.items || []) {
    leidas += 1;
    if (!pasaFiltro(item, fuente.keywords)) continue;

    const guid = item.guid || item.id || item.link;
    if (!guid) continue;

    const publicada = item.isoDate ? new Date(item.isoDate) : new Date();

    const r = await db.query(
      "SELECT sp_noticia_insertar($1, $2, $3, $4, $5, $6, $7, $8) AS id",
      [
        fuente.id,
        fuente.comunidad_id ?? null,
        String(item.title || "").trim().slice(0, 500),
        resumenDeItem(item),
        String(item.link || "").trim(),
        item.enclosure?.url ?? null,
        String(guid).slice(0, 500),
        publicada,
      ]
    );
    if (r.rows[0]?.id) insertadas += 1;
  }

  await db.query("SELECT sp_fuente_marcar_lectura($1)", [fuente.id]);

  return { fuente_id: fuente.id, nombre: fuente.nombre, leidas, insertadas };
}

// Recorre todas las fuentes activas y las ingesta. Devuelve un resumen.
// Los errores por fuente se capturan para no cortar el resto.
export async function ejecutarIngesta() {
  const r = await db.query("SELECT * FROM sp_fuentes_activas()");
  const resultados = [];
  for (const fuente of r.rows) {
    try {
      const info = await ingestarFuente(fuente);
      resultados.push({ ok: true, ...info });
    } catch (err) {
      console.error(
        "[ingesta] fuente=%d %s error=%s",
        fuente.id,
        fuente.nombre,
        err.message
      );
      resultados.push({
        ok: false,
        fuente_id: fuente.id,
        nombre: fuente.nombre,
        error: err.message,
      });
    }
  }
  return resultados;
}
