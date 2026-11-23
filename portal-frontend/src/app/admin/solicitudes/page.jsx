'use client';
import { useEffect, useState } from 'react';
import MainLayout from '@/components/layout/MainLayout';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Input } from '@/components/ui/input';
import api from '@/lib/api';
import { Search } from 'lucide-react';
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

export default function AdminSolicitudes() {
  const [solicitudes, setSolicitudes] = useState([]);
  const [loading, setLoading] = useState(true);
  const [buscar, setBuscar] = useState('');

  useEffect(() => {
    api.get('/api/admin/solicitudes')
      .then(({ data }) => setSolicitudes(data.data))
      .catch(() => {})
      .finally(() => setLoading(false));
  }, []);

  const filtradas = solicitudes.filter(s =>
    s.nombre_completo.toLowerCase().includes(buscar.toLowerCase()) ||
    s.numero_solicitud.toLowerCase().includes(buscar.toLowerCase()) ||
    s.cuit_dni.includes(buscar)
  );

  return (
    <ProtectedRoute roles={['administrador']}>
    <MainLayout>
      <div className="mb-8">
        <h1 className="text-2xl font-bold text-slate-900">Solicitudes</h1>
        <p className="text-slate-500 mt-1">Todas las solicitudes del sistema</p>
      </div>

      <Card>
        <CardHeader>
          <div className="flex items-center gap-4">
            <div className="relative flex-1 max-w-sm">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
              <Input
                placeholder="Buscar por nombre, número o DNI..."
                className="pl-9"
                value={buscar}
                onChange={e => setBuscar(e.target.value)}
              />
            </div>
          </div>
        </CardHeader>
        <CardContent>
          {loading ? (
            <p className="text-slate-500 text-center py-8">Cargando...</p>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-slate-200">
                    <th className="text-left py-3 px-4 font-semibold text-slate-700">Número</th>
                    <th className="text-left py-3 px-4 font-semibold text-slate-700">Nombre</th>
                    <th className="text-left py-3 px-4 font-semibold text-slate-700">DNI/CUIT</th>
                    <th className="text-left py-3 px-4 font-semibold text-slate-700">Ciudad</th>
                    <th className="text-left py-3 px-4 font-semibold text-slate-700">Estado</th>
                    <th className="text-left py-3 px-4 font-semibold text-slate-700">Fecha</th>
                  </tr>
                </thead>
                <tbody>
                  {filtradas.map(s => (
                    <tr key={s.id} className="border-b border-slate-100 hover:bg-slate-50">
                      <td className="py-3 px-4 font-mono text-blue-700 font-medium">{s.numero_solicitud}</td>
                      <td className="py-3 px-4 font-medium text-slate-900">{s.nombre_completo}</td>
                      <td className="py-3 px-4 text-slate-600">{s.cuit_dni}</td>
                      <td className="py-3 px-4 text-slate-600">{s.ciudad_nombre}</td>
                      <td className="py-3 px-4">
                        <span className={`px-2 py-1 rounded-full text-xs font-medium ${estadoColors[s.estado] || 'bg-slate-100 text-slate-600'}`}>
                          {s.estado.replace(/_/g, ' ')}
                        </span>
                      </td>
                      <td className="py-3 px-4 text-slate-500">
                        {new Date(s.fecha_solicitud).toLocaleDateString('es-AR')}
                      </td>
                    </tr>
                  ))}
                  {filtradas.length === 0 && (
                    <tr><td colSpan={6} className="text-center py-8 text-slate-400">Sin resultados</td></tr>
                  )}
                </tbody>
              </table>
            </div>
          )}
        </CardContent>
      </Card>
    </MainLayout>
  </ProtectedRoute>
  );
}