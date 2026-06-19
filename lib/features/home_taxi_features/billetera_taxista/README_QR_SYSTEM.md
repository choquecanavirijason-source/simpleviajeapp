# Sistema de QR de Recarga - Documentación

## 📋 Resumen

Sistema completo para gestionar el QR de recarga desde un admin React y mostrarlo en tiempo real a los taxistas en la app Flutter.

## 🏗️ Arquitectura

```
┌─────────────────┐
│  Admin React    │ ──► Sube imagen QR a Firebase Storage
│                 │ ──► Guarda URL en Firestore
└─────────────────┘
         │
         ▼
┌─────────────────┐
│  Firestore DB   │
│  qr_recarga/    │
│    └─ activo    │ ◄── Stream en tiempo real
└─────────────────┘
         │
         ▼
┌─────────────────┐
│  App Flutter    │ ──► Taxista ve QR actualizado
│  (Taxista)      │     automáticamente
└─────────────────┘
```

## 📁 Estructura de Archivos

### Flutter (App del Taxista)

```
lib/features/home_taxi_features/billetera_taxista/
├── scripts/
│   ├── inicializar_qr.dart         # Modelo y repositorio
│   └── REACT_ADMIN_GUIDE.md        # Guía completa React
└── widgets/
    └── qr_recarga_widget.dart      # UI para mostrar QR
```

### Firestore

```
qr_recarga/
  └── activo/                       # Documento con ID fijo
      ├── imageUrl: string          # URL de Firebase Storage
      ├── descripcion: string       # Texto para el taxista
      ├── creadoPor: string         # Email del admin
      ├── fechaCreacion: timestamp
      ├── fechaActualizacion: timestamp
      ├── activo: boolean           # true
      └── version: number           # Incrementa con cada cambio

qr_recarga/historial/versiones/    # Historial automático
  └── [auto-id]/
      └── (mismos campos + archivadoEn)
```

## 🚀 Uso Rápido

### En Flutter (Taxista)

```dart
// Opción 1: Página completa
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const QRRecargaPage(),
  ),
);

// Opción 2: Modal/Bottom Sheet
showModalBottomSheet(
  context: context,
  builder: (context) => const QRRecargaWidget(),
);

// Opción 3: Stream directo
StreamBuilder<QRRecargaModel?>(
  stream: QRRecargaRepository.streamQRActivo(),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return CircularProgressIndicator();
    final qr = snapshot.data!;
    return Image.network(qr.imageUrl);
  },
)
```

### En React (Admin)

```jsx
import QRManager from './components/QRManager';

function AdminPanel() {
  return (
    <div>
      <h1>Panel de Administración</h1>
      <QRManager />
    </div>
  );
}
```

## 🔧 Configuración Inicial

### 1. Firebase Storage (Reglas)

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /qr_recarga/{filename} {
      // Solo admins pueden subir
      allow write: if request.auth != null && 
                      request.auth.token.rol == 'admin';
      
      // Todos los autenticados pueden leer
      allow read: if request.auth != null;
      
      // Validar imagen < 5MB
      allow write: if request.resource.size < 5 * 1024 * 1024 &&
                      request.resource.contentType.matches('image/.*');
    }
  }
}
```

### 2. Firestore (Reglas)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /qr_recarga/{document=**} {
      // Taxistas solo leen
      allow read: if request.auth != null && 
                     request.auth.token.rol == 'taxista';
      
      // Admins leen y escriben
      allow read, write: if request.auth != null && 
                            request.auth.token.rol == 'admin';
    }
  }
}
```

### 3. Inicializar (Primera vez)

```dart
// Ejecutar una sola vez
await inicializarQRRecarga();
```

## 📱 Características

### En la App Flutter

✅ **Actualización en tiempo real** - El taxista ve el QR más reciente automáticamente
✅ **Manejo de errores** - Muestra mensajes claros si no hay QR o hay error
✅ **UI profesional** - Diseño limpio con instrucciones claras
✅ **Historial** - Guarda versiones anteriores automáticamente
✅ **Estado de carga** - Muestra progress indicator mientras carga

### En el Admin React

✅ **Subida de imágenes** - Drag & drop o selector
✅ **Preview** - Vista previa antes de subir
✅ **Validación** - Solo imágenes < 5MB
✅ **Descripción** - Texto personalizable para taxistas
✅ **Ver QR actual** - Muestra la versión activa
✅ **Versiones** - Sistema de versionado automático
✅ **Storage automático** - Elimina imagen anterior al actualizar

## 🔄 Flujo de Actualización

1. **Admin sube nuevo QR** en React:
   ```
   Selecciona imagen → Preview → Escribe descripción → Enviar
   ```

2. **Backend procesa**:
   ```
   Sube a Storage → Guarda en Firestore → Incrementa versión → 
   Archiva anterior → Elimina imagen vieja de Storage
   ```

3. **App Flutter actualiza**:
   ```
   Stream detecta cambio → Descarga nueva imagen → 
   Muestra al taxista → Cache local
   ```

Todo esto ocurre en **tiempo real**, sin que el taxista necesite refrescar.

## 📊 Modelo de Datos

```dart
class QRRecargaModel {
  final String imageUrl;        // URL de Firebase Storage
  final String descripcion;     // Instrucciones para taxista
  final String creadoPor;       // Email del admin
  final DateTime fechaCreacion;
  final DateTime fechaActualizacion;
  final bool activo;            // Siempre true en 'activo'
  final int version;            // Auto-incrementa
}
```

## 🛡️ Seguridad

- ✅ Solo admins autenticados pueden subir QR
- ✅ Validación de tipo de archivo (solo imágenes)
- ✅ Validación de tamaño (máx 5MB)
- ✅ Taxistas solo pueden leer, no escribir
- ✅ URLs firmadas de Firebase Storage
- ✅ Reglas de seguridad en Firestore y Storage

## 📈 Ventajas

1. **Sin código duro** - No hay URLs fijas en el código
2. **Tiempo real** - Cambios instantáneos
3. **Historial** - Recupera versiones anteriores
4. **Escalable** - Funciona con miles de taxistas
5. **Seguro** - Control de acceso granular
6. **Mantenible** - Admin React independiente de la app

## 🐛 Troubleshooting

### El taxista no ve el QR

1. Verificar que hay un documento en `qr_recarga/activo`
2. Revisar que `activo: true`
3. Verificar permisos de Firestore
4. Comprobar URL de Storage

### Error al subir desde Admin

1. Verificar configuración de Firebase en React
2. Revisar reglas de Storage
3. Confirmar que usuario admin tiene claim `rol: 'admin'`
4. Validar que imagen es < 5MB

### Imagen no carga en la app

1. Verificar conexión a internet
2. Revisar URL en Firestore
3. Comprobar reglas de Storage (read permitido)
4. Validar que archivo existe en Storage

## 📚 Referencias

- Guía completa React: `REACT_ADMIN_GUIDE.md`
- Repositorio: `inicializar_qr.dart`
- Widget UI: `qr_recarga_widget.dart`
- Firebase Docs: https://firebase.google.com/docs

## 💡 Próximas Mejoras

- [ ] Programar cambio de QR automático
- [ ] Múltiples QRs para diferentes métodos de pago
- [ ] Analytics de cuántos taxistas ven el QR
- [ ] Notificación push cuando cambia el QR
- [ ] Panel de estadísticas en admin

## Para que el admin haga la correcta gestion y uso de esto 
// En Firestore
usuarios/{taxistaId}/
  └── saldo: number  // Saldo actual del taxista

// Repositorio para manejar saldo
class SaldoTaxistaRepository {
  static Future<void> incrementarSaldo(String taxistaId, double monto) {
    // Solo admin puede ejecutar esto
  }
  
  static Future<void> decrementarSaldo(String taxistaId, double monto) {
    // Cuando el taxista usa su saldo
  }
  
  static Stream<double> streamSaldo(String taxistaId) {
    // Para mostrar saldo en tiempo real
  }
}