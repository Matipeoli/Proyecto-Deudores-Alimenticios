'use client';
import { useState, useEffect } from 'react';
import { toast } from 'sonner';
import solicitudesService from '@/services/solicitudesService';
import api from '@/lib/api';

export function useSolicitudes() {
  const [solicitudes, setSolicitudes] = useState([]);
  const [ciudades, setCiudades] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchSolicitudes();
    fetchCiudades();
  }, []);

  const fetchSolicitudes = async () => {
    setLoading(true);
    try {
      const { data } = await solicitudesService.getMisSolicitudes();
      setSolicitudes(Array.isArray(data) ? data : data.data || []);
    } catch {
      toast.error('Error al cargar solicitudes');
    } finally {
      setLoading(false);
    }
  };

  const fetchCiudades = async () => {
    try {
      const { data } = await solicitudesService.getCiudades();
      setCiudades(Array.isArray(data) ? data : data.data || []);
    } catch {}
  };

  const handleCrear = async (form, onSuccess) => {
    if (!form.nombre_completo || !form.cuit_dni || !form.ciudad_id) {
      toast.error('Completá todos los campos');
      return;
    }
    try {
      const { data } = await solicitudesService.crear(form);
      toast.success('Solicitud creada correctamente');
      fetchSolicitudes();
      if (onSuccess) onSuccess(data);
    } catch (err) {
      toast.error(err.response?.data?.error || 'Error al crear solicitud');
    }
  };

  const handleCancelar = async (id) => {
    try {
      await solicitudesService.cancelar(id);
      toast.success('Solicitud cancelada');
      fetchSolicitudes();
    } catch (err) {
      toast.error(err.response?.data?.error || 'No se puede cancelar esta solicitud');
    }
  };

  const handleDescargarCertificado = async (certificadoId) => {
    try {
      const response = await api.get(`/api/certificados/${certificadoId}/descargar`, {
        responseType: 'blob',
      });
      const url = window.URL.createObjectURL(new Blob([response.data]));
      const link = document.createElement('a');
      link.href = url;
      link.setAttribute('download', `certificado-${certificadoId}.pdf`);
      document.body.appendChild(link);
      link.click();
      link.remove();
    } catch {
      toast.error('Error al descargar el certificado');
    }
  };

  return {
    solicitudes, ciudades, loading,
    handleCrear, handleCancelar, handleDescargarCertificado,
  };
}