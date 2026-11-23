import api from '@/lib/api';

const empleadoService = {
  getSolicitudes: (params) => api.get('/api/empleado/solicitudes', { params }),
  getSolicitud: (id) => api.get(`/api/empleado/solicitudes/${id}`),
  getMisSolicitudesCompletas: (params) => api.get('/api/empleado/solicitudes', { params }),
  aprobar: (id) => api.patch(`/api/empleado/solicitudes/${id}/aprobar`),
  rechazar: (id, motivo_rechazo) => api.patch(`/api/empleado/solicitudes/${id}/rechazar`, { motivo_rechazo }),
  cambiarPrioridad: (id, prioridad) => api.patch(`/api/empleado/solicitudes/${id}/prioridad`, { prioridad }),
  subirCertificado: (id, formData) => api.post(`/api/empleado/solicitudes/${id}/certificado`, formData, {
    headers: { 'Content-Type': 'multipart/form-data' }
  }),
  tomarRevision: (id) => api.patch(`/api/empleado/solicitudes/${id}/tomar-revision`),
};


export default empleadoService;