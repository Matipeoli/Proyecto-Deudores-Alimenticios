import api from '@/lib/api';

const configuracionService = {
  getAll: () => api.get('/api/admin/configuracion'),
  update: (clave, valor) => api.put(`/api/admin/configuracion/${clave}`, { valor }),
};

export default configuracionService;