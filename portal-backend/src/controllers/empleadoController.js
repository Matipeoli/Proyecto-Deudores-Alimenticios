const pool = require('../config/db');

// 3.1 Listar solicitudes kanban (empleado)
const listarSolicitudesKanban = async (req, res) => {
  const { estado, ciudad_id, prioridad, buscar, fecha_desde, fecha_hasta, page = 1, limit = 20 } = req.query;
  const offset = (page - 1) * limit;

  try {
    let conditions = [`s.estado IN ('pagada', 'en_revision', 'aprobada')`];
    let params = [];
    let i = 1;

    if (estado) {
      conditions[0] = `s.estado = $${i++}`;
      params.push(estado);
    }
    if (ciudad_id) {
      conditions.push(`s.ciudad_id = $${i++}`);
      params.push(ciudad_id);
    }
    if (prioridad) {
      conditions.push(`s.prioridad = $${i++}`);
      params.push(prioridad);
    }
    if (buscar) {
      conditions.push(`(s.cuit_dni ILIKE $${i} OR s.nombre_completo ILIKE $${i++})`);
      params.push(`%${buscar}%`);
    }
    if (fecha_desde) {
      conditions.push(`s.fecha_solicitud >= $${i++}`);
      params.push(fecha_desde);
    }
    if (fecha_hasta) {
      conditions.push(`s.fecha_solicitud <= $${i++}`);
      params.push(fecha_hasta);
    }

    const where = `WHERE ${conditions.join(' AND ')}`;

    const result = await pool.query(
      `SELECT 
        s.id, s.numero_solicitud, s.nombre_completo, s.cuit_dni,
        s.estado, s.prioridad, s.fecha_solicitud, s.fecha_pago,
        c.id AS ciudad_id, c.nombre AS ciudad_nombre,
        e.id AS empleado_id, e.nombre AS empleado_nombre
       FROM portal.solicitudes s
       LEFT JOIN portal.ciudades c ON s.ciudad_id = c.id
       LEFT JOIN portal.empleados e ON s.empleado_asignado_id = e.id
       ${where}
       ORDER BY s.prioridad DESC, s.fecha_solicitud ASC
       LIMIT $${i++} OFFSET $${i++}`,
      [...params, limit, offset]
    );

    // Conteo por estado para el kanban
    const conteos = await pool.query(
      `SELECT estado, COUNT(*) AS total
       FROM portal.solicitudes
       WHERE estado IN ('pagada', 'en_revision', 'aprobada')
       GROUP BY estado`
    );

    return res.json({
      data: result.rows,
      conteos: conteos.rows,
      pagination: {
        current_page: parseInt(page),
        total_pages: Math.ceil((result.rowCount || 1) / limit),
        total_records: result.rowCount,
      },
    });
  } catch (err) {
    console.error('Error en listarSolicitudesKanban:', err);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// 3.2 Obtener detalle de solicitud (empleado)
const obtenerSolicitudDetalle = async (req, res) => {
  const { id } = req.params;

  try {
    const result = await pool.query(
      `SELECT 
        s.*,
        c.nombre AS ciudad_nombre,
        e.nombre AS empleado_asignado_nombre,
        cert.id AS certificado_id, cert.numero_certificado, 
        cert.fecha_vencimiento, cert.es_deudor,
        t.monto, t.estado AS estado_pago, t.metodo_pago, 
        t.referencia_pluspagos, t.codigo_autorizacion
       FROM portal.solicitudes s
       LEFT JOIN portal.ciudades c ON s.ciudad_id = c.id
       LEFT JOIN portal.empleados e ON s.empleado_asignado_id = e.id
       LEFT JOIN portal.certificados cert ON s.id = cert.solicitud_id
       LEFT JOIN LATERAL (
         SELECT * FROM portal.transacciones tr
         WHERE tr.solicitud_id = s.id
         ORDER BY tr.fecha_transaccion DESC LIMIT 1
       ) t ON TRUE
       WHERE s.id = $1`,
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Solicitud no encontrada' });
    }

    // Historial de auditoría
    const auditoria = await pool.query(
      `SELECT a.accion, a.created_at, a.valores_anteriores, a.valores_nuevos,
              e.nombre AS usuario_nombre
       FROM portal.auditoria a
       LEFT JOIN portal.empleados e ON a.usuario_id = e.id
       WHERE a.tabla_afectada = 'solicitudes' AND a.registro_id = $1
       ORDER BY a.created_at DESC`,
      [id]
    );

    return res.json({
      ...result.rows[0],
      historial: auditoria.rows,
    });
  } catch (err) {
    console.error('Error en obtenerSolicitudDetalle:', err);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// 3.3 Aprobar solicitud
const aprobarSolicitud = async (req, res) => {
  const { id } = req.params;
  const { observaciones } = req.body || {};
  const empleado = req.user;

  try {
    const solicitud = await pool.query(
      `SELECT * FROM portal.solicitudes WHERE id = $1`, [id]
    );

    if (solicitud.rows.length === 0) {
      return res.status(404).json({ error: 'Solicitud no encontrada' });
    }

    if (solicitud.rows[0].estado !== 'en_revision') {
      return res.status(422).json({ error: 'La solicitud debe estar en estado en_revision' });
    }

    await pool.query('SET LOCAL app.current_user_id = $1', [String(empleado.id)]);
    await pool.query('SET LOCAL app.current_user_email = $1', [empleado.email]);
    await pool.query('SET LOCAL app.current_user_rol = $1', [empleado.rol]);

    const result = await pool.query(
      `UPDATE portal.solicitudes 
       SET estado = 'aprobada', observaciones = COALESCE($1, observaciones)
       WHERE id = $2 RETURNING *`,
      [observaciones, id]
    );

    return res.json({
      success: true,
      mensaje: 'Solicitud aprobada correctamente',
      solicitud: result.rows[0],
    });
  } catch (err) {
    console.error('Error en aprobarSolicitud:', err);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// 3.4 Rechazar solicitud
const rechazarSolicitud = async (req, res) => {
  const { id } = req.params;
  const { motivo_rechazo } = req.body;
  const empleado = req.user;

  if (!motivo_rechazo || motivo_rechazo.trim().length < 10) {
    return res.status(422).json({ error: 'El motivo de rechazo debe tener al menos 10 caracteres' });
  }

  try {
    const solicitud = await pool.query(
      `SELECT * FROM portal.solicitudes WHERE id = $1`, [id]
    );

    if (solicitud.rows.length === 0) {
      return res.status(404).json({ error: 'Solicitud no encontrada' });
    }

    if (solicitud.rows[0].estado !== 'en_revision') {
      return res.status(422).json({ error: 'La solicitud debe estar en estado en_revision' });
    }

    await pool.query('SET LOCAL app.current_user_id = $1', [String(empleado.id)]);
    await pool.query('SET LOCAL app.current_user_email = $1', [empleado.email]);
    await pool.query('SET LOCAL app.current_user_rol = $1', [empleado.rol]);

    const result = await pool.query(
      `UPDATE portal.solicitudes 
       SET estado = 'rechazada', motivo_rechazo = $1
       WHERE id = $2 RETURNING *`,
      [motivo_rechazo, id]
    );

    return res.json({
      success: true,
      mensaje: 'Solicitud rechazada',
      solicitud: result.rows[0],
    });
  } catch (err) {
    console.error('Error en rechazarSolicitud:', err);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// 3.5 Reasignar solicitud
const reasignarSolicitud = async (req, res) => {
  const { id } = req.params;
  const { empleado_id } = req.body;
  const empleado = req.user;

  if (!empleado_id) {
    return res.status(400).json({ error: 'empleado_id es requerido' });
  }

  try {
    const solicitud = await pool.query(
      `SELECT * FROM portal.solicitudes WHERE id = $1`, [id]
    );

    if (solicitud.rows.length === 0) {
      return res.status(404).json({ error: 'Solicitud no encontrada' });
    }

    const estadosPermitidos = ['pagada', 'en_revision'];
    if (!estadosPermitidos.includes(solicitud.rows[0].estado)) {
      return res.status(422).json({ error: 'Solo se pueden reasignar solicitudes en estado pagada o en_revision' });
    }

    // Verificar que el empleado destino existe y está activo
    const destino = await pool.query(
      `SELECT * FROM portal.empleados WHERE id = $1 AND estado = 'activo'`, [empleado_id]
    );

    if (destino.rows.length === 0) {
      return res.status(404).json({ error: 'Empleado destino no encontrado o inactivo' });
    }

    await pool.query('SET LOCAL app.current_user_id = $1', [String(empleado.id)]);
    await pool.query('SET LOCAL app.current_user_email = $1', [empleado.email]);
    await pool.query('SET LOCAL app.current_user_rol = $1', [empleado.rol]);

    const result = await pool.query(
      `UPDATE portal.solicitudes SET empleado_asignado_id = $1 WHERE id = $2 RETURNING *`,
      [empleado_id, id]
    );

    return res.json({
      success: true,
      mensaje: 'Solicitud reasignada correctamente',
      solicitud: result.rows[0],
    });
  } catch (err) {
    console.error('Error en reasignarSolicitud:', err);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// 3.6 Marcar prioridad urgente
const cambiarPrioridad = async (req, res) => {
  const { id } = req.params;
  const { prioridad } = req.body;

  if (!['normal', 'urgente'].includes(prioridad)) {
    return res.status(422).json({ error: 'Prioridad debe ser normal o urgente' });
  }

  try {
    const result = await pool.query(
      `UPDATE portal.solicitudes SET prioridad = $1 WHERE id = $2 RETURNING *`,
      [prioridad, id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Solicitud no encontrada' });
    }

    return res.json({
      success: true,
      mensaje: `Prioridad cambiada a ${prioridad}`,
      solicitud: result.rows[0],
    });
  } catch (err) {
    console.error('Error en cambiarPrioridad:', err);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// 3.7 Tomar solicitud en revisión
const tomarRevision = async (req, res) => {
  const { id } = req.params;
  const empleado = req.user;

  try {
    const solicitud = await pool.query(
      `SELECT * FROM portal.solicitudes WHERE id = $1`, [id]
    );

    if (solicitud.rows.length === 0) {
      return res.status(404).json({ error: 'Solicitud no encontrada' });
    }

    if (solicitud.rows[0].estado !== 'pagada') {
      return res.status(422).json({ error: 'La solicitud debe estar en estado pagada' });
    }

    await pool.query('SET LOCAL app.current_user_id = $1', [String(empleado.id)]);
    await pool.query('SET LOCAL app.current_user_email = $1', [empleado.email]);
    await pool.query('SET LOCAL app.current_user_rol = $1', [empleado.rol]);

    const result = await pool.query(
      `UPDATE portal.solicitudes
       SET estado = 'en_revision', empleado_asignado_id = $1
       WHERE id = $2 RETURNING *`,
      [empleado.id, id]
    );

    return res.json({
      success: true,
      mensaje: 'Solicitud tomada en revisión',
      solicitud: result.rows[0],
    });
  } catch (err) {
    console.error('Error en tomarRevision:', err);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
};
module.exports = {
  listarSolicitudesKanban,
  obtenerSolicitudDetalle,
  aprobarSolicitud,
  rechazarSolicitud,
  reasignarSolicitud,
  cambiarPrioridad,
  tomarRevision,
};