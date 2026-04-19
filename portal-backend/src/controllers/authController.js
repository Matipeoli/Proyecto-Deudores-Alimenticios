const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const pool = require('../config/db');
require('dotenv').config();

// 1.3 Login Empleado/Admin
const loginEmpleado = async (req, res) => {
  const { email, password } = req.body;

  // Validar formato email institucional
  const emailRegex = /^[A-Za-z0-9._%+-]+@gobierno\.gob\.ar$/;
  if (!emailRegex.test(email)) {
    return res.status(422).json({ error: 'El email debe ser @gobierno.gob.ar' });
  }

  try {
    // Buscar empleado
    const result = await pool.query(
      'SELECT * FROM portal.empleados WHERE email = $1',
      [email]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Credenciales inválidas' });
    }

    const empleado = result.rows[0];

    // Verificar si está activo
    if (empleado.estado !== 'activo') {
      return res.status(403).json({ error: 'Empleado inactivo' });
    }

    // Verificar contraseña
    const passwordValida = await bcrypt.compare(password, empleado.password_hash);
    if (!passwordValida) {
      return res.status(401).json({ error: 'Credenciales inválidas' });
    }

    // Actualizar ultimo_acceso
    await pool.query(
      'UPDATE portal.empleados SET ultimo_acceso = NOW() WHERE id = $1',
      [empleado.id]
    );

    // Registrar en auditoría
    await pool.query(
      `INSERT INTO portal.auditoria (tabla_afectada, registro_id, accion, usuario_id, usuario_email, usuario_rol)
       VALUES ('empleados', $1, 'login', $1, $2, $3)`,
      [empleado.id, empleado.email, empleado.rol]
    );

    // Generar JWT
    const token = jwt.sign(
      {
        id: empleado.id,
        email: empleado.email,
        rol: empleado.rol,
        ciudad_id: empleado.ciudad_id,
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
        id: empleado.id,
        nombre: empleado.nombre,
        email: empleado.email,
        rol: empleado.rol,
        ultimo_acceso: empleado.ultimo_acceso,
      },
    });
  } catch (err) {
    console.error('Error en loginEmpleado:', err);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// 1.4 Refresh Token
const refreshToken = async (req, res) => {
  try {
    const token = jwt.sign(
      {
        id: req.user.id,
        email: req.user.email,
        rol: req.user.rol,
        ciudad_id: req.user.ciudad_id,
      },
      process.env.JWT_SECRET,
      { expiresIn: parseInt(process.env.JWT_EXPIRES_IN) }
    );

    return res.json({
      access_token: token,
      expires_in: parseInt(process.env.JWT_EXPIRES_IN),
    });
  } catch (err) {
    console.error('Error en refreshToken:', err);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// 1.5 Logout
const logoutEmpleado = async (req, res) => {
  try {
    await pool.query(
      `INSERT INTO portal.auditoria (tabla_afectada, registro_id, accion, usuario_id, usuario_email, usuario_rol)
       VALUES ('empleados', $1, 'logout', $1, $2, $3)`,
      [req.user.id, req.user.email, req.user.rol]
    );
    return res.status(204).send();
  } catch (err) {
    console.error('Error en logoutEmpleado:', err);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
};

module.exports = { loginEmpleado, logoutEmpleado, refreshToken };