'use client';
import { useState } from 'react';
import { toast } from 'sonner';
import perfilService from '@/services/perfilService';

export function usePerfil() {
  const [loading, setLoading] = useState(false);
  const [form, setForm] = useState({
    password_actual: '',
    password_nuevo: '',
    password_confirmar: '',
  });

  const handleCambiarPassword = async () => {
    if (!form.password_actual || !form.password_nuevo || !form.password_confirmar) {
      toast.error('Completá todos los campos');
      return;
    }
    if (form.password_nuevo !== form.password_confirmar) {
      toast.error('Las contraseñas nuevas no coinciden');
      return;
    }
    if (form.password_nuevo.length < 8) {
      toast.error('La nueva contraseña debe tener al menos 8 caracteres');
      return;
    }
    setLoading(true);
    try {
      await perfilService.cambiarPassword(form.password_actual, form.password_nuevo);
      toast.success('Contraseña actualizada correctamente');
      setForm({ password_actual: '', password_nuevo: '', password_confirmar: '' });
    } catch (err) {
      toast.error(err.response?.data?.error || 'Error al cambiar contraseña');
    } finally {
      setLoading(false);
    }
  };

  return { form, setForm, loading, handleCambiarPassword };
}