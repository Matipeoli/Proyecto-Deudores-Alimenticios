'use client';
import { useEffect, useState } from 'react';
import MainLayout from '@/components/layout/MainLayout';
import { Card, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Toaster } from '@/components/ui/sonner';
import { toast } from 'sonner';
import { useSolicitudes } from '@/hooks/useSolicitudes';
import useAuthStore from '@/store/authStore';
import { FileText, Plus, Download, XCircle } from 'lucide-react';
import ProtectedRoute from '@/components/layout/ProtectedRoute';

const estadoColors = {
  pendiente_pago: 'bg-yellow-100 text-yellow-800',
  pagada: 'bg-blue-100 text-blue-800',
  en_revision: 'bg-indigo-100 text-indigo-800',
  aprobada: 'bg-green-100 text-green-800',
  rechazada: 'bg-red-100 text-red-800',
  cancelada: 'bg-slate-100 text-slate-600',
  certificado_emitido: 'bg-emerald-100 text-emerald-800',
};

export default function CiudadanoPage() {
  const { user, loadFromStorage } = useAuthStore();
  const { solicitudes, ciudades, loading, handleCrear, handleCancelar, handleDescargarCertificado } = useSolicitudes();
  const [showModal, setShowModal] = useState(false);
  const [showPago, setShowPago] = useState(false);
  const [solicitudCreada, setSolicitudCreada] = useState(null);
  const [form, setForm] = useState({ nombre_completo: '', cuit_dni: '', ciudad_id: '' });

  useEffect(() => {
    loadFromStorage();
  }, []);

  const onSolicitudCreada = (data) => {
    setSolicitudCreada(data);
    setShowModal(false);
    setShowPago(true);
  };

  const handleIrAPagar = () => 
    { const token = localStorage.getItem('token');
      const BASE = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3000';
      window.location.href = `${BASE}/api/solicitudes/${solicitudCreada.id}/pagar?_token=${token}`;
  setShowPago(false); 
};


  return (
    <ProtectedRoute roles={['ciudadano']}>
    <MainLayout>
      <Toaster position="top-right" />

      <div className="mb-8 flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">Mis Solicitudes</h1>
          <p className="text-slate-500 mt-1">Bienvenido, {user?.email}</p>
        </div>
        <Button className="bg-blue-700 hover:bg-blue-800" onClick={() => setShowModal(true)}>
          <Plus className="w-4 h-4 mr-2" /> Nueva Solicitud
        </Button>
      </div>

      {loading ? (
        <p className="text-slate-500 text-center py-16">Cargando...</p>
      ) : solicitudes.length === 0 ? (
        <div className="text-center py-16">
          <FileText className="w-12 h-12 text-slate-300 mx-auto mb-4" />
          <p className="text-slate-500">No tenés solicitudes todavía</p>
          <Button className="mt-4 bg-blue-700 hover:bg-blue-800" onClick={() => setShowModal(true)}>
            Crear primera solicitud
          </Button>
        </div>
      ) : (
        <div className="grid gap-4">
          {solicitudes.map(s => (
            <Card key={s.id} className="hover:shadow-md transition-shadow">
              <CardContent className="p-5">
                <div className="flex items-center justify-between">
                  <div className="flex-1">
                    <div className="flex items-center gap-3 mb-2">
                      <span className="font-mono text-blue-700 font-semibold text-sm">{s.numero_solicitud}</span>
                      <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${estadoColors[s.estado] || 'bg-slate-100 text-slate-600'}`}>
                        {s.estado.replace(/_/g, ' ')}
                      </span>
                    </div>
                    <p className="text-sm text-slate-600">{s.nombre_completo} — {s.cuit_dni}</p>
                    <p className="text-xs text-slate-400 mt-1">
                        {new Date(s.fecha_solicitud).toLocaleDateString('es-AR')} — {s.ciudad?.nombre || s.ciudad_nombre}
                      </p>
                      {s.estado === 'rechazada' && s.motivo_rechazo && (
                        <p className="text-xs text-red-600 mt-1 bg-red-50 px-2 py-1 rounded">
                       <strong>Motivo:</strong> {s.motivo_rechazo}
                        </p>
                    )}
                  </div>
                  <div className="flex items-center gap-2">
                    {s.estado === 'pendiente_pago' && (
                      <Button size="sm" className="bg-blue-700 hover:bg-blue-800"
                        onClick={() => { setSolicitudCreada(s); setShowPago(true); }}>
                        Pagar
                      </Button>
                    )}
                    {s.estado === 'certificado_emitido' && s.certificado_id && (
                      <Button size="sm" variant="outline" className="text-green-700 border-green-300"
                        onClick={() => handleDescargarCertificado(s.certificado_id)}>
                        <Download className="w-3.5 h-3.5 mr-1" /> Descargar
                      </Button>
                    )}
                    {['pendiente_pago', 'pago_fallido'].includes(s.estado) && (
                      <Button size="sm" variant="outline" className="text-red-600 border-red-300"
                        onClick={() => handleCancelar(s.id)}>
                        <XCircle className="w-3.5 h-3.5 mr-1" /> Cancelar
                      </Button>
                    )}
                  </div>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      )}

      {/* Modal Nueva Solicitud */}
      {showModal && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
          <div className="bg-white rounded-xl p-6 w-full max-w-md shadow-xl">
            <h2 className="text-lg font-semibold text-slate-900 mb-4">Nueva Solicitud</h2>
            <div className="space-y-4">
              <div>
                <label className="text-sm font-medium text-slate-700">Nombre completo</label>
                <Input className="mt-1" value={form.nombre_completo}
                  onChange={e => setForm({ ...form, nombre_completo: e.target.value })} />
              </div>
              <div>
                <label className="text-sm font-medium text-slate-700">DNI / CUIT</label>
                <Input className="mt-1" value={form.cuit_dni}
                  onChange={e => setForm({ ...form, cuit_dni: e.target.value })} />
              </div>
              <div>
                <label className="text-sm font-medium text-slate-700">Ciudad</label>
                <select className="mt-1 w-full border border-slate-300 rounded-md px-3 py-2 text-sm"
                  value={form.ciudad_id} onChange={e => setForm({ ...form, ciudad_id: e.target.value })}>
                  <option value="">Seleccioná una ciudad</option>
                  {ciudades.map(c => <option key={c.id} value={c.id}>{c.nombre}</option>)}
                </select>
              </div>
            </div>
            <div className="flex gap-3 mt-6">
              <Button className="flex-1 bg-blue-700 hover:bg-blue-800"
                onClick={() => handleCrear({ ...form, email: user?.email }, onSolicitudCreada)}>
                Crear Solicitud
              </Button>
              <Button variant="outline" className="flex-1" onClick={() => setShowModal(false)}>Cancelar</Button>
            </div>
          </div>
        </div>
      )}

      {/* Modal Pago */}
      {showPago && solicitudCreada && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
          <div className="bg-white rounded-xl p-6 w-full max-w-md shadow-xl text-center">
            <div className="w-14 h-14 bg-blue-100 rounded-full flex items-center justify-center mx-auto mb-4">
              <FileText className="w-7 h-7 text-blue-700" />
            </div>
            <h2 className="text-lg font-semibold text-slate-900 mb-2">Solicitud Lista</h2>
            <p className="text-sm text-slate-600 mb-1">
              <span className="font-mono text-blue-700">{solicitudCreada.numero_solicitud}</span>
            </p>
            <p className="text-sm text-slate-600 mb-6">
              Monto a pagar: <strong>${Number(solicitudCreada.monto).toLocaleString('es-AR')}</strong>
            </p>
            <div className="flex gap-3">
              <Button className="flex-1 bg-blue-700 hover:bg-blue-800" onClick={handleIrAPagar}>
                Ir a Pagar
              </Button>
              <Button variant="outline" className="flex-1" onClick={() => setShowPago(false)}>
                Pagar después
              </Button>
            </div>
          </div>
        </div>
      )}
    </MainLayout>
    </ProtectedRoute>
  );
}