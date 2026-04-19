const pool = require('../config/db');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

// 4.1 Subir certificado PDF (empleado)
const subirCertificado = async (req, res) => {
  const { id } = req.params;
  const { es_deudor, monto_deuda, tipo_deuda, estado_deuda, numero_expediente } = req.body;
  const empleado = req.user;

  if (!req.file) {
    return res.status(400).json({ error: 'El archivo PDF es requerido' });
  }

  try {
    // Verificar que la solicitud existe y está en estado aprobada
    const solicitud = await pool.query(
      `SELECT * FROM portal.solicitudes WHERE id = $1`, [id]
    );

    if (solicitud.rows.length === 0) {
      fs.unlinkSync(req.file.path);
      return res.status(404).json({ error: 'Solicitud no encontrada' });
    }

    if (solicitud.rows[0].estado !== 'aprobada') {
      fs.unlinkSync(req.file.path);
      return res.status(422).json({ error: 'La solicitud debe estar en estado aprobada' });
    }

    // Calcular hash SHA-256 del archivo
    const fileBuffer = fs.readFileSync(req.file.path);
    const hash = crypto.createHash('sha256').update(fileBuffer).digest('hex');

    const pdfPath = `certificados/${req.file.filename}`;
    const esDeudorBool = es_deudor === 'true' || es_deudor === true;

    // Insertar certificado
    await pool.query('SET LOCAL app.current_user_id = $1', [String(empleado.id)]);
    await pool.query('SET LOCAL app.current_user_email = $1', [empleado.email]);
    await pool.query('SET LOCAL app.current_user_rol = $1', [empleado.rol]);

    const cert = await pool.query(
      `INSERT INTO portal.certificados 
        (solicitud_id, empleado_emisor_id, numero_certificado, archivo_pdf_path, 
         archivo_pdf_hash, es_deudor, monto_deuda, tipo_deuda, estado_deuda, 
         numero_expediente, tamano_bytes)
       VALUES ($1, $2, '', $3, $4, $5, $6, $7, $8, $9, $10)
       RETURNING *`,
      [
        id, empleado.id, pdfPath, hash,
        esDeudorBool,
        monto_deuda || null,
        tipo_deuda || null,
        estado_deuda || null,
        numero_expediente || null,
        req.file.size,
      ]
    );

    // Cambiar estado de solicitud a certificado_emitido
    await pool.query(
      `UPDATE portal.solicitudes SET estado = 'certificado_emitido' WHERE id = $1`, [id]
    );

    return res.status(201).json({
      success: true,
      mensaje: 'Certificado subido correctamente',
      certificado: cert.rows[0],
    });
  } catch (err) {
    if (req.file && fs.existsSync(req.file.path)) {
      fs.unlinkSync(req.file.path);
    }
    console.error('Error en subirCertificado:', err);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
};

// 4.2 Descargar certificado (ciudadano)
const descargarCertificado = async (req, res) => {
  const { id } = req.params;
  const user = req.user;

  try {
    let query;
    let params;

    if (user.rol === 'ciudadano') {
      query = `
        SELECT cert.*, s.email 
        FROM portal.certificados cert
        JOIN portal.solicitudes s ON cert.solicitud_id = s.id
        WHERE cert.id = $1 AND s.email = $2`;
      params = [id, user.email];
    } else {
      query = `SELECT * FROM portal.certificados WHERE id = $1`;
      params = [id];
    }

    const result = await pool.query(query, params);

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Certificado no encontrado' });
    }

    const cert = result.rows[0];
    const filePath = `uploads/${cert.archivo_pdf_path}`;

    if (!fs.existsSync(filePath)) {
      return res.status(404).json({ error: 'Archivo PDF no encontrado' });
    }

    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename="${cert.numero_certificado}.pdf"`);
    return res.sendFile(path.resolve(filePath));
  } catch (err) {
    console.error('Error en descargarCertificado:', err);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
};



module.exports = { subirCertificado, descargarCertificado };