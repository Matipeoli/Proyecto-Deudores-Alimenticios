'use client';
import { useState, useEffect } from 'react';
import { toast } from 'sonner';
import adminService from '@/services/adminService';
import api from '@/lib/api';

export function useEmpleados() {
  const [empleados, setEmpleados] = useState([]);
  const [ciudades, setCiudades] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showModal, setShowModal] = useState(false);
  const [buscar, setBuscar] = useState('');
  const [form, setForm] = useState({
    nombre: '', email: '', password: '', rol: 'empleado', ciudad_id: ''
  });

  useEffect(() => {
    fetchEmpleados();
    api.get('/api/ciudades').then(({ data }) => setCiudades(Array.isArray(data) ? data : data.data || []));
  }, []);

  const fetchEmpleados = async () => {
    setLoading(true);
    try {
      const { data } = await adminService.getEmpleados();
      setEmpleados(data.data);
    } catch {
      toast.error('Error al cargar empleados');
    } finally {
      setLoading(false);
    }
  };

  const handleCrear = async () => {
    if (!form.nombre || !form.email || !form.password) {
      toast.error('Completá todos los campos obligatorios');
      return;
    }
    try {
      await adminService.crearEmpleado(form);
      toast.success('Empleado creado correctamente');
      setShowModal(false);
      setForm({ nombre: '', email: '', password: '', rol: 'empleado', ciudad_id: '' });
      fetchEmpleados();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Error al crear empleado');
    }
  };

  const handleToggleEstado = async (emp) => {
    try {
      await adminService.toggleEstado(emp.id, emp.estado === 'activo' ? 'inactivo' : 'activo');
      toast.success('Estado actualizado');
      fetchEmpleados();
    } catch {
      toast.error('Error al cambiar estado');
    }
  };

  const filtrados = empleados.filter(e =>
    e.nombre.toLowerCase().includes(buscar.toLowerCase()) ||
    e.email.toLowerCase().includes(buscar.toLowerCase())
  );

  return {
    filtrados, ciudades, loading, buscar, setBuscar,
    showModal, setShowModal, form, setForm,
    handleCrear, handleToggleEstado,
  };
}