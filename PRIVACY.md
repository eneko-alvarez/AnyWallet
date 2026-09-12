# Política de privacidad de AnyWallet

Última actualización: 13 de septiembre de 2026.

AnyWallet convierte documentos elegidos por el usuario en pases personales para Apple Wallet.

## Datos tratados

El PDF o la imagen seleccionados para reconocer un billete o tarjeta se analizan localmente en el iPhone y no se suben. Para crear el pase, la app envía temporalmente al servicio de firma únicamente los campos revisados por el usuario, el color, el tipo de pase y los bytes del código QR o de barras. Si el usuario crea un pase desde cero y añade una foto, esta se comprime en el dispositivo y se envía únicamente para incorporarla al pase firmado.

El servicio conserva esos datos y la foto opcional solo en memoria durante un máximo de diez minutos y los elimina al descargar el pase. El contenido de los pases no se utiliza para publicidad, analítica, elaboración de perfiles ni seguimiento y no se comparte con terceros. Las claves públicas de App Attest se mantienen mientras sean necesarias para prevenir abuso; puedes solicitar su eliminación mediante el correo de contacto.

## Seguridad

AnyWallet usa App Attest para comprobar que las solicitudes proceden de una instalación legítima. El servidor conserva la clave pública y el contador criptográfico asociados a esa instalación para prevenir abuso y repetición de solicitudes. No se usan para identificar personalmente al usuario ni se comparten con terceros.

La comunicación de producción utiliza HTTPS. Los pases se firman con un certificado de Apple almacenado únicamente en el servidor.

## Publicidad y terceros

Esta versión de AnyWallet no muestra anuncios ni integra redes publicitarias.

AnyWallet no vende los datos introducidos en los pases. Los servicios de Apple necesarios para App Attest y Wallet están sujetos a las políticas de Apple.

## Derechos

Para consultas de privacidad o solicitudes de acceso y eliminación, escribe a anywallet@topitup.party.
