# AnyWallet 1.0.0: archivo y envío desde el Mac

La primera versión no incluye publicidad. El archivo `.ipa` solo se puede
generar en macOS con Xcode 26 o posterior y un perfil de distribución válido.

Antes de ejecutar los comandos, confirma en Apple Developer que el App ID
`com.eneko.anywallet` pertenece al equipo `B6757Q5N7U` y tiene App Attest
activado. En App Store Connect, crea la app iOS con ese Bundle ID, versión
`1.0.0` y build `1`. Inicia
sesión con el mismo equipo en Xcode > Settings > Accounts.

Desde la raíz del repositorio en el Mac:

```bash
git pull --ff-only
xcodebuild -version
brew install xcodegen
./ios/archive-app-store.sh
```

El comando genera `ios/build/AppStore/AnyWallet.ipa` y detiene la exportación
si el archive apunta a otra API o contiene el identificador o el SDK de
Google Ads. Para enviarlo a App Store Connect desde Terminal, con la sesión
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
puede crear y añadir un pase real a Wallet. Usa
`APP_STORE_METADATA_ES.md` para los textos de la ficha.
