const express = require('express');
const router = express.Router();
const { loginEmpleado, logoutEmpleado, refreshToken } = require('../controllers/authController');
const { sendOTP, verifyOTP } = require('../controllers/otpController');
const { verificarToken } = require('../middlewares/auth');
/**
 * @swagger
 * /api/auth/send-otp:
 *   post:
 *     summary: Enviar código OTP al ciudadano
 *     tags: [Auth]
 *     security: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [dni, email]
 *             properties:
 *               dni:
 *                 type: string
 *                 example: "12345678"
 *               email:
 *                 type: string
 *                 example: "ciudadano@email.com"
 *     responses:
 *       200:
 *         description: Código enviado correctamente
 *       400:
 *         description: DNI o email inválido
 *       429:
 *         description: Rate limit excedido
 */
router.post('/send-otp', sendOTP);

/**
 * @swagger
 * /api/auth/verify-otp:
 *   post:
 *     summary: Verificar código OTP y obtener JWT
 *     tags: [Auth]
 *     security: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [email, code]
 *             properties:
 *               email:
 *                 type: string
 *                 example: "ciudadano@email.com"
 *               code:
 *                 type: string
 *                 example: "123456"
 *     responses:
 *       200:
 *         description: Token JWT generado
 *       400:
 *         description: Código inválido
 *       401:
 *         description: Código expirado
 *       429:
 *         description: Máximo de intentos excedido
 */
router.post('/verify-otp', verifyOTP);

/**
 * @swagger
 * /api/auth/empleado/login:
 *   post:
 *     summary: Login de empleado o administrador
 *     tags: [Auth]
 *     security: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [email, password]
 *             properties:
 *               email:
 *                 type: string
 *                 example: "admin@gobierno.gob.ar"
 *               password:
 *                 type: string
 *                 example: "Admin2026!"
 *     responses:
 *       200:
 *         description: Login exitoso, retorna JWT
 *       401:
 *         description: Credenciales inválidas
 *       403:
 *         description: Empleado inactivo
 *       422:
 *         description: Email no es @gobierno.gob.ar
 */
router.post('/empleado/login', loginEmpleado);

/**
 * @swagger
 * /api/auth/logout:
 *   post:
 *     summary: Logout de empleado
 *     tags: [Auth]
 *     responses:
 *       204:
 *         description: Logout exitoso
 */
router.post('/logout', verificarToken, logoutEmpleado);
router.post('/refresh', verificarToken, refreshToken);

module.exports = router;