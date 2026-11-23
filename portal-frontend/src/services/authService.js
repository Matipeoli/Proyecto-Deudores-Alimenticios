import api from '@/lib/api';

const authService = {
  sendOTP: (dni, email) => api.post('/api/auth/send-otp', { dni, email }),

  verifyOTP: (email, code) => api.post('/api/auth/verify-otp', { email, code }),

  loginEmpleado: (email, password) => api.post('/api/auth/empleado/login', { email, password }),

  logout: () => api.post('/api/auth/logout'),

  refresh: () => api.post('/api/auth/refresh'),
};

export default authService;