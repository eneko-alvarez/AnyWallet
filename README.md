# AnyWallet

App iOS nativa para convertir billetes y tarjetas de membresía en pases personales de Apple Wallet.

El PDF o la imagen se analiza completamente en el iPhone mediante PDFKit y Vision. El servidor recibe únicamente los campos finales, el tipo de pase y los bytes del código, firma el `.pkpass` y entrega un enlace de descarga de un solo uso.

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

La URL del API se inyecta mediante el build setting `API_BASE_URL` y termina en la clave `APIBaseURL` del bundle.

- Simulador: `http://localhost:8787`
- iPhone físico: usa la IP LAN del Mac, por ejemplo `http://192.168.1.20:8787`
- Producción: usa siempre HTTPS. Release no incluye excepciones ATS y exige App Attest.

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

El health check público devuelve únicamente `{ "ok": true }`; no revela si los certificados están configurados. El API tampoco simula un pase válido cuando faltan credenciales de firma.

## Despliegue público seguro

La imagen de producción se construye desde la raíz del repositorio:

```bash
docker build -t anywallet-api .
```

Configura el proveedor con TLS administrado, un volumen persistente montado en `/app/server/data` y los secretos del certificado fuera de la imagen. Variables obligatorias de producción:

```dotenv
NODE_ENV=production
PORT=8787
PUBLIC_BASE_URL=https://api.tudominio.com
TRUST_PROXY=true
APP_BUNDLE_IDENTIFIER=com.eneko.anywallet
APP_ATTEST_REQUIRED=true
APP_ATTEST_ALLOW_DEVELOPMENT=false
APP_ATTEST_DATABASE_PATH=/app/server/data/app-attest.sqlite
APPLE_TEAM_IDENTIFIER=TU_TEAM_ID
PASS_TYPE_IDENTIFIER=pass.com.tudominio.anywallet
PASS_ORGANIZATION_NAME=AnyWallet
PASS_CONTACT_EMAIL=soporte@tudominio.com
PASS_SIGNER_CERT_PATH=/run/secrets/signerCert.pem
PASS_SIGNER_KEY_PATH=/run/secrets/signerKey.pem
PASS_WWDR_CERT_PATH=/run/secrets/wwdr.pem
PASS_SIGNER_KEY_PASSPHRASE=GESTOR_DE_SECRETOS
```

El puerto `8787` no debe quedar expuesto directamente a Internet; solo el proxy HTTPS debe alcanzarlo. Mantén una sola réplica hasta mover también los borradores temporales a un almacén compartido.

Para archivar iOS, sustituye el dominio inválido de seguridad incluido en Release:

```bash
xcodebuild archive \
  -project ios/AnyWallet.xcodeproj \
  -scheme AnyWallet \
  -configuration Release \
  API_BASE_URL=https://api.tudominio.com
```

Antes de subir a App Store Connect, activa App Attest para el App ID `com.eneko.anywallet`, confirma que el perfil de distribución contiene el entitlement y publica `PRIVACY.md` en una URL HTTPS. Apple exige una URL de política de privacidad y declarar las prácticas de datos en App Store Connect.

## Límites

- Archivo máximo: 15 MB. Los PDF admiten hasta 12 páginas y las imágenes hasta 40 megapíxeles.
- Código QR, Code 128, PDF417 o Aztec de hasta 4 KB. Si hay varios, el usuario debe elegir uno.
- OCR local en español e inglés para documentos escaneados.
- El tipo y los campos detectados son sugerencias editables; el usuario puede cambiar entre viaje y membresía.
- El PDF o la imagen nunca se envía al servidor.
- El servidor limita el JSON a 64 KB y elimina el borrador tras la primera descarga o a los 10 minutos.
- El pase identifica a AnyWallet como firmante y al transportista únicamente como operador original.
- En producción, crear un pase requiere una clave App Attest válida y una aserción nueva para cada petición.
