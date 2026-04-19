const nodemailer = require('nodemailer');
require('dotenv').config();

const transporter = nodemailer.createTransport({
  host: process.env.EMAIL_HOST,
  port: process.env.EMAIL_PORT,
  secure: false,
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS,
  },
});

transporter.verify((error) => {
  if (error) {
    console.error('❌ Error al conectar con el servidor de email:', error);
  } else {
    console.log('✅ Servidor de email listo');
  }
});

const enviarOTP = async (email, codigo) => {
  await transporter.sendMail({
    from: process.env.EMAIL_FROM,
    to: email,
    subject: 'Tu código de verificación - Portal de Certificados',
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 500px; margin: 0 auto;">
        <h2 style="color: #1a5276;">Portal de Certificados de Deudor</h2>
        <p>Tu código de verificación es:</p>
        <div style="background: #f2f3f4; padding: 20px; text-align: center; border-radius: 8px;">
          <h1 style="color: #1a5276; letter-spacing: 8px; font-size: 40px;">${codigo}</h1>
        </div>
        <p>Este código es válido por <strong>10 minutos</strong>.</p>
        <p>Si no solicitaste este código, ignorá este mensaje.</p>
        <hr/>
        <small style="color: #999;">Gobierno de la República Argentina</small>
      </div>
    `,
  });
};

module.exports = { enviarOTP };