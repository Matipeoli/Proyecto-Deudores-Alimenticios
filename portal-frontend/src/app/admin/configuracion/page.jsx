'use client';
import MainLayout from '@/components/layout/MainLayout';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { Toaster } from '@/components/ui/sonner';
import { useConfiguracion } from '@/hooks/useConfiguracion';
import { Settings, Pencil, Check, X } from 'lucide-react';
import ProtectedRoute from '@/components/layout/ProtectedRoute';

export default function AdminConfiguracion() {
  const {
    config, loading, editando, valorEdit, setValorEdit,
    handleEditar, handleGuardar, handleCancelar,
  } = useConfiguracion();

  return (
    <ProtectedRoute roles={['administrador']}>
    <MainLayout>
      <Toaster position="top-right" />
      <div className="mb-8">
        <h1 className="text-2xl font-bold text-slate-900">Configuración</h1>
        <p className="text-slate-500 mt-1">Parámetros del sistema</p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="text-base flex items-center gap-2">
            <Settings className="w-4 h-4 text-slate-600" /> Parámetros
          </CardTitle>
        </CardHeader>
        <CardContent>
          {loading ? (
            <p className="text-slate-500 text-center py-8">Cargando...</p>
          ) : (
            <div className="space-y-3">
              {config.map(item => (
                <div key={item.clave} className="flex items-center justify-between p-4 border border-slate-200 rounded-lg hover:bg-slate-50">
                  <div className="flex-1">
                    <p className="text-sm font-medium text-slate-900">{item.clave}</p>
                    {item.descripcion && <p className="text-xs text-slate-500 mt-0.5">{item.descripcion}</p>}
                  </div>
                  <div className="flex items-center gap-3">
                    {editando === item.clave ? (
                      <>
                        <Input
                          className="w-40 h-8 text-sm"
                          value={valorEdit}
                          onChange={e => setValorEdit(e.target.value)}
                          autoFocus
                        />
                        <button onClick={() => handleGuardar(item.clave)}
                          className="text-green-600 hover:text-green-800">
                          <Check className="w-4 h-4" />
                        </button>
                        <button onClick={handleCancelar}
                          className="text-red-500 hover:text-red-700">
                          <X className="w-4 h-4" />
                        </button>
                      </>
                    ) : (
                      <>
                        <span className="text-sm font-mono bg-slate-100 px-3 py-1 rounded text-slate-700">
                          {item.valor}
                        </span>
                        <button onClick={() => handleEditar(item)}
                          className="text-slate-400 hover:text-blue-600 transition-colors">
                          <Pencil className="w-4 h-4" />
                        </button>
                      </>
                    )}
                  </div>
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>
    </MainLayout>
  </ProtectedRoute>
  );
}