import Fastify from "fastify";
import { randomBytes } from "node:crypto";
import { z } from "zod";
import { config, limits } from "./config.js";
import { createSignedPass, signingIsConfigured } from "./pass.js";
import type { PassDraft } from "./types.js";

const color = z.string().regex(/^rgb\(\d{1,3}, \d{1,3}, \d{1,3}\)$/);
const passDraftSchema = z.object({
  title: z.string().trim().min(1).max(80),
  issuer: z.string().trim().max(80).default(""),
  origin: z.string().trim().max(60).default(""),
  destination: z.string().trim().max(60).default(""),
  passenger: z.string().trim().max(80).default(""),
  reference: z.string().trim().max(40).default(""),
  relevantDate: z.iso.datetime().nullable(),
  qrPayloadBase64: z.string().min(1).max(Math.ceil(limits.maxQrBytes * 4 / 3) + 4),
  backgroundColor: color.default("rgb(15, 118, 110)"),
  sourceFilename: z.string().trim().min(1).max(180),
});

type PendingPass = { draft: PassDraft; expiresAt: number };

export async function buildApp() {
  const app = Fastify({ logger: process.env.NODE_ENV !== "test", bodyLimit: 64 * 1024 });
  const pending = new Map<string, PendingPass>();

  app.get("/health", async () => ({ ok: true, signingConfigured: signingIsConfigured() }));

  app.post("/v1/passes", async (request, reply) => {
    const parsed = passDraftSchema.safeParse(request.body);
    if (!parsed.success) return reply.code(400).send({ code: "INVALID_PASS", message: "Revisa los datos del billete." });
    const qrBytes = Buffer.from(parsed.data.qrPayloadBase64, "base64");
    if (qrBytes.byteLength === 0 || qrBytes.byteLength > limits.maxQrBytes) {
      return reply.code(400).send({ code: "INVALID_QR", message: "El QR seleccionado no es válido." });
    }
    if (!signingIsConfigured()) {
      return reply.code(503).send({
        code: "SIGNING_NOT_CONFIGURED",
        message: "Falta configurar el certificado Pass Type ID del proyecto.",
      });
    }
    const token = randomBytes(24).toString("base64url");
    pending.set(token, { draft: parsed.data, expiresAt: Date.now() + limits.passTtlMs });
    return { downloadUrl: `${config.PUBLIC_BASE_URL}/v1/passes/${token}`, expiresInSeconds: limits.passTtlMs / 1000 };
  });

  app.get<{ Params: { token: string } }>("/v1/passes/:token", async (request, reply) => {
    const entry = pending.get(request.params.token);
    pending.delete(request.params.token);
    if (!entry || entry.expiresAt < Date.now()) {
      return reply.code(404).send({ code: "PASS_EXPIRED", message: "El enlace del pase ha caducado." });
    }
    try {
      const pass = await createSignedPass(entry.draft);
      return reply
        .header("Content-Type", "application/vnd.apple.pkpass")
        .header("Content-Disposition", 'attachment; filename="anywallet.pkpass"')
        .header("Cache-Control", "no-store")
        .send(pass);
    } catch (error) {
      request.log.error({ error }, "Pass generation failed");
      return reply.code(500).send({ code: "PASS_FAILED", message: "No se ha podido firmar el pase." });
    }
  });

  app.addHook("onRequest", async () => {
    const now = Date.now();
    for (const [token, entry] of pending) if (entry.expiresAt < now) pending.delete(token);
  });

  return app;
}
