export type PassDraft = {
  passKind: "travel" | "membership";
  title: string;
  issuer: string;
  origin: string;
  destination: string;
  passenger: string;
  reference: string;
  memberName: string;
  memberNumber: string;
  relevantDate: string | null;
  barcodeFormat: "qr" | "code128" | "pdf417" | "aztec";
  barcodePayloadBase64: string;
  backgroundColor: string;
};
