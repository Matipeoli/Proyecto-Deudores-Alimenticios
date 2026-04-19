const pool = require('../config/db');
const { generarFormularioPago } = require('../config/pluspagos');
// 2.1 Crear solicitud
const crearSolicitud = async (req, res) => {
  const { nombre_completo, cuit_dni, email, ciudad_id } = req.body;

  if (!nombre_completo || !cuit_dni || !email || !ciudad_id) {
    return res.status(400).json({ error: 'Todos los campos son requeridos' });
  }

  // Validar cuit_dni
  const cuitRegex = /^(\d{7,8}|\d{2}-\d{7,8}-\d)$/;
  if (!cuitRegex.test(cuit_dni)) {
    return res.status(422).json({ error: 'Formato de CUIT/DNI inválido' });
  }

  // Validar email
  const emailRegex = /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/;
  if (!emailRegex.test(email)) {
    return res.status(422).json({ error: 'Formato de email inválido' });
  }

  try {
    // Verificar que la ciudad existe y está activa
    const ciudad = await pool.query(
      `SELECT id, nombre FROM portal.ciudades WHERE id = $1 AND estado = 'activa'`,
      [ciudad_id]
    );
    if (ciudad.rows.length === 0) {
      return res.status(422).json({ error: 'Ciudad no existe o está inactiva' });
    }

    // Leer monto de configuración
    const config = await pool.query(
      `SELECT valor FROM portal.configuracion WHERE clave = 'monto_certificado'`
    );
    const monto = parseFloat(config.rows[0]?.valor || '8000');

    // Crear solicitud
    const result = await pool.query(
      `INSERT INTO portal.solicitudes 
        (nombre_completo, cuit_dni, email, ciudad_id, estado, numero_solicitud)
       VALUES ($1, $2, $3, $4, 'pendiente_pago', '')
       RETURNING *`,
      [nombre_completo, cuit_dni, email, ciudad_id]
    );

    const solicitud = result.rows[0];

    return res.status(201).json({
      id: solicitud.id,
      numero_solicitud: solicitud.numero_solicitud,
      nombre_completo: solicitud.nombre_completo,
      cuit_dni: solicitud.cuit_dni,
      email: solicitud.email,
      ciudad: ciudad.rows[0],
      estado: solicitud.estado,
      monto,
      fecha_solicitud: solicitud.fecha_solicitud,
      link_pago: null,
    });
  } catch (err) {
    console.error('Error en crearSolicitud:', err);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// 2.2 Listar mis solicitudes (ciudadano)
const listarMisSolicitudes = async (req, res) => {
  const { page = 1, limit = 10, estado } = req.query;
  const offset = (page - 1) * limit;
  const emailJWT = req.user.email;

  try {
    let conditions = [`s.email = $1`];
    let params = [emailJWT];
    let i = 2;

    if (estado) {
      conditions.push(`s.estado = $${i++}`);
      params.push(estado);
    }

    const where = `WHERE ${conditions.join(' AND ')}`;

    const result = await pool.query(
      `SELECT 
        s.id, s.numero_solicitud, s.nombre_completo, s.cuit_dni,
        s.estado, s.fecha_solicitud, s.fecha_emision,
        c.id AS ciudad_id, c.nombre AS ciudad_nombre,
        cert.id AS certificado_id, cert.numero_certificado,
        CASE WHEN s.estado = 'certificado_emitido' AND cert.id IS NOT NULL 
             THEN true ELSE false END AS puede_descargar
       FROM portal.solicitudes s
       LEFT JOIN portal.ciudades c ON s.ciudad_id = c.id
       LEFT JOIN portal.certificados cert ON s.id = cert.solicitud_id
       ${where}
       ORDER BY s.fecha_solicitud DESC
       LIMIT $${i++} OFFSET $${i++}`,
      [...params, limit, offset]
    );

    const total = await pool.query(
      `SELECT COUNT(*) FROM portal.solicitudes s ${where}`,
      params
    );

    return res.json({
      data: result.rows,
      pagination: {
        current_page: parseInt(page),
        total_pages: Math.ceil(total.rows[0].count / limit),
        total_records: parseInt(total.rows[0].count),
      },
    });
  } catch (err) {
    console.error('Error en listarMisSolicitudes:', err);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// 2.3 Obtener detalle de solicitud (ciudadano)
const obtenerSolicitud = async (req, res) => {
  const { id } = req.params;
  const emailJWT = req.user.email;

  try {
    const result = await pool.query(
      `SELECT 
        s.*, 
        c.nombre AS ciudad_nombre,
        cert.id AS certificado_id, cert.numero_certificado, cert.fecha_vencimiento,
        t.monto, t.estado AS estado_pago, t.metodo_pago, t.referencia_pluspagos
       FROM portal.solicitudes s
       LEFT JOIN portal.ciudades c ON s.ciudad_id = c.id
       LEFT JOIN portal.certificados cert ON s.id = cert.solicitud_id
       LEFT JOIN LATERAL (
         SELECT * FROM portal.transacciones tr
         WHERE tr.solicitud_id = s.id
         ORDER BY tr.fecha_transaccion DESC LIMIT 1
       ) t ON TRUE
       WHERE s.id = $1 AND s.email = $2`,
      [id, emailJWT]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Solicitud no encontrada' });
    }

    return res.json(result.rows[0]);
  } catch (err) {
    console.error('Error en obtenerSolicitud:', err);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// 2.4 Cancelar solicitud (ciudadano)
const cancelarSolicitud = async (req, res) => {
  const { id } = req.params;
  const emailJWT = req.user.email;

  try {
    const solicitud = await pool.query(
      `SELECT * FROM portal.solicitudes WHERE id = $1 AND email = $2`,
      [id, emailJWT]
    );

    if (solicitud.rows.length === 0) {
      return res.status(404).json({ error: 'Solicitud no encontrada' });
    }

    const estadosPermitidos = ['pendiente_pago', 'pago_fallido'];
    if (!estadosPermitidos.includes(solicitud.rows[0].estado)) {
      return res.status(422).json({
        error: 'Solo se pueden cancelar solicitudes en estado pendiente_pago o pago_fallido',
      });
    }

    const result = await pool.query(
      `UPDATE portal.solicitudes SET estado = 'cancelada' WHERE id = $1 RETURNING *`,
      [id]
    );

    return res.json({
      success: true,
      mensaje: 'Solicitud cancelada correctamente',
      solicitud: result.rows[0],
    });
  } catch (err) {
    console.error('Error en cancelarSolicitud:', err);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
};

const iniciarPago = async (req, res) => {
  const { id } = req.params;
  const emailJWT = req.user.email;

  try {
    const result = await pool.query(
      `SELECT s.*, c.valor AS monto
       FROM portal.solicitudes s
       CROSS JOIN portal.configuracion c
       WHERE s.id = $1 AND s.email = $2 AND c.clave = 'monto_certificado'`,
      [id, emailJWT]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Solicitud no encontrada' });
    }

    const solicitud = result.rows[0];

    if (solicitud.estado !== 'pendiente_pago') {
      return res.status(422).json({ error: 'La solicitud no está pendiente de pago' });
    }

    const html = generarFormularioPago(solicitud.id, solicitud.numero_solicitud, parseFloat(solicitud.monto));
    res.setHeader('Content-Security-Policy', "script-src 'self' 'unsafe-inline'");
    return res.send(html);
  } catch (err) {
    console.error('Error en iniciarPago:', err);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
};

module.exports = { crearSolicitud, listarMisSolicitudes, obtenerSolicitud, cancelarSolicitud, iniciarPago };