export type PassDraft = {
  title: string;
  issuer: string;
  origin: string;
  destination: string;
  passenger: string;
  reference: string;
  relevantDate: string | null;
  qrPayloadBase64: string;
  backgroundColor: string;
  sourceFilename: string;
};
