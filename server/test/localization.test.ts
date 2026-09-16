import { describe, expect, it } from "vitest";
import { languageFromHeader } from "../src/localization.js";
import { buildPassMetadata } from "../src/pass.js";
import { buildApp } from "../src/app.js";
import type { PassDraft } from "../src/types.js";

const draft: PassDraft = {
  passKind: "travel", title: "Mi billete", issuer: "Original", origin: "Bilbao",
  destination: "London", passenger: "Ane", reference: "ABC", memberName: "Ane",
  memberNumber: "123", relevantDate: null, backgroundColor: "rgb(15, 118, 110)",
  customFields: [{ label: "Mi etiqueta", value: "Mi valor" }],
};

describe("localization", () => {
  it("uses only the first language", () => {
    expect(languageFromHeader("es-MX,en;q=0.9")).toBe("es");
    expect(languageFromHeader("fr,es;q=0.9")).toBe("en");
    expect(languageFromHeader("en")).toBe("en");
  });

  for (const passKind of ["travel", "membership", "custom"] as const) {
    it(`translates ${passKind} labels without translating user content`, () => {
      const es = buildPassMetadata({ ...draft, passKind, language: "es" }, "same");
      const en = buildPassMetadata({ ...draft, passKind, language: "en" }, "same");
      expect(en.description).toBe("Mi billete");
      expect(JSON.stringify(en)).toContain('"label":"Notice"');
      expect(JSON.stringify(es)).toContain('"label":"Aviso"');
      expect(buildPassMetadata({ ...draft, passKind }, "same")).toEqual(es);
      if (passKind === "custom") expect(JSON.stringify(en)).toContain('"label":"Mi etiqueta","value":"Mi valor"');
    });
  }

  it("localizes linked privacy and API errors", async () => {
    const app = await buildApp({ attestationRequired: false });
    try {
      const privacy = await app.inject({ method: "GET", url: "/privacy?lang=en" });
      expect(privacy.body).toContain('<html lang="en">');
      expect(privacy.body).toContain("does not display ads");
      const spanish = await app.inject({ method: "GET", url: "/privacy?lang=es" });
      expect(spanish.body).toContain('<html lang="es">');
      const error = await app.inject({ method: "GET", url: "/v1/passes/expired", headers: { "accept-language": "en" } });
      expect(error.json().message).toBe("The pass download link has expired.");
    } finally { await app.close(); }
  });
});
