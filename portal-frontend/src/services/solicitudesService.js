import api from '@/lib/api';

const solicitudesService = {
  getMisSolicitudes: () => api.get('/api/solicitudes'),
  getSolicitud: (id) => api.get(`/api/solicitudes/${id}`),
  crear: (data) => api.post('/api/solicitudes', data),
  cancelar: (id) => api.patch(`/api/solicitudes/${id}/cancelar`),
  getCiudades: () => api.get('/api/ciudades'),
};

export default solicitudesService;