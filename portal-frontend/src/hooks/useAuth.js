'use client';
import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { toast } from 'sonner';
import authService from '@/services/authService';
import useAuthStore from '@/store/authStore';


export function useAuth() {
  const router = useRouter();
  const { setAuth, logout: logoutStore } = useAuthStore();
  const [loading, setLoading] = useState(false);


  const sendOTP = async (dni, email) => {
    setLoading(true);
    try {
      await authService.sendOTP(dni, email);
      toast.success('Código enviado a ' + email);
      return true;
    } catch (err) {
      toast.error(err.response?.data?.error || 'Error al enviar el código');
      return false;
    } finally {
      setLoading(false);
    }
  };


  const verifyOTP = async (email, code) => {
  setLoading(true);
  try {
    const { data } = await authService.verifyOTP(email, code);
    setAuth(data.user, data.access_token);
    toast.success('Bienvenido');
    setTimeout(() => router.push('/ciudadano'), 100);
    return true;
  } catch (err) {
    toast.error(err.response?.data?.error || 'Código inválido');
    return false;
  } finally {
    setLoading(false);
  }
};



  const loginEmpleado = async (email, password) => {
    setLoading(true);
    try {
      const { data } = await authService.loginEmpleado(email, password);
      setAuth(data.user, data.access_token);
      toast.success('Bienvenido ' + data.user.nombre);
      if (data.user.rol === 'administrador') router.push('/admin');
      else router.push('/empleado');
      return true;
    } catch (err) {
      toast.error(err.response?.data?.error || 'Credenciales inválidas');
      return false;
    } finally {
      setLoading(false);
    }
  };


  const logout = async () => {
    try {
      await authService.logout();
    } catch (_) {}
    logoutStore();
    router.push('/login');
  };


  return { sendOTP, verifyOTP, loginEmpleado, logout, loading };
}