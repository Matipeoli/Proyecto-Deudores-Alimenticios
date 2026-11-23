'use client';
import { useState, useEffect } from 'react';
import { toast } from 'sonner';
import empleadoService from '@/services/empleadoService';

export function useMisSolicitudes() {
  const [solicitudes, setSolicitudes] = useState([]);
  const [loading, setLoading] = useState(true);
  const [buscar, setBuscar] = useState('');
  const [estadoFiltro, setEstadoFiltro] = useState('');

  useEffect(() => {
    fetchSolicitudes();
  }, [estadoFiltro]);

  const fetchSolicitudes = async () => {
    setLoading(true);
    try {
      const params = {};
      if (estadoFiltro) params.estado = estadoFiltro;
      const { data } = await empleadoService.getSolicitudes(params);
      setSolicitudes(data.data || []);
    } catch {
      toast.error('Error al cargar solicitudes');
    } finally {
      setLoading(false);
    }
  };

  const filtradas = solicitudes.filter(s =>
    s.nombre_completo.toLowerCase().includes(buscar.toLowerCase()) ||
    s.numero_solicitud.toLowerCase().includes(buscar.toLowerCase()) ||
    s.cuit_dni.includes(buscar)
  );

  return { filtradas, loading, buscar, setBuscar, estadoFiltro, setEstadoFiltro };
}