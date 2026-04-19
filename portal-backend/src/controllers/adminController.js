const pool = require('../config/db');
const bcrypt = require('bcrypt');

// 5.1 Listar empleados
const listarEmpleados = async (req, res) => {
  const { estado, ciudad_id, buscar, page = 1, limit = 20 } = req.query;
  const offset = (page - 1) * limit;

  try {
    let conditions = [];
    let params = [];
    let i = 1;

    if (estado) {
      conditions.push(`e.estado = $${i++}`);
      params.push(estado);
    }
    if (ciudad_id) {
      conditions.push(`e.ciudad_id = $${i++}`);
      params.push(ciudad_id);
    }
    if (buscar) {
      conditions.push(`(e.nombre ILIKE $${i} OR e.email ILIKE $${i++})`);
      params.push(`%${buscar}%`);
    }

    const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';

    const result = await pool.query(
      `SELECT 
        e.id, e.nombre, e.email, e.estado, e.rol,
        e.fecha_creacion, e.ultimo_acceso,
        c.id AS ciudad_id, c.nombre AS ciudad_nombre
       FROM portal.empleados e
       LEFT JOIN portal.ciudades c ON e.ciudad_id = c.id
       ${where}
       ORDER BY e.nombre ASC
       LIMIT $${i++} OFFSET $${i++}`,
      [...params, limit, offset]
    );

    const total = await pool.query(
      `SELECT COUNT(*) FROM portal.empleados e ${where}`, params
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
    console.error('Error en listarEmpleados:', err);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// 5.2 Obtener empleado por ID
const obtenerEmpleado = async (req, res) => {
  const { id } = req.params;
  try {
    const result = await pool.query(
      `SELECT e.id, e.nombre, e.email, e.estado, e.rol,
              e.fecha_creacion, e.ultimo_acceso,
              c.id AS ciudad_id, c.nombre AS ciudad_nombre
       FROM portal.empleados e
       LEFT JOIN portal.ciudades c ON e.ciudad_id = c.id
       WHERE e.id = $1`,
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Empleado no encontrado' });
    }

    return res.json(result.rows[0]);
  } catch (err) {
    console.error('Error en obtenerEmpleado:', err);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// 5.3 Crear empleado
const crearEmpleado = async (req, res) => {
  const { nombre, email, password, rol = 'empleado', ciudad_id } = req.body;

  if (!nombre || !email || !password) {
    return res.status(400).json({ error: 'Nombre, email y password son requeridos' });
  }

  const emailRegex = /^[A-Za-z0-9._%+-]+@gobierno\.gob\.ar$/;
  if (!emailRegex.test(email)) {
    return res.status(422).json({ error: 'El email debe ser @gobierno.gob.ar' });
  }

  try {
    const passwordHash = await bcrypt.hash(password, 12);

    const result = await pool.query(
      `INSERT INTO portal.empleados (nombre, email, password_hash, rol, ciudad_id)
       VALUES ($1, $2, $3, $4, $5) RETURNING id, nombre, email, rol, estado, ciudad_id`,
      [nombre, email, passwordHash, rol, ciudad_id || null]
    );

    return res.status(201).json(result.rows[0]);
  } catch (err) {
    if (err.code === '23505') {
      return res.status(409).json({ error: 'Ya existe un empleado con ese email' });
    }
    console.error('Error en crearEmpleado:', err);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// 5.4 Actualizar empleado
const actualizarEmpleado = async (req, res) => {
  const { id } = req.params;
  const { nombre, rol, ciudad_id } = req.body;

  try {
    const fields = [];
    const params = [];
    let i = 1;

    if (nombre) { fields.push(`nombre = $${i++}`); params.push(nombre); }
    if (rol) { fields.push(`rol = $${i++}`); params.push(rol); }
    if (ciudad_id !== undefined) { fields.push(`ciudad_id = $${i++}`); params.push(ciudad_id || null); }

    if (fields.length === 0) {
      return res.status(400).json({ error: 'No hay campos para actualizar' });
    }

    params.push(id);
    const result = await pool.query(
      `UPDATE portal.empleados SET ${fields.join(', ')} WHERE id = $${i} RETURNING id, nombre, email, rol, estado, ciudad_id`,
      params
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Empleado no encontrado' });
    }

    return res.json(result.rows[0]);
  } catch (err) {
    console.error('Error en actualizarEmpleado:', err);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// 5.6 Cambiar estado empleado
const cambiarEstadoEmpleado = async (req, res) => {
  const { id } = req.params;
  const { estado } = req.body;

  if (!['activo', 'inactivo'].includes(estado)) {
    return res.status(422).json({ error: 'Estado debe ser activo o inactivo' });
  }

  try {
    const result = await pool.query(
      `UPDATE portal.empleados SET estado = $1 WHERE id = $2 RETURNING id, nombre, email, estado`,
      [estado, id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Empleado no encontrado' });
    }

    return res.json(result.rows[0]);
  } catch (err) {
    console.error('Error en cambiarEstadoEmpleado:', err);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// 5.7 Cambiar password empleado
const cambiarPasswordEmpleado = async (req, res) => {
  const { id } = req.params;
  const { password } = req.body;

  if (!password || password.length < 8) {
    return res.status(422).json({ error: 'La contraseña debe tener al menos 8 caracteres' });
  }

  try {
    const hash = await bcrypt.hash(password, 12);
    const result = await pool.query(
      `UPDATE portal.empleados SET password_hash = $1 WHERE id = $2 RETURNING id, nombre, email`,
      [hash, id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Empleado no encontrado' });
    }

    return res.json({ success: true, mensaje: 'Contraseña actualizada correctamente' });
  } catch (err) {
    console.error('Error en cambiarPasswordEmpleado:', err);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// 5.7b Cambio de password propio del empleado
const cambiarPasswordPropio = async (req, res) => {
  const { password_actual, password_nuevo } = req.body;
  const empleadoId = req.user.id;

  if (!password_actual || !password_nuevo) {
    return res.status(400).json({ error: 'password_actual y password_nuevo son requeridos' });
  }

  if (password_nuevo.length < 8) {
    return res.status(422).json({ error: 'La nueva contrasena debe tener al menos 8 caracteres' });
  }

  try {
    const result = await pool.query(
      `SELECT password_hash FROM portal.empleados WHERE id = $1`, [empleadoId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Empleado no encontrado' });
    }

    const valida = await bcrypt.compare(password_actual, result.rows[0].password_hash);
    if (!valida) {
      return res.status(401).json({ error: 'La contrasena actual es incorrecta' });
    }

    const nuevoHash = await bcrypt.hash(password_nuevo, 12);
    await pool.query(
      `UPDATE portal.empleados SET password_hash = $1 WHERE id = $2`,
      [nuevoHash, empleadoId]
    );

    return res.json({ success: true, mensaje: 'Contrasena actualizada correctamente' });
  } catch (err) {
    console.error('Error en cambiarPasswordPropio:', err);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// 6.1 Dashboard KPIs
const getDashboard = async (req, res) => {
  try {
    const kpis = await pool.query(`SELECT * FROM portal.v_kpis_dashboard`);

    const porCiudad = await pool.query(
      `SELECT c.nombre AS ciudad, COUNT(s.id) AS total,
              COUNT(*) FILTER (WHERE s.estado = 'certificado_emitido') AS emitidos
       FROM portal.solicitudes s
       JOIN portal.ciudades c ON s.ciudad_id = c.id
       GROUP BY c.nombre ORDER BY total DESC`
    );

    const porEmpleado = await pool.query(
      `SELECT e.nombre, e.email,
              COUNT(s.id) AS asignadas,
              COUNT(*) FILTER (WHERE s.estado = 'certificado_emitido') AS emitidas
       FROM portal.empleados e
       LEFT JOIN portal.solicitudes s ON s.empleado_asignado_id = e.id
       WHERE e.estado = 'activo'
       GROUP BY e.id ORDER BY asignadas DESC`
    );

    return res.json({
      kpis: kpis.rows[0],
      por_ciudad: porCiudad.rows,
      por_empleado: porEmpleado.rows,
    });
  } catch (err) {
    console.error('Error en getDashboard:', err);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// 6.3 Reporte por empleado
const getReporteEmpleado = async (req, res) => {
  const { id } = req.params;
  const { fecha_desde, fecha_hasta } = req.query;

  try {
    const empleado = await pool.query(
      `SELECT id, nombre, email, rol, estado FROM portal.empleados WHERE id = $1`, [id]
    );

    if (empleado.rows.length === 0) {
      return res.status(404).json({ error: 'Empleado no encontrado' });
    }

    let conditions = [`s.empleado_asignado_id = $1`];
    let params = [id];
    let i = 2;

    if (fecha_desde) { conditions.push(`s.fecha_solicitud >= $${i++}`); params.push(fecha_desde); }
    if (fecha_hasta) { conditions.push(`s.fecha_solicitud <= $${i++}`); params.push(fecha_hasta); }

    const where = `WHERE ${conditions.join(' AND ')}`;

    const stats = await pool.query(
      `SELECT 
        COUNT(*) AS total_asignadas,
        COUNT(*) FILTER (WHERE s.estado = 'certificado_emitido') AS emitidas,
        COUNT(*) FILTER (WHERE s.estado = 'rechazada') AS rechazadas,
        COUNT(*) FILTER (WHERE s.estado = 'en_revision') AS en_revision,
        COUNT(*) FILTER (WHERE s.estado = 'aprobada') AS aprobadas,
        ROUND(AVG(EXTRACT(EPOCH FROM (s.fecha_emision - s.fecha_pago))/3600)::numeric, 2) AS promedio_horas_resolucion
       FROM portal.solicitudes s
       ${where}`,
      params
    );

    const porCiudad = await pool.query(
      `SELECT c.nombre AS ciudad, COUNT(*) AS total
       FROM portal.solicitudes s
       JOIN portal.ciudades c ON s.ciudad_id = c.id
       ${where}
       GROUP BY c.nombre ORDER BY total DESC`,
      params
    );

    return res.json({
      empleado: empleado.rows[0],
      estadisticas: stats.rows[0],
      por_ciudad: porCiudad.rows,
    });
  } catch (err) {
    console.error('Error en getReporteEmpleado:', err);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// 6.4 Resumen de solicitudes
const getResumenSolicitudes = async (req, res) => {
  const { fecha_desde, fecha_hasta, ciudad_id } = req.query;

  try {
    let conditions = [];
    let params = [];
    let i = 1;

    if (fecha_desde) { conditions.push(`fecha_solicitud >= $${i++}`); params.push(fecha_desde); }
    if (fecha_hasta) { conditions.push(`fecha_solicitud <= $${i++}`); params.push(fecha_hasta); }
    if (ciudad_id) { conditions.push(`ciudad_id = $${i++}`); params.push(ciudad_id); }

    const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';

    const result = await pool.query(
      `SELECT 
        estado,
        COUNT(*) AS total,
        ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS porcentaje
       FROM portal.solicitudes
       ${where}
       GROUP BY estado
       ORDER BY total DESC`,
      params
    );

    const ingresos = await pool.query(
      `SELECT 
        COALESCE(SUM(t.monto), 0) AS total_ingresos,
        COUNT(t.id) AS total_transacciones
       FROM portal.transacciones t
       JOIN portal.solicitudes s ON t.solicitud_id = s.id
       WHERE t.estado = 'exitoso'
       ${conditions.length ? 'AND ' + conditions.map(c => c.replace(/\$(\d+)/g, (_, n) => `$${parseInt(n)}`)).join(' AND ') : ''}`,
      params
    );

    return res.json({
      por_estado: result.rows,
      ingresos: ingresos.rows[0],
    });
  } catch (err) {
    console.error('Error en getResumenSolicitudes:', err);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// 6.5 Tiempos promedio
const getTiemposPromedio = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT
        ROUND(AVG(EXTRACT(EPOCH FROM (fecha_pago - fecha_solicitud))/3600)::numeric, 2) AS horas_hasta_pago,
        ROUND(AVG(EXTRACT(EPOCH FROM (fecha_emision - fecha_pago))/3600)::numeric, 2) AS horas_pago_a_emision,
        ROUND(AVG(EXTRACT(EPOCH FROM (fecha_emision - fecha_solicitud))/3600)::numeric, 2) AS horas_total
       FROM portal.solicitudes
       WHERE estado = 'certificado_emitido'
         AND fecha_pago IS NOT NULL
         AND fecha_emision IS NOT NULL`
    );

    return res.json(result.rows[0]);
  } catch (err) {
    console.error('Error en getTiemposPromedio:', err);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// 6.6 Reporte deudores
const getReporteDeudores = async (req, res) => {
  const { ciudad_id, es_deudor, page = 1, limit = 20 } = req.query;
  const offset = (page - 1) * limit;

  try {
    let conditions = [`s.estado = 'certificado_emitido'`];
    let params = [];
    let i = 1;

    if (ciudad_id) { conditions.push(`s.ciudad_id = $${i++}`); params.push(ciudad_id); }
    if (es_deudor !== undefined) { conditions.push(`c.es_deudor = $${i++}`); params.push(es_deudor === 'true'); }

    const where = `WHERE ${conditions.join(' AND ')}`;

    const result = await pool.query(
      `SELECT 
        s.nombre_completo, s.cuit_dni, s.email,
        ci.nombre AS ciudad,
        c.es_deudor, c.monto_deuda, c.tipo_deuda,
        c.numero_certificado, c.fecha_emision, c.fecha_vencimiento
       FROM portal.solicitudes s
       JOIN portal.certificados c ON s.id = c.solicitud_id
       JOIN portal.ciudades ci ON s.ciudad_id = ci.id
       ${where}
       ORDER BY c.fecha_emision DESC
       LIMIT $${i++} OFFSET $${i++}`,
      [...params, limit, offset]
    );

    const total = await pool.query(
      `SELECT COUNT(*) FROM portal.solicitudes s
       JOIN portal.certificados c ON s.id = c.solicitud_id
       ${where}`,
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
    console.error('Error en getReporteDeudores:', err);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// 6b.1 Listar todas las solicitudes (Admin)
const listarSolicitudesAdmin = async (req, res) => {
  const { estado, ciudad_id, empleado_id, buscar, fecha_desde, fecha_hasta, page = 1, limit = 20 } = req.query;
  const offset = (page - 1) * limit;

  try {
    let conditions = [];
    let params = [];
    let i = 1;

    if (estado) { conditions.push(`s.estado = $${i++}::portal.estado_solicitud_t`); params.push(estado); }
    if (ciudad_id) { conditions.push(`s.ciudad_id = $${i++}`); params.push(ciudad_id); }
    if (empleado_id) { conditions.push(`s.empleado_asignado_id = $${i++}`); params.push(empleado_id); }
    if (buscar) { conditions.push(`(s.cuit_dni ILIKE $${i} OR s.nombre_completo ILIKE $${i++})`); params.push(`%${buscar}%`); }
    if (fecha_desde) { conditions.push(`s.fecha_solicitud >= $${i++}`); params.push(fecha_desde); }
    if (fecha_hasta) { conditions.push(`s.fecha_solicitud <= $${i++}`); params.push(fecha_hasta); }

    const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';

    const result = await pool.query(
      `SELECT 
        s.id, s.numero_solicitud, s.nombre_completo, s.cuit_dni, s.email,
        s.estado, s.prioridad, s.fecha_solicitud, s.fecha_pago, s.fecha_emision,
        s.motivo_rechazo, s.observaciones,
        c.nombre AS ciudad_nombre,
        e.nombre AS empleado_nombre
       FROM portal.solicitudes s
       LEFT JOIN portal.ciudades c ON s.ciudad_id = c.id
       LEFT JOIN portal.empleados e ON s.empleado_asignado_id = e.id
       ${where}
       ORDER BY s.fecha_solicitud DESC
       LIMIT $${i++} OFFSET $${i++}`,
      [...params, limit, offset]
    );

    const total = await pool.query(
      `SELECT COUNT(*) FROM portal.solicitudes s ${where}`, params
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
    console.error('Error en listarSolicitudesAdmin:', err);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// 6b.2 Obtener solicitud por ID (Admin)
const obtenerSolicitudAdmin = async (req, res) => {
  const { id } = req.params;
  try {
    const result = await pool.query(
      `SELECT s.*,
        c.nombre AS ciudad_nombre,
        e.nombre AS empleado_nombre,
        cert.numero_certificado, cert.fecha_vencimiento, cert.es_deudor,
        t.monto, t.estado AS estado_pago, t.referencia_pluspagos
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

    return res.json(result.rows[0]);
  } catch (err) {
    console.error('Error en obtenerSolicitudAdmin:', err);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// 6b.3 Actualizar solicitud (Admin)
const actualizarSolicitudAdmin = async (req, res) => {
  const { id } = req.params;
  const { estado, prioridad, observaciones, motivo_rechazo, empleado_asignado_id } = req.body;

  try {
    const fields = [];
    const params = [];
    let i = 1;

    if (estado) { fields.push(`estado = $${i++}::portal.estado_solicitud_t`); params.push(estado); }
    if (prioridad) { fields.push(`prioridad = $${i++}::portal.prioridad_t`); params.push(prioridad); }
    if (observaciones !== undefined) { fields.push(`observaciones = $${i++}`); params.push(observaciones); }
    if (motivo_rechazo !== undefined) { fields.push(`motivo_rechazo = $${i++}`); params.push(motivo_rechazo); }
    if (empleado_asignado_id !== undefined) { fields.push(`empleado_asignado_id = $${i++}`); params.push(empleado_asignado_id || null); }

    if (fields.length === 0) {
      return res.status(400).json({ error: 'No hay campos para actualizar' });
    }

    params.push(id);
    const result = await pool.query(
      `UPDATE portal.solicitudes SET ${fields.join(', ')} WHERE id = $${i} RETURNING *`,
      params
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Solicitud no encontrada' });
    }

    return res.json(result.rows[0]);
  } catch (err) {
    console.error('Error en actualizarSolicitudAdmin:', err);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// 6b.4 Eliminar solicitud (Admin)
const eliminarSolicitudAdmin = async (req, res) => {
  const { id } = req.params;

  try {
    const solicitud = await pool.query(
      `SELECT estado FROM portal.solicitudes WHERE id = $1`, [id]
    );

    if (solicitud.rows.length === 0) {
      return res.status(404).json({ error: 'Solicitud no encontrada' });
    }

    const estadosTerminales = ['certificado_emitido', 'rechazada', 'cancelada'];
    if (!estadosTerminales.includes(solicitud.rows[0].estado)) {
      return res.status(422).json({ error: 'Solo se pueden eliminar solicitudes en estado terminal (certificado_emitido, rechazada, cancelada)' });
    }

    await pool.query(`DELETE FROM portal.solicitudes WHERE id = $1`, [id]);

    return res.json({ success: true, mensaje: 'Solicitud eliminada correctamente' });
  } catch (err) {
    console.error('Error en eliminarSolicitudAdmin:', err);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// 7.1 Listar configuración
const listarConfiguracion = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT id, clave, valor, tipo, descripcion, updated_at FROM portal.configuracion ORDER BY clave`
    );
    return res.json({ data: result.rows });
  } catch (err) {
    console.error('Error en listarConfiguracion:', err);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// 7.2 Actualizar configuración
const actualizarConfiguracion = async (req, res) => {
  const { clave } = req.params;
  const { valor } = req.body;
  const empleado = req.user;

  if (!valor) {
    return res.status(400).json({ error: 'El valor es requerido' });
  }

  try {
    const result = await pool.query(
      `UPDATE portal.configuracion SET valor = $1, updated_by = $2 WHERE clave = $3 RETURNING *`,
      [valor, empleado.id, clave]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Configuración no encontrada' });
    }

    return res.json(result.rows[0]);
  } catch (err) {
    console.error('Error en actualizarConfiguracion:', err);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// 13.1 Listar auditoría
const listarAuditoria = async (req, res) => {
  const { tabla, accion, usuario_id, fecha_desde, fecha_hasta, page = 1, limit = 20 } = req.query;
  const offset = (page - 1) * limit;

  try {
    let conditions = [];
    let params = [];
    let i = 1;

    if (tabla) { conditions.push(`a.tabla_afectada = $${i++}`); params.push(tabla); }
    if (accion) { conditions.push(`a.accion = $${i++}::portal.accion_auditoria_t`); params.push(accion); }
    if (usuario_id) { conditions.push(`a.usuario_id = $${i++}`); params.push(usuario_id); }
    if (fecha_desde) { conditions.push(`a.created_at >= $${i++}`); params.push(fecha_desde); }
    if (fecha_hasta) { conditions.push(`a.created_at <= $${i++}`); params.push(fecha_hasta); }

    const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';

    const result = await pool.query(
      `SELECT 
        a.id, a.tabla_afectada, a.registro_id, a.accion,
        a.usuario_id, a.usuario_email, a.usuario_rol,
        a.ip_address, a.session_id, a.created_at,
        e.nombre AS usuario_nombre
       FROM portal.auditoria a
       LEFT JOIN portal.empleados e ON a.usuario_id = e.id
       ${where}
       ORDER BY a.created_at DESC
       LIMIT $${i++} OFFSET $${i++}`,
      [...params, limit, offset]
    );

    const total = await pool.query(
      `SELECT COUNT(*) FROM portal.auditoria a ${where}`, params
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
    console.error('Error en listarAuditoria:', err);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// 13.2 Obtener registro de auditoría por ID
const obtenerAuditoria = async (req, res) => {
  const { id } = req.params;
  try {
    const result = await pool.query(
      `SELECT a.*, e.nombre AS usuario_nombre
       FROM portal.auditoria a
       LEFT JOIN portal.empleados e ON a.usuario_id = e.id
       WHERE a.id = $1`,
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Registro de auditoría no encontrado' });
    }

    return res.json(result.rows[0]);
  } catch (err) {
    console.error('Error en obtenerAuditoria:', err);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// 14.1 Listar transacciones
const listarTransacciones = async (req, res) => {
  const { estado, solicitud_id, fecha_desde, fecha_hasta, page = 1, limit = 20 } = req.query;
  const offset = (page - 1) * limit;

  try {
    let conditions = [];
    let params = [];
    let i = 1;

    if (estado) { conditions.push(`t.estado = $${i++}::portal.estado_transaccion_t`); params.push(estado); }
    if (solicitud_id) { conditions.push(`t.solicitud_id = $${i++}`); params.push(solicitud_id); }
    if (fecha_desde) { conditions.push(`t.fecha_transaccion >= $${i++}`); params.push(fecha_desde); }
    if (fecha_hasta) { conditions.push(`t.fecha_transaccion <= $${i++}`); params.push(fecha_hasta); }

    const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';

    const result = await pool.query(
      `SELECT 
        t.id, t.solicitud_id, t.monto, t.estado, t.metodo_pago,
        t.referencia_pluspagos, t.codigo_autorizacion, t.mensaje_error,
        t.fecha_transaccion, t.fecha_confirmacion,
        s.numero_solicitud, s.nombre_completo, s.email
       FROM portal.transacciones t
       LEFT JOIN portal.solicitudes s ON t.solicitud_id = s.id
       ${where}
       ORDER BY t.fecha_transaccion DESC
       LIMIT $${i++} OFFSET $${i++}`,
      [...params, limit, offset]
    );

    const total = await pool.query(
      `SELECT COUNT(*) FROM portal.transacciones t ${where}`, params
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
    console.error('Error en listarTransacciones:', err);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// 14.2 Obtener transacción por ID
const obtenerTransaccion = async (req, res) => {
  const { id } = req.params;
  try {
    const result = await pool.query(
      `SELECT t.*, s.numero_solicitud, s.nombre_completo, s.email
       FROM portal.transacciones t
       LEFT JOIN portal.solicitudes s ON t.solicitud_id = s.id
       WHERE t.id = $1`,
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Transacción no encontrada' });
    }

    return res.json(result.rows[0]);
  } catch (err) {
    console.error('Error en obtenerTransaccion:', err);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// 15.1 Listar OTP sessions
const listarOtpSessions = async (req, res) => {
  const { email, usado, page = 1, limit = 20 } = req.query;
  const offset = (page - 1) * limit;

  try {
    let conditions = [];
    let params = [];
    let i = 1;

    if (email) { conditions.push(`email ILIKE $${i++}`); params.push(`%${email}%`); }
    if (usado !== undefined) { conditions.push(`usado = $${i++}`); params.push(usado === 'true'); }

    const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';

    const result = await pool.query(
      `SELECT id, email, cuit_dni, intentos, expira_at, usado, created_at
       FROM portal.otp_sessions
       ${where}
       ORDER BY created_at DESC
       LIMIT $${i++} OFFSET $${i++}`,
      [...params, limit, offset]
    );

    const total = await pool.query(
      `SELECT COUNT(*) FROM portal.otp_sessions ${where}`, params
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
    console.error('Error en listarOtpSessions:', err);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// 15.2 Eliminar OTP session por ID
const eliminarOtpSession = async (req, res) => {
  const { id } = req.params;
  try {
    const result = await pool.query(
      `DELETE FROM portal.otp_sessions WHERE id = $1 RETURNING id, email`,
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Sesión OTP no encontrada' });
    }

    return res.json({
      success: true,
      mensaje: 'Sesión OTP eliminada',
      id: result.rows[0].id,
      email: result.rows[0].email,
    });
  } catch (err) {
    console.error('Error en eliminarOtpSession:', err);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// 15.3 Invalidar todas las sesiones OTP de un usuario
const invalidarOtpSesionesUsuario = async (req, res) => {
  const { email, cuit_dni, motivo } = req.body;
  const admin = req.user;

  if (!email || !cuit_dni) {
    return res.status(400).json({ error: 'email y cuit_dni son requeridos' });
  }

  try {
    const result = await pool.query(
      `UPDATE portal.otp_sessions 
       SET expira_at = NOW()
       WHERE email = $1 AND cuit_dni = $2 AND usado = FALSE AND expira_at > NOW()
       RETURNING id`,
      [email, cuit_dni]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'No se encontraron sesiones activas para ese usuario' });
    }

    // Registrar en auditoría
    await pool.query(
      `INSERT INTO portal.auditoria (tabla_afectada, registro_id, accion, usuario_id, usuario_email, usuario_rol)
       VALUES ('otp_sessions', $1, 'actualizar', $2, $3, $4)`,
      [result.rows[0].id, admin.id, admin.email, admin.rol]
    );

    return res.json({
      success: true,
      mensaje: 'Todas las sesiones OTP invalidadas',
      sesiones_invalidadas: result.rows.length,
      email,
    });
  } catch (err) {
    console.error('Error en invalidarOtpSesionesUsuario:', err);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
};

module.exports = {
  listarEmpleados,
  obtenerEmpleado,
  crearEmpleado,
  actualizarEmpleado,
  cambiarEstadoEmpleado,
  cambiarPasswordEmpleado,
  getDashboard,
  listarConfiguracion,
  actualizarConfiguracion,
  cambiarPasswordPropio, 
  listarAuditoria,
  obtenerAuditoria,
  listarTransacciones,
  obtenerTransaccion,
  listarOtpSessions,
  eliminarOtpSession,
  invalidarOtpSesionesUsuario,
  getReporteEmpleado,
  getResumenSolicitudes,
  getTiemposPromedio,
  getReporteDeudores,
  listarSolicitudesAdmin,
  obtenerSolicitudAdmin,
  actualizarSolicitudAdmin,
  eliminarSolicitudAdmin,
};