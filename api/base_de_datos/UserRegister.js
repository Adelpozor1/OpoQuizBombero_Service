import express from "express";
import bcrypt from "bcryptjs";
import db from "../../db.js";
import {
  validarEmail,
  validarPassword,
  validarNombre,
  normalizarEmail,
  rateLimitRegister,
} from "./_seguridad.js";

const router = express.Router();

const BCRYPT_COST = Number(process.env.BCRYPT_COST) || 12;

router.post("/UserRegister", rateLimitRegister, async (req, res) => {
  try {
    const { nombre, email, password } = req.body ?? {};

    if (!validarNombre(nombre) || !validarEmail(email) || !validarPassword(password)) {
      return res.status(400).json({
        msg:
          "Datos invalidos. Nombre y email obligatorios; contraseña de al menos 8 caracteres.",
      });
    }

    const emailNorm = normalizarEmail(email);
    const nombreNorm = String(nombre).trim();
    const hash = await bcrypt.hash(password, BCRYPT_COST);

    try {
      await db.query("SELECT sp_usuario_registrar($1, $2, $3)", [
        nombreNorm,
        emailNorm,
        hash,
      ]);
    } catch (err) {
      if (err.code === "23505") {
        return res.status(409).json({ msg: "El email ya está registrado" });
      }
      throw err;
    }

    res.status(201).json({ msg: "Usuario registrado correctamente" });
  } catch (error) {
    console.error("Error en UserRegister:", error);
    res.status(500).json({ msg: "Error interno del servidor" });
  }
});

export default router;
