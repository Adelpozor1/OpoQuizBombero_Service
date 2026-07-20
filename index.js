import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import userRegisterRouter from "./api/base_de_datos/UserRegister.js";
import userLoginRouter from "./api/base_de_datos/UserLogin.js";

dotenv.config();

const app = express();

app.use(cors({ origin: "http://localhost:3000" }));
app.use(express.json());

app.get("/ping", (req, res) => {
  res.json({ ok: true, msg: "pong" });
});

// Montar rutas de registro
app.use("/api/base_de_datos", userRegisterRouter);
app.use("/api/base_de_datos", userLoginRouter);

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log("Backend escuchando en puerto:", PORT);
});


   




