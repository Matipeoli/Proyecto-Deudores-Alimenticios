'use client';
import { useState } from 'react';
import { useAuth } from '@/hooks/useAuth';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Toaster } from '@/components/ui/sonner';
import { FileText, Shield, Users } from 'lucide-react';

export default function LoginPage() {
  const { sendOTP, verifyOTP, loginEmpleado, loading } = useAuth();
  const [vista, setVista] = useState('seleccion');
  const [step, setStep] = useState(1);

  const [dni, setDni] = useState('');
  const [email, setEmail] = useState('');
  const [code, setCode] = useState('');
  const [empEmail, setEmpEmail] = useState('');
  const [empPassword, setEmpPassword] = useState('');

  const handleSendOTP = async () => {
    if (!dni || dni.length < 7) return;
    const ok = await sendOTP(dni, email);
    if (ok) setStep(2);
  };

  const handleVerifyOTP = async () => {
    if (!code || code.length !== 6) return;
    await verifyOTP(email, code);
  };

  const handleLoginEmpleado = async () => {
    if (!empEmail || !empPassword) return;
    await loginEmpleado(empEmail, empPassword);
  };

  return (
    <div className="min-h-screen bg-slate-50 flex items-center justify-center p-4">
      <Toaster position="top-right" />
      <div className="w-full max-w-md">

        {/* Logo */}
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center w-14 h-14 bg-blue-700 rounded-xl mb-4">
            <FileText className="w-7 h-7 text-white" />
          </div>
          <h1 className="text-2xl font-bold text-slate-900">Portal de Certificados</h1>
          <p className="text-slate-500 text-sm mt-1">Gobierno de la República Argentina</p>
        </div>

        {/* SELECCIÓN */}
        {vista === 'seleccion' && (
          <div className="space-y-4">
            <p className="text-center text-slate-600 font-medium mb-6">¿Cómo querés ingresar?</p>
            <button onClick={() => setVista('ciudadano')}
              className="w-full flex items-center gap-4 p-5 bg-white rounded-xl border border-slate-200 hover:border-blue-400 hover:shadow-md transition-all text-left">
              <div className="w-12 h-12 bg-blue-100 rounded-lg flex items-center justify-center">
                <Users className="w-6 h-6 text-blue-700" />
              </div>
              <div>
                <p className="font-semibold text-slate-900">Soy Ciudadano</p>
                <p className="text-sm text-slate-500">Solicitar certificado de deudor</p>
              </div>
            </button>
            <button onClick={() => setVista('empleado')}
              className="w-full flex items-center gap-4 p-5 bg-white rounded-xl border border-slate-200 hover:border-blue-400 hover:shadow-md transition-all text-left">
              <div className="w-12 h-12 bg-slate-100 rounded-lg flex items-center justify-center">
                <Shield className="w-6 h-6 text-slate-700" />
              </div>
              <div>
                <p className="font-semibold text-slate-900">Soy Empleado / Admin</p>
                <p className="text-sm text-slate-500">Acceso con credenciales institucionales</p>
              </div>
            </button>
          </div>
        )}

        {/* CIUDADANO */}
        {vista === 'ciudadano' && (
          <Card>
            <CardHeader><CardTitle className="text-lg">Acceso Ciudadano</CardTitle></CardHeader>
            <CardContent className="space-y-4">
              {step === 1 && (
                <>
                  <div className="space-y-2">
                    <Label>DNI</Label>
                    <Input placeholder="Ej: 12345678" value={dni} onChange={e => setDni(e.target.value)} />
                  </div>
                  <div className="space-y-2">
                    <Label>Email</Label>
                    <Input type="email" placeholder="tu@email.com" value={email} onChange={e => setEmail(e.target.value)} />
                  </div>
                  <Button className="w-full bg-blue-700 hover:bg-blue-800" onClick={handleSendOTP} disabled={loading}>
                    {loading ? 'Enviando...' : 'Enviar código'}
                  </Button>
                </>
              )}
              {step === 2 && (
                <>
                  <p className="text-sm text-slate-600">Código enviado a <strong>{email}</strong></p>
                  <div className="space-y-2">
                    <Label>Código OTP</Label>
                    <Input placeholder="123456" maxLength={6} value={code} onChange={e => setCode(e.target.value)} />
                  </div>
                  <Button className="w-full bg-blue-700 hover:bg-blue-800" onClick={handleVerifyOTP} disabled={loading}>
                    {loading ? 'Verificando...' : 'Verificar código'}
                  </Button>
                  <button onClick={() => setStep(1)} className="text-sm text-slate-500 hover:text-slate-700 w-full text-center">
                    ← Volver
                  </button>
                </>
              )}
              <button onClick={() => { setVista('seleccion'); setStep(1); }}
                className="text-sm text-slate-500 hover:text-slate-700 w-full text-center">
                ← Volver al inicio
              </button>
            </CardContent>
          </Card>
        )}

        {/* EMPLEADO */}
        {vista === 'empleado' && (
          <Card>
            <CardHeader><CardTitle className="text-lg">Acceso Institucional</CardTitle></CardHeader>
            <CardContent className="space-y-4">
              <div className="space-y-2">
                <Label>Email institucional</Label>
                <Input type="email" placeholder="usuario@gobierno.gob.ar" value={empEmail} onChange={e => setEmpEmail(e.target.value)} />
              </div>
              <div className="space-y-2">
                <Label>Contraseña</Label>
                <Input type="password" placeholder="••••••••" value={empPassword}
                  onChange={e => setEmpPassword(e.target.value)}
                  onKeyDown={e => e.key === 'Enter' && handleLoginEmpleado()} />
              </div>
              <Button className="w-full bg-blue-700 hover:bg-blue-800" onClick={handleLoginEmpleado} disabled={loading}>
                {loading ? 'Ingresando...' : 'Ingresar'}
              </Button>
              <button onClick={() => setVista('seleccion')}
                className="text-sm text-slate-500 hover:text-slate-700 w-full text-center">
                ← Volver al inicio
              </button>
            </CardContent>
          </Card>
        )}
      </div>
    </div>
  );
}