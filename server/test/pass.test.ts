import { describe, expect, it } from "vitest";
import { buildPassMetadata, walletBarcodeFormat } from "../src/pass.js";

describe("buildPassMetadata", () => {
  it("maps every supported barcode format to PassKit", () => {
    expect(walletBarcodeFormat("qr")).toBe("PKBarcodeFormatQR");
    expect(walletBarcodeFormat("code128")).toBe("PKBarcodeFormatCode128");
    expect(walletBarcodeFormat("pdf417")).toBe("PKBarcodeFormatPDF417");
    expect(walletBarcodeFormat("aztec")).toBe("PKBarcodeFormatAztec");
  });

  it("keeps original issuer separate and identifies the personal pass", () => {
    const metadata = buildPassMetadata({
      passKind: "travel",
      title: "Billete Bilbao - Donostia",
      issuer: "Autobuses Norte",
      origin: "Bilbao",
      destination: "Donostia",
      passenger: "Ane Lopez",
      reference: "ABC123",
      memberName: "",
      memberNumber: "",
      relevantDate: "2026-09-14T06:30:00.000Z",
      barcodeFormat: "qr",
      barcodePayloadBase64: Buffer.from("ABC123").toString("base64"),
      backgroundColor: "rgb(15, 118, 110)",
    }, "serial-1");

    expect(metadata.organizationName).toBe("AnyWallet");
    expect(metadata).toHaveProperty("generic");
    if (!("generic" in metadata)) throw new Error("Expected a generic pass");
    expect(metadata.generic.primaryFields[0]?.value).toBe("Billete Bilbao - Donostia");
    expect(metadata.generic.backFields.some((field) => field.value.includes("No está emitido"))).toBe(true);
    expect(metadata.relevantDates).toEqual([{ relevantDate: "2026-09-14T06:30:00.000Z" }]);
  });

  it("uses the store card layout for memberships", () => {
    const metadata = buildPassMetadata({
      passKind: "membership",
      title: "Lidl Plus",
      issuer: "Lidl",
      origin: "",
      destination: "",
      passenger: "",
      reference: "",
      memberName: "Ane Lopez",
      memberNumber: "204938102",
      relevantDate: null,
      barcodeFormat: "code128",
      barcodePayloadBase64: Buffer.from("204938102").toString("base64"),
      backgroundColor: "rgb(15, 118, 110)",
    }, "serial-2");

    expect(metadata).not.toHaveProperty("generic");
    expect(metadata).toHaveProperty("storeCard");
    if (!("storeCard" in metadata)) throw new Error("Expected a store card pass");
    expect(metadata.storeCard.primaryFields[0]?.value).toBe("Lidl Plus");
    expect(metadata.storeCard.headerFields[0]?.value).toBe("204938102");
  });
});
