import { afterEach, describe, expect, it } from "vitest";
import { buildApp } from "../src/app.js";

describe("API", () => {
  let app: Awaited<ReturnType<typeof buildApp>> | undefined;
  afterEach(async () => app?.close());

  it("exposes signing readiness", async () => {
    app = await buildApp();
    const response = await app.inject({ method: "GET", url: "/health" });
    expect(response.statusCode).toBe(200);
    expect(response.json()).toEqual({ ok: true, signingConfigured: false });
  });

  it("does not expose a PDF upload endpoint", async () => {
    app = await buildApp();
    const response = await app.inject({ method: "POST", url: "/v1/analyze" });
    expect(response.statusCode).toBe(404);
  });

  it("does not pretend to create a pass without Apple certificates", async () => {
    app = await buildApp();
    const response = await app.inject({
      method: "POST",
      url: "/v1/passes",
      payload: {
        title: "Mi billete",
        issuer: "",
        origin: "",
        destination: "",
        passenger: "",
        reference: "",
        relevantDate: null,
        qrPayloadBase64: Buffer.from("ABC123").toString("base64"),
        backgroundColor: "rgb(15, 118, 110)",
        sourceFilename: "ticket.pdf",
      },
    });
    expect(response.statusCode).toBe(503);
    expect(response.json().code).toBe("SIGNING_NOT_CONFIGURED");
  });
});
