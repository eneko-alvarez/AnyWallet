export function englishPrivacyPage(email: string): string {
  return `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>AnyWallet Privacy Policy</title><style>body{font:17px/1.6 system-ui,sans-serif;max-width:760px;margin:40px auto;padding:0 20px;color:#172033}h1,h2{line-height:1.2}</style></head>
<body><h1>AnyWallet Privacy Policy</h1><p>Last updated: September 17, 2026.</p>
<h2>Data we process</h2><p>The PDFs and images you choose are analyzed locally on your iPhone and are not uploaded. To create a pass, AnyWallet temporarily sends the details you reviewed, the color, the pass type, and the barcode bytes to the signing service. Optional photos are compressed on your device and used only to include them in the pass.</p>
<p>The draft is kept in memory for up to ten minutes and deleted when the pass is downloaded. Its contents are not used for advertising, analytics, profiling, or tracking, and are not shared with third parties. App Attest public keys are retained for as long as needed to prevent abuse; you can request their deletion using the contact email below.</p>
<h2>Security</h2><p>AnyWallet uses App Attest to verify that requests come from a legitimate installation. The server stores the installation's public key and cryptographic counter to prevent abuse and replay attacks. Communication uses HTTPS, and passes are signed with an Apple certificate stored only on the server.</p>
<h2>Advertising</h2><p>Versions of AnyWallet that include advertising may show a non-personalized ad after a pass has been successfully added to Apple Wallet. Watching the ad is never required to create a pass.</p>
<p>Google AdMob and its consent platform may process your IP address (to estimate approximate location), app or device identifiers, ad interactions, and diagnostic data. Pass fields and barcodes are not sent to Google for advertising. Where required, the app displays a consent message and provides access to privacy options. See <a href="https://policies.google.com/privacy">Google's privacy policy</a> as well.</p>
<h2>Contact</h2><p>For privacy questions or requests to access or delete data: <a href="mailto:${email}">${email}</a>.</p></body></html>`;
}
