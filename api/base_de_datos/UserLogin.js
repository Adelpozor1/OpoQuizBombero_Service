import express from "express";
import bcrypt from "bcryptjs";
import db from "../../db.js";

const router = express.Router();

router.post("/UserLogin", async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ msg: "Email y contraseña son obligatorios" });
    }

    const result = await db.query(
      "SELECT id, nombre, email, password FROM usuarios WHERE email = $1",
      [email]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ msg: "Credenciales incorrectas" });
    }

    const usuario = result.rows[0];
    const coincide = await bcrypt.compare(password, usuario.password);

    if (!coincide) {
      return res.status(401).json({ msg: "Credenciales incorrectas" });
    }

    res.json({
      msg: "Login correcto",
      usuario: { id: usuario.id, nombre: usuario.nombre, email: usuario.email },
    });
  } catch (error) {
    console.error("Error en UserLogin:", error);
    res.status(500).json({ msg: "Error interno del servidor" });
  }
});

export default router;
