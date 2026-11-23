'use client';
import { useEffect, useState } from 'react';
import MainLayout from '@/components/layout/MainLayout';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import api from '@/lib/api';
import { FileText, CheckCircle, XCircle, DollarSign } from 'lucide-react';
import ProtectedRoute from '@/components/layout/ProtectedRoute';

export default function AdminDashboard() {
  const [kpis, setKpis] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    api.get('/api/admin/reportes/dashboard')
      .then(({ data }) => setKpis(data.kpis))
      .catch(() => {})
      .finally(() => setLoading(false));
  }, []);

  const cards = [
    { label: 'Total Solicitudes', value: kpis?.total_solicitudes || 0, icon: FileText, color: 'text-blue-700', bg: 'bg-blue-50' },
    { label: 'Certificados Emitidos', value: kpis?.certificados_emitidos || 0, icon: CheckCircle, color: 'text-green-700', bg: 'bg-green-50' },
    { label: 'Rechazadas', value: kpis?.rechazadas || 0, icon: XCircle, color: 'text-red-700', bg: 'bg-red-50' },
    { label: 'Ingresos Totales', value: `$${Number(kpis?.ingresos_totales || 0).toLocaleString()}`, icon: DollarSign, color: 'text-emerald-700', bg: 'bg-emerald-50' },
  ];

  return (
    <ProtectedRoute roles={['administrador']}>
      <MainLayout>
        <div className="mb-8">
          <h1 className="text-2xl font-bold text-slate-900">Dashboard</h1>
          <p className="text-slate-500 mt-1">Resumen general del sistema</p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
          {cards.map(({ label, value, icon: Icon, color, bg }) => (
            <Card key={label}>
              <CardContent className="p-6">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm text-slate-500">{label}</p>
                    <p className="text-2xl font-bold text-slate-900 mt-1">
                      {loading ? '...' : value}
                    </p>
                  </div>
                  <div className={`w-12 h-12 ${bg} rounded-xl flex items-center justify-center`}>
                    <Icon className={`w-6 h-6 ${color}`} />
                  </div>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      </MainLayout>
    </ProtectedRoute>
  );
}