import { describe, expect, it } from "vitest";
import { buildPassMetadata } from "../src/pass.js";

describe("buildPassMetadata", () => {
  it("keeps original issuer separate and identifies the personal pass", () => {
    const metadata = buildPassMetadata({
      title: "Billete Bilbao - Donostia",
      issuer: "Autobuses Norte",
      origin: "Bilbao",
      destination: "Donostia",
      passenger: "Ane Lopez",
      reference: "ABC123",
      relevantDate: "2026-09-14T06:30:00.000Z",
      qrPayloadBase64: Buffer.from("ABC123").toString("base64"),
      backgroundColor: "rgb(15, 118, 110)",
      sourceFilename: "billete.pdf",
    }, "serial-1");

    expect(metadata.organizationName).toBe("AnyWallet");
    expect(metadata.generic.primaryFields[0]?.value).toBe("Billete Bilbao - Donostia");
    expect(metadata.generic.backFields.some((field) => field.value.includes("No está emitido"))).toBe(true);
    expect(metadata.relevantDates).toEqual([{ relevantDate: "2026-09-14T06:30:00.000Z" }]);
  });
});
