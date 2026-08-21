import "dotenv/config";
import { z } from "zod";

const optionalPath = z.string().trim().min(1).optional();

export const config = z
  .object({
    PORT: z.coerce.number().int().min(1).max(65535).default(8787),
    PUBLIC_BASE_URL: z.string().url().default("http://localhost:8787"),
    PASS_TYPE_IDENTIFIER: z.string().startsWith("pass.").default("pass.com.example.anywallet"),
    APPLE_TEAM_IDENTIFIER: z.string().trim().min(1).default("YOURTEAMID"),
    PASS_ORGANIZATION_NAME: z.string().trim().min(1).default("AnyWallet"),
    PASS_CONTACT_EMAIL: z.string().email().default("support@example.com"),
    PASS_SIGNER_CERT_PATH: optionalPath,
    PASS_SIGNER_KEY_PATH: optionalPath,
    PASS_WWDR_CERT_PATH: optionalPath,
    PASS_SIGNER_KEY_PASSPHRASE: z.string().optional(),
  })
  .parse(process.env);

export const limits = {
  maxQrBytes: 4096,
  passTtlMs: 10 * 60 * 1000,
} as const;
