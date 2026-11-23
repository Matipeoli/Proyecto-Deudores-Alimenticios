'use client';
import MainLayout from '@/components/layout/MainLayout';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { Toaster } from '@/components/ui/sonner';
import { useKanban } from '@/hooks/useKanban';
import { Search, AlertTriangle, Flag } from 'lucide-react';
import ProtectedRoute from '@/components/layout/ProtectedRoute';

export default function EmpleadoKanban() {
  const {
    loading, selected, setSelected,
    showDetalle, setShowDetalle,
    showRechazar, setShowRechazar,
    showCertificado, setShowCertificado,
    motivo, setMotivo,
    pdfFile, setPdfFile,
    esDeudor, setEsDeudor,
    buscar, setBuscar,
    columnas, getSolicitudesByEstado,
    handleAprobar, handleRechazar,
    handleSubirCertificado, handleCambiarPrioridad,
    montoDeuda, setMontoDeuda,
    handleTomarRevision,
  } = useKanban();

  return (
    <ProtectedRoute roles={['administrador', 'empleado']}>
      <MainLayout>
        <Toaster position="top-right" />

        <div className="mb-6 flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-bold text-slate-900">Kanban de Solicitudes</h1>
            <p className="text-slate-500 mt-1">Gestión del flujo de trabajo</p>
          </div>
          <div className="relative w-72">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
            <Input placeholder="Buscar solicitud..." className="pl-9" value={buscar} onChange={e => setBuscar(e.target.value)} />
          </div>
        </div>

        {loading ? (
          <p className="text-slate-500 text-center py-16">Cargando...</p>
        ) : (
          <div className="grid grid-cols-3 gap-6">
            {columnas.map(({ key, label, color, bg }) => {
              const items = getSolicitudesByEstado(key);
              return (
                <div key={key} className="bg-slate-100 rounded-xl p-4 min-h-96">
                  <div className="flex items-center justify-between mb-4">
                    <h3 className={`font-semibold ${color}`}>{label}</h3>
                    <span className={`${bg} ${color} text-xs font-bold px-2 py-1 rounded-full`}>
                      {items.length}
                    </span>
                  </div>
                  <div className="space-y-3">
                    {items.map(s => (
                      <div key={s.id}
                        onClick={() => { setSelected(s); setShowDetalle(true); }}
                        className={`bg-white rounded-lg p-3 shadow-sm cursor-pointer hover:shadow-md transition-all border-l-4 ${s.prioridad === 'urgente' ? 'border-amber-400' : 'border-transparent'}`}>
                        <div className="flex items-start justify-between mb-2">
                          <span className="text-xs font-mono text-blue-700 font-semibold">{s.numero_solicitud}</span>
                          {s.prioridad === 'urgente' && <AlertTriangle className="w-3.5 h-3.5 text-amber-500" />}
                        </div>
                        <p className="text-sm font-medium text-slate-900">{s.nombre_completo}</p>
                        <p className="text-xs text-slate-500 mt-0.5">{s.cuit_dni}</p>
                        <div className="flex items-center justify-between mt-3 pt-2 border-t border-slate-100">
                          <span className="text-xs text-slate-400">
                            {new Date(s.fecha_solicitud).toLocaleDateString('es-AR')}
                          </span>
                          <button
                            onClick={e => { e.stopPropagation(); handleCambiarPrioridad(s.id); }}
                            className="text-slate-300 hover:text-amber-500 transition-colors">
                            <Flag className="w-3.5 h-3.5" />
                          </button>
                        </div>
                      </div>
                    ))}
                    {items.length === 0 && (
                      <p className="text-center text-slate-400 text-sm py-8">Sin solicitudes</p>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        )}

        {/* Modal Detalle */}
        {showDetalle && selected && (
          <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
            <div className="bg-white rounded-xl p-6 w-full max-w-lg shadow-xl">
              <div className="flex items-center justify-between mb-4">
                <h2 className="text-lg font-semibold text-slate-900">{selected.numero_solicitud}</h2>
                <button onClick={() => setShowDetalle(false)} className="text-slate-400 hover:text-slate-600 text-xl">✕</button>
              </div>
              <div className="space-y-2 text-sm mb-6">
                <div className="flex justify-between"><span className="text-slate-500">Nombre</span><span className="font-medium">{selected.nombre_completo}</span></div>
                <div className="flex justify-between"><span className="text-slate-500">DNI/CUIT</span><span className="font-mono">{selected.cuit_dni}</span></div>
                <div className="flex justify-between"><span className="text-slate-500">Email</span><span>{selected.email}</span></div>
                <div className="flex justify-between"><span className="text-slate-500">Ciudad</span><span>{selected.ciudad_nombre}</span></div>
                <div className="flex justify-between"><span className="text-slate-500">Estado</span>
                  <span className="px-2 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-700">
                    {selected.estado.replace(/_/g, ' ')}
                  </span>
                </div>
                <div className="flex justify-between"><span className="text-slate-500">Prioridad</span>
                  <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${selected.prioridad === 'urgente' ? 'bg-amber-100 text-amber-700' : 'bg-slate-100 text-slate-600'}`}>
                    {selected.prioridad}
                  </span>
                </div>
              </div>
              <div className="flex gap-3">
                {selected.estado === 'pagada' && (
                  <Button className="flex-1 bg-indigo-600 hover:bg-indigo-700"
                    onClick={() => handleTomarRevision(selected.id)}>
                    Tomar en Revisión
                  </Button>
                )}
                {selected.estado === 'en_revision' && (
                  <>
                    <Button className="flex-1 bg-green-600 hover:bg-green-700" onClick={() => handleAprobar(selected.id)}>
                      Aprobar
                    </Button>
                    <Button className="flex-1 bg-red-600 hover:bg-red-700" onClick={() => { setShowDetalle(false); setShowRechazar(true); }}>
                      Rechazar
                    </Button>
                  </>
                )}
                {selected.estado === 'aprobada' && (
                  <Button className="flex-1 bg-blue-700 hover:bg-blue-800" onClick={() => { setShowDetalle(false); setShowCertificado(true); }}>
                    Subir Certificado
                  </Button>
                )}
                <Button variant="outline" className="flex-1" onClick={() => setShowDetalle(false)}>Cerrar</Button>
              </div>
            </div>
          </div>
        )}

        {/* Modal Rechazar */}
        {showRechazar && selected && (
          <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
            <div className="bg-white rounded-xl p-6 w-full max-w-md shadow-xl">
              <h2 className="text-lg font-semibold text-slate-900 mb-4">Rechazar Solicitud</h2>
              <p className="text-sm text-slate-600 mb-3">{selected.numero_solicitud} — {selected.nombre_completo}</p>
              <textarea
                className="w-full border border-slate-300 rounded-lg p-3 text-sm resize-none h-28 focus:outline-none focus:ring-2 focus:ring-blue-500"
                placeholder="Motivo del rechazo (mínimo 10 caracteres)..."
                value={motivo}
                onChange={e => setMotivo(e.target.value)}
              />
              <div className="flex gap-3 mt-4">
                <Button className="flex-1 bg-red-600 hover:bg-red-700" onClick={() => handleRechazar(selected.id)}>Confirmar Rechazo</Button>
                <Button variant="outline" className="flex-1" onClick={() => { setShowRechazar(false); setMotivo(''); }}>Cancelar</Button>
              </div>
            </div>
          </div>
        )}

        {/* Modal Certificado */}
        {showCertificado && selected && (
          <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
            <div className="bg-white rounded-xl p-6 w-full max-w-md shadow-xl">
              <h2 className="text-lg font-semibold text-slate-900 mb-4">Subir Certificado</h2>
              <p className="text-sm text-slate-600 mb-4">{selected.numero_solicitud} — {selected.nombre_completo}</p>
              <div className="space-y-4">
                <div>
                  <label className="text-sm font-medium text-slate-700">Archivo PDF</label>
                  <input type="file" accept=".pdf" className="mt-1 w-full text-sm text-slate-600 border border-slate-300 rounded-lg p-2"
                    onChange={e => setPdfFile(e.target.files[0])} />
                </div>
                <div className="flex items-center gap-3">
                  <input type="checkbox" id="es_deudor" checked={esDeudor} onChange={e => setEsDeudor(e.target.checked)} className="w-4 h-4" />
                  <label htmlFor="es_deudor" className="text-sm text-slate-700">¿Es deudor alimenticio?</label>
                </div>
                {esDeudor && (
                  <div>
                    <label className="text-sm font-medium text-slate-700">Monto de deuda</label>
                    <Input className="mt-1" type="number" placeholder="Ej: 15000"
                      value={montoDeuda} onChange={e => setMontoDeuda(e.target.value)} />
                  </div>
                )}
              </div>
              <div className="flex gap-3 mt-6">
                <Button className="flex-1 bg-blue-700 hover:bg-blue-800" onClick={() => handleSubirCertificado(selected.id)}>Emitir Certificado</Button>
                <Button variant="outline" className="flex-1" onClick={() => { setShowCertificado(false); setPdfFile(null); }}>Cancelar</Button>
              </div>
            </div>
          </div>
        )}
      </MainLayout>
    </ProtectedRoute>
  );
}