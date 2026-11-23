import api from '@/lib/api';

const reportesService = {
  getDashboard: () => api.get('/api/admin/reportes/dashboard'),
  getResumenSolicitudes: () => api.get('/api/admin/reportes/solicitudes-resumen'),
  getTiemposPromedio: () => api.get('/api/admin/reportes/tiempos-promedio'),
};

export default reportesService;