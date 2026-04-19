/**
 * Cliente de Prueba - PlusPagos Mock
 * Summer Campus 2026 - i2T Software Factory
 * 
 * Simula un comercio que integra con la pasarela de pagos.
 */

const express = require('express');
const { encryptString } = require('./crypto');

const app = express();
const PORT = 3012;

// ============================================
// CONFIGURACIÓN - Debe coincidir con el mock
// ============================================
const CONFIG = {
  PLUSPAGOS_URL: 'http://localhost:3000',
  MERCHANT_GUID: 'test-merchant-001',
  SECRET_KEY: 'clave-secreta-campus-2026',
  CALLBACK_URL: 'http://localhost:' + PORT + '/webhook',
  FRONTEND_URL: 'http://localhost:' + PORT
};

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// ============================================
// PÁGINA PRINCIPAL - Formulario de pago
// ============================================
app.get('/', (req, res) => {
  const html = '<!DOCTYPE html><html><head><meta charset="UTF-8"><title>Mi Tienda - Test</title>' +
    '<style>*{margin:0;padding:0;box-sizing:border-box}' +
    'body{font-family:system-ui;background:linear-gradient(135deg,#667eea,#764ba2);min-height:100vh;display:flex;align-items:center;justify-content:center;padding:20px}' +
    '.card{background:white;border-radius:16px;padding:40px;max-width:500px;width:100%;box-shadow:0 25px 50px rgba(0,0,0,0.2)}' +
    'h1{color:#1e293b;margin-bottom:10px}p{color:#64748b;margin-bottom:30px}' +
    '.form-group{margin-bottom:20px}label{display:block;color:#374151;font-weight:600;margin-bottom:6px}' +
    'input,select{width:100%;padding:14px;border:2px solid #e5e7eb;border-radius:8px;font-size:1rem}' +
    'input:focus,select:focus{outline:none;border-color:#667eea}' +
    '.btn{width:100%;padding:16px;background:linear-gradient(135deg,#667eea,#764ba2);color:white;border:none;border-radius:8px;font-size:1.1rem;font-weight:600;cursor:pointer}' +
    '.btn:hover{opacity:0.9}' +
    '.config{background:#f8fafc;border-radius:8px;padding:15px;margin-top:25px;font-size:0.85rem}' +
    '.config code{background:#e2e8f0;padding:2px 6px;border-radius:4px;font-size:0.8rem}' +
    '</style></head><body>' +
    '<div class="card">' +
    '<h1>🛒 Mi Tienda Online</h1>' +
    '<p>Simulador de comercio - Summer Campus 2026</p>' +
    '<form action="/checkout" method="POST">' +
    '<div class="form-group"><label>Producto</label>' +
    '<select name="producto"><option value="Curso de Node.js">Curso de Node.js - $2500</option>' +
    '<option value="Curso de React">Curso de React - $3000</option>' +
    '<option value="Pack Completo">Pack Completo - $5000</option></select></div>' +
    '<div class="form-group"><label>Monto (en pesos)</label>' +
    '<input type="number" name="monto" value="2500" step="0.01" min="1" required></div>' +
    '<div class="form-group"><label>Tu nombre</label>' +
    '<input type="text" name="nombre" value="Juan Pérez" required></div>' +
    '<div class="form-group"><label>Tu email</label>' +
    '<input type="email" name="email" value="juan@test.com" required></div>' +
    '<button type="submit" class="btn">💳 Pagar Ahora</button>' +
    '</form>' +
    '<div class="config"><strong>⚙️ Configuración:</strong><br>' +
    'Mock URL: <code>' + CONFIG.PLUSPAGOS_URL + '</code><br>' +
    'GUID: <code>' + CONFIG.MERCHANT_GUID + '</code><br>' +
    'Secret: <code>' + CONFIG.SECRET_KEY + '</code></div>' +
    '</div></body></html>';
  res.send(html);
});

// ============================================
// POST /checkout - Prepara y redirige a PlusPagos
// ============================================
app.post('/checkout', (req, res) => {
  const { producto, monto, nombre, email } = req.body;
  
  console.log('\\n=== NUEVO CHECKOUT ===');
  console.log('Producto:', producto);
  console.log('Monto:', monto);
  console.log('Cliente:', nombre, email);
  
  // Generar ID único para esta transacción
  const transaccionId = 'TXN-' + Date.now();
  
  // Convertir monto a centavos
  const montoCentavos = Math.round(parseFloat(monto) * 100).toString();
  
  // URLs de callback (el mock nos notifica aquí)
  const callbackSuccess = CONFIG.CALLBACK_URL + '?status=success&txn=' + transaccionId;
  const callbackCancel = CONFIG.CALLBACK_URL + '?status=cancel&txn=' + transaccionId;
  
  // URLs de redirección del usuario
  const urlSuccess = CONFIG.FRONTEND_URL + '/resultado?status=success&txn=' + transaccionId;
  const urlError = CONFIG.FRONTEND_URL + '/resultado?status=error&txn=' + transaccionId;
  
  // Encriptar campos sensibles con el SECRET compartido
  const secret = CONFIG.SECRET_KEY;
  
  const encrypted = {
    Monto: encryptString(montoCentavos, secret),
    CallbackSuccess: encryptString(callbackSuccess, secret),
    CallbackCancel: encryptString(callbackCancel, secret),
    UrlSuccess: encryptString(urlSuccess, secret),
    UrlError: encryptString(urlError, secret),
    Informacion: encryptString(JSON.stringify({ producto, nombre, email }), secret)
  };
  
  console.log('Monto en centavos:', montoCentavos);
  console.log('Campos encriptados ✓');
  
  // Generar HTML con formulario que hace POST automático a PlusPagos
  const html = '<!DOCTYPE html><html><head><meta charset="UTF-8"><title>Redirigiendo...</title>' +
    '<style>body{font-family:system-ui;background:#1e293b;color:white;display:flex;align-items:center;justify-content:center;min-height:100vh;margin:0}' +
    '.loader{text-align:center}.spinner{width:50px;height:50px;border:4px solid rgba(255,255,255,0.2);border-top-color:#667eea;border-radius:50%;animation:spin 1s linear infinite;margin:0 auto 20px}' +
    '@keyframes spin{to{transform:rotate(360deg)}}</style></head><body>' +
    '<div class="loader"><div class="spinner"></div><p>Conectando con la pasarela de pago...</p></div>' +
    '<form id="f" action="' + CONFIG.PLUSPAGOS_URL + '" method="POST" style="display:none">' +
    '<input name="Comercio" value="' + CONFIG.MERCHANT_GUID + '">' +
    '<input name="TransaccionComercioId" value="' + transaccionId + '">' +
    '<input name="Monto" value="' + encrypted.Monto + '">' +
    '<input name="CallbackSuccess" value="' + encrypted.CallbackSuccess + '">' +
    '<input name="CallbackCancel" value="' + encrypted.CallbackCancel + '">' +
    '<input name="UrlSuccess" value="' + encrypted.UrlSuccess + '">' +
    '<input name="UrlError" value="' + encrypted.UrlError + '">' +
    '<input name="Informacion" value="' + encrypted.Informacion + '">' +
    '<input name="Producto[0]" value="' + producto + '">' +
    '<input name="MontoProducto[0]" value="' + montoCentavos + '">' +
    '</form>' +
    '<script>document.getElementById("f").submit();</script>' +
    '</body></html>';
  
  res.send(html);
});

// ============================================
// WEBHOOK - Recibe notificaciones del mock
// ============================================
app.post('/webhook', (req, res) => {
  console.log('\\n=== WEBHOOK RECIBIDO ===');
  console.log('Query:', req.query);
  console.log('Body:', JSON.stringify(req.body, null, 2));
  console.log('========================\\n');
  
  // Aquí guardarías el estado del pago en tu base de datos
  
  res.json({ received: true });
});

// ============================================
// RESULTADO - Página final para el usuario
// ============================================
app.get('/resultado', (req, res) => {
  const { status, txn } = req.query;
  const isSuccess = status === 'success';
  
  const html = '<!DOCTYPE html><html><head><meta charset="UTF-8"><title>Resultado</title>' +
    '<style>body{font-family:system-ui;background:linear-gradient(135deg,#667eea,#764ba2);min-height:100vh;display:flex;align-items:center;justify-content:center;margin:0}' +
    '.card{background:white;border-radius:16px;padding:50px;text-align:center;max-width:400px;box-shadow:0 25px 50px rgba(0,0,0,0.2)}' +
    '.icon{font-size:4rem;margin-bottom:20px}h1{color:' + (isSuccess ? '#059669' : '#dc2626') + ';margin-bottom:10px}' +
    'p{color:#64748b}.txn{background:#f1f5f9;padding:12px;border-radius:8px;margin:20px 0;font-family:monospace;font-size:0.9rem}' +
    '.btn{display:inline-block;padding:14px 30px;background:linear-gradient(135deg,#667eea,#764ba2);color:white;text-decoration:none;border-radius:8px;margin-top:15px}' +
    '</style></head><body>' +
    '<div class="card">' +
    '<div class="icon">' + (isSuccess ? '✅' : '❌') + '</div>' +
    '<h1>' + (isSuccess ? '¡Pago Exitoso!' : 'Pago Rechazado') + '</h1>' +
    '<p>' + (isSuccess ? 'Tu compra fue procesada correctamente.' : 'No pudimos procesar tu pago. Intentá de nuevo.') + '</p>' +
    '<div class="txn">ID: ' + (txn || 'N/A') + '</div>' +
    '<a href="/" class="btn">Volver a la tienda</a>' +
    '</div></body></html>';
  
  res.send(html);
});

// ============================================
// INICIAR SERVIDOR
// ============================================
app.listen(PORT, () => {
  console.log('');
  console.log('╔════════════════════════════════════════════════════════════╗');
  console.log('║  🛒 Cliente de Prueba - PlusPagos                          ║');
  console.log('║  Summer Campus 2026                                        ║');
  console.log('╠════════════════════════════════════════════════════════════╣');
  console.log('║  🌐 Tienda:  http://localhost:' + PORT + '                         ║');
  console.log('║  🔔 Webhook: http://localhost:' + PORT + '/webhook                 ║');
  console.log('╠════════════════════════════════════════════════════════════╣');
  console.log('║  ⚠️  El mock debe estar corriendo en localhost:3000        ║');
  console.log('╚════════════════════════════════════════════════════════════╝');
  console.log('');
});
