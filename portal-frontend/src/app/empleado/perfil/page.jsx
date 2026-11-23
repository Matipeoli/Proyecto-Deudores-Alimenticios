'use client';
import MainLayout from '@/components/layout/MainLayout';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { Toaster } from '@/components/ui/sonner';
import { usePerfil } from '@/hooks/usePerfil';
import ProtectedRoute from '@/components/layout/ProtectedRoute';
import useAuthStore from '@/store/authStore';
import { KeyRound, User } from 'lucide-react';

export default function EmpleadoPerfil() {
  const { form, setForm, loading, handleCambiarPassword } = usePerfil();
  const { user } = useAuthStore();

  return (
    <ProtectedRoute roles={['administrador', 'empleado']}>
      <MainLayout>
        <Toaster position="top-right" />
        <div className="mb-8">
          <h1 className="text-2xl font-bold text-slate-900">Mi Perfil</h1>
          <p className="text-slate-500 mt-1">Configuración de tu cuenta</p>
        </div>

        <div className="grid gap-6 max-w-xl">
          {/* Info */}
          <Card>
            <CardHeader>
              <CardTitle className="text-base flex items-center gap-2">
                <User className="w-4 h-4" /> Información
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-3 text-sm">
              <div className="flex justify-between">
                <span className="text-slate-500">Nombre</span>
                <span className="font-medium">{user?.nombre}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-500">Email</span>
                <span className="font-medium">{user?.email}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-500">Rol</span>
                <span className="font-medium capitalize">{user?.rol}</span>
              </div>
            </CardContent>
          </Card>

          {/* Cambiar contraseña */}
          <Card>
            <CardHeader>
              <CardTitle className="text-base flex items-center gap-2">
                <KeyRound className="w-4 h-4" /> Cambiar Contraseña
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div>
                <label className="text-sm font-medium text-slate-700">Contraseña actual</label>
                <Input className="mt-1" type="password" value={form.password_actual}
                  onChange={e => setForm({ ...form, password_actual: e.target.value })} />
              </div>
              <div>
                <label className="text-sm font-medium text-slate-700">Nueva contraseña</label>
                <Input className="mt-1" type="password" value={form.password_nuevo}
                  onChange={e => setForm({ ...form, password_nuevo: e.target.value })} />
              </div>
              <div>
                <label className="text-sm font-medium text-slate-700">Confirmar nueva contraseña</label>
                <Input className="mt-1" type="password" value={form.password_confirmar}
                  onChange={e => setForm({ ...form, password_confirmar: e.target.value })} />
              </div>
              <Button className="w-full bg-blue-700 hover:bg-blue-800"
                onClick={handleCambiarPassword} disabled={loading}>
                {loading ? 'Guardando...' : 'Cambiar Contraseña'}
              </Button>
            </CardContent>
          </Card>
        </div>
      </MainLayout>
    </ProtectedRoute>
  );
}