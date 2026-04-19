# Portal de Certificados de Deudor Alimenticio

**Autores:** Matias Oliver 

---

## Descripción

Sistema web fullstack para la gestión de certificados de deudores alimenticios. Permite a ciudadanos solicitar y descargar certificados de manera digital, a empleados municipales gestionar el flujo de trabajo vía un tablero Kanban, y a administradores supervisar todo el sistema.

---

## Stack tecnológico

### Backend
| Tecnología | Versión | Rol |
|---------|------|----------------------|
| Node.js | 22.x | Runtime del servidor |
| Express | 5.x | Framework HTTP y routing |
| PostgreSQL | 17 | Base de datos relacional |
| jsonwebtoken | 9.x | Autenticación con JWT |
| bcrypt | 6.x | Hash de contraseñas |
| nodemailer | 8.x | Envío de OTP por email |
| multer | 2.x | Subida de archivos PDF |
| swagger-jsdoc | 6.x | Documentación de API |
| helmet + cors | latest | Seguridad HTTP |
| express-rate-limit | 8.x | Rate limiting por endpoint |

### Frontend
| Tecnología | Versión | Rol |
|---|---|---|
| Next.js | 16.x | Framework React con App Router |
| React | 19.x | Librería de UI |
| Tailwind CSS | 4.x | Estilos utilitarios |
| Zustand | 5.x | Estado global (auth) |
| Axios | 1.x | Cliente HTTP |
| React Hook Form | 7.x | Manejo de formularios |
| Zod | 4.x | Validación de schemas |
| shadcn/ui | latest | Componentes de UI |
| Sonner | 2.x | Notificaciones toast |

### Infraestructura
| Componente | Descripción |
|---|---|
| Docker + Docker Compose | Orquestación de 4 contenedores |
| PlusPagos mock | Simulador de pasarela de pago en Express (puerto 4000) |
| Swagger UI | Documentación interactiva de la API (puerto 3000/api/docs) |

---

## Arquitectura

El proyecto corre en 4 contenedores Docker orquestados con `docker-compose`:

```
┌─────────────────────────────────────────────────────────────┐
│                      docker-compose                         │
│                                                             │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │ rdam_frontend│    │ rdam_backend │    │rdam_pluspagos│   │
│  │  :3001       │───▶│  :3000       │    │  :4000       │   │
│  │  Next.js     │    │  Express API │◀───│  Mock pago   │  │
│  └──────────────┘    └──────┬───────┘    └──────────────┘  │
│                             │                               │
│                      ┌──────▼───────┐                       │
│                      │ rdam_postgres│                       │
│                      │  :5432       │                       │
│                      │  PostgreSQL  │                       │
│                      └──────────────┘                       │
└─────────────────────────────────────────────────────────────┘
```

### Base de datos

Schema dedicado `portal` con las siguientes tablas:

| Tabla | Descripción |
|---|---|
| `empleados` | Personal con roles `empleado` / `administrador`, email institucional `@gobierno.gob.ar` |
| `solicitudes` | Ciclo de vida completo con 9 estados y numeración automática `CERT-YYYY-XXXXXX` |
| `transacciones` | Registro de pagos vinculados a cada solicitud |
| `certificados` | PDFs emitidos con hash SHA-256, vencimiento a 90 días, número único `CERTIF-YYYY-XXXXXXXX` |
| `otp_sessions` | Tokens de un solo uso para login de ciudadanos |
| `configuracion` | Parámetros del sistema editables por admin |
| `auditoria` | Tabla **inmutable** — todos los cambios quedan registrados con triggers |

---

## Levantar el proyecto

### Requisitos previos
- [Docker Desktop](https://www.docker.com/products/docker-desktop) instalado y corriendo

### Pasos

**1. Descomprimir o clonar el proyecto**

**2. Crear el archivo de variables de entorno del backend**
```bash
# Linux / Mac
cp portal-backend/.env.example portal-backend/.env

# Windows (PowerShell)
Copy-Item portal-backend\.env.example portal-backend\.env
```

**4. Crear el `.env` del frontend**
```bash
# Linux / Mac
echo "NEXT_PUBLIC_API_URL=http://localhost:3000" > portal-frontend/.env.local

# Windows (PowerShell)
echo "NEXT_PUBLIC_API_URL=http://localhost:3000" | Out-File -Encoding utf8 portal-frontend\.env.local
```

**5. Levantar todos los servicios**
```bash
docker-compose up --build
```

**6. Esperar que los 4 contenedores estén listos** (aprox. 1-2 minutos la primera vez)

```
✅ rdam_postgres   — Base de datos PostgreSQL
✅ rdam_backend    — API REST en puerto 3000
✅ rdam_frontend   — Portal web en puerto 3001
✅ rdam_pluspagos  — Pasarela de pago mock en puerto 4000
```

### URLs del sistema

| Servicio | URL |
|---|---|
| Portal web (ciudadano / empleado / admin) | http://localhost:3001 |
| API Backend | http://localhost:3000 |
| Swagger (documentación de API) | http://localhost:3000/api/docs |
| Pasarela de pago mock | http://localhost:4000 |
| Dashboard de transacciones | http://localhost:4000/dashboard |

### Detener el proyecto
```bash
# Solo detener
docker-compose down

# Detener y borrar también los datos de la BD
docker-compose down -v
```

---

## Credenciales de prueba

| Rol | Email | Contraseña |
|---|---|---|
| Administrador | `admin@gobierno.gob.ar` | `Admin2027!` |
| Empleado | `nico.oliver@gobierno.gob.ar` | `nicolas123` |
| Empleado | Se puede generar desde la pantalla admin
| Ciudadano | cualquier email real | OTP por email |

> **Ciudadano:** no tiene contraseña fija. Al ingresar su email y DNI/CUIT recibe un código OTP de 6 dígitos en su casilla. El código es válido por 10 minutos y permite hasta 3 intentos.

---

## Flujos principales

### Ciudadano

1. Ir a http://localhost:3001/login y seleccionar **"Ingresar como ciudadano"**
2. Completar email y DNI/CUIT → presionar **"Enviar código"**
3. Revisar el email y copiar el código OTP de 6 dígitos
4. Ingresarlo en la pantalla de verificación
5. En el dashboard hacer clic en **"Nueva Solicitud"**
6. Completar nombre, DNI/CUIT y ciudad → **"Crear Solicitud"**
7. Hacer clic en **"Ir a Pagar"** para ir a la pasarela PlusPagos
8. Usar una tarjeta de prueba (ver sección siguiente)
9. Una vez aprobado el pago, la solicitud queda en estado `pagada`
10. Cuando un empleado emita el certificado, aparece el botón **"Descargar"**

### Empleado

1. Ir a http://localhost:3001/login con email y contraseña institucional
2. Ver el tablero **Kanban** con columnas: Pagadas / En revisión / Emitidas
3. Hacer clic en una solicitud en estado `pagada` → **"Tomar en revisión"**
4. Revisar los datos → presionar **"Aprobar"** o **"Rechazar"**
5. Si aprueba: **"Subir certificado"** → cargar un PDF → marcar si es deudor alimenticio
6. El ciudadano puede descargar el certificado desde su portal

### Administrador

- Mismo login que el empleado (rol `administrador`)
- Accede al Kanban igual que los empleados
- Panel adicional en http://localhost:3001/admin con:
  - **Gestión de empleados** — crear, activar, desactivar
  - **Reportes y KPIs** — dashboard con métricas del sistema
  - **Configuración** — cambiar monto del certificado, duración OTP, etc.
  - **Auditoría** — historial completo e inmutable de todos los cambios

---

## Tarjetas de prueba (pasarela mock)

| Número | Resultado | Tipo |
|---|---|---|
| `4242 4242 4242 4242` | ✅ Aprobada | Visa |
| `4000 0000 0000 0002` | ❌ Rechazada | Visa |
| `5555 5555 5555 4444` | ✅ Aprobada | Mastercard |
| `5105 1051 0510 5100` | ❌ Rechazada | Mastercard |
| `3782 822463 10005` | ✅ Aprobada | Amex |

- **Fecha de vencimiento:** cualquier fecha futura (ej: `12/28`)
- **CVV:** cualquier número de 3 o 4 dígitos

---

## Endpoints de la API

| Módulo | Endpoints | Descripción |
|---|---|---|
| Auth (OTP + JWT) | 4 | Envío OTP, verificación, login empleado, logout, refresh |
| Ciudades | 5 | Listar, crear, editar, activar/desactivar |
| Solicitudes (ciudadano) | 5 | Crear, listar, cancelar, iniciar pago |
| Empleado (Kanban) | 7 | Listar, tomar revisión, aprobar, rechazar, cambiar prioridad |
| Certificados | 2 | Subir PDF, descargar certificado |
| Admin — Empleados | 8 | CRUD completo de empleados |
| Admin — Reportes y KPIs | 6 | Dashboard, estadísticas por empleado |
| Admin — Configuración | 4 | Leer y actualizar parámetros del sistema |
| Admin — Auditoría | 4 | Historial completo de cambios |
| Pagos (webhook + pasarela) | 3 | Webhook PlusPagos, success/error redirect |
| **Total** | **54** | |

> Documentación interactiva completa en **Swagger**: http://localhost:3000/api/docs

---

## Características destacadas

### Base de datos
- Schema dedicado `portal` con roles de acceso diferenciados (`portal_app` / `portal_readonly`)
- ENUMs de PostgreSQL para todos los estados: solicitudes, empleados, transacciones, deuda
- Triggers automáticos: timestamps, numeración de solicitudes y certificados, auditoría inmutable
- Constraint de negocio: rechazar una solicitud requiere motivo de al menos 10 caracteres
- Índices parciales optimizados para el Kanban y sesiones OTP activas
- Vistas materializadas: `v_solicitudes_completas` y `v_kpis_dashboard`
- Función `obtener_estadisticas_empleado()` para reportes de rendimiento individual

### Seguridad
- JWT con expiración configurable (8 horas por defecto)
- Contraseñas hasheadas con bcrypt (12 rounds)
- Rate limiting diferenciado: 100 req/min general, 5 req/min en endpoints de autenticación
- Helmet para headers HTTP de seguridad
- CORS configurado para aceptar solo el origen del frontend
- OTP de 6 dígitos con expiración de 10 minutos y máximo 3 intentos
- Auditoría inmutable: trigger que impide `UPDATE`/`DELETE` en la tabla de auditoría

### Frontend
- Next.js App Router con rutas protegidas por rol
- Zustand para estado global de autenticación
- Hooks personalizados por dominio (`useKanban`, `useSolicitudes`, `useEmpleados`, etc.)
- Componentes de UI con shadcn/ui + Tailwind CSS
- Notificaciones toast con Sonner

---

## Configuración del sistema (admin)

Parámetros editables desde http://localhost:3001/admin/configuracion:

| Clave | Valor por defecto | Descripción |
|---|---|---|
| `monto_certificado` | `8` (ARS) | Monto a cobrar por cada certificado |
| `duracion_otp_minutos` | `10` | Minutos de validez del código OTP |
| `max_intentos_otp` | `3` | Intentos máximos para validar OTP |
| `dias_vigencia_certificado` | `90` | Días de validez del certificado emitido |
| `metodos_pago_habilitados` | `["tarjeta_credito", "tarjeta_debito", ...]` | Métodos de pago disponibles |
| `email_soporte` | `soporte@gobierno.gob.ar` | Email de contacto para ciudadanos |
