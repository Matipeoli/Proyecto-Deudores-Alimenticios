const pool = require('../config/db');

// 16.5 Listar ciudades activas (público)
const listarCiudadesPublico = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT id, nombre FROM portal.ciudades 
       WHERE estado = 'activa' 
       ORDER BY nombre ASC`
    );
    return res.json({ data: result.rows });
  } catch (err) {
    console.error('Error en listarCiudadesPublico:', err);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// 16.1 Listar ciudades (Admin)
const listarCiudades = async (req, res) => {
  const { estado, buscar, page = 1, limit = 50 } = req.query;
  const offset = (page - 1) * limit;

  try {
    let conditions = [];
    let params = [];
    let i = 1;

    if (estado) {
      conditions.push(`c.estado = $${i++}`);
      params.push(estado);
    }
    if (buscar) {
      conditions.push(`c.nombre ILIKE $${i++}`);
      params.push(`%${buscar}%`);
    }

    const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';

    const result = await pool.query(
      `SELECT 
        c.id, c.nombre, c.provincia, c.estado, c.created_at, c.updated_at,
        COUNT(s.id) FILTER (
          WHERE s.estado NOT IN ('certificado_emitido', 'rechazada', 'cancelada')
        ) AS solicitudes_activas
       FROM portal.ciudades c
       LEFT JOIN portal.solicitudes s ON s.ciudad_id = c.id
       ${where}
       GROUP BY c.id
       ORDER BY c.nombre ASC
       LIMIT $${i++} OFFSET $${i++}`,
      [...params, limit, offset]
    );

    const total = await pool.query(
      `SELECT COUNT(*) FROM portal.ciudades c ${where}`,
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
    console.error('Error en listarCiudades:', err);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// 16.2 Obtener ciudad por ID (Admin)
const obtenerCiudad = async (req, res) => {
  const { id } = req.params;
  try {
    const result = await pool.query(
      `SELECT 
        c.id, c.nombre, c.provincia, c.estado, c.created_at, c.updated_at,
        COUNT(s.id) FILTER (
          WHERE s.estado NOT IN ('certificado_emitido', 'rechazada', 'cancelada')
        ) AS solicitudes_activas
       FROM portal.ciudades c
       LEFT JOIN portal.solicitudes s ON s.ciudad_id = c.id
       WHERE c.id = $1
       GROUP BY c.id`,
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Ciudad no encontrada' });
    }

    const empleados = await pool.query(
      `SELECT id, nombre, estado FROM portal.empleados WHERE ciudad_id = $1`,
      [id]
    );

    return res.json({
      ...result.rows[0],
      empleados_asignados: empleados.rows,
    });
  } catch (err) {
    console.error('Error en obtenerCiudad:', err);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// 16.3 Crear ciudad (Admin)
const crearCiudad = async (req, res) => {
  const { nombre, provincia = 'Santa Fe' } = req.body;

  if (!nombre) {
    return res.status(422).json({ error: 'El nombre es requerido' });
  }

  try {
    const result = await pool.query(
      `INSERT INTO portal.ciudades (nombre, provincia) VALUES ($1, $2) RETURNING *`,
      [nombre, provincia]
    );
    return res.status(201).json(result.rows[0]);
  } catch (err) {
    if (err.code === '23505') {
      return res.status(409).json({ error: 'Ya existe una ciudad con ese nombre' });
    }
    console.error('Error en crearCiudad:', err);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// 16.4 Actualizar ciudad (Admin)
const actualizarCiudad = async (req, res) => {
  const { id } = req.params;
  const { nombre, estado } = req.body;

  try {
    // Verificar que existe
    const ciudad = await pool.query(
      `SELECT * FROM portal.ciudades WHERE id = $1`, [id]
    );
    if (ciudad.rows.length === 0) {
      return res.status(404).json({ error: 'Ciudad no encontrada' });
    }

    // Si quieren desactivar, verificar que no tenga solicitudes activas
    if (estado === 'inactiva') {
      const activas = await pool.query(
        `SELECT COUNT(*) FROM portal.solicitudes 
         WHERE ciudad_id = $1 AND estado NOT IN ('certificado_emitido', 'rechazada', 'cancelada')`,
        [id]
      );
      if (parseInt(activas.rows[0].count) > 0) {
        return res.status(422).json({
          error: 'No se puede desactivar: la ciudad tiene solicitudes activas',
          solicitudes_activas: parseInt(activas.rows[0].count),
        });
      }
    }

    const fields = [];
    const params = [];
    let i = 1;

    if (nombre) { fields.push(`nombre = $${i++}`); params.push(nombre); }
    if (estado) { fields.push(`estado = $${i++}`); params.push(estado); }

    params.push(id);
    const result = await pool.query(
      `UPDATE portal.ciudades SET ${fields.join(', ')} WHERE id = $${i} RETURNING *`,
      params
    );

    return res.json(result.rows[0]);
  } catch (err) {
    if (err.code === '23505') {
      return res.status(409).json({ error: 'Ya existe una ciudad con ese nombre' });
    }
    console.error('Error en actualizarCiudad:', err);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
};

module.exports = { listarCiudadesPublico, listarCiudades, obtenerCiudad, crearCiudad, actualizarCiudad };