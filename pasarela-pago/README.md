# 🏦 PlusPagos Mock + Cliente de Prueba

**Summer Campus 2026 - i2T Software Factory**

Simulador de pasarela de pago para aprender integración de pagos online.

---

## 📦 Contenido

```
├── pluspagos-mock-simple/    # Simulador de la pasarela (puerto 3000)
│   ├── server.js             # Servidor principal
│   ├── crypto.js             # Módulo de encriptación
│   └── package.json
│
└── test-pasarela-simple/     # Cliente de prueba (puerto 3012)
    ├── server.js             # Tienda de ejemplo
    ├── crypto.js             # Mismo módulo de encriptación
    └── package.json
```

---

## 🚀 Instalación y Uso

### Paso 1: Instalar dependencias

```bash
# En la carpeta del mock
cd pluspagos-mock-simple
npm install

# En la carpeta del cliente
cd ../test-pasarela-simple
npm install
```

### Paso 2: Iniciar los servidores

**Terminal 1 - Mock (pasarela):**
```bash
cd pluspagos-mock-simple
npm start
```

**Terminal 2 - Cliente (tienda):**
```bash
cd test-pasarela-simple
npm start
```

### Paso 3: Probar

1. Abrí http://localhost:3012 (la tienda)
2. Completá el formulario y hacé clic en "Pagar"
3. Serás redirigido a la pasarela (puerto 3000)
4. Ingresá una tarjeta de prueba
5. Verás el resultado del pago

---

## 💳 Tarjetas de Prueba

| Número | Resultado |
|--------|-----------|
| `4242 4242 4242 4242` | ✅ Aprobada |
| `4000 0000 0000 0002` | ❌ Rechazada |
| `5555 5555 5555 4444` | ✅ Aprobada |
| `5105 1051 0510 5100` | ❌ Rechazada |

**CVV:** Cualquier número de 3 dígitos  
**Vencimiento:** Cualquier fecha futura (ej: 12/25)

---

## 🔑 Configuración

Ambos proyectos deben usar las **mismas credenciales**:

| Parámetro | Valor por defecto |
|-----------|-------------------|
| GUID | `test-merchant-001` |
| Secret Key | `clave-secreta-campus-2026` |

### Cambiar credenciales

**En el mock** (`pluspagos-mock-simple/server.js`):
```javascript
const CONFIG = {
  MERCHANT_GUID: 'mi-nuevo-guid',
  SECRET_KEY: 'mi-nueva-clave',
  // ...
};
```

**En el cliente** (`test-pasarela-simple/server.js`):
```javascript
const CONFIG = {
  MERCHANT_GUID: 'mi-nuevo-guid',      // Debe coincidir
  SECRET_KEY: 'mi-nueva-clave',         // Debe coincidir
  // ...
};
```

También podés cambiar el **Secret Key** desde el Dashboard: http://localhost:3000/dashboard

---

## 🔒 Cómo funciona la encriptación

El módulo `crypto.js` usa **AES-256-CBC** con CryptoJS:

```javascript
const { encryptString, decryptString } = require('./crypto');

// Encriptar
const encrypted = encryptString('mi-texto-secreto', 'mi-clave');

// Desencriptar
const original = decryptString(encrypted, 'mi-clave');
```

**Formato del texto encriptado:** `Base64(IV_16_bytes + Ciphertext)`

---

## 📊 Dashboard

Accedé a http://localhost:3000/dashboard para:

- Ver todas las transacciones
- Cambiar el Secret Key
- Configurar Webhook URL para recibir notificaciones

---

## 🔔 Webhooks

El mock puede enviar notificaciones HTTP POST cuando se procesa un pago.

**Configurar:**
1. Ir al Dashboard
2. Poner tu URL en "Webhook URL" (ej: `http://localhost:3012/webhook`)
3. Guardar

**Payload que recibís:**
```json
{
  "Tipo": "PAGO",
  "TransaccionPlataformaId": "123456",
  "TransaccionComercioId": "TXN-1234567890",
  "Monto": "2500.00",
  "EstadoId": "3",
  "Estado": "REALIZADA",
  "FechaProcesamiento": "2026-01-21T15:30:00.000Z"
}
```

---

## 📝 Flujo de integración

```
┌─────────────┐     1. POST con datos encriptados      ┌─────────────┐
│             │ ─────────────────────────────────────▶ │             │
│   CLIENTE   │                                        │  PASARELA   │
│  (Tu app)   │ ◀───────────────────────────────────── │   (Mock)    │
│             │     4. Redirect a UrlSuccess/Error     │             │
└─────────────┘                                        └─────────────┘
       │                                                      │
       │                                                      │
       │                    2. Usuario                        │
       │                    completa pago                     │
       │                                                      │
       │                                                      │
       │              3. Webhook POST (opcional)              │
       │◀─────────────────────────────────────────────────────│
```

---

## ❓ Troubleshooting

**Error: "Comercio inválido"**
- Verificá que el GUID coincida en ambos proyectos

**Error: "Monto inválido"**
- Verificá que el SECRET_KEY sea el mismo en ambos proyectos
- Asegurate de estar usando el módulo `crypto.js` incluido

**El pago no redirige de vuelta**
- Verificá que el cliente esté corriendo en el puerto correcto
- Revisá las URLs en la configuración

---

## 🎓 Para los alumnos

Este proyecto es ideal para aprender:

1. **Integración de APIs de pago** - Cómo funcionan los flujos de checkout
2. **Encriptación** - AES-256-CBC en la práctica
3. **Webhooks** - Notificaciones servidor a servidor
4. **Redirecciones** - Flujo de usuario entre sistemas

**Ejercicios sugeridos:**
- [ ] Agregar nuevos campos al formulario de pago
- [ ] Implementar una nueva tarjeta de prueba con comportamiento especial
- [ ] Guardar las transacciones en una base de datos SQLite
- [ ] Agregar autenticación al Dashboard
- [ ] Implementar firma HMAC en los webhooks

---

**¡Éxitos en el Campus! 🚀**
