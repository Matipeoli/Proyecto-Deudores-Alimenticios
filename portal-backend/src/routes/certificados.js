const express = require('express');
const router = express.Router();
const { verificarToken, requireRol } = require('../middlewares/auth');
const upload = require('../config/upload');
const { subirCertificado, descargarCertificado } = require('../controllers/certificadosController');


/**
 * @swagger
 * /api/empleado/solicitudes/{id}/certificado:
 *   post:
 *     summary: Subir certificado PDF (empleado/admin)
 *     tags: [Certificados]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         example: 1
 *     requestBody:
 *       required: true
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             required: [pdf, es_deudor]
 *             properties:
 *               pdf:
 *                 type: string
 *                 format: binary
 *               es_deudor:
 *                 type: boolean
 *                 example: false
 *               monto_deuda:
 *                 type: number
 *                 example: 15000
 *     responses:
 *       201:
 *         description: Certificado subido correctamente
 *       400:
 *         description: Archivo PDF requerido
 *       422:
 *         description: La solicitud debe estar en estado aprobada
 *       404:
 *         description: Solicitud no encontrada
 */
router.post(
  '/empleado/solicitudes/:id/certificado',
  verificarToken,
  requireRol('empleado', 'administrador'),
  upload.single('pdf'),
  subirCertificado
);


/**
 * @swagger
 * /api/certificados/{id}/descargar:
 *   get:
 *     summary: Descargar certificado PDF
 *     tags: [Certificados]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         example: 1
 *     responses:
 *       200:
 *         description: Archivo PDF del certificado
 *         content:
 *           application/pdf:
 *             schema:
 *               type: string
 *               format: binary
 *       404:
 *         description: Certificado o archivo no encontrado
 */
router.get(
  '/certificados/:id/descargar',
  verificarToken,
  descargarCertificado
);


module.exports = router;



