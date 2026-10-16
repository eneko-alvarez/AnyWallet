import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { unzipSync } from "fflate";
import sharp from "sharp";
import { buildApp } from "../src/app.js";
import { config } from "../src/config.js";

describe("signed pass download", () => {
  const originalConfig = { ...config };
  let directory: string;

  beforeAll(() => {
    directory = mkdtempSync(join(tmpdir(), "anywallet-signing-"));
    const certificate = join(directory, "certificate.pem");
    const key = join(directory, "key.pem");
    execFileSync("openssl", [
      "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1",
      "-subj", "/CN=AnyWallet Test", "-keyout", key, "-out", certificate,
    ], { stdio: "ignore" });
    Object.assign(config, {
      APPLE_TEAM_IDENTIFIER: "TESTTEAMID",
      PASS_TYPE_IDENTIFIER: "pass.test.anywallet",
      PASS_SIGNER_CERT_PATH: certificate,
      PASS_SIGNER_KEY_PATH: key,
      PASS_WWDR_CERT_PATH: certificate,
      PASS_SIGNER_KEY_PASSPHRASE: undefined,
    });
  });

  afterAll(() => {
    Object.assign(config, originalConfig);
    if (directory) rmSync(directory, { recursive: true, force: true });
  });

  it.each(["travel", "membership", "custom"] as const)(
    "creates and verifies a complete %s pass with real image rendering and signing",
    async (passKind) => {
      const app = await buildApp({ attestationRequired: false });
      try {
        const photo = passKind === "custom"
          ? await sharp({ create: { width: 32, height: 32, channels: 3, background: "#123456" } }).png().toBuffer()
          : undefined;
        const creation = await app.inject({
          method: "POST",
          url: "/v1/passes",
          payload: {
            challenge: "A".repeat(43),
            draft: {
              passKind,
              title: "Diagnostic test",
              relevantDate: null,
              ...(photo ? {
                photoAspect: "square", photoBase64: photo.toString("base64"),
                customFields: [{ label: "Name", value: "Test" }],
              } : { barcodeFormat: "qr", barcodePayloadBase64: Buffer.from("TEST123").toString("base64") }),
            },
          },
        });
        expect(creation.statusCode).toBe(200);
        const url = new URL(creation.json().downloadUrl).pathname;
        const download = await app.inject({ method: "GET", url });
        expect(download.statusCode).toBe(200);
        expect(download.headers["content-type"]).toBe("application/vnd.apple.pkpass");
        const files = unzipSync(download.rawPayload);
        const metadata = JSON.parse(Buffer.from(files["pass.json"]!).toString());
        expect(metadata.passTypeIdentifier).toBe("pass.test.anywallet");
        expect(metadata).toHaveProperty(passKind === "membership" ? "storeCard" : "generic");
        for (const [name, size] of [["icon.png", 29], ["icon@2x.png", 58], ["icon@3x.png", 87]] as const) {
          expect(await sharp(files[name]!).metadata()).toMatchObject({ width: size, height: size, format: "png" });
        }
        if (photo) expect(files).toHaveProperty("thumbnail@3x.png");
        const manifest = JSON.parse(Buffer.from(files["manifest.json"]!).toString());
        expect(Object.keys(manifest).sort()).toEqual(Object.keys(files).filter((name) => !["signature", "manifest.json"].includes(name)).sort());
        for (const [name, digest] of Object.entries(manifest)) {
          expect(createHash("sha1").update(files[name]!).digest("hex")).toBe(digest);
        }
        const signaturePath = join(directory, "signature.der");
        const manifestPath = join(directory, "manifest.json");
        writeFileSync(signaturePath, files.signature!);
        writeFileSync(manifestPath, files["manifest.json"]!);
        const verified = execFileSync("openssl", [
          "smime", "-verify", "-binary", "-inform", "DER", "-in", signaturePath,
          "-content", manifestPath, "-noverify",
        ], { stdio: ["ignore", "pipe", "pipe"] });
        expect(verified).toEqual(Buffer.from(files["manifest.json"]!));
        expect((await app.inject({ method: "GET", url })).statusCode).toBe(404);
      } finally {
        await app.close();
      }
    },
  );
});
