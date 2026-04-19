const errorHandler = (err, req, res, next) => {
  console.error('❌ Error:', err.message);

  // Error de validación de PostgreSQL
  if (err.code === '23505') {
    return res.status(409).json({ error: 'Ya existe un registro con esos datos' });
  }

  if (err.code === '23503') {
    return res.status(422).json({ error: 'Referencia a un registro que no existe' });
  }

  if (err.code === '23514') {
    return res.status(422).json({ error: 'Los datos no cumplen las validaciones requeridas' });
  }

  // Error de JWT
  if (err.name === 'JsonWebTokenError') {
    return res.status(401).json({ error: 'Token inválido' });
  }

  if (err.name === 'TokenExpiredError') {
    return res.status(401).json({ error: 'Token expirado' });
  }

  // Error de multer
  if (err.message === 'Solo se permiten archivos PDF') {
    return res.status(422).json({ error: err.message });
  }

  if (err.code === 'LIMIT_FILE_SIZE') {
    return res.status(422).json({ error: 'El archivo supera el tamaño máximo de 5MB' });
  }

  // Error genérico
  const status = err.status || 500;
  const message = err.message || 'Error interno del servidor';

  return res.status(status).json({ error: message });
};

const notFound = (req, res) => {
  return res.status(404).json({ error: `Ruta ${req.method} ${req.path} no encontrada` });
};

module.exports = { errorHandler, notFound };