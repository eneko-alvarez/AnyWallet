const appleIcon = `<svg viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path fill="currentColor" d="M17.05 12.54c.02-2.12 1.73-3.12 1.8-3.17a3.86 3.86 0 0 0-3.04-1.64c-1.28-.13-2.52.77-3.17.77-.66 0-1.64-.76-2.71-.74A4 4 0 0 0 6.56 9.8c-1.46 2.54-.37 6.27 1.03 8.32.7 1.01 1.52 2.14 2.59 2.1 1.04-.04 1.43-.67 2.68-.67 1.23 0 1.59.67 2.68.64 1.11-.02 1.81-1.01 2.48-2.03a8.36 8.36 0 0 0 1.13-2.31 3.65 3.65 0 0 1-2.1-3.31ZM14.98 6.38A3.74 3.74 0 0 0 15.83 3a3.78 3.78 0 0 0-2.45 1.17 3.58 3.58 0 0 0-.89 3.28 3.15 3.15 0 0 0 2.49-1.07Z"/></svg>`;

const escapeAttribute = (value: string) => value.replace(/[&<>"']/g, (character) => ({
  "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;",
})[character] ?? character);

export function renderLanding(appStoreUrl?: string): string {
  const storeButton = appStoreUrl
    ? `<a class="store-button" href="${escapeAttribute(appStoreUrl)}" target="_blank" rel="noopener noreferrer" aria-label="Descargar AnyWallet en la App Store">${appleIcon}<span><small>Descargar en la</small><strong>App Store</strong></span><span class="store-arrow" aria-hidden="true">↗</span></a>`
    : `<button class="store-button store-button--soon" type="button" disabled aria-label="Próximamente en la App Store">${appleIcon}<span><small>Próximamente en la</small><strong>App Store</strong></span></button>`;

  return `<!doctype html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="theme-color" content="#f7f7f5">
  <meta name="description" content="Convierte billetes, tarjetas y códigos en pases para Apple Wallet. Importa, revisa y guarda desde tu iPhone con AnyWallet.">
  <meta property="og:type" content="website">
  <meta property="og:title" content="AnyWallet — Tus pases, en su sitio">
  <meta property="og:description" content="Billetes, tarjetas y códigos, listos para Apple Wallet.">
  <meta property="og:image" content="/brand-mark.png">
  <link rel="icon" type="image/png" href="/favicon.png">
  <link rel="apple-touch-icon" href="/brand-mark.png">
  <title>AnyWallet — Tus pases, en su sitio</title>
  <style>
    :root{color-scheme:light;--ink:#1c1d20;--muted:#696b70;--line:#e5e4e0;--paper:#f7f7f5;--orange:#ff593b}
    *{box-sizing:border-box}
    html{scroll-behavior:smooth}
    body{margin:0;background:var(--paper);color:var(--ink);font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;-webkit-font-smoothing:antialiased}
    a{color:inherit;text-decoration:none}
    a:focus-visible{outline:3px solid var(--orange);outline-offset:4px;border-radius:5px}
    .skip{position:absolute;left:16px;top:-60px;z-index:10;padding:10px 14px;background:#fff;border-radius:10px}
    .skip:focus{top:12px}
    .wrap{width:min(1160px,calc(100% - 48px));margin-inline:auto}
    .site-header{height:88px;display:flex;align-items:center;justify-content:space-between;gap:24px;border-bottom:1px solid var(--line)}
    .brand{display:inline-flex;align-items:center;gap:11px;font-size:21px;font-weight:750;letter-spacing:-.055em;white-space:nowrap}
    .brand img{width:39px;height:39px;object-fit:contain}
    .nav{display:flex;align-items:center;gap:34px;color:#53545a;font-size:14px;font-weight:600}
    .nav a:hover,.footer-links a:hover{text-decoration:underline;text-underline-offset:5px}
    .nav-download{border:1px solid #d7d7d5;padding:11px 17px;border-radius:999px;color:var(--ink);transition:background .2s,border-color .2s}
    .nav-download:hover{background:#fff;border-color:#aaa}
    .hero{position:relative;display:grid;grid-template-columns:1fr 1fr;align-items:center;min-height:660px;gap:30px;padding:72px 0 92px;isolation:isolate}
    .hero::before{content:"";position:absolute;z-index:-1;right:-7%;top:12%;width:56%;height:70%;border-radius:50%;background:radial-gradient(ellipse,#ffe5da 0%,#ffede4 35%,transparent 72%);filter:blur(24px)}
    .eyebrow{display:inline-flex;align-items:center;gap:8px;text-transform:uppercase;letter-spacing:.14em;font-size:11px;font-weight:800;color:#d3543b}
    .eyebrow::before{content:"";width:7px;height:7px;background:var(--orange);border-radius:50%}
    h1,h2,h3,p{margin-top:0}
    h1{max-width:640px;margin:23px 0 23px;font-size:clamp(56px,6.7vw,91px);letter-spacing:-.084em;line-height:.99;font-weight:760}
    h1 span{display:block;color:#f1694e}
    .hero-copy{max-width:485px;font-size:20px;line-height:1.55;color:var(--muted);letter-spacing:-.023em}
    .hero-actions{display:flex;align-items:center;gap:19px;flex-wrap:wrap;margin-top:33px}
    .store-button{display:inline-flex;align-items:center;gap:12px;min-width:211px;min-height:61px;padding:10px 18px;border:0;border-radius:14px;background:#1c1d20;color:#fff;font:inherit;text-align:left;box-shadow:0 12px 28px #1c1d201f;transition:transform .2s,box-shadow .2s}
    a.store-button:hover{transform:translateY(-3px);box-shadow:0 17px 32px #1c1d202b}
    .store-button svg{width:29px;height:29px;flex:none}
    .store-button span:not(.store-arrow){display:flex;flex-direction:column;line-height:1.12}
    .store-button small{font-size:11px;font-weight:500;letter-spacing:.01em}
    .store-button strong{font-size:21px;letter-spacing:-.035em;font-weight:680}
    .store-arrow{font-size:17px;margin-left:auto;align-self:flex-start;opacity:.7}
    .store-button--soon{background:#333438;cursor:default;box-shadow:none}
    .hero-note{font-size:13px;color:#77787d}
    .visual{position:relative;width:min(100%,515px);height:490px;justify-self:end;display:grid;place-items:center}
    .visual-halo{position:absolute;width:430px;height:430px;border:1px solid #f5cfc4;border-radius:50%;transform:translate(14px,6px)}
    .visual-halo::before,.visual-halo::after{content:"";position:absolute;inset:32px;border:1px solid #f2d5cc;border-radius:50%}
    .visual-halo::after{inset:78px}
    .pass{position:absolute;width:356px;height:225px;border-radius:22px;overflow:hidden;box-shadow:0 28px 65px #692b242a,0 4px 10px #692b2414}
    .pass-back{transform:translate(54px,-78px) rotate(12deg);background:linear-gradient(135deg,#e1e5e9,#b8c0c9)}
    .pass-back .card-icon{color:#777f87}
    .pass-front{transform:translate(-19px,45px) rotate(-8deg);background:linear-gradient(137deg,#ff8c67 0%,#ff603f 45%,#ed432f 100%);color:#fff;box-shadow:0 38px 70px #bd5b453e}
    .pass-top{display:flex;align-items:center;justify-content:space-between;padding:22px 23px 19px;border-bottom:1px solid #ffffff42;font-size:13px;font-weight:700}
    .pass-back .pass-top{border-bottom-color:#ffffff6b;color:#3f464b}
    .pass-label{font-size:9px;letter-spacing:.16em;text-transform:uppercase;font-weight:760;opacity:.72}
    .pass-route{display:flex;align-items:center;gap:10px;padding:20px 23px 0;font-size:25px;font-weight:730;letter-spacing:-.05em}
    .pass-route .route-line{height:1px;flex:1;background:#ffffffa8;position:relative}
    .pass-route .route-line::before,.pass-route .route-line::after{content:"";position:absolute;top:-3px;width:7px;height:7px;background:#fff;border-radius:50%}
    .pass-route .route-line::before{left:0}.pass-route .route-line::after{right:0}
    .pass-bottom{display:flex;justify-content:space-between;align-items:end;padding:19px 23px 0}
    .pass-bottom strong{display:block;margin-top:5px;font-size:13px;letter-spacing:-.01em}
    .barcode{width:106px;height:31px;background:repeating-linear-gradient(90deg,#fff 0 2px,transparent 2px 5px,#fff 5px 6px,transparent 6px 9px,#fff 9px 12px,transparent 12px 15px);opacity:.94}
    .card-icon{position:absolute;right:22px;top:20px;font-size:27px;color:#838e99;opacity:.55}
    .pass-back .pass-label{position:absolute;left:24px;top:26px;color:#56616a}
    .pass-back .card-name{position:absolute;left:24px;bottom:25px;font-size:18px;letter-spacing:-.04em;font-weight:700;color:#44505b}
    .float-chip{position:absolute;display:flex;align-items:center;gap:9px;padding:11px 15px;background:#fff;border:1px solid #f1e6e1;border-radius:999px;box-shadow:0 12px 35px #7e45331a;font-size:12px;font-weight:720;letter-spacing:-.01em}
    .float-chip::before{content:"✓";display:grid;place-items:center;width:19px;height:19px;background:#eaf8ed;color:#288a4c;border-radius:50%;font-size:11px}
    .float-chip--top{top:29px;left:3px;transform:rotate(-5deg)}
    .float-chip--bottom{right:2px;bottom:9px;transform:rotate(5deg)}
    .steps{border-top:1px solid var(--line);padding:61px 0 84px}
    .section-head{display:flex;align-items:end;justify-content:space-between;gap:30px;margin-bottom:34px}
    .section-head h2{font-size:clamp(34px,3.5vw,49px);letter-spacing:-.065em;line-height:1.08;margin:12px 0 0}
    .section-head p{max-width:280px;margin:0;color:var(--muted);font-size:15px;line-height:1.55}
    .step-grid{display:grid;grid-template-columns:repeat(3,1fr);gap:14px}
    .step{min-height:214px;padding:27px;border:1px solid #e9e8e5;border-radius:24px;background:#fff;box-shadow:0 8px 22px #393a3e05}
    .step-icon{display:grid;place-items:center;width:43px;height:43px;border-radius:13px;background:#fff0ea;color:#ec6749;font-size:23px;line-height:1;margin-bottom:30px}
    .step h3{font-size:20px;letter-spacing:-.04em;margin:0 0 8px}
    .step p{color:var(--muted);font-size:14px;line-height:1.5;margin:0;max-width:240px}
    .privacy-panel{position:relative;display:flex;justify-content:space-between;align-items:center;gap:30px;min-height:242px;margin-bottom:79px;padding:46px 55px;border-radius:29px;background:#202125;color:#fff;overflow:hidden}
    .privacy-panel::after{content:"";position:absolute;width:300px;height:300px;right:-40px;top:-125px;border:1px solid #ffffff20;border-radius:50%;box-shadow:0 0 0 48px #ffffff09,0 0 0 96px #ffffff06}
    .privacy-panel .eyebrow{color:#ffac97}
    .privacy-panel h2{position:relative;z-index:1;font-size:clamp(31px,3.5vw,45px);line-height:1.1;letter-spacing:-.06em;margin:13px 0 13px;max-width:570px}
    .privacy-panel p{position:relative;z-index:1;color:#bfc0c2;font-size:15px;line-height:1.6;margin:0;max-width:560px}
    .privacy-symbol{z-index:1;flex:none;display:grid;place-items:center;width:130px;height:130px;border:1px solid #ffffff26;border-radius:30px;color:#ff9b82;font-size:69px;font-weight:300;transform:rotate(8deg)}
    .site-footer{display:flex;justify-content:space-between;align-items:center;gap:25px;padding:28px 0 36px;border-top:1px solid var(--line);font-size:13px;color:#797a7e}
    .site-footer .brand{font-size:16px;color:var(--ink)}
    .site-footer .brand img{width:26px;height:26px}
    .footer-links{display:flex;flex-wrap:wrap;gap:22px}
    @media(max-width:900px){.hero{min-height:0;padding:78px 0 64px;grid-template-columns:1fr 1fr;gap:0}.visual{transform:scale(.8);transform-origin:center right;width:450px;max-width:100%;height:460px}h1{font-size:clamp(54px,7vw,74px)}.hero-copy{font-size:17px}}
    @media(max-width:700px){.wrap{width:min(100% - 36px,520px)}.site-header{height:75px}.nav{gap:17px;font-size:13px}.nav a:first-child{display:none}.nav-download{padding:9px 13px}.hero{display:flex;flex-direction:column;align-items:stretch;padding:67px 0 36px}.hero::before{width:100%;height:50%;top:42%;right:0}h1{font-size:clamp(56px,12vw,78px);margin:20px 0}.hero-copy{font-size:18px;line-height:1.5}.hero-actions{margin-top:26px}.visual{align-self:center;transform:scale(.8);transform-origin:center center;margin-top:2px;margin-bottom:-55px;width:460px;height:430px}.steps{padding:54px 0 64px}.section-head{display:block}.section-head p{margin-top:16px}.step-grid{grid-template-columns:1fr}.step{min-height:0;padding:23px}.step-icon{margin-bottom:20px}.privacy-panel{padding:34px 30px;margin-bottom:52px}.privacy-symbol{display:none}.site-footer{align-items:flex-start;flex-direction:column;gap:19px}}
    @media(max-width:430px){.nav a:nth-child(2){display:none}.visual{transform:scale(.66);width:440px;margin-top:-40px;margin-bottom:-110px}.hero-note{max-width:100px}.pass{width:356px}.float-chip--bottom{right:-12px}}
    @media(prefers-reduced-motion:reduce){html{scroll-behavior:auto}a.store-button,.nav-download{transition:none}}
  </style>
</head>
<body>
  <a class="skip" href="#main">Saltar al contenido</a>
  <header class="site-header wrap">
    <a class="brand" href="/" aria-label="AnyWallet, inicio"><img src="/brand-mark.png" alt="" width="39" height="39">AnyWallet</a>
    <nav class="nav" aria-label="Principal"><a href="#como-funciona">Cómo funciona</a><a href="/support">Soporte</a><a class="nav-download" href="#descargar">Descargar app</a></nav>
  </header>
  <main id="main">
    <section class="hero wrap" aria-labelledby="hero-title">
      <div class="hero-content">
        <div class="eyebrow">Hecha para iPhone</div>
        <h1 id="hero-title">Tus pases.<span>En su sitio.</span></h1>
        <p class="hero-copy">Billetes, tarjetas y códigos, listos para Apple Wallet. Importa un documento o crea un pase desde cero, en unos pocos toques.</p>
        <div class="hero-actions" id="descargar">${storeButton}<span class="hero-note">Para iPhone · Sin anuncios</span></div>
      </div>
      <div class="visual" role="img" aria-label="Ilustración de un billete y una tarjeta convertidos en pases de Wallet">
        <div class="visual-halo" aria-hidden="true"></div>
        <div class="pass pass-back" aria-hidden="true"><span class="pass-label">Tu tarjeta</span><span class="card-icon">✳</span><span class="card-name">Todo a mano.</span></div>
        <div class="pass pass-front" aria-hidden="true"><div class="pass-top"><span>AnyWallet</span><span>✳</span></div><div class="pass-route"><span>BCN</span><span class="route-line"></span><span>MAD</span></div><div class="pass-bottom"><div><span class="pass-label">Tu billete</span><strong>Listo para Wallet</strong></div><span class="barcode"></span></div></div>
        <div class="float-chip float-chip--top" aria-hidden="true">Importado en segundos</div>
        <div class="float-chip float-chip--bottom" aria-hidden="true">Siempre contigo</div>
      </div>
    </section>
    <section class="steps wrap" id="como-funciona" aria-labelledby="steps-title">
      <div class="section-head"><div><span class="eyebrow">Así de fácil</span><h2 id="steps-title">Del documento a Wallet.</h2></div><p>Elige lo que quieres guardar. AnyWallet te ayuda con el resto.</p></div>
      <div class="step-grid">
        <article class="step"><span class="step-icon" aria-hidden="true">↗</span><h3>Importa</h3><p>Abre un PDF o una imagen de tu billete o tarjeta.</p></article>
        <article class="step"><span class="step-icon" aria-hidden="true">✎</span><h3>Revisa</h3><p>Comprueba los datos, ajusta el pase o créalo desde cero.</p></article>
        <article class="step"><span class="step-icon" aria-hidden="true">✓</span><h3>Añade a Wallet</h3><p>Guárdalo en Apple Wallet y llévalo contigo.</p></article>
      </div>
    </section>
    <section class="privacy-panel wrap" aria-labelledby="privacy-title"><div><span class="eyebrow">Tu espacio, tus datos</span><h2 id="privacy-title">Tus documentos se analizan en tu iPhone.</h2><p>El archivo original no se sube. Solo se envían los datos necesarios para firmar el pase que decides crear.</p></div><div class="privacy-symbol" aria-hidden="true">⌁</div></section>
  </main>
  <footer class="site-footer wrap"><a class="brand" href="/"><img src="/brand-mark.png" alt="" width="26" height="26">AnyWallet</a><span>Hecho para llevar lo importante contigo.</span><div class="footer-links"><a href="/privacy">Política de privacidad</a><a href="/support">Soporte</a></div></footer>
</body>
</html>`;
}
