import bcrypt from "bcryptjs";
import db from "./db.js";

const USUARIO_PRUEBA = {
  nombre: "Usuario Test",
  email: "test@opoquiz.com",
  password: "test1234",
};

async function seed() {
  try {
    const existing = await db.query("SELECT id FROM usuarios WHERE email = $1", [USUARIO_PRUEBA.email]);

    if (existing.rows.length > 0) {
      console.log("El usuario de prueba ya existe:", USUARIO_PRUEBA.email);
      process.exit(0);
    }

    const hash = await bcrypt.hash(USUARIO_PRUEBA.password, 10);
    await db.query(
      "INSERT INTO usuarios (nombre, email, password) VALUES ($1, $2, $3)",
      [USUARIO_PRUEBA.nombre, USUARIO_PRUEBA.email, hash]
    );

    console.log("Usuario de prueba creado:");
    console.log("  Email:   ", USUARIO_PRUEBA.email);
    console.log("  Password:", USUARIO_PRUEBA.password);
    process.exit(0);
  } catch (error) {
    console.error("Error en seed:", error.message);
    process.exit(1);
  }
}

seed();
