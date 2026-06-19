import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/banner_model.dart';

class BannerService {
  final FirebaseFirestore _firestore;

  /// Caché en memoria de los banners activos durante la sesión
  List<BannerModel>? _cachedBanners;

  BannerService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Stream de banners activos, ordenados por el campo 'order'
  Stream<List<BannerModel>> streamBannersActivos() {
    return _firestore
        .collection('banners')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final banners = snapshot.docs
              .map((doc) => BannerModel.fromFirestore(doc.id, doc.data()))
              .toList();
          // Ordenar en el cliente por el campo 'order'
          banners.sort((a, b) => a.order.compareTo(b.order));
          return banners;
        });
  }

  Future<List<BannerModel>> obtenerBannersActivos({
    bool forceRefresh = false,
  }) async {
    // Si ya tenemos datos en caché y no se pide refrescar, devolverlos.
    if (!forceRefresh && _cachedBanners != null && _cachedBanners!.isNotEmpty) {
      return _cachedBanners!;
    }

    try {
      final snapshot = await _firestore
          .collection('banners')
          .where('isActive', isEqualTo: true)
          .get();

      final banners = snapshot.docs
          .map((doc) => BannerModel.fromFirestore(doc.id, doc.data()))
          .toList();
      // Ordenar en el cliente por el campo 'order'
      banners.sort((a, b) => a.order.compareTo(b.order));

      // Guardar en caché para reutilizar durante la sesión
      _cachedBanners = banners;

      return banners;
    } catch (e) {
      print('Error al obtener banners: $e');
      return [];
    }
  }

  /// Devuelve el caché actual de banners (puede ser null si aún no se cargaron).
  List<BannerModel>? get cachedBanners => _cachedBanners;

  /// Permite limpiar manualmente el caché, por ejemplo tras un logout.
  // void clearCache() {
  //   _cachedBanners = null;
  // }
}
