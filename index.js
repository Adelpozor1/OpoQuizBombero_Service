import express from "express";
import cors from "cors";
import helmet from "helmet";
import cookieParser from "cookie-parser";
import dotenv from "dotenv";
import userRegisterRouter from "./api/base_de_datos/UserRegister.js";
import userLoginRouter from "./api/base_de_datos/UserLogin.js";
import userRefreshRouter from "./api/base_de_datos/UserRefresh.js";
import userLogoutRouter from "./api/base_de_datos/UserLogout.js";
import userMeRouter from "./api/base_de_datos/UserMe.js";
import testsRouter from "./api/base_de_datos/Tests.js";
import portalRouter from "./api/base_de_datos/Portal.js";
import adminRouter from "./api/base_de_datos/Admin.js";
import estudioRouter from "./api/base_de_datos/Estudio.js";

dotenv.config();

const app = express();

// Trust proxy: para que express-rate-limit vea la IP real detras de proxy.
app.set("trust proxy", Number(process.env.TRUST_PROXY ?? 1));

// Cabeceras de seguridad por defecto.
app.use(helmet());

// CORS con credentials para que la cookie refresh viaje.
const corsOrigin = process.env.CORS_ORIGIN || "http://localhost:3000";
app.use(
  cors({
    origin: corsOrigin,
    methods: ["GET", "POST"],
    credentials: true,
  })
);

app.use(express.json({ limit: "10kb" }));
app.use(cookieParser());

app.get("/ping", (req, res) => {
  res.json({ ok: true, msg: "pong" });
});

app.use("/api/base_de_datos", userRegisterRouter);
app.use("/api/base_de_datos", userLoginRouter);
app.use("/api/base_de_datos", userRefreshRouter);
app.use("/api/base_de_datos", userLogoutRouter);
app.use("/api/base_de_datos", userMeRouter);
app.use("/api/base_de_datos", testsRouter);
app.use("/api/base_de_datos", portalRouter);
app.use("/api/base_de_datos", adminRouter);
app.use("/api/base_de_datos", estudioRouter);

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log("Backend escuchando en puerto:", PORT);
});
