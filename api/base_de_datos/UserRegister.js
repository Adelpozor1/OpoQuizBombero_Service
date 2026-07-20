import express from "express";
import bcrypt from "bcryptjs";
import db from "../../db.js";

const router = express.Router();

router.post("/UserRegister", async (req, res) => {
  try {
    const { nombre, email, password } = req.body;

    if (!nombre || !email || !password) {
      return res.status(400).json({ msg: "Todos los campos son obligatorios" });
    }

    const existing = await db.query("SELECT id FROM usuarios WHERE email = $1", [email]);
    if (existing.rows.length > 0) {
      return res.status(409).json({ msg: "El email ya está registrado" });
    }

    const hash = await bcrypt.hash(password, 10);

    await db.query(
      "INSERT INTO usuarios (nombre, email, password) VALUES ($1, $2, $3)",
      [nombre, email, hash]
    );

    res.status(201).json({ msg: "Usuario registrado correctamente" });
  } catch (error) {
    console.error("Error en UserRegister:", error);
    res.status(500).json({ msg: "Error interno del servidor" });
  }
});

export default router;
