const express = require('express');
const router = express.Router();
const { verificarToken, requireRol } = require('../middlewares/auth');
const {
  listarEmpleados, obtenerEmpleado, crearEmpleado, actualizarEmpleado,
  cambiarEstadoEmpleado, cambiarPasswordEmpleado, cambiarPasswordPropio,
  getDashboard, listarConfiguracion, actualizarConfiguracion,
  listarAuditoria, obtenerAuditoria, listarTransacciones, obtenerTransaccion,
  listarOtpSessions, eliminarOtpSession, invalidarOtpSesionesUsuario,
  getReporteEmpleado, getResumenSolicitudes, getTiemposPromedio,
  getReporteDeudores, listarSolicitudesAdmin, obtenerSolicitudAdmin,
  actualizarSolicitudAdmin, eliminarSolicitudAdmin
} = require('../controllers/adminController');


const auth = [verificarToken, requireRol('administrador')];


/**
 * @swagger
 * /api/admin/empleados:
 *   get:
 *     summary: Listar empleados (admin)
 *     tags: [Admin - Empleados]
 *     responses:
 *       200:
 *         description: Lista de empleados
 */
router.get('/empleados', ...auth, listarEmpleados);


/**
 * @swagger
 * /api/admin/empleados/{id}:
 *   get:
 *     summary: Obtener empleado por ID (admin)
 *     tags: [Admin - Empleados]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         example: 1
 *     responses:
 *       200:
 *         description: Empleado encontrado
 *       404:
 *         description: Empleado no encontrado
 */
router.get('/empleados/:id', ...auth, obtenerEmpleado);


/**
 * @swagger
 * /api/admin/empleados:
 *   post:
 *     summary: Crear empleado (admin)
 *     tags: [Admin - Empleados]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [nombre, email, password, rol]
 *             properties:
 *               nombre:
 *                 type: string
 *                 example: "Carlos López"
 *               email:
 *                 type: string
 *                 example: "carlos@gobierno.gob.ar"
 *               password:
 *                 type: string
 *                 example: "Password123!"
 *               rol:
 *                 type: string
 *                 enum: [empleado, administrador]
 *                 example: "empleado"
 *     responses:
 *       201:
 *         description: Empleado creado correctamente
 *       422:
 *         description: Datos inválidos
 */
router.post('/empleados', ...auth, crearEmpleado);


/**
 * @swagger
 * /api/admin/empleados/{id}:
 *   put:
 *     summary: Actualizar empleado (admin)
 *     tags: [Admin - Empleados]
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
 *               nombre:
 *                 type: string
 *                 example: "Carlos López"
 *               email:
 *                 type: string
 *                 example: "carlos@gobierno.gob.ar"
 *     responses:
 *       200:
 *         description: Empleado actualizado
 *       404:
 *         description: Empleado no encontrado
 */
router.put('/empleados/:id', ...auth, actualizarEmpleado);


/**
 * @swagger
 * /api/admin/empleados/{id}/estado:
 *   patch:
 *     summary: Cambiar estado de empleado activo/inactivo (admin)
 *     tags: [Admin - Empleados]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         example: 1
 *     responses:
 *       200:
 *         description: Estado actualizado
 *       404:
 *         description: Empleado no encontrado
 */
router.patch('/empleados/:id/estado', ...auth, cambiarEstadoEmpleado);


/**
 * @swagger
 * /api/admin/empleados/{id}/password:
 *   patch:
 *     summary: Cambiar contraseña de empleado (admin)
 *     tags: [Admin - Empleados]
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
 *             required: [password_nuevo]
 *             properties:
 *               password_nuevo:
 *                 type: string
 *                 example: "NuevoPass123!"
 *     responses:
 *       200:
 *         description: Contraseña actualizada
 *       404:
 *         description: Empleado no encontrado
 */
router.patch('/empleados/:id/password', ...auth, cambiarPasswordEmpleado);


/**
 * @swagger
 * /api/admin/empleado/perfil/password:
 *   patch:
 *     summary: Cambiar contraseña propia (empleado/admin)
 *     tags: [Admin - Empleados]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [password_actual, password_nuevo]
 *             properties:
 *               password_actual:
 *                 type: string
 *                 example: "Admin2026!"
 *               password_nuevo:
 *                 type: string
 *                 example: "NuevoPass123!"
 *     responses:
 *       200:
 *         description: Contraseña actualizada
 *       401:
 *         description: Contraseña actual incorrecta
 */
router.patch('/empleado/perfil/password', verificarToken, requireRol('empleado', 'administrador'), cambiarPasswordPropio);


/**
 * @swagger
 * /api/admin/reportes/dashboard:
 *   get:
 *     summary: Dashboard con KPIs generales (admin)
 *     tags: [Admin - Reportes]
 *     responses:
 *       200:
 *         description: KPIs del dashboard
 */
router.get('/reportes/dashboard', ...auth, getDashboard);


/**
 * @swagger
 * /api/admin/reportes/empleado/{id}:
 *   get:
 *     summary: Reporte de rendimiento por empleado (admin)
 *     tags: [Admin - Reportes]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         example: 1
 *     responses:
 *       200:
 *         description: Reporte del empleado
 */
router.get('/reportes/empleado/:id', ...auth, getReporteEmpleado);


/**
 * @swagger
 * /api/admin/reportes/solicitudes-resumen:
 *   get:
 *     summary: Resumen de solicitudes por estado y período (admin)
 *     tags: [Admin - Reportes]
 *     parameters:
 *       - in: query
 *         name: fecha_desde
 *         schema:
 *           type: string
 *         example: "2026-01-01"
 *       - in: query
 *         name: fecha_hasta
 *         schema:
 *           type: string
 *         example: "2026-12-31"
 *     responses:
 *       200:
 *         description: Resumen de solicitudes
 */
router.get('/reportes/solicitudes-resumen', ...auth, getResumenSolicitudes);


/**
 * @swagger
 * /api/admin/reportes/tiempos-promedio:
 *   get:
 *     summary: Tiempos promedio de resolución (admin)
 *     tags: [Admin - Reportes]
 *     responses:
 *       200:
 *         description: Tiempos promedio por estado
 */
router.get('/reportes/tiempos-promedio', ...auth, getTiemposPromedio);


/**
 * @swagger
 * /api/admin/reportes/deudores:
 *   get:
 *     summary: Reporte de deudores alimenticios (admin)
 *     tags: [Admin - Reportes]
 *     responses:
 *       200:
 *         description: Lista de certificados de deudores
 */
router.get('/reportes/deudores', ...auth, getReporteDeudores);


/**
 * @swagger
 * /api/admin/configuracion:
 *   get:
 *     summary: Listar parámetros de configuración (admin)
 *     tags: [Admin - Configuración]
 *     responses:
 *       200:
 *         description: Lista de parámetros
 */
router.get('/configuracion', ...auth, listarConfiguracion);


/**
 * @swagger
 * /api/admin/configuracion/{clave}:
 *   put:
 *     summary: Actualizar parámetro de configuración (admin)
 *     tags: [Admin - Configuración]
 *     parameters:
 *       - in: path
 *         name: clave
 *         required: true
 *         schema:
 *           type: string
 *         example: "monto_certificado"
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [valor]
 *             properties:
 *               valor:
 *                 type: string
 *                 example: "5000"
 *     responses:
 *       200:
 *         description: Configuración actualizada
 *       404:
 *         description: Clave no encontrada
 */
router.put('/configuracion/:clave', ...auth, actualizarConfiguracion);


/**
 * @swagger
 * /api/admin/auditoria:
 *   get:
 *     summary: Listar registros de auditoría (admin)
 *     tags: [Admin - Auditoría]
 *     parameters:
 *       - in: query
 *         name: tabla
 *         schema:
 *           type: string
 *         example: "solicitudes"
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *         example: 1
 *     responses:
 *       200:
 *         description: Lista de registros de auditoría
 */
router.get('/auditoria', ...auth, listarAuditoria);


/**
 * @swagger
 * /api/admin/auditoria/{id}:
 *   get:
 *     summary: Obtener registro de auditoría por ID (admin)
 *     tags: [Admin - Auditoría]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         example: 1
 *     responses:
 *       200:
 *         description: Registro de auditoría
 *       404:
 *         description: Registro no encontrado
 */
router.get('/auditoria/:id', ...auth, obtenerAuditoria);


/**
 * @swagger
 * /api/admin/transacciones:
 *   get:
 *     summary: Listar transacciones de pago (admin)
 *     tags: [Admin - Transacciones]
 *     parameters:
 *       - in: query
 *         name: estado
 *         schema:
 *           type: string
 *           enum: [pendiente, aprobada, rechazada]
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *         example: 1
 *     responses:
 *       200:
 *         description: Lista de transacciones
 */
router.get('/transacciones', ...auth, listarTransacciones);


/**
 * @swagger
 * /api/admin/transacciones/{id}:
 *   get:
 *     summary: Obtener transacción por ID (admin)
 *     tags: [Admin - Transacciones]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         example: 1
 *     responses:
 *       200:
 *         description: Transacción encontrada
 *       404:
 *         description: Transacción no encontrada
 */
router.get('/transacciones/:id', ...auth, obtenerTransaccion);


/**
 * @swagger
 * /api/admin/otp-sessions:
 *   get:
 *     summary: Listar sesiones OTP activas (admin)
 *     tags: [Admin - OTP Sessions]
 *     responses:
 *       200:
 *         description: Lista de sesiones OTP
 */
router.get('/otp-sessions', ...auth, listarOtpSessions);


/**
 * @swagger
 * /api/admin/otp-sessions/{id}:
 *   delete:
 *     summary: Eliminar sesión OTP (admin)
 *     tags: [Admin - OTP Sessions]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         example: 1
 *     responses:
 *       200:
 *         description: Sesión eliminada
 *       404:
 *         description: Sesión no encontrada
 */
router.delete('/otp-sessions/:id', ...auth, eliminarOtpSession);


/**
 * @swagger
 * /api/admin/otp-sessions/invalidate-user:
 *   post:
 *     summary: Invalidar todas las sesiones OTP de un usuario (admin)
 *     tags: [Admin - OTP Sessions]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [email]
 *             properties:
 *               email:
 *                 type: string
 *                 example: "ciudadano@email.com"
 *     responses:
 *       200:
 *         description: Sesiones invalidadas
 */
router.post('/otp-sessions/invalidate-user', ...auth, invalidarOtpSesionesUsuario);


/**
 * @swagger
 * /api/admin/solicitudes:
 *   get:
 *     summary: Listar todas las solicitudes (admin)
 *     tags: [Admin - Solicitudes]
 *     parameters:
 *       - in: query
 *         name: estado
 *         schema:
 *           type: string
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *         example: 1
 *     responses:
 *       200:
 *         description: Lista de solicitudes
 */
router.get('/solicitudes', ...auth, listarSolicitudesAdmin);


/**
 * @swagger
 * /api/admin/solicitudes/{id}:
 *   get:
 *     summary: Obtener solicitud por ID (admin)
 *     tags: [Admin - Solicitudes]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         example: 1
 *     responses:
 *       200:
 *         description: Solicitud encontrada
 *       404:
 *         description: Solicitud no encontrada
 */
router.get('/solicitudes/:id', ...auth, obtenerSolicitudAdmin);


/**
 * @swagger
 * /api/admin/solicitudes/{id}:
 *   patch:
 *     summary: Actualizar solicitud (admin)
 *     tags: [Admin - Solicitudes]
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
 *               estado:
 *                 type: string
 *               observaciones:
 *                 type: string
 *     responses:
 *       200:
 *         description: Solicitud actualizada
 *       404:
 *         description: Solicitud no encontrada
 */
router.patch('/solicitudes/:id', ...auth, actualizarSolicitudAdmin);


/**
 * @swagger
 * /api/admin/solicitudes/{id}:
 *   delete:
 *     summary: Eliminar solicitud (admin)
 *     tags: [Admin - Solicitudes]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         example: 1
 *     responses:
 *       200:
 *         description: Solicitud eliminada
 *       404:
 *         description: Solicitud no encontrada
 */
router.delete('/solicitudes/:id', ...auth, eliminarSolicitudAdmin);


module.exports = router;



