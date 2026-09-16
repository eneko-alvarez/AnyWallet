export type Language = "es" | "en";

export function languageFromHeader(value: string | undefined): Language {
  const first = value?.split(",")[0]?.split(";")[0]?.trim().toLowerCase();
  return first === "es" || first?.startsWith("es-") ? "es" : "en";
}

const english: Record<string, string> = {
  "PASE PERSONAL": "PERSONAL PASS",
  "Aviso": "Notice",
  "Pase personal creado por el usuario. AnyWallet únicamente firma y entrega el pase.": "Personal pass created by the user. AnyWallet only signs and delivers the pass.",
  "Emisor del pase": "Pass issuer",
  "N.º DE SOCIO": "MEMBER NUMBER",
  "MEMBRESÍA": "MEMBERSHIP",
  "PROGRAMA": "PROGRAM",
  "TITULAR": "CARDHOLDER",
  "Comercio o programa original": "Original store or program",
  "Pase personal creado a partir de una tarjeta del usuario. No está emitido ni respaldado por el comercio original.": "Personal pass created from the user's card. It is not issued or endorsed by the original store.",
  "REFERENCIA": "REFERENCE",
  "BILLETE": "TICKET",
  "ORIGEN": "FROM",
  "DESTINO": "TO",
  "FECHA": "DATE",
  "VIAJERO": "PASSENGER",
  "Operador original": "Original carrier",
  "Pase personal creado a partir de un documento del usuario. No está emitido ni respaldado por el operador original. Conserva el PDF original.": "Personal pass created from the user's document. It is not issued or endorsed by the original carrier. Keep the original PDF.",
  "HTTPS es obligatorio.": "HTTPS is required.",
  "Ruta no disponible.": "This endpoint is unavailable.",
  "Revisa los datos del pase.": "Check your pass details.",
  "El código seleccionado no es válido.": "The selected barcode is invalid.",
  "Los datos personalizados no corresponden a este tipo de pase.": "Custom details aren't supported for this pass type.",
  "La imagen del pase está incompleta.": "The pass image is incomplete.",
  "La imagen del pase no es válida.": "The pass image is invalid.",
  "El servicio de firma no está disponible.": "The signing service is unavailable.",
  "El servicio está ocupado. Inténtalo de nuevo.": "The service is busy. Please try again.",
  "El enlace del pase ha caducado.": "The pass download link has expired.",
  "No se ha podido firmar el pase.": "Couldn't sign the pass.",
  "Cliente no autorizado.": "This app installation isn't authorized."
};

export function translate(text: string, language: Language): string {
  return language === "es" ? text : english[text] ?? text;
}
