import { randomUUID, createHash } from "node:crypto";
import { spawn } from "node:child_process";
import { existsSync } from "node:fs";
import sharp from "sharp";
import { zipSync } from "fflate";
import { config } from "./config.js";
import type { PassDraft } from "./types.js";

export function signingIsConfigured(): boolean {
  const paths = [config.PASS_SIGNER_CERT_PATH, config.PASS_SIGNER_KEY_PATH, config.PASS_WWDR_CERT_PATH];
  return config.APPLE_TEAM_IDENTIFIER !== "YOURTEAMID" && paths.every((path) => Boolean(path && existsSync(path)));
}

export function buildPassMetadata(draft: PassDraft, serialNumber: string = randomUUID()) {
  const relevantDate = draft.relevantDate ? new Date(draft.relevantDate).toISOString() : undefined;
  const common = {
    formatVersion: 1 as const,
    serialNumber,
    passTypeIdentifier: config.PASS_TYPE_IDENTIFIER,
    teamIdentifier: config.APPLE_TEAM_IDENTIFIER,
    organizationName: config.PASS_ORGANIZATION_NAME,
    description: draft.title,
    logoText: "AnyWallet",
    backgroundColor: draft.backgroundColor,
    foregroundColor: "rgb(255, 255, 255)",
    labelColor: "rgb(226, 232, 240)",
  };

  if (draft.passKind === "membership") {
    return {
      ...common,
      expirationDate: relevantDate,
      storeCard: {
        headerFields: draft.memberNumber ? [{ key: "memberNumber", label: "N.º DE SOCIO", value: draft.memberNumber }] : [],
        primaryFields: [{ key: "title", label: "MEMBRESÍA", value: draft.title }],
        secondaryFields: draft.issuer ? [{ key: "issuer", label: "PROGRAMA", value: draft.issuer }] : [],
        auxiliaryFields: draft.memberName ? [{ key: "memberName", label: "TITULAR", value: draft.memberName }] : [],
        backFields: [
          ...(draft.issuer ? [{ key: "issuerDetail", label: "Comercio o programa original", value: draft.issuer }] : []),
          {
            key: "notice",
            label: "Aviso",
            value: "Pase personal creado a partir de una tarjeta del usuario. No está emitido ni respaldado por el comercio original.",
          },
          { key: "contact", label: "Emisor del pase", value: `${config.PASS_ORGANIZATION_NAME} · ${config.PASS_CONTACT_EMAIL}` },
        ],
      },
    };
  }

  return {
    ...common,
    relevantDate,
    relevantDates: relevantDate ? [{ relevantDate }] : undefined,
    generic: {
      headerFields: draft.reference ? [{ key: "reference", label: "REFERENCIA", value: draft.reference }] : [],
      primaryFields: [{ key: "title", label: "BILLETE", value: draft.title }],
      secondaryFields: [
        ...(draft.origin ? [{ key: "origin", label: "ORIGEN", value: draft.origin }] : []),
        ...(draft.destination ? [{ key: "destination", label: "DESTINO", value: draft.destination }] : []),
      ],
      auxiliaryFields: [
        ...(relevantDate ? [{ key: "date", label: "FECHA", value: relevantDate, dateStyle: "PKDateStyleMedium", timeStyle: "PKDateStyleShort" }] : []),
        ...(draft.passenger ? [{ key: "passenger", label: "VIAJERO", value: draft.passenger }] : []),
      ],
      backFields: [
        ...(draft.issuer ? [{ key: "issuer", label: "Operador original", value: draft.issuer }] : []),
        {
          key: "notice",
          label: "Aviso",
          value: "Pase personal creado a partir de un documento del usuario. No está emitido ni respaldado por el operador original. Conserva el PDF original.",
        },
        { key: "contact", label: "Emisor del pase", value: `${config.PASS_ORGANIZATION_NAME} · ${config.PASS_CONTACT_EMAIL}` },
      ],
    },
  };
}

export function walletBarcodeFormat(format: PassDraft["barcodeFormat"]): string {
  switch (format) {
    case "qr": return "PKBarcodeFormatQR";
    case "code128": return "PKBarcodeFormatCode128";
    case "pdf417": return "PKBarcodeFormatPDF417";
    case "aztec": return "PKBarcodeFormatAztec";
  }
}

function signManifest(manifest: Buffer): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    const passphraseArgs = config.PASS_SIGNER_KEY_PASSPHRASE ? ["-passin", "env:ANYWALLET_PASS_KEY_PASSPHRASE"] : [];
    const child = spawn(
      "openssl",
      [
        "smime",
        "-binary",
        "-sign",
        "-certfile",
        config.PASS_WWDR_CERT_PATH!,
        "-signer",
        config.PASS_SIGNER_CERT_PATH!,
        "-inkey",
        config.PASS_SIGNER_KEY_PATH!,
        ...passphraseArgs,
        "-outform",
        "DER",
      ],
      {
        env: {
          ...process.env,
          ANYWALLET_PASS_KEY_PASSPHRASE: config.PASS_SIGNER_KEY_PASSPHRASE,
        },
        stdio: ["pipe", "pipe", "pipe"],
      },
    );
    const stdout: Buffer[] = [];
    const stderr: Buffer[] = [];
    child.stdout.on("data", (chunk: Buffer) => stdout.push(chunk));
    child.stderr.on("data", (chunk: Buffer) => stderr.push(chunk));
    child.on("error", reject);
    child.on("close", (code) => {
      if (code === 0) resolve(Buffer.concat(stdout));
      else reject(new Error(`OpenSSL failed (${code ?? "unknown"}): ${Buffer.concat(stderr).toString("utf8").trim()}`));
    });
    child.stdin.end(manifest);
  });
}

async function icon(size: number): Promise<Buffer> {
  const inset = Math.round(size * 0.2);
  return sharp({ create: { width: size, height: size, channels: 4, background: "#0B1220" } })
    .composite([
      {
        input: Buffer.from(`<svg width="${size}" height="${size}"><rect x="${inset}" y="${Math.round(size * 0.28)}" width="${size - inset * 2}" height="${Math.round(size * 0.44)}" rx="${Math.round(size * 0.06)}" fill="#F8FAFC"/><rect x="${Math.round(size * 0.6)}" y="${Math.round(size * 0.39)}" width="${Math.round(size * 0.1)}" height="${Math.round(size * 0.22)}" fill="#22C55E"/></svg>`),
      },
    ])
    .png()
    .toBuffer();
}

export async function createSignedPass(draft: PassDraft): Promise<Buffer> {
  if (!signingIsConfigured()) throw new Error("SIGNING_NOT_CONFIGURED");
  const [icon1x, icon2x, icon3x] = await Promise.all([
    icon(29),
    icon(58),
    icon(87),
  ]);
  const metadata = {
    ...buildPassMetadata(draft),
    barcodes: [
      {
        format: walletBarcodeFormat(draft.barcodeFormat),
        message: Buffer.from(draft.barcodePayloadBase64, "base64").toString("latin1"),
        messageEncoding: "iso-8859-1",
      },
    ],
  };
  const files: Record<string, Uint8Array> = {
    "icon.png": icon1x,
    "icon@2x.png": icon2x,
    "icon@3x.png": icon3x,
    "pass.json": Buffer.from(JSON.stringify(metadata)),
  };
  const manifestEntries = Object.fromEntries(
    Object.entries(files).map(([filename, contents]) => [filename, createHash("sha1").update(contents).digest("hex")]),
  );
  const manifest = Buffer.from(JSON.stringify(manifestEntries));
  const signature = await signManifest(manifest);
  files["manifest.json"] = manifest;
  files.signature = signature;
  return Buffer.from(zipSync(files, { level: 6 }));
}
