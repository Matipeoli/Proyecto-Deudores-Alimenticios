import api from '@/lib/api';

const adminService = {
  getEmpleados: (params) => api.get('/api/admin/empleados', { params }),
  crearEmpleado: (data) => api.post('/api/admin/empleados', data),
  toggleEstado: (id, estado) => api.patch(`/api/admin/empleados/${id}/estado`, { estado }),
  cambiarPasswordEmpleado: (id, password_nuevo) =>
  api.patch(`/api/admin/empleados/${id}/password`, { password_nuevo }),
};

export default adminService;