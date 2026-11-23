import api from '@/lib/api';

const perfilService = {
  cambiarPassword: (password_actual, password_nuevo) =>
api.patch('/api/admin/empleado/perfil/password', { password_actual, password_nuevo })
};

export default perfilService;