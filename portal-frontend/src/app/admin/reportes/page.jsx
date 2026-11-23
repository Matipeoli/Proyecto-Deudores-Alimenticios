'use client';
import MainLayout from '@/components/layout/MainLayout';
import ProtectedRoute from '@/components/layout/ProtectedRoute';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Toaster } from '@/components/ui/sonner';
import { useReportes } from '@/hooks/useReportes';
import { Clock, DollarSign, FileText } from 'lucide-react';

const estadoColors = {
  pendiente_pago: 'bg-yellow-100 text-yellow-800',
  pagada: 'bg-blue-100 text-blue-800',
  en_revision: 'bg-indigo-100 text-indigo-800',
  aprobada: 'bg-green-100 text-green-800',
  rechazada: 'bg-red-100 text-red-800',
  cancelada: 'bg-slate-100 text-slate-600',
  certificado_emitido: 'bg-emerald-100 text-emerald-800',
};

export default function AdminReportes() {
  const { resumen, tiempos, loading } = useReportes();

  return (
    <ProtectedRoute roles={['administrador']}>
    <MainLayout>
      <Toaster position="top-right" />
      <div className="mb-8">
        <h1 className="text-2xl font-bold text-slate-900">Reportes</h1>
        <p className="text-slate-500 mt-1">Estadísticas y métricas del sistema</p>
      </div>

      {loading ? (
        <p className="text-slate-500 text-center py-8">Cargando...</p>
      ) : (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">

          {/* Ingresos */}
          <Card>
            <CardHeader>
              <CardTitle className="text-base flex items-center gap-2">
                <DollarSign className="w-4 h-4 text-emerald-600" /> Ingresos
              </CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-3xl font-bold text-slate-900">
                ${Number(resumen?.ingresos?.total_ingresos || 0).toLocaleString('es-AR')}
              </p>
              <p className="text-sm text-slate-500 mt-1">
                {resumen?.ingresos?.total_transacciones || 0} transacciones exitosas
              </p>
            </CardContent>
          </Card>

          {/* Tiempos promedio */}
          <Card>
            <CardHeader>
              <CardTitle className="text-base flex items-center gap-2">
                <Clock className="w-4 h-4 text-blue-600" /> Tiempos Promedio
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-3">
              <div className="flex justify-between text-sm">
                <span className="text-slate-600">Hasta el pago</span>
                <span className="font-medium">{tiempos?.horas_hasta_pago || '—'} hs</span>
              </div>
              <div className="flex justify-between text-sm">
                <span className="text-slate-600">Pago a emisión</span>
                <span className="font-medium">{tiempos?.horas_pago_a_emision || '—'} hs</span>
              </div>
              <div className="flex justify-between text-sm border-t pt-3">
                <span className="text-slate-700 font-medium">Total</span>
                <span className="font-bold">{tiempos?.horas_total || '—'} hs</span>
              </div>
            </CardContent>
          </Card>

          {/* Por estado */}
          <Card className="lg:col-span-2">
            <CardHeader>
              <CardTitle className="text-base flex items-center gap-2">
                <FileText className="w-4 h-4 text-blue-600" /> Solicitudes por Estado
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="space-y-3">
                {resumen?.por_estado?.map(({ estado, total, porcentaje }) => (
                  <div key={estado}>
                    <div className="flex justify-between text-sm mb-1">
                      <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${estadoColors[estado] || 'bg-slate-100 text-slate-600'}`}>
                        {estado.replace(/_/g, ' ')}
                      </span>
                      <span className="text-slate-600">{total} ({porcentaje}%)</span>
                    </div>
                    <div className="w-full bg-slate-100 rounded-full h-2">
                      <div className="bg-blue-600 h-2 rounded-full transition-all"
                        style={{ width: `${porcentaje}%` }} />
                    </div>
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>
        </div>
      )}
    </MainLayout>
  </ProtectedRoute>
  );
}