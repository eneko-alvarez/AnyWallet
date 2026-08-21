import { buildApp } from "./app.js";
import { config } from "./config.js";
import { signingIsConfigured } from "./pass.js";

if (config.NODE_ENV === "production" && !signingIsConfigured()) {
  throw new Error("Pass signing credentials are missing or unreadable");
}

const app = await buildApp();
await app.listen({ port: config.PORT, host: "0.0.0.0" });
