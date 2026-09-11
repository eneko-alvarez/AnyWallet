import "dotenv/config";
import { z } from "zod";

const optionalPath = z.string().trim().min(1).optional();
const envBoolean = (defaultValue: boolean) => z.enum(["true", "false"])
  .optional()
  .transform((value) => value === undefined ? defaultValue : value === "true");
const production = process.env.NODE_ENV === "production";

export const config = z
  .object({
    NODE_ENV: z.enum(["development", "test", "production"]).default("development"),
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
    APP_BUNDLE_IDENTIFIER: z.string().trim().min(1).default("com.eneko.anywallet"),
    APP_ATTEST_REQUIRED: envBoolean(production),
    APP_ATTEST_ALLOW_DEVELOPMENT: envBoolean(!production),
    APP_ATTEST_DATABASE_PATH: z.string().trim().min(1).default("./data/app-attest.sqlite"),
    TRUST_PROXY: envBoolean(production),
    APP_ADS_TXT: z.string().trim().min(1).optional(),
  })
  .superRefine((value, context) => {
    if (value.NODE_ENV === "production" && !value.PUBLIC_BASE_URL.startsWith("https://")) {
      context.addIssue({ code: "custom", path: ["PUBLIC_BASE_URL"], message: "HTTPS is required in production" });
    }
    if (value.NODE_ENV === "production" && !value.APP_ATTEST_REQUIRED) {
      context.addIssue({ code: "custom", path: ["APP_ATTEST_REQUIRED"], message: "App Attest is required in production" });
    }
    if (value.NODE_ENV === "production" && value.APP_ATTEST_ALLOW_DEVELOPMENT) {
      context.addIssue({ code: "custom", path: ["APP_ATTEST_ALLOW_DEVELOPMENT"], message: "Development attestations are forbidden in production" });
    }
    if (value.NODE_ENV === "production" && value.APPLE_TEAM_IDENTIFIER === "YOURTEAMID") {
      context.addIssue({ code: "custom", path: ["APPLE_TEAM_IDENTIFIER"], message: "A real Apple team identifier is required" });
    }
    if (value.NODE_ENV === "production" && value.PASS_TYPE_IDENTIFIER === "pass.com.example.anywallet") {
      context.addIssue({ code: "custom", path: ["PASS_TYPE_IDENTIFIER"], message: "A real Pass Type ID is required" });
    }
    if (value.NODE_ENV === "production") {
      for (const field of ["PASS_SIGNER_CERT_PATH", "PASS_SIGNER_KEY_PATH", "PASS_WWDR_CERT_PATH"] as const) {
        if (!value[field]) context.addIssue({ code: "custom", path: [field], message: "Required in production" });
      }
    }
  })
  .parse(process.env);

export const limits = {
  maxBarcodeBytes: 4096,
  maxPhotoBytes: 280_000,
  maxPhotoPixels: 16_000_000,
  passTtlMs: 10 * 60 * 1000,
  challengeTtlMs: 2 * 60 * 1000,
  maxPendingPasses: 1_000,
} as const;
