const CryptoJS = require('crypto-js');
require('dotenv').config();

const SECRET_KEY = process.env.PLUSPAGOS_SECRET;
const MERCHANT_GUID = process.env.PLUSPAGOS_GUID;
const PLUSPAGOS_URL = process.env.PLUSPAGOS_URL;
const BACKEND_URL = process.env.BACKEND_URL;

function encryptString(plainText) {
  const key = CryptoJS.SHA256(SECRET_KEY);
  const iv = CryptoJS.lib.WordArray.random(16);
  const encrypted = CryptoJS.AES.encrypt(plainText, key, {
    iv,
    mode: CryptoJS.mode.CBC,
    padding: CryptoJS.pad.Pkcs7,
  });
  const combined = iv.concat(encrypted.ciphertext);
  return CryptoJS.enc.Base64.stringify(combined);
}

function generarFormularioPago(solicitudId, numeroSolicitud, monto) {
  const montoCentavos = Math.round(monto * 100).toString();

  const campos = {
    Comercio: MERCHANT_GUID,
    TransaccionComercioId: numeroSolicitud,
    Monto: encryptString(montoCentavos),
    UrlSuccess: encryptString(`${BACKEND_URL}/api/pagos/success?solicitud_id=${solicitudId}`),
    UrlError: encryptString(`${BACKEND_URL}/api/pagos/error?solicitud_id=${solicitudId}`),
    CallbackSuccess: encryptString(`${BACKEND_URL}/api/pagos/webhook`),
    CallbackCancel: encryptString(`${BACKEND_URL}/api/pagos/webhook`),
  };

  const inputs = Object.entries(campos)
    .map(([k, v]) => `<input type="hidden" name="${k}" value="${v}">`)
    .join('\n');

  return `
    <!DOCTYPE html>
    <html>
    <head><meta charset="UTF-8"><title>Redirigiendo al pago...</title></head>
    <body>
      <p>Redirigiendo a la pasarela de pago...</p>
      <form id="payForm" action="${PLUSPAGOS_URL}/" method="POST">
        ${inputs}
      </form>
      <script>document.getElementById('payForm').submit();</script>
    </body>
    </html>
  `;
}

module.exports = { generarFormularioPago };