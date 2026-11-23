'use client';
import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';


export default function ProtectedRoute({ children, roles = [] }) {
  const router = useRouter();
  const [autorizado, setAutorizado] = useState(false);


  useEffect(() => {
    const token = localStorage.getItem('token');
    const userStr = localStorage.getItem('user');

    if (!token || !userStr) {
      router.push('/login');
      return;
    }

    if (roles.length > 0) {
      const user = JSON.parse(userStr);
      if (!roles.includes(user.rol || user.role)) {
        router.push('/login');
        return;
      }
    }
    setAutorizado(true);
  }, []);
  if (!autorizado) return null;
  return children;
}
