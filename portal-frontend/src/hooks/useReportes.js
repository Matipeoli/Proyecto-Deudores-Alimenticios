'use client';
import { useState, useEffect } from 'react';
import { toast } from 'sonner';
import reportesService from '@/services/reportesService';

export function useReportes() {
  const [resumen, setResumen] = useState(null);
  const [tiempos, setTiempos] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    Promise.all([
      reportesService.getResumenSolicitudes(),
      reportesService.getTiemposPromedio(),
    ])
      .then(([res, tpo]) => {
        setResumen(res.data);
        setTiempos(tpo.data);
      })
      .catch(() => toast.error('Error al cargar reportes'))
      .finally(() => setLoading(false));
  }, []);

  return { resumen, tiempos, loading };
}