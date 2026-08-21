# AnyWallet

App iOS nativa para convertir billetes PDF con QR en pases personales de Apple Wallet.

El PDF se analiza completamente en el iPhone mediante PDFKit y Vision. El servidor recibe únicamente los campos finales y los bytes del QR, firma el `.pkpass` y entrega un enlace de descarga de un solo uso.

## Estructura

- `ios`: aplicación SwiftUI para iOS 17 o posterior, sin dependencias externas.
- `server`: API Fastify dedicada exclusivamente a firmar pases.

## Primer arranque en el Mac

El proyecto usa [XcodeGen](https://github.com/yonaskolb/XcodeGen) para evitar guardar un `.xcodeproj` frágil generado a mano.

```bash
brew install xcodegen
cd ios
xcodegen generate
open AnyWallet.xcodeproj
```

En Xcode:

1. Selecciona el target `AnyWallet`.
2. En **Signing & Capabilities**, selecciona tu Apple Developer Team.
3. Sustituye `com.anywallet.app` por un Bundle ID propio si ya está ocupado.
4. Ejecuta primero los tests en un simulador y después la app en un iPhone físico.

Comando equivalente para pruebas:

```bash
xcodebuild \
  -project ios/AnyWallet.xcodeproj \
  -scheme AnyWallet \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  test
```

Los tests Swift generan un PDF real, dibujan texto y un QR, lo analizan mediante PDFKit/Vision y comparan los bytes recuperados.

## Servidor local

Requiere Node.js 24, npm y OpenSSL.

```bash
npm install
cp server/.env.example server/.env
npm run dev:server
```

La URL del API está en `ios/AnyWallet/Resources/Info.plist`, clave `APIBaseURL`.

- Simulador: `http://localhost:8787`
- iPhone físico: usa la IP LAN del Mac, por ejemplo `http://192.168.1.20:8787`
- Producción: usa siempre HTTPS.

En el iPhone físico, `PUBLIC_BASE_URL` en `server/.env` debe usar la misma IP LAN o dominio HTTPS. El valor `localhost` apuntaría al propio iPhone y rompería la descarga del pase.

## Pass Type ID y firma

En Apple Developer:

1. Registra un Pass Type ID, por ejemplo `pass.com.tudominio.anywallet`.
2. Crea un certificado **Pass Type ID Certificate** asociado.
3. Instala el `.cer` en Acceso a Llaveros y exporta el certificado con su clave privada como `.p12`.
4. Descarga el certificado intermedio WWDR de Apple.
5. Convierte los archivos a PEM y configura `server/.env`.

```bash
openssl x509 -inform DER -in pass.cer -out signerCert.pem
openssl pkcs12 -in pass-key.p12 -nocerts -out signerKey.pem
openssl x509 -inform DER -in AppleWWDRCAG4.cer -out wwdr.pem
```

```dotenv
PUBLIC_BASE_URL=https://api.tudominio.com
PASS_TYPE_IDENTIFIER=pass.com.tudominio.anywallet
APPLE_TEAM_IDENTIFIER=TU_TEAM_ID
PASS_ORGANIZATION_NAME=AnyWallet
PASS_CONTACT_EMAIL=soporte@tudominio.com
PASS_SIGNER_CERT_PATH=./certs/signerCert.pem
PASS_SIGNER_KEY_PATH=./certs/signerKey.pem
PASS_WWDR_CERT_PATH=./certs/wwdr.pem
```

No añadas certificados, `.p12` ni claves privadas al repositorio. El Pass Type ID se usa para firmar los pases en el servidor; no es necesario añadir un identificador ficticio al proyecto Xcode para presentar un pase ya firmado con `PKAddPassesViewController`.

## Verificación del servidor

```bash
npm run typecheck
npm test
npm audit --omit=dev
curl http://localhost:8787/health
```

`signingConfigured` será `false` hasta configurar el certificado real. El API no simula un pase válido cuando faltan esas credenciales.

## Límites

- PDF máximo: 15 MB y 12 páginas, comprobado localmente.
- QR máximo: 4 KB. Si hay varios, el usuario debe elegir uno.
- OCR local en español e inglés para documentos escaneados.
- Los campos detectados son sugerencias editables y el título es obligatorio.
- El PDF nunca se envía al servidor.
- El servidor limita el JSON a 64 KB y elimina el borrador tras la primera descarga o a los 10 minutos.
- El pase identifica a AnyWallet como firmante y al transportista únicamente como operador original.
