import { afterEach, describe, expect, it } from "vitest";
import { buildApp } from "../src/app.js";
import { SQLiteAttestationStore } from "../src/attestation.js";
import { renderLanding } from "../src/landing.js";

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
  customFields: [],
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

  it("publishes the privacy policy and developer website", async () => {
    app = await buildApp();
    const website = await app.inject({ method: "GET", url: "/" });
    expect(website.statusCode).toBe(200);
    expect(website.body).toContain("Política de privacidad");
    expect(website.body).toContain("Tus pases.");
    expect(website.body).toContain('href="/favicon.png"');
    expect(website.body).toContain("Ya disponible en la App Store");
    expect(website.body).toContain("Gratis · Anuncios desde 1.1");
    expect(website.body).not.toContain("Sin anuncios");
    expect(website.body).toContain('href="https://apps.apple.com/us/app/anywallet/id6811444719"');
    const favicon = await app.inject({ method: "GET", url: "/favicon.png" });
    expect(favicon.statusCode).toBe(200);
    expect(favicon.headers["content-type"]).toBe("image/png");
    expect(favicon.headers["cache-control"]).toBe("public, max-age=86400");
    expect(favicon.rawPayload.subarray(0, 8)).toEqual(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]));
    const response = await app.inject({ method: "GET", url: "/privacy" });
    expect(response.statusCode).toBe(200);
    expect(response.headers["content-type"]).toContain("text/html");
    expect(response.body).toContain("Google AdMob");
    expect(response.body).toContain("Los campos y códigos del pase no se envían a Google");
  });

  it("publishes the AdMob ownership record as plain text", async () => {
    app = await buildApp();
    const response = await app.inject({ method: "GET", url: "/app-ads.txt" });
    expect(response.statusCode).toBe(200);
    expect(response.headers["content-type"]).toContain("text/plain");
    expect(response.body).toBe("google.com, pub-3290168130965932, DIRECT, f08c47fec0942fa0\n");
  });

  it("serves the English landing and localized support link", async () => {
    app = await buildApp();
    const page = await app.inject({ method: "GET", url: "/?lang=en" });
    expect(page.statusCode).toBe(200);
    expect(page.body).toContain('<html lang="en">');
    expect(page.body).toContain("Now on the App Store");
    expect(page.body).toContain("Free · Ads from 1.1");
    expect(page.body).toContain('href="https://apps.apple.com/us/app/anywallet/id6811444719"');
    expect(page.body).toContain('href="/support?lang=en"');
    expect(page.body).not.toContain("Próximamente");
    const support = await app.inject({ method: "GET", url: "/support?lang=en" });
    expect(support.body).toContain("AnyWallet Support");
    expect(renderLanding("https://apps.apple.com/us/app/anywallet/id6811444719", "es")).toContain("Descargar AnyWallet en la App Store");
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

  it("accepts a custom pass without a barcode", async () => {
    app = await buildApp({ signingIsConfigured: () => true });
    const response = await app.inject({
      method: "POST",
      url: "/v1/passes",
      payload: {
        challenge: testChallenge,
        draft: {
          ...validDraft,
          passKind: "custom",
          barcodeFormat: undefined,
          barcodePayloadBase64: undefined,
          customFields: [{ label: "Nombre", value: "Ane" }],
        },
      },
    });
    expect(response.statusCode).toBe(200);
  });

  it("rejects malformed custom photos before creating a download", async () => {
    app = await buildApp({ signingIsConfigured: () => true });
    const response = await app.inject({
      method: "POST",
      url: "/v1/passes",
      payload: {
        challenge: testChallenge,
        draft: {
          ...validDraft,
          passKind: "custom",
          customFields: [],
          photoAspect: "square",
          photoBase64: Buffer.from("not-an-image").toString("base64"),
        },
      },
    });
    expect(response.statusCode).toBe(400);
    expect(response.json().code).toBe("INVALID_PHOTO");
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
