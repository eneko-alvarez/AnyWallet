export type PassDraft = {
  passKind: "travel" | "membership" | "custom";
  title: string;
  issuer: string;
  origin: string;
  destination: string;
  passenger: string;
  reference: string;
  memberName: string;
  memberNumber: string;
  relevantDate: string | null;
  barcodeFormat?: "qr" | "code128" | "pdf417" | "aztec";
  barcodePayloadBase64?: string;
  backgroundColor: string;
  customFields: Array<{ label: string; value: string }>;
  photoAspect?: "square" | "portrait" | "landscape" | "wide";
  photoBase64?: string;
};
