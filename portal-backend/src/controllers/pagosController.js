const pool = require('../config/db');

const webhook = async (req, res) => {
  console.log('📩 Webhook recibido:', req.body);

  // La pasarela manda dos webhooks con formato diferente, manejamos ambos
  const numeroSolicitud = req.body.TransaccionComercioId || req.body.comercioId;
  const estadoId = req.body.EstadoId || (req.body.estado === 'approved' ? '3' : '4');
  const monto = req.body.Monto || req.body.monto;
  const plataformaId = req.body.TransaccionPlataformaId || req.body.transaccionId;

  if (!numeroSolicitud) {
    console.log('⚠️ Webhook sin numero de solicitud, ignorando');
    return res.status(200).json({ success: true });
  }

  try {
    const solicitud = await pool.query(
      `SELECT * FROM portal.solicitudes WHERE numero_solicitud = $1`,
      [numeroSolicitud]
    );

    if (solicitud.rows.length === 0) {
      console.log('⚠️ Solicitud no encontrada:', numeroSolicitud);
      return res.status(200).json({ success: true });
    }

    const s = solicitud.rows[0];
    const exitoso = estadoId === '3';
    const nuevoEstado = exitoso ? 'pagada' : 'pago_fallido';

    // Registrar transacción
    await pool.query(
      `INSERT INTO portal.transacciones 
        (solicitud_id, monto, estado, referencia_pluspagos, codigo_autorizacion, fecha_confirmacion, mensaje_error)
       VALUES ($1, $2, $3::portal.estado_transaccion_t, $4, $5, NOW(), $6)`,
      [
        s.id,
        parseFloat(monto),
        exitoso ? 'exitoso' : 'fallido',
        plataformaId?.toString(),
        exitoso ? plataformaId?.toString() : null,
        exitoso ? null : 'Pago rechazado por la pasarela',
      ]
    );

    // Actualizar estado solicitud
    await pool.query(
      `UPDATE portal.solicitudes 
       SET estado = $1::portal.estado_solicitud_t, 
           fecha_pago = CASE WHEN $1 = 'pagada' THEN NOW() ELSE fecha_pago END
       WHERE id = $2`,
      [nuevoEstado, s.id]
    );

    console.log(`✅ Solicitud ${numeroSolicitud} → ${nuevoEstado}`);
    return res.status(200).json({ success: true });
  } catch (err) {
    console.error('Error en webhook:', err);
    return res.status(500).json({ error: 'Error interno' });
  }
};

const pagoSuccess = async (req, res) => {
return res.redirect(`${process.env.FRONTEND_URL}/ciudadano`);};

const pagoError = async (req, res) => {
  const { solicitud_id } = req.query;
  return res.json({
    success: false,
    mensaje: 'El pago no pudo procesarse. Podés intentarlo nuevamente.',
    solicitud_id,
  });
};

module.exports = { webhook, pagoSuccess, pagoError };