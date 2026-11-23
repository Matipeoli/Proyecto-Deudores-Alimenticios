'use client';
import MainLayout from '@/components/layout/MainLayout';
import { Card, CardContent, CardHeader } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { Toaster } from '@/components/ui/sonner';
import { useEmpleados } from '@/hooks/useEmpleados';
import { Search, Plus, CheckCircle, XCircle } from 'lucide-react';
import ProtectedRoute from '@/components/layout/ProtectedRoute';

export default function AdminEmpleados() {
  const {
    filtrados, ciudades, loading, buscar, setBuscar,
    showModal, setShowModal, form, setForm,
    handleCrear, handleToggleEstado,
  } = useEmpleados();

  return (
    <ProtectedRoute roles={['administrador']}>
    <MainLayout>
      <Toaster position="top-right" />
      <div className="mb-8 flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">Empleados</h1>
          <p className="text-slate-500 mt-1">Gestión de usuarios institucionales</p>
        </div>
        <Button className="bg-blue-700 hover:bg-blue-800" onClick={() => setShowModal(true)}>
          <Plus className="w-4 h-4 mr-2" /> Nuevo Empleado
        </Button>
      </div>

      <Card>
        <CardHeader>
          <div className="relative max-w-sm">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
            <Input placeholder="Buscar empleado..." className="pl-9" value={buscar} onChange={e => setBuscar(e.target.value)} />
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
                    <th className="text-left py-3 px-4 font-semibold text-slate-700">Nombre</th>
                    <th className="text-left py-3 px-4 font-semibold text-slate-700">Email</th>
                    <th className="text-left py-3 px-4 font-semibold text-slate-700">Rol</th>
                    <th className="text-left py-3 px-4 font-semibold text-slate-700">Ciudad</th>
                    <th className="text-left py-3 px-4 font-semibold text-slate-700">Estado</th>
                    <th className="text-left py-3 px-4 font-semibold text-slate-700">Acciones</th>
                  </tr>
                </thead>
                <tbody>
                  {filtrados.map(e => (
                    <tr key={e.id} className="border-b border-slate-100 hover:bg-slate-50">
                      <td className="py-3 px-4 font-medium text-slate-900">{e.nombre}</td>
                      <td className="py-3 px-4 text-slate-600">{e.email}</td>
                      <td className="py-3 px-4">
                        <span className={`px-2 py-1 rounded-full text-xs font-medium ${e.rol === 'administrador' ? 'bg-purple-100 text-purple-700' : 'bg-blue-100 text-blue-700'}`}>
                          {e.rol}
                        </span>
                      </td>
                      <td className="py-3 px-4 text-slate-600">{e.ciudad_nombre || '—'}</td>
                      <td className="py-3 px-4">
                        <span className={`px-2 py-1 rounded-full text-xs font-medium ${e.estado === 'activo' ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'}`}>
                          {e.estado}
                        </span>
                      </td>
                      <td className="py-3 px-4">
                        <button onClick={() => handleToggleEstado(e)}>
                          {e.estado === 'activo'
                            ? <XCircle className="w-5 h-5 text-red-500 hover:text-red-700" />
                            : <CheckCircle className="w-5 h-5 text-green-500 hover:text-green-700" />}
                        </button>
                      </td>
                    </tr>
                  ))}
                  {filtrados.length === 0 && (
                    <tr><td colSpan={6} className="text-center py-8 text-slate-400">Sin resultados</td></tr>
                  )}
                </tbody>
              </table>
            </div>
          )}
        </CardContent>
      </Card>

      {/* Modal */}
      {showModal && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
          <div className="bg-white rounded-xl p-6 w-full max-w-md shadow-xl">
            <h2 className="text-lg font-semibold text-slate-900 mb-4">Nuevo Empleado</h2>
            <div className="space-y-4">
              <div>
                <label className="text-sm font-medium text-slate-700">Nombre completo</label>
                <Input className="mt-1" value={form.nombre} onChange={e => setForm({ ...form, nombre: e.target.value })} />
              </div>
              <div>
                <label className="text-sm font-medium text-slate-700">Email institucional</label>
                <Input className="mt-1" type="email" placeholder="usuario@gobierno.gob.ar" value={form.email} onChange={e => setForm({ ...form, email: e.target.value })} />
              </div>
              <div>
                <label className="text-sm font-medium text-slate-700">Contraseña</label>
                <Input className="mt-1" type="password" value={form.password} onChange={e => setForm({ ...form, password: e.target.value })} />
              </div>
              <div>
                <label className="text-sm font-medium text-slate-700">Rol</label>
                <select className="mt-1 w-full border border-slate-300 rounded-md px-3 py-2 text-sm"
                  value={form.rol} onChange={e => setForm({ ...form, rol: e.target.value })}>
                  <option value="empleado">Empleado</option>
                  <option value="administrador">Administrador</option>
                </select>
              </div>
              <div>
                <label className="text-sm font-medium text-slate-700">Ciudad</label>
                <select className="mt-1 w-full border border-slate-300 rounded-md px-3 py-2 text-sm"
                  value={form.ciudad_id} onChange={e => setForm({ ...form, ciudad_id: e.target.value })}>
                  <option value="">Sin ciudad asignada</option>
                  {ciudades.map(c => <option key={c.id} value={c.id}>{c.nombre}</option>)}
                </select>
              </div>
            </div>
            <div className="flex gap-3 mt-6">
              <Button className="flex-1 bg-blue-700 hover:bg-blue-800" onClick={handleCrear}>Crear Empleado</Button>
              <Button variant="outline" className="flex-1" onClick={() => setShowModal(false)}>Cancelar</Button>
            </div>
          </div>
        </div>
      )}
    </MainLayout>
  </ProtectedRoute>
  );
}