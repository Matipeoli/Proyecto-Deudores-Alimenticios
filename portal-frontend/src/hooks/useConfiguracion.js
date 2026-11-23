'use client';
import { useState, useEffect } from 'react';
import { toast } from 'sonner';
import configuracionService from '@/services/configuracionService';

export function useConfiguracion() {
  const [config, setConfig] = useState([]);
  const [loading, setLoading] = useState(true);
  const [editando, setEditando] = useState(null);
  const [valorEdit, setValorEdit] = useState('');

  useEffect(() => {
    fetchConfig();
  }, []);

  const fetchConfig = async () => {
    setLoading(true);
    try {
      const { data } = await configuracionService.getAll();
setConfig(Array.isArray(data) ? data : data.data || []);
    } catch {
      toast.error('Error al cargar configuración');
    } finally {
      setLoading(false);
    }
  };

  const handleEditar = (item) => {
    setEditando(item.clave);
    setValorEdit(item.valor);
  };

  const handleGuardar = async (clave) => {
    try {
      await configuracionService.update(clave, valorEdit);
      toast.success('Configuración actualizada');
      setEditando(null);
      fetchConfig();
    } catch {
      toast.error('Error al actualizar');
    }
  };

  const handleCancelar = () => {
    setEditando(null);
    setValorEdit('');
  };

  return {
    config, loading, editando, valorEdit, setValorEdit,
    handleEditar, handleGuardar, handleCancelar,
  };
}