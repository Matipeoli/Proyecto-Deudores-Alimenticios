const express = require('express');
const router = express.Router();
const { verificarToken, requireRol } = require('../middlewares/auth');
const { crearSolicitud, listarMisSolicitudes, obtenerSolicitud, cancelarSolicitud, iniciarPago } = require('../controllers/solicitudesController');


/**
 * @swagger
 * /api/solicitudes:
 *   post:
 *     summary: Crear nueva solicitud de certificado
 *     tags: [Solicitudes]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [nombre_completo, cuit_dni, email, ciudad_id]
 *             properties:
 *               nombre_completo:
 *                 type: string
 *                 example: "Juan Pérez"
 *               cuit_dni:
 *                 type: string
 *                 example: "20123456789"
 *               email:
 *                 type: string
 *                 example: "juan@email.com"
 *               ciudad_id:
 *                 type: integer
 *                 example: 1
 *     responses:
 *       201:
 *         description: Solicitud creada correctamente
 *       422:
 *         description: Datos inválidos
 */
router.post('/', verificarToken, requireRol('ciudadano'), crearSolicitud);


/**
 * @swagger
 * /api/solicitudes:
 *   get:
 *     summary: Listar mis solicitudes (ciudadano)
 *     tags: [Solicitudes]
 *     parameters:
 *       - in: query
 *         name: estado
 *         schema:
 *           type: string
 *         example: "pagada"
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *         example: 1
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *         example: 10
 *     responses:
 *       200:
 *         description: Lista de solicitudes del ciudadano
 */
router.get('/', verificarToken, requireRol('ciudadano'), listarMisSolicitudes);


/**
 * @swagger
 * /api/solicitudes/{id}:
 *   get:
 *     summary: Obtener detalle de una solicitud (ciudadano)
 *     tags: [Solicitudes]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         example: 1
 *     responses:
 *       200:
 *         description: Detalle de la solicitud
 *       404:
 *         description: Solicitud no encontrada
 */
router.get('/:id', verificarToken, requireRol('ciudadano'), obtenerSolicitud);


/**
 * @swagger
 * /api/solicitudes/{id}/cancelar:
 *   patch:
 *     summary: Cancelar solicitud (ciudadano)
 *     tags: [Solicitudes]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         example: 1
 *     responses:
 *       200:
 *         description: Solicitud cancelada
 *       422:
 *         description: No se puede cancelar en este estado
 *       404:
 *         description: Solicitud no encontrada
 */
router.patch('/:id/cancelar', verificarToken, requireRol('ciudadano'), cancelarSolicitud);


/**
 * @swagger
 * /api/solicitudes/{id}/pagar:
 *   get:
 *     summary: Iniciar pago de solicitud (redirige a pasarela)
 *     tags: [Solicitudes]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         example: 1
 *       - in: query
 *         name: _token
 *         schema:
 *           type: string
 *         description: JWT token (alternativa al header Authorization)
 *     responses:
 *       200:
 *         description: HTML de la pasarela de pago
 *       404:
 *         description: Solicitud no encontrada
 *       422:
 *         description: La solicitud no está en estado pendiente_pago
 */
router.get('/:id/pagar', verificarToken, requireRol('ciudadano'), iniciarPago);


module.exports = router;



