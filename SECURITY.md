# Seguridad y privacidad

## Flujo de datos

PDFKit y Vision procesan el documento dentro del iPhone. El servidor nunca recibe el PDF, el texto completo extraído ni imágenes de sus páginas.

Para firmar el pase se envían únicamente:

- título y campos que el usuario ha revisado;
- bytes del QR codificados en Base64;
- nombre del archivo de origen;
- color del pase.

El borrador vive en memoria durante un máximo de 10 minutos y desaparece en la primera descarga. No se registra el contenido del QR.

## Controles

- PDF limitado a 15 MB y 12 páginas en el dispositivo;
- QR limitado a 4 KB tanto en el cliente como en el servidor;
- contenido QR tratado como datos opacos, sin abrir URLs ni hacer solicitudes;
- cuerpo JSON limitado a 64 KB y validado con esquema estricto;
- clave privada y certificado disponibles únicamente en el servidor;
- token de descarga aleatorio, no cacheable y de un solo uso;
- firma PKCS#7 mediante OpenSSL con el certificado intermedio WWDR;
- separación explícita entre AnyWallet, firmante del pase, y el operador original.

## Producción

Usa HTTPS, rate limiting en el proxy, un proceso sin privilegios, límites de CPU/memoria y un gestor de secretos. Configura contacto y política de privacidad reales antes de App Review. Rota el certificado si existe cualquier sospecha de exposición de la clave privada.
