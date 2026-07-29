import bcrypt from "bcryptjs";
import db from "./db.js";

const USUARIO_PRUEBA = {
  nombre: "Usuario Test",
  email: "test@opoquiz.com",
  // Password aleatoria de 20 caracteres. No es un secreto real: sirve solo
  // para el usuario de dev. Rota con `openssl rand -base64 18 | tr -d '/+='`.
  password: "NtPi5sanIyCdwQNrCknd",
};

async function seed() {
  try {
    const hash = await bcrypt.hash(USUARIO_PRUEBA.password, 12);

    try {
      await db.query("SELECT sp_usuario_registrar($1, $2, $3)", [
        USUARIO_PRUEBA.nombre,
        USUARIO_PRUEBA.email,
        hash,
      ]);
      console.log("Usuario de prueba creado:");
    } catch (err) {
      if (err.code !== "23505") throw err;
      // Ya existia: actualizamos la password para que el seed sea idempotente.
      await db.query(
        "SELECT sp_usuario_actualizar_password_por_email($1, $2)",
        [USUARIO_PRUEBA.email, hash]
      );
      console.log("Usuario de prueba ya existia. Password actualizada:");
    }

    console.log("  Email:   ", USUARIO_PRUEBA.email);
    console.log("  Password:", USUARIO_PRUEBA.password);
    process.exit(0);
  } catch (error) {
    console.error("Error en seed:", error.message);
    process.exit(1);
  }
}

seed();
