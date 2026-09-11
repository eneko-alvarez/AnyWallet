import helmet from "@fastify/helmet";
import rateLimit from "@fastify/rate-limit";
import Fastify, { LogController, type FastifyRequest } from "fastify";
import rawBody from "fastify-raw-body";
import { createHash, randomBytes } from "node:crypto";
import { z } from "zod";
import {
  assertRequest as verifyRequestAssertion,
  attestKey as verifyKeyAttestation,
  SQLiteAttestationStore,
  type AttestationStore,
  type AttestedKey,
} from "./attestation.js";
import { config, limits } from "./config.js";
import { createSignedPass, signingIsConfigured, validateCustomPhoto } from "./pass.js";
import type { PassDraft } from "./types.js";

const color = z.string().regex(/^rgb\((?:25[0-5]|2[0-4]\d|1?\d?\d), (?:25[0-5]|2[0-4]\d|1?\d?\d), (?:25[0-5]|2[0-4]\d|1?\d?\d)\)$/);
const challenge = z.string().regex(/^[A-Za-z0-9_-]{43}$/);
const base64 = z.string().regex(/^[A-Za-z0-9+/]+={0,2}$/);
const keyId = z.string().trim().min(20).max(200);
const text = (maximum: number) => z.string().trim().max(maximum).refine(
  (value) => !/[\u0000-\u001F\u007F]/.test(value),
  "Control characters are not allowed",
);

const passDraftSchema = z.object({
  passKind: z.enum(["travel", "membership", "custom"]),
  title: text(80).pipe(z.string().min(1)),
  issuer: text(80).default(""),
  origin: text(60).default(""),
  destination: text(60).default(""),
  passenger: text(80).default(""),
  reference: text(40).default(""),
  memberName: text(80).default(""),
  memberNumber: text(80).default(""),
  relevantDate: z.iso.datetime().nullable(),
  barcodeFormat: z.enum(["qr", "code128", "pdf417", "aztec"]).optional(),
  barcodePayloadBase64: base64.max(Math.ceil(limits.maxBarcodeBytes * 4 / 3) + 4).optional(),
  backgroundColor: color.default("rgb(15, 118, 110)"),
  customFields: z.array(z.object({ label: text(30).pipe(z.string().min(1)), value: text(80).pipe(z.string().min(1)) }).strict()).max(4).default([]),
  photoAspect: z.enum(["square", "portrait", "landscape", "wide"]).optional(),
  photoBase64: base64.max(Math.ceil(limits.maxPhotoBytes * 4 / 3) + 4).optional(),
}).strict();

const createPassSchema = z.object({
  challenge,
  draft: passDraftSchema,
}).strict();

const attestationSchema = z.object({
  challenge,
  keyId,
  attestation: base64.max(32 * 1024),
}).strict();

type PendingPass = { draft: PassDraft; expiresAt: number };
type RequestHeaders = { headers: Record<string, string | string[] | undefined> };
type BuildAppOptions = {
  signingIsConfigured?: () => boolean;
  attestationRequired?: boolean;
  attestationStore?: AttestationStore;
  verifyAttestation?: (input: { attestation: string; challenge: string; keyId: string }) => AttestedKey;
  verifyAssertion?: (input: { assertion: string; keyId: string; payload: Buffer; key: AttestedKey }) => number;
};

export async function buildApp(options: BuildAppOptions = {}) {
  const app = Fastify({
    logger: config.NODE_ENV !== "test",
    logController: new LogController({ disableRequestLogging: true }),
    bodyLimit: 512 * 1024,
    trustProxy: config.TRUST_PROXY ? (_address, hop) => hop === 0 : false,
    requestIdHeader: false,
  });
  const pending = new Map<string, PendingPass>();
  const isSigningConfigured = options.signingIsConfigured ?? signingIsConfigured;
  const attestationRequired = options.attestationRequired ?? config.APP_ATTEST_REQUIRED;
  const ownsStore = attestationRequired && !options.attestationStore;
  const store = attestationRequired
    ? options.attestationStore ?? new SQLiteAttestationStore(config.APP_ATTEST_DATABASE_PATH, limits.challengeTtlMs)
    : undefined;
  const verifyAttestation = options.verifyAttestation ?? ((input) => verifyKeyAttestation(input, {
    bundleIdentifier: config.APP_BUNDLE_IDENTIFIER,
    teamIdentifier: config.APPLE_TEAM_IDENTIFIER,
    allowDevelopmentEnvironment: config.APP_ATTEST_ALLOW_DEVELOPMENT,
  }));
  const verifyAssertion = options.verifyAssertion ?? ((input) => verifyRequestAssertion(input, {
    bundleIdentifier: config.APP_BUNDLE_IDENTIFIER,
    teamIdentifier: config.APPLE_TEAM_IDENTIFIER,
  }));

  await app.register(helmet, { contentSecurityPolicy: false, crossOriginEmbedderPolicy: false });
  await app.register(rateLimit, { global: true, max: 120, timeWindow: "1 minute" });
  await app.register(rawBody, { field: "rawBody", global: false, encoding: false, runFirst: true });

  app.addHook("onRequest", async (request, reply) => {
    if (config.NODE_ENV === "production" && request.protocol !== "https") {
      return reply.code(400).send({ code: "HTTPS_REQUIRED", message: "HTTPS es obligatorio." });
    }
  });
  app.addHook("onSend", async (_request, reply, payload) => {
    reply.header("Cache-Control", "no-store");
    return payload;
  });
  app.addHook("onClose", async () => {
    if (ownsStore) store?.close();
  });

  app.get("/health", { config: { rateLimit: { max: 30, timeWindow: "1 minute" } } }, async () => ({ ok: true }));

  app.post("/v1/attest/challenge", {
    config: { rateLimit: { max: 20, timeWindow: "1 minute" } },
  }, async (_request, reply) => {
    if (!store) return reply.code(404).send({ code: "NOT_FOUND", message: "Ruta no disponible." });
    return { challenge: store.issueChallenge() };
  });

  app.post("/v1/attest", {
    config: { rateLimit: { max: 10, timeWindow: "1 minute" } },
  }, async (request, reply) => {
    if (!store) return reply.code(404).send({ code: "NOT_FOUND", message: "Ruta no disponible." });
    const parsed = attestationSchema.safeParse(request.body);
    if (!parsed.success || !store.consumeChallenge(parsed.data.challenge)) return unauthorized(reply);
    try {
      const verified = verifyAttestation(parsed.data);
      if (store.findKey(parsed.data.keyId)) return unauthorized(reply);
      store.saveKey(parsed.data.keyId, verified);
      return reply.code(204).send();
    } catch {
      request.log.warn("App Attest registration rejected");
      return unauthorized(reply);
    }
  });

  app.post("/v1/passes", {
    config: {
      rawBody: true,
      rateLimit: {
        max: 30,
        timeWindow: "1 hour",
        keyGenerator: (request: FastifyRequest) => header(request, "x-app-attest-key-id") ?? request.ip,
      },
    },
  }, async (request, reply) => {
    const parsed = createPassSchema.safeParse(request.body);
    if (!parsed.success) {
      const details = parsed.error.issues.map((issue) => ({ field: issue.path.join(".") || "body", message: issue.message }));
      request.log.warn({ fields: details.map((detail) => detail.field) }, "Invalid pass draft");
      return reply.code(400).send({ code: "INVALID_PASS", message: "Revisa los datos del pase.", details });
    }
    if (store) {
      const assertion = header(request, "x-app-attest-assertion");
      const requestKeyId = header(request, "x-app-attest-key-id");
      const registeredKey = requestKeyId ? store.findKey(requestKeyId) : undefined;
      const payload = (request as unknown as { rawBody?: Buffer }).rawBody;
      if (!assertion || !requestKeyId || !registeredKey || !payload || !store.consumeChallenge(parsed.data.challenge)) {
        return unauthorized(reply);
      }
      try {
        const signCount = verifyAssertion({ assertion, keyId: requestKeyId, payload, key: registeredKey });
        store.saveKey(requestKeyId, { ...registeredKey, signCount });
      } catch {
        request.log.warn("App Attest assertion rejected");
        return unauthorized(reply);
      }
    }

    const draft = parsed.data.draft;
    const barcodeBytes = draft.barcodePayloadBase64 ? Buffer.from(draft.barcodePayloadBase64, "base64") : undefined;
    const hasCompleteBarcode = Boolean(draft.barcodeFormat && barcodeBytes?.byteLength);
    if ((draft.passKind !== "custom" && !hasCompleteBarcode) ||
        Boolean(draft.barcodeFormat) !== Boolean(draft.barcodePayloadBase64) ||
        (barcodeBytes && barcodeBytes.byteLength > limits.maxBarcodeBytes)) {
      return reply.code(400).send({ code: "INVALID_BARCODE", message: "El código seleccionado no es válido." });
    }
    if (draft.passKind !== "custom" && (draft.customFields.length || draft.photoBase64 || draft.photoAspect)) {
      return reply.code(400).send({ code: "INVALID_CUSTOM_DATA", message: "Los datos personalizados no corresponden a este tipo de pase." });
    }
    if (Boolean(draft.photoBase64) !== Boolean(draft.photoAspect)) {
      return reply.code(400).send({ code: "INVALID_PHOTO", message: "La imagen del pase está incompleta." });
    }
    if (draft.photoBase64) {
      const photo = Buffer.from(draft.photoBase64, "base64");
      if (photo.byteLength === 0 || photo.byteLength > limits.maxPhotoBytes || !(await validateCustomPhoto(photo))) {
        return reply.code(400).send({ code: "INVALID_PHOTO", message: "La imagen del pase no es válida." });
      }
    }
    if (!isSigningConfigured()) {
      return reply.code(503).send({ code: "SIGNING_UNAVAILABLE", message: "El servicio de firma no está disponible." });
    }
    if (pending.size >= limits.maxPendingPasses) {
      return reply.code(503).send({ code: "SERVER_BUSY", message: "El servicio está ocupado. Inténtalo de nuevo." });
    }
    const token = randomBytes(32).toString("base64url");
    pending.set(tokenDigest(token), { draft, expiresAt: Date.now() + limits.passTtlMs });
    return { downloadUrl: `${config.PUBLIC_BASE_URL}/v1/passes/${token}`, expiresInSeconds: limits.passTtlMs / 1000 };
  });

  app.get<{ Params: { token: string } }>("/v1/passes/:token", {
    config: { rateLimit: { max: 60, timeWindow: "1 minute" } },
  }, async (request, reply) => {
    const digest = tokenDigest(request.params.token);
    const entry = pending.get(digest);
    pending.delete(digest);
    if (!entry || entry.expiresAt < Date.now()) {
      return reply.code(404).send({ code: "PASS_EXPIRED", message: "El enlace del pase ha caducado." });
    }
    try {
      const pass = await createSignedPass(entry.draft);
      return reply
        .header("Content-Type", "application/vnd.apple.pkpass")
        .header("Content-Disposition", 'attachment; filename="anywallet.pkpass"')
        .send(pass);
    } catch {
      request.log.error("Pass generation failed");
      return reply.code(500).send({ code: "PASS_FAILED", message: "No se ha podido firmar el pase." });
    }
  });

  app.addHook("onRequest", async () => {
    const now = Date.now();
    for (const [token, entry] of pending) if (entry.expiresAt < now) pending.delete(token);
  });

  return app;
}

function header(request: RequestHeaders, name: string): string | undefined {
  const value = request.headers[name];
  return typeof value === "string" ? value : undefined;
}

function tokenDigest(token: string): string {
  return createHash("sha256").update(token).digest("hex");
}

function unauthorized(reply: { code(statusCode: number): { send(payload: unknown): unknown } }) {
  return reply.code(401).send({ code: "UNAUTHORIZED", message: "Cliente no autorizado." });
}
