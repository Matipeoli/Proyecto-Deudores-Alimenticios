const express = require('express');
app.use(cors({
  origin: process.env.CORS_ORIGIN || 'http://localhost:3001',
  credentials: true,
}));
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const swaggerUi = require('swagger-ui-express');
require('dotenv').config();

const app = express();

// Middlewares globales
app.use(helmet());
app.use(cors());
app.use(express.json());

// Rate limiting
const limiterGeneral = rateLimit({
  windowMs: 60 * 1000,
  max: 100,
  message: { error: 'Demasiadas solicitudes, intentá en un minuto' },
});

const limiterAuth = rateLimit({
  windowMs: 60 * 1000,
  max: 5,
  message: { error: 'Demasiados intentos, esperá un minuto' },
});

app.use('/api', limiterGeneral);
app.use('/api/auth/send-otp', limiterAuth);
app.use('/api/auth/empleado/login', limiterAuth);

// Rutas
const authRoutes = require('./routes/auth');
const ciudadesRoutes = require('./routes/ciudades');
const solicitudesRoutes = require('./routes/solicitudes');
const empleadoRoutes = require('./routes/empleado');
const certificadosRoutes = require('./routes/certificados');
const adminRoutes = require('./routes/admin');
const pagosRoutes = require('./routes/pagos');

app.use('/api/auth', authRoutes);
app.use('/api/ciudades', ciudadesRoutes);
app.use('/api/solicitudes', solicitudesRoutes);
app.use('/api/empleado', empleadoRoutes);
app.use('/api', certificadosRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/pagos', pagosRoutes);

// Swagger
const swaggerSpec = require('./config/swagger');
app.use('/api/docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec));

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.get('/', (req, res) => {
  res.json({ message: 'Portal de Certificados API v1' });
});

// Error handlers — siempre al final
const { errorHandler, notFound } = require('./middlewares/errorHandler');
app.use(notFound);
app.use(errorHandler);

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🚀 Servidor corriendo en http://localhost:${PORT}`);
});

module.exports = app;