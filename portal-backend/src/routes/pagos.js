const express = require('express');
const router = express.Router();
const { webhook, pagoSuccess, pagoError } = require('../controllers/pagosController');


/**
 * @swagger
 * /api/pagos/webhook:
 *   post:
 *     summary: Webhook de PlusPagos para confirmar pago
 *     tags: [Pagos]
 *     security: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               solicitud_id:
 *                 type: integer
 *                 example: 1
 *               estado:
 *                 type: string
 *                 example: "aprobada"
 *               monto:
 *                 type: number
 *                 example: 5000
 *               referencia:
 *                 type: string
 *                 example: "PP-123456"
 *               codigo_autorizacion:
 *                 type: string
 *                 example: "AUTH-789"
 *     responses:
 *       200:
 *         description: Webhook procesado correctamente
 *       400:
 *         description: Datos inválidos
 */
router.post('/webhook', webhook);


/**
 * @swagger
 * /api/pagos/success:
 *   get:
 *     summary: Redirección tras pago exitoso
 *     tags: [Pagos]
 *     security: []
 *     parameters:
 *       - in: query
 *         name: solicitud_id
 *         schema:
 *           type: integer
 *         example: 1
 *     responses:
 *       302:
 *         description: Redirige al portal del ciudadano
 */
router.get('/success', pagoSuccess);


/**
 * @swagger
 * /api/pagos/error:
 *   get:
 *     summary: Redirección tras pago fallido
 *     tags: [Pagos]
 *     security: []
 *     responses:
 *       200:
 *         description: Mensaje de error de pago
 */
router.get('/error', pagoError);


module.exports = router;



