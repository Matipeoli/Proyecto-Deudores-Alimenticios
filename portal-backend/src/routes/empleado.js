const express = require('express');
const router = express.Router();
const { verificarToken, requireRol } = require('../middlewares/auth');
const {
  listarSolicitudesKanban,
  obtenerSolicitudDetalle,
  aprobarSolicitud,
  rechazarSolicitud,
  reasignarSolicitud,
  cambiarPrioridad,
  tomarRevision,
} = require('../controllers/empleadoController');


/**
 * @swagger
 * /api/empleado/solicitudes:
 *   get:
 *     summary: Listar solicitudes kanban (empleado/admin)
 *     tags: [Empleado]
 *     parameters:
 *       - in: query
 *         name: estado
 *         schema:
 *           type: string
 *           enum: [pagada, en_revision, aprobada]
 *         example: "pagada"
 *       - in: query
 *         name: prioridad
 *         schema:
 *           type: string
 *           enum: [normal, urgente]
 *       - in: query
 *         name: buscar
 *         schema:
 *           type: string
 *         example: "Juan"
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *         example: 1
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *         example: 20
 *     responses:
 *       200:
 *         description: Lista de solicitudes con conteos por estado
 */
router.get('/solicitudes', verificarToken, requireRol('empleado', 'administrador'), listarSolicitudesKanban);


/**
 * @swagger
 * /api/empleado/solicitudes/{id}:
 *   get:
 *     summary: Obtener detalle de solicitud con historial (empleado/admin)
 *     tags: [Empleado]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         example: 1
 *     responses:
 *       200:
 *         description: Detalle de la solicitud con auditoría
 *       404:
 *         description: Solicitud no encontrada
 */
router.get('/solicitudes/:id', verificarToken, requireRol('empleado', 'administrador'), obtenerSolicitudDetalle);


/**
 * @swagger
 * /api/empleado/solicitudes/{id}/tomar-revision:
 *   patch:
 *     summary: Tomar solicitud en revisión (empleado/admin)
 *     tags: [Empleado]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         example: 1
 *     responses:
 *       200:
 *         description: Solicitud tomada en revisión
 *       422:
 *         description: La solicitud debe estar en estado pagada
 *       404:
 *         description: Solicitud no encontrada
 */
router.patch('/solicitudes/:id/tomar-revision', verificarToken, requireRol('empleado', 'administrador'), tomarRevision);


/**
 * @swagger
 * /api/empleado/solicitudes/{id}/aprobar:
 *   patch:
 *     summary: Aprobar solicitud (empleado/admin)
 *     tags: [Empleado]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         example: 1
 *     requestBody:
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               observaciones:
 *                 type: string
 *                 example: "Todo en orden"
 *     responses:
 *       200:
 *         description: Solicitud aprobada
 *       422:
 *         description: La solicitud debe estar en estado en_revision
 *       404:
 *         description: Solicitud no encontrada
 */
router.patch('/solicitudes/:id/aprobar', verificarToken, requireRol('empleado', 'administrador'), aprobarSolicitud);


/**
 * @swagger
 * /api/empleado/solicitudes/{id}/rechazar:
 *   patch:
 *     summary: Rechazar solicitud (empleado/admin)
 *     tags: [Empleado]
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
 *         application/json:
 *           schema:
 *             type: object
 *             required: [motivo_rechazo]
 *             properties:
 *               motivo_rechazo:
 *                 type: string
 *                 example: "Documentación incompleta"
 *     responses:
 *       200:
 *         description: Solicitud rechazada
 *       422:
 *         description: Motivo debe tener al menos 10 caracteres
 *       404:
 *         description: Solicitud no encontrada
 */
router.patch('/solicitudes/:id/rechazar', verificarToken, requireRol('empleado', 'administrador'), rechazarSolicitud);


/**
 * @swagger
 * /api/empleado/solicitudes/{id}/reasignar:
 *   patch:
 *     summary: Reasignar solicitud a otro empleado (empleado/admin)
 *     tags: [Empleado]
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
 *         application/json:
 *           schema:
 *             type: object
 *             required: [empleado_id]
 *             properties:
 *               empleado_id:
 *                 type: integer
 *                 example: 3
 *     responses:
 *       200:
 *         description: Solicitud reasignada
 *       404:
 *         description: Solicitud o empleado no encontrado
 *       422:
 *         description: Estado inválido para reasignar
 */
router.patch('/solicitudes/:id/reasignar', verificarToken, requireRol('empleado', 'administrador'), reasignarSolicitud);


/**
 * @swagger
 * /api/empleado/solicitudes/{id}/prioridad:
 *   patch:
 *     summary: Cambiar prioridad de solicitud (empleado/admin)
 *     tags: [Empleado]
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
 *         application/json:
 *           schema:
 *             type: object
 *             required: [prioridad]
 *             properties:
 *               prioridad:
 *                 type: string
 *                 enum: [normal, urgente]
 *                 example: "urgente"
 *     responses:
 *       200:
 *         description: Prioridad actualizada
 *       422:
 *         description: Prioridad debe ser normal o urgente
 */
router.patch('/solicitudes/:id/prioridad', verificarToken, requireRol('empleado', 'administrador'), cambiarPrioridad);


module.exports = router;



