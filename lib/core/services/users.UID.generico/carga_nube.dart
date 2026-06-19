// lib/core/services/users.UID.generico/cargar_nube.dart
import 'package:flutter/widgets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserCampoCargaNubeService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static Map<String, dynamic>? _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }

  static String _fmt(dynamic value) {
    if (value == null) return '';
    if (value is num) {
      final s = value.toString();
      return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
    }
    return value.toString();
  }

  // Función genérica para obtener el campo de cualquier sección
  // <uid>.<seccionGenerica>.<campoGenerico>
  static Future<String> obtenerSaldoOcampo({
    required String fetchCampo, // Nombre de la sección (ej, 'empresa')
    required String saldoCampo, // Nombre del campo (ej, 'saldo')
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('Usuario no autenticado');
    }

    final snap = await _db.collection('users').doc(uid).get();
    final data = _asMap(snap.data());
    final campo = _asMap(data?[fetchCampo]);

    if (campo != null && campo[saldoCampo] != null) {
      return campo[saldoCampo].toStringAsFixed(
        2,
      ); // Retorna el saldo formateado
    } else {
      throw Exception('Campo no encontrado');
    }
  }

  // Hacemos público el método _fetchCampo
  static Future<Map<String, dynamic>?> fetchCampo(String nombreCampo) async {
    print('☁️ [NUBE] Cargando campo "$nombreCampo"...');
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      print('❌ [NUBE] Usuario no autenticado.');
      return null;
    }
    final snap = await _db.collection('users').doc(uid).get();
    final data = _asMap(snap.data());
    final campo = _asMap(data?[nombreCampo]);
    if (campo == null || campo.isEmpty) {
      print('⚠️ [NUBE] No hay datos para campo "$nombreCampo".');
    } else {
      print('✅ [NUBE] Campo "$nombreCampo" cargado.');
    }
    return campo;
  }

  /// ✅ Genérico: la page pasa sus controllers (clave -> controller)
  /// y este método los rellena si existen en la nube.
  static Future<void> fillControllersByKeys({
    required String nombreCampo,
    required Map<String, TextEditingController> ctrls,
  }) async {
    print('🖊️ [NUBE] Rellenando controllers para campo "$nombreCampo"...');
    final mapa = await fetchCampo(nombreCampo);
    if (mapa == null || mapa.isEmpty) {
      print('⚠️ [NUBE] Nada que rellenar en controllers.');
      return;
    }

    for (final entry in ctrls.entries) {
      final key = entry.key;
      if (!mapa.containsKey(key)) continue;
      final value = mapa[key];
      if (value == null) continue;
      entry.value.text = _fmt(
        value,
      ); // funciona con TextEditingController y NumberEditingController
      print('🖊️ [NUBE] Controller "$key" rellenado con valor "$value".');
    }
  }
}

/* Ejemplo de uso:

void initState() {
  super.initState();
  _baseFareCtrl = NumberEditingController(allowDecimal: true, decimalPlaces: 2);
  _baseKmCtrl   = NumberEditingController(allowDecimal: true, decimalPlaces: 2);

  // Cargar datos desde la NUBE y llenar los campos
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await UserCampoCargaNubeService.fillControllersByKeys(
      nombreCampo: sectionName,
      ctrls: _ctrls,
    );
  });
}
*/

/* Ejemplo campo especifico: <uid>.<seccionGenerica>.<campoGenerico>
String saldoDisponible = "0.00";  // Inicia con un valor predeterminado

@override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final saldo = await UserCampoCargaNubeService.obtenerSaldoOcampo(
          fetchCampo: 'empresa',  // El nombre de la sección
          saldoCampo: 'saldo',    // El campo a obtener
        );

        setState(() {
          saldoDisponible = saldo; // Actualiza el saldo en el estado
        });
      } catch (e) {
        print("Error al obtener saldo: $e");
      }
    });
  }
  ...
  Text('Saldo: \$${saldoDisponible}'), // Muestra el saldo en la UI
*/
