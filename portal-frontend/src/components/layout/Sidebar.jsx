'use client';
import { usePathname, useRouter } from 'next/navigation';
import { useAuth } from '@/hooks/useAuth';
import useAuthStore from '@/store/authStore';
import {
  LayoutDashboard, FileText, Users, Settings,
  ClipboardList, BarChart3, LogOut, Shield, User
} from 'lucide-react';
import { useEffect } from 'react';
import Link from 'next/link';

const navAdmin = [
  { label: 'Dashboard', href: '/admin', icon: LayoutDashboard },
  { label: 'Solicitudes', href: '/admin/solicitudes', icon: FileText },
  { label: 'Empleados', href: '/admin/empleados', icon: Users },
  { label: 'Reportes', href: '/admin/reportes', icon: BarChart3 },
  { label: 'Configuracion', href: '/admin/configuracion', icon: Settings },
];

const navEmpleado = [
  { label: 'Kanban', href: '/empleado', icon: ClipboardList },
  { label: 'Mis Solicitudes', href: '/empleado/solicitudes', icon: FileText },
  { label: 'Mi Perfil', href: '/empleado/perfil', icon: User },
];

const navCiudadano = [
  { label: 'Mis Solicitudes', href: '/ciudadano', icon: FileText },
];

export default function Sidebar() {
  const pathname = usePathname();
  const { logout } = useAuth();
  const { user, loadFromStorage } = useAuthStore();

  useEffect(() => {
    loadFromStorage();
  }, []);
  const nav = user?.rol === 'administrador' ? navAdmin
    : user?.rol === 'empleado' ? navEmpleado
    : navCiudadano;

  return (
    <aside className="w-64 bg-white border-r border-slate-200 flex flex-col fixed h-full">
      {/* Logo */}
      <div className="p-6 border-b border-slate-200">
        <div className="flex items-center gap-3">
          <div className="w-8 h-8 bg-blue-700 rounded-lg flex items-center justify-center">
            <Shield className="w-4 h-4 text-white" />
          </div>
          <div>
            <p className="font-bold text-slate-900 text-sm">Portal Certificados</p>
            <p className="text-xs text-slate-500">Gobierno Argentina</p>
          </div>
        </div>
      </div>

      {/* Nav */}
      <nav className="flex-1 p-4 space-y-1">
        {nav.map(({ label, href, icon: Icon }) => {
          const active = pathname === href;
          return (
            <Link key={href} href={href}
              className={`flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm transition-all
                ${active
                  ? 'bg-blue-50 text-blue-700 font-medium border-l-4 border-blue-700 pl-2'
                  : 'text-slate-600 hover:bg-slate-50 hover:text-slate-900'
                }`}>
              <Icon className="w-4 h-4" />
              {label}
            </Link>
          );
        })}
      </nav>

      {/* Footer */}
      <div className="p-4 border-t border-slate-200">
        <div className="flex items-center gap-3 mb-3">
          <div className="w-8 h-8 rounded-full bg-blue-600 flex items-center justify-center text-white text-sm font-semibold">
            {user?.nombre?.charAt(0) || 'U'}
          </div>
          <div className="flex-1 min-w-0">
            <p className="text-sm font-medium text-slate-900 truncate">{user?.nombre}</p>
            <p className="text-xs text-slate-500 capitalize">{user?.rol}</p>
          </div>
        </div>
        <button onClick={logout}
          className="w-full flex items-center gap-2 px-3 py-2 text-sm text-slate-600 hover:text-red-600 hover:bg-red-50 rounded-lg transition-all">
          <LogOut className="w-4 h-4" />
          Cerrar sesión
        </button>
      </div>
    </aside>
  );
}