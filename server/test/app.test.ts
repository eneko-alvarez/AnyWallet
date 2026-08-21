import { afterEach, describe, expect, it } from "vitest";
import { buildApp } from "../src/app.js";
import { SQLiteAttestationStore } from "../src/attestation.js";

const testChallenge = "A".repeat(43);
const validDraft = {
  passKind: "travel",
  title: "Mi billete",
  issuer: "",
  origin: "",
  destination: "",
  passenger: "",
  reference: "",
  memberName: "",
  memberNumber: "",
  relevantDate: null,
  barcodeFormat: "qr",
  barcodePayloadBase64: Buffer.from("ABC123").toString("base64"),
  backgroundColor: "rgb(15, 118, 110)",
};

describe("API", () => {
  let app: Awaited<ReturnType<typeof buildApp>> | undefined;
  let store: SQLiteAttestationStore | undefined;
  afterEach(async () => {
    await app?.close();
    store?.close();
  });

  it("exposes a minimal health response", async () => {
    app = await buildApp({ signingIsConfigured: () => false });
    const response = await app.inject({ method: "GET", url: "/health" });
    expect(response.statusCode).toBe(200);
    expect(response.json()).toEqual({ ok: true });
    expect(response.headers["cache-control"]).toBe("no-store");
    expect(response.headers["x-content-type-options"]).toBe("nosniff");
  });

  it("does not expose a PDF upload endpoint", async () => {
    app = await buildApp();
    const response = await app.inject({ method: "POST", url: "/v1/analyze" });
    expect(response.statusCode).toBe(404);
  });

  it("returns field-level validation details", async () => {
    app = await buildApp({ signingIsConfigured: () => true });
    const response = await app.inject({
      method: "POST",
      url: "/v1/passes",
      payload: { challenge: testChallenge, draft: { title: "" } },
    });

    expect(response.statusCode).toBe(400);
    expect(response.json()).toMatchObject({
      code: "INVALID_PASS",
      details: expect.arrayContaining([expect.objectContaining({ field: "draft.passKind" })]),
    });
  });

  it("does not pretend to create a pass without Apple certificates", async () => {
    app = await buildApp({ signingIsConfigured: () => false });
    const response = await app.inject({
      method: "POST",
      url: "/v1/passes",
      payload: {
        challenge: testChallenge,
        draft: validDraft,
      },
    });
    expect(response.statusCode).toBe(503);
    expect(response.json().code).toBe("SIGNING_UNAVAILABLE");
  });

  it("rejects unknown pass fields", async () => {
    app = await buildApp({ signingIsConfigured: () => true });
    const response = await app.inject({
      method: "POST",
      url: "/v1/passes",
      payload: { challenge: testChallenge, draft: { ...validDraft, admin: true } },
    });
    expect(response.statusCode).toBe(400);
  });

  it("requires an attested key and a fresh assertion for pass creation", async () => {
    store = new SQLiteAttestationStore(":memory:", 120_000);
    app = await buildApp({
      signingIsConfigured: () => true,
      attestationRequired: true,
      attestationStore: store,
      verifyAttestation: () => ({ publicKey: "test-public-key", signCount: 0 }),
      verifyAssertion: ({ payload, key }) => {
        expect(payload.toString()).toContain("Mi billete");
        return key.signCount + 1;
      },
    });

    const unauthenticated = await app.inject({
      method: "POST",
      url: "/v1/passes",
      payload: { challenge: testChallenge, draft: validDraft },
    });
    expect(unauthenticated.statusCode).toBe(401);

    const registrationChallenge = (await app.inject({ method: "POST", url: "/v1/attest/challenge" })).json().challenge;
    const key = "test-key-identifier-123456789";
    const registration = await app.inject({
      method: "POST",
      url: "/v1/attest",
      payload: { challenge: registrationChallenge, keyId: key, attestation: "YXR0ZXN0YXRpb24=" },
    });
    expect(registration.statusCode).toBe(204);

    const requestChallenge = (await app.inject({ method: "POST", url: "/v1/attest/challenge" })).json().challenge;
    const payload = { challenge: requestChallenge, draft: validDraft };
    const authenticated = await app.inject({
      method: "POST",
      url: "/v1/passes",
      headers: {
        "x-app-attest-key-id": key,
        "x-app-attest-assertion": "YXNzZXJ0aW9u",
      },
      payload,
    });
    expect(authenticated.statusCode).toBe(200);
    expect(authenticated.json().downloadUrl).toContain("/v1/passes/");

    const replay = await app.inject({
      method: "POST",
      url: "/v1/passes",
      headers: {
        "x-app-attest-key-id": key,
        "x-app-attest-assertion": "YXNzZXJ0aW9u",
      },
      payload,
    });
    expect(replay.statusCode).toBe(401);
  });
});
