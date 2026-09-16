# AnyWallet 1.1: archivo y envío desde el Mac

La versión 1.1 incorpora Google AdMob y el consentimiento de User Messaging
Platform. El archivo `.ipa` solo se puede generar en macOS con Xcode 26 o
posterior y un perfil de distribución válido.

Antes de ejecutar los comandos, confirma en Apple Developer que el App ID
`com.eneko.anywallet` pertenece al equipo `B6757Q5N7U` y tiene App Attest
activado. En App Store Connect, prepara la versión `1.1` y el build `2`. Inicia
sesión con el mismo equipo en Xcode > Settings > Accounts.

Antes del archive, verifica la aplicación y el archivo `app-ads.txt` en AdMob,
publica los mensajes de consentimiento aplicables y actualiza App Privacy y
la clasificación por edades de la ficha. Guarda los IDs reales en
`ios/.env.ads.production`, con este formato (el archivo está excluido de Git):

```bash
ADMOB_APP_ID=ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY
ADMOB_INTERSTITIAL_ID=ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ
```

Desde la raíz del repositorio en el Mac:

```bash
git pull --ff-only
xcodebuild -version
brew install xcodegen
./ios/archive-app-store.sh
```

El comando genera `ios/build/AppStore/AnyWallet.ipa` y detiene la exportación
si faltan los IDs reales, no coinciden entre sí, o el archive apunta a otra
API o lleva otros IDs. Para enviarlo a App Store Connect desde Terminal, con la sesión
de Apple ya iniciada en Xcode:

```bash
xcodebuild -exportArchive \
  -archivePath ios/build/AnyWallet.xcarchive \
  -exportPath ios/build/AppStoreUpload \
  -exportOptionsPlist ios/UploadOptions-AppStore.plist \
  -allowProvisioningUpdates
```

Esto solo sube el build; la publicación requiere completar la ficha y
enviarla a App Review en App Store Connect. Antes de enviarla, prueba la
versión Release en un iPhone físico con la API de producción y confirma que
puede crear y añadir un pase real a Wallet, cancelar Wallet sin anuncio,
aceptar o rechazar el consentimiento y abrir las opciones de privacidad.
Usa
`APP_STORE_METADATA_ES.md` para los textos de la ficha.
