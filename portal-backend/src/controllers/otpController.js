const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const pool = require('../config/db');
const { enviarOTP } = require('../config/email');
require('dotenv').config();

// 1.1 Enviar OTP
const sendOTP = async (req, res) => {
  const { dni, email } = req.body;

  if (!dni || !email) {
    return res.status(400).json({ error: 'DNI y email son requeridos' });
  }

  // Validar formato DNI
  const dniRegex = /^\d{7,8}$/;
  if (!dniRegex.test(dni)) {
    return res.status(400).json({ error: 'DNI inválido' });
  }

  // Validar formato email
  const emailRegex = /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/;
  if (!emailRegex.test(email)) {
    return res.status(400).json({ error: 'Email inválido' });
  }

  try {
    // Leer configuración de duración OTP
    const configResult = await pool.query(
      `SELECT valor FROM portal.configuracion WHERE clave = 'duracion_otp_minutos'`
    );
    const duracionMinutos = parseInt(configResult.rows[0]?.valor || '10');

    // Generar código de 6 dígitos
    const codigo = Math.floor(100000 + Math.random() * 900000).toString();

    // Hashear el código
    const codigoHash = await bcrypt.hash(codigo, 12);

    // Invalidar OTPs anteriores del mismo usuario
    await pool.query(
      `UPDATE portal.otp_sessions 
       SET usado = TRUE 
       WHERE email = $1 AND cuit_dni = $2 AND usado = FALSE`,
      [email, dni]
    );

    // Insertar nuevo OTP
    const expiraAt = new Date(Date.now() + duracionMinutos * 60 * 1000);
    await pool.query(
      `INSERT INTO portal.otp_sessions (email, cuit_dni, codigo_otp_hash, intentos, expira_at, usado)
       VALUES ($1, $2, $3, 0, $4, FALSE)`,
      [email, dni, codigoHash, expiraAt]
    );

    // Enviar email
    await enviarOTP(email, codigo);

    return res.json({
      success: true,
      message: `Código enviado a ${email}`,
      expires_at: expiraAt.toISOString(),
      attempts_remaining: 3,
    });
  } catch (err) {
    console.error('Error en sendOTP:', err);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// 1.2 Verificar OTP
const verifyOTP = async (req, res) => {
  const { email, code } = req.body;

  if (!email || !code) {
    return res.status(400).json({ error: 'Email y código son requeridos' });
  }

  try {
    // Leer max intentos
    const configResult = await pool.query(
      `SELECT valor FROM portal.configuracion WHERE clave = 'max_intentos_otp'`
    );
    const maxIntentos = parseInt(configResult.rows[0]?.valor || '3');

    // Buscar OTP activo
    const result = await pool.query(
      `SELECT * FROM portal.otp_sessions 
       WHERE email = $1 AND usado = FALSE AND expira_at > NOW()
       ORDER BY created_at DESC LIMIT 1`,
      [email]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Código expirado o no existe' });
    }

    const session = result.rows[0];

    // Verificar si ya agotó intentos
    if (session.intentos >= maxIntentos) {
      await pool.query(
        `UPDATE portal.otp_sessions SET usado = TRUE WHERE id = $1`,
        [session.id]
      );
      return res.status(429).json({ error: 'Máximo de intentos excedido' });
    }

    // Verificar código
    const codigoValido = await bcrypt.compare(code, session.codigo_otp_hash);

    if (!codigoValido) {
      // Incrementar intentos
      const nuevosIntentos = session.intentos + 1;
      await pool.query(
        `UPDATE portal.otp_sessions SET intentos = $1 WHERE id = $2`,
        [nuevosIntentos, session.id]
      );

      if (nuevosIntentos >= maxIntentos) {
        await pool.query(
          `UPDATE portal.otp_sessions SET usado = TRUE WHERE id = $1`,
          [session.id]
        );
        return res.status(429).json({ error: 'Máximo de intentos excedido' });
      }

      return res.status(400).json({
        error: 'Código inválido',
        attempts_remaining: maxIntentos - nuevosIntentos,
      });
    }

    // Código válido — marcar como usado
    await pool.query(
      `UPDATE portal.otp_sessions SET usado = TRUE WHERE id = $1`,
      [session.id]
    );

    // Generar JWT para ciudadano
    const token = jwt.sign(
      {
        email: session.email,
        cuit_dni: session.cuit_dni,
        rol: 'ciudadano',
      },
      process.env.JWT_SECRET,
      { expiresIn: parseInt(process.env.JWT_EXPIRES_IN) }
    );

    return res.json({
      success: true,
      access_token: token,
      token_type: 'Bearer',
      expires_in: parseInt(process.env.JWT_EXPIRES_IN),
      user: {
        email: session.email,
        dni: session.cuit_dni,
        role: 'ciudadano',
      },
    });
  } catch (err) {
    console.error('Error en verifyOTP:', err);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
};

module.exports = { sendOTP, verifyOTP };