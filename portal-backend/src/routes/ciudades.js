const express = require('express');
const router = express.Router();
const { verificarToken, requireRol } = require('../middlewares/auth');
const {
  listarCiudadesPublico,
  listarCiudades,
  obtenerCiudad,
  crearCiudad,
  actualizarCiudad,
} = require('../controllers/ciudadesController');


/**
 * @swagger
 * /api/ciudades:
 *   get:
 *     summary: Listar ciudades (público)
 *     tags: [Ciudades]
 *     security: []
 *     responses:
 *       200:
 *         description: Lista de ciudades activas
 */
router.get('/', listarCiudadesPublico);


/**
 * @swagger
 * /api/ciudades/admin:
 *   get:
 *     summary: Listar todas las ciudades (admin)
 *     tags: [Ciudades]
 *     responses:
 *       200:
 *         description: Lista completa de ciudades
 *       401:
 *         description: No autorizado
 */
router.get('/admin', verificarToken, requireRol('administrador'), listarCiudades);


/**
 * @swagger
 * /api/ciudades/admin/{id}:
 *   get:
 *     summary: Obtener ciudad por ID (admin)
 *     tags: [Ciudades]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         example: 1
 *     responses:
 *       200:
 *         description: Ciudad encontrada
 *       404:
 *         description: Ciudad no encontrada
 */
router.get('/admin/:id', verificarToken, requireRol('administrador'), obtenerCiudad);


/**
 * @swagger
 * /api/ciudades/admin:
 *   post:
 *     summary: Crear ciudad (admin)
 *     tags: [Ciudades]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [nombre, provincia]
 *             properties:
 *               nombre:
 *                 type: string
 *                 example: "Rosario"
 *               provincia:
 *                 type: string
 *                 example: "Santa Fe"
 *     responses:
 *       201:
 *         description: Ciudad creada correctamente
 *       422:
 *         description: Datos inválidos
 */
router.post('/admin', verificarToken, requireRol('administrador'), crearCiudad);


/**
 * @swagger
 * /api/ciudades/admin/{id}:
 *   put:
 *     summary: Actualizar ciudad (admin)
 *     tags: [Ciudades]
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
 *             properties:
 *               nombre:
 *                 type: string
 *                 example: "Rosario"
 *               provincia:
 *                 type: string
 *                 example: "Santa Fe"
 *               activa:
 *                 type: boolean
 *                 example: true
 *     responses:
 *       200:
 *         description: Ciudad actualizada
 *       404:
 *         description: Ciudad no encontrada
 */
router.put('/admin/:id', verificarToken, requireRol('administrador'), actualizarCiudad);


module.exports = router;



