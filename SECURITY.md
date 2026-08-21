# Seguridad y privacidad

## Flujo de datos

PDFKit y Vision procesan el documento dentro del iPhone. El servidor nunca recibe el PDF, el texto completo extraído ni imágenes de sus páginas.

Para firmar el pase se envían únicamente:

- título y campos que el usuario ha revisado;
- bytes del QR o código de barras codificados en Base64;
- color del pase.

El borrador vive en memoria durante un máximo de 10 minutos y desaparece en la primera descarga. No se registra el contenido del QR.

## Controles

- PDF limitado a 15 MB y 12 páginas en el dispositivo;
- código limitado a 4 KB tanto en el cliente como en el servidor;
- contenido del código tratado como datos opacos, sin abrir URLs ni hacer solicitudes;
- cuerpo JSON limitado a 64 KB y validado con esquema estricto;
- clave privada y certificado disponibles únicamente en el servidor;
- token de descarga aleatorio, no cacheable y de un solo uso;
- token de descarga guardado en memoria únicamente como hash SHA-256;
- App Attest obligatorio en producción con desafío de un solo uso y contador anti-replay;
- límite global por IP y límite específico por instalación atestada;
- cabeceras HTTP seguras y respuestas no cacheables;
- firma PKCS#7 mediante OpenSSL con el certificado intermedio WWDR;
- separación explícita entre AnyWallet, firmante del pase, y el operador original.

## Producción

El servidor rechaza el arranque de producción si la URL pública no usa HTTPS, si App Attest está desactivado o si acepta atestaciones de desarrollo. El contenedor se ejecuta sin privilegios y no incorpora certificados ni archivos `.env`.

En producción:

- expón el contenedor únicamente detrás de un proxy HTTPS y bloquea el acceso directo al puerto interno;
- desactiva o redacta en el proxy el access log de `/v1/passes/:token` para no registrar tokens de descarga;
- monta `server/data` en un volumen persistente para conservar claves y contadores de App Attest;
- inyecta certificados y contraseña desde el gestor de secretos del proveedor;
- ejecuta una sola réplica mientras los borradores permanezcan en memoria, o añade un almacén compartido antes de escalar horizontalmente;
- configura alertas de tasa de errores `401`, `429` y `5xx` sin registrar cuerpos, códigos o datos del pase;
- rota el certificado si existe cualquier sospecha de exposición de la clave privada.

App Attest reduce de forma importante el abuso, pero no sustituye rate limiting, monitorización ni límites de gasto. No debe añadirse una API key fija al binario de iOS: podría extraerse y reutilizarse.
