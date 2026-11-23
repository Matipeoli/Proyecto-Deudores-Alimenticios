'use client';
import { useState, useEffect } from 'react';
import { toast } from 'sonner';
import empleadoService from '@/services/empleadoService';

export function useKanban() {
  const [solicitudes, setSolicitudes] = useState([]);
  const [conteos, setConteos] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selected, setSelected] = useState(null);
  const [showDetalle, setShowDetalle] = useState(false);
  const [showRechazar, setShowRechazar] = useState(false);
  const [showCertificado, setShowCertificado] = useState(false);
  const [motivo, setMotivo] = useState('');
  const [pdfFile, setPdfFile] = useState(null);
  const [esDeudor, setEsDeudor] = useState(false);
  const [buscar, setBuscar] = useState('');
  const [montoDeuda, setMontoDeuda] = useState('');
  const [tipoDeuda, setTipoDeuda] = useState('');
  const [fechaVencDeuda, setFechaVencDeuda] = useState('');

  useEffect(() => {
    fetchSolicitudes();
  }, []);

  const fetchSolicitudes = async () => {
    setLoading(true);
    try {
      const { data } = await empleadoService.getSolicitudes();
      setSolicitudes(data.data);
      setConteos(data.conteos || []);
    } catch {
      toast.error('Error al cargar solicitudes');
    } finally {
      setLoading(false);
    }
  };

  const handleAprobar = async (id) => {
    try {
      await empleadoService.aprobar(id);
      toast.success('Solicitud aprobada');
      setShowDetalle(false);
      fetchSolicitudes();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Error al aprobar');
    }
  };

  const handleRechazar = async (id) => {
    if (!motivo || motivo.length < 10) {
      toast.error('El motivo debe tener al menos 10 caracteres');
      return;
    }
    try {
      await empleadoService.rechazar(id, motivo);
      toast.success('Solicitud rechazada');
      setShowRechazar(false);
      setShowDetalle(false);
      setMotivo('');
      fetchSolicitudes();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Error al rechazar');
    }
  };

 const handleSubirCertificado = async (id) => {
  if (!pdfFile) { toast.error('Seleccioná un archivo PDF'); return; }
  if (esDeudor && !montoDeuda) { toast.error('Ingresá el monto de deuda'); return; }
  
  const formData = new FormData();
  formData.append('pdf', pdfFile);
  formData.append('es_deudor', esDeudor);
  if (esDeudor) {
    formData.append('monto_deuda', montoDeuda);
  }
  try {
    await empleadoService.subirCertificado(id, formData);
    toast.success('Certificado emitido correctamente');
    setShowCertificado(false);
    setShowDetalle(false);
    setPdfFile(null);
    setMontoDeuda('');
    fetchSolicitudes();
  } catch (err) {
    toast.error(err.response?.data?.error || 'Error al subir certificado');
  }
};

  const handleCambiarPrioridad = async (id) => {
  const s = solicitudes.find(x => x.id === id);
  const nuevaPrioridad = s?.prioridad === 'urgente' ? 'normal' : 'urgente';
  try {
    await empleadoService.cambiarPrioridad(id, nuevaPrioridad);
    fetchSolicitudes();
  } catch {
    toast.error('Error al cambiar prioridad');
  }
};


  const handleTomarRevision = async (id) => {
    try {
      await empleadoService.tomarRevision(id);
      toast.success('Solicitud en revisión');
      setShowDetalle(false);
     fetchSolicitudes();
    } catch (err) {
     toast.error(err.response?.data?.error || 'Error al tomar en revisión');
    }
  };

  const columnas = [
    { key: 'pagada', label: 'Pagadas', color: 'text-blue-700', bg: 'bg-blue-50' },
    { key: 'en_revision', label: 'En Revisión', color: 'text-indigo-700', bg: 'bg-indigo-50' },
    { key: 'aprobada', label: 'Aprobadas', color: 'text-green-700', bg: 'bg-green-50' },
  ];

  const getSolicitudesByEstado = (estado) =>
    solicitudes.filter(s =>
      s.estado === estado &&
      (buscar === '' ||
        s.nombre_completo.toLowerCase().includes(buscar.toLowerCase()) ||
        s.numero_solicitud.toLowerCase().includes(buscar.toLowerCase()))
    );

  return {
    solicitudes, conteos, loading, selected, setSelected,
    showDetalle, setShowDetalle,
    showRechazar, setShowRechazar,
    showCertificado, setShowCertificado,
    motivo, setMotivo,
    pdfFile, setPdfFile,
    esDeudor, setEsDeudor,
    buscar, setBuscar,
    columnas, getSolicitudesByEstado,
    handleAprobar, handleRechazar,
    handleSubirCertificado, handleCambiarPrioridad,
    montoDeuda, setMontoDeuda, handleTomarRevision,
    tipoDeuda, setTipoDeuda,
    fechaVencDeuda, setFechaVencDeuda,
};
}