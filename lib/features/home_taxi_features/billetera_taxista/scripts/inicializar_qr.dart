import 'package:cloud_firestore/cloud_firestore.dart';

/// ============================================================================
/// MODELO DE DATOS PARA QR EN FIRESTORE
/// ============================================================================
///
/// Colección: qr_recarga
/// Documento ID: 'activo' (siempre usar este ID para el QR actual)
///
/// Estructura del documento:
/// {
///   "imageUrl": "https://firebasestorage.googleapis.com/...",
///   "descripcion": "Texto descriptivo",
///   "creadoPor": "admin@example.com",
///   "fechaCreacion": Timestamp,
///   "fechaActualizacion": Timestamp,
///   "activo": true,
///   "version": 1
/// }
/// ============================================================================

class QRRecargaModel {
  final String imageUrl;
  final String descripcion;
  final String creadoPor;
  final DateTime fechaCreacion;
  final DateTime fechaActualizacion;
  final bool activo;
  final int version;

  QRRecargaModel({
    required this.imageUrl,
    required this.descripcion,
    required this.creadoPor,
    required this.fechaCreacion,
    required this.fechaActualizacion,
    this.activo = true,
    this.version = 1,
  });

  factory QRRecargaModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return QRRecargaModel(
      imageUrl: data['imageUrl'] ?? '',
      descripcion: data['descripcion'] ?? '',
      creadoPor: data['creadoPor'] ?? '',
      fechaCreacion:
          (data['fechaCreacion'] as Timestamp?)?.toDate() ?? DateTime.now(),
      fechaActualizacion:
          (data['fechaActualizacion'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      activo: data['activo'] ?? true,
      version: data['version'] ?? 1,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'imageUrl': imageUrl,
      'descripcion': descripcion,
      'creadoPor': creadoPor,
      'fechaCreacion': Timestamp.fromDate(fechaCreacion),
      'fechaActualizacion': Timestamp.fromDate(fechaActualizacion),
      'activo': activo,
      'version': version,
    };
  }
}

/// ============================================================================
/// REPOSITORIO PARA GESTIONAR QR DE RECARGA
/// ============================================================================

class QRRecargaRepository {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'qr_recarga';
  static const String _documentId = 'activo';

  /// Obtener el QR activo actual (para taxistas)
  static Future<QRRecargaModel?> obtenerQRActivo() async {
    try {
      final doc = await _firestore
          .collection(_collection)
          .doc(_documentId)
          .get();

      if (!doc.exists) {
        print('⚠️ No hay QR configurado');
        return null;
      }

      return QRRecargaModel.fromFirestore(doc);
    } catch (e) {
      print('❌ Error al obtener QR: $e');
      return null;
    }
  }

  /// Stream del QR activo (actualización en tiempo real)
  static Stream<QRRecargaModel?> streamQRActivo() {
    return _firestore.collection(_collection).doc(_documentId).snapshots().map((
      doc,
    ) {
      if (!doc.exists) return null;
      return QRRecargaModel.fromFirestore(doc);
    });
  }

  /// Crear o actualizar QR (desde admin)
  /// Esta función será llamada desde el admin de React después de subir la imagen
  static Future<bool> guardarQR({
    required String imageUrl,
    required String descripcion,
    required String creadoPor,
  }) async {
    try {
      // Obtener versión anterior si existe
      final docActual = await _firestore
          .collection(_collection)
          .doc(_documentId)
          .get();

      int nuevaVersion = 1;
      if (docActual.exists) {
        final data = docActual.data() as Map<String, dynamic>;
        nuevaVersion = (data['version'] ?? 0) + 1;

        // Guardar versión anterior en historial
        await _guardarEnHistorial(data, nuevaVersion - 1);
      }

      // Guardar nuevo QR
      await _firestore.collection(_collection).doc(_documentId).set({
        'imageUrl': imageUrl,
        'descripcion': descripcion,
        'creadoPor': creadoPor,
        'fechaCreacion': docActual.exists
            ? (docActual.data() as Map<String, dynamic>)['fechaCreacion']
            : FieldValue.serverTimestamp(),
        'fechaActualizacion': FieldValue.serverTimestamp(),
        'activo': true,
        'version': nuevaVersion,
      });

      print('✅ QR guardado exitosamente - Versión $nuevaVersion');
      return true;
    } catch (e) {
      print('❌ Error al guardar QR: $e');
      return false;
    }
  }

  /// Guardar versión anterior en historial
  static Future<void> _guardarEnHistorial(
    Map<String, dynamic> data,
    int version,
  ) async {
    try {
      await _firestore.collection('$_collection/historial/versiones').add({
        ...data,
        'version': version,
        'archivadoEn': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('⚠️ Error al guardar en historial: $e');
    }
  }

  /// Obtener historial de QRs (opcional, para admin)
  static Future<List<Map<String, dynamic>>> obtenerHistorial() async {
    try {
      final snapshot = await _firestore
          .collection('$_collection/historial/versiones')
          .orderBy('version', descending: true)
          .limit(10)
          .get();

      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    } catch (e) {
      print('❌ Error al obtener historial: $e');
      return [];
    }
  }

  /// Eliminar QR activo (solo admin)
  static Future<bool> eliminarQRActivo(String adminEmail) async {
    try {
      await _firestore.collection(_collection).doc(_documentId).update({
        'activo': false,
        'eliminadoPor': adminEmail,
        'fechaEliminacion': FieldValue.serverTimestamp(),
      });

      print('✅ QR desactivado');
      return true;
    } catch (e) {
      print('❌ Error al eliminar QR: $e');
      return false;
    }
  }
}

/// ============================================================================
/// FUNCIONES LEGACY (mantener compatibilidad)
/// ============================================================================

Future<void> inicializarQRRecarga() async {
  try {
    print('🔄 Inicializando sistema de QR...');

    // Crear estructura inicial si no existe
    await QRRecargaRepository.guardarQR(
      imageUrl: '',
      descripcion:
          'Escanea este QR para realizar tu recarga. El saldo se verá reflejado después de la verificación del administrador.',
      creadoPor: 'sistema',
    );

    print('✅ Sistema de QR inicializado');
  } catch (e) {
    print('❌ Error al inicializar: $e');
    rethrow;
  }
}

Future<void> actualizarQR({String? nuevaUrl, String? nuevaDescripcion}) async {
  try {
    print('🔄 Actualizando QR...');

    if (nuevaUrl != null && nuevaDescripcion != null) {
      await QRRecargaRepository.guardarQR(
        imageUrl: nuevaUrl,
        descripcion: nuevaDescripcion,
        creadoPor: 'admin',
      );
    }

    print('✅ QR actualizado correctamente');
  } catch (e) {
    print('❌ Error al actualizar QR: $e');
    rethrow;
  }
}
