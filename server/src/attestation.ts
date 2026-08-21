import cbor from "cbor";
import { createHash, randomBytes, X509Certificate } from "node:crypto";
import { mkdirSync } from "node:fs";
import { dirname } from "node:path";
import { DatabaseSync } from "node:sqlite";
import { verifyAssertion, verifyAttestation } from "node-app-attest";

export type AttestedKey = {
  publicKey: string;
  signCount: number;
};

export interface AttestationStore {
  issueChallenge(): string;
  consumeChallenge(challenge: string): boolean;
  findKey(keyId: string): AttestedKey | undefined;
  saveKey(keyId: string, key: AttestedKey): void;
  close(): void;
}

export class SQLiteAttestationStore implements AttestationStore {
  private readonly database: DatabaseSync;
  private readonly challengeTtlMs: number;

  constructor(path: string, challengeTtlMs: number) {
    if (path !== ":memory:") mkdirSync(dirname(path), { recursive: true });
    this.database = new DatabaseSync(path);
    this.challengeTtlMs = challengeTtlMs;
    this.database.exec(`
      PRAGMA journal_mode = WAL;
      CREATE TABLE IF NOT EXISTS app_attest_challenges (
        digest TEXT PRIMARY KEY,
        expires_at INTEGER NOT NULL
      );
      CREATE TABLE IF NOT EXISTS app_attest_keys (
        key_id TEXT PRIMARY KEY,
        public_key TEXT NOT NULL,
        sign_count INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
    `);
  }

  issueChallenge(): string {
    const challenge = randomBytes(32).toString("base64url");
    const now = Date.now();
    this.database.prepare("DELETE FROM app_attest_challenges WHERE expires_at < ?").run(now);
    this.database.prepare("INSERT INTO app_attest_challenges (digest, expires_at) VALUES (?, ?)")
      .run(digest(challenge), now + this.challengeTtlMs);
    return challenge;
  }

  consumeChallenge(challenge: string): boolean {
    const challengeDigest = digest(challenge);
    const row = this.database.prepare("SELECT expires_at FROM app_attest_challenges WHERE digest = ?")
      .get(challengeDigest) as { expires_at: number } | undefined;
    this.database.prepare("DELETE FROM app_attest_challenges WHERE digest = ?").run(challengeDigest);
    return Boolean(row && row.expires_at >= Date.now());
  }

  findKey(keyId: string): AttestedKey | undefined {
    const row = this.database.prepare("SELECT public_key, sign_count FROM app_attest_keys WHERE key_id = ?")
      .get(keyId) as { public_key: string; sign_count: number } | undefined;
    return row ? { publicKey: row.public_key, signCount: row.sign_count } : undefined;
  }

  saveKey(keyId: string, key: AttestedKey): void {
    this.database.prepare(`
      INSERT INTO app_attest_keys (key_id, public_key, sign_count, updated_at)
      VALUES (?, ?, ?, ?)
      ON CONFLICT(key_id) DO UPDATE SET
        public_key = excluded.public_key,
        sign_count = excluded.sign_count,
        updated_at = excluded.updated_at
    `).run(keyId, key.publicKey, key.signCount, Date.now());
  }

  close(): void {
    this.database.close();
  }
}

type AppIdentity = {
  bundleIdentifier: string;
  teamIdentifier: string;
  allowDevelopmentEnvironment: boolean;
};

export function attestKey(
  input: { attestation: string; challenge: string; keyId: string },
  identity: AppIdentity,
): AttestedKey {
  validateCertificateEnvelope(Buffer.from(input.attestation, "base64"));
  const result = verifyAttestation({
    attestation: Buffer.from(input.attestation, "base64"),
    challenge: input.challenge,
    keyId: input.keyId,
    ...identity,
  });
  return { publicKey: result.publicKey, signCount: 0 };
}

export function assertRequest(
  input: { assertion: string; keyId: string; payload: Buffer; key: AttestedKey },
  identity: Omit<AppIdentity, "allowDevelopmentEnvironment">,
): number {
  const result = verifyAssertion({
    assertion: Buffer.from(input.assertion, "base64"),
    payload: input.payload,
    publicKey: input.key.publicKey,
    signCount: input.key.signCount,
    ...identity,
  });
  return result.signCount;
}

function digest(value: string): string {
  return createHash("sha256").update(value).digest("hex");
}

function validateCertificateEnvelope(attestation: Buffer): void {
  const decoded = cbor.decodeAllSync(attestation);
  if (decoded.length !== 1) throw new Error("Invalid attestation envelope");
  const chain = decoded[0]?.attStmt?.x5c;
  if (!Array.isArray(chain) || chain.length !== 2 || !chain.every(Buffer.isBuffer)) {
    throw new Error("Invalid attestation certificate chain");
  }
  const certificates = chain.map((value: Buffer) => new X509Certificate(value));
  const now = Date.now();
  for (const certificate of certificates) {
    if (Date.parse(certificate.validFrom) > now || Date.parse(certificate.validTo) < now) {
      throw new Error("Expired attestation certificate");
    }
  }
  const leaf = certificates.find((certificate) => !certificate.ca);
  const intermediate = certificates.find((certificate) => certificate.ca);
  if (!leaf || !intermediate || leaf.publicKey.asymmetricKeyType !== "ec") {
    throw new Error("Invalid attestation certificate properties");
  }
}
