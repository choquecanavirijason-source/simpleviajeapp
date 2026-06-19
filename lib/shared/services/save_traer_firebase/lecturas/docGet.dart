import 'package:cloud_firestore/cloud_firestore.dart';
import '../helpers/placeholders.dart';

import 'package:flutter/foundation.dart';
/* Asi funciona Firebase
*- doc.get() = lectura del doc 1 vez
*- doc.snapshots() = escucha el doc en tiempo real. 1 lectura +1 cada vez que cambia
/- coleccion.get() = lectura de todos los docs 1 vez. 1 lectura por cada doc
/- collection.where(...).get() = mira una colección y devuelve los docs que cumplen el filtro.
  1 lectura por cada doc que devuelve
/- collection.where(...).snapshots() = escucha en tiempo real los docs que cumplen el filtro
  1 lectura por cada doc que devuelve +1 cada vez que cambia alguno
/+ collectionGroup.get() = consulta todas las subcolecciones con un mismo nombre 1 vez.
  1 lectura por cada doc que devuelve
/+ collectionGroup.where(...).get() = consulta todas las subcolecciones con un mismo nombre y devuelve los docs que cumplen el filtro.
  1 lectura por cada doc que devuelve
/+ collectionGroup.where(...).snapshots() = escucha en vivo todas las subcolecciones con un mismo nombre que cumplen el filtro.
  1 lectura por cada doc que devuelve +1 cada vez que cambia alguno
*/
/*
✅ Resumen práctico:
*- doc.get() → una vez, rápido, startup/init.
*- doc.snapshots() → en vivo, se actualiza automáticamente.
/- collection.get() → trae todo (peligroso si hay muchos).
/- collection.where(...).get() → una vez, con filtro.
/- collection.where(...).snapshots() → en vivo, con filtro.
/+ collectionGroup.get() → trae todo de subcolecciones con mismo nombre (peligroso si hay muchos).
/+ collectionGroup.where(...).get() → una vez, con filtro, de subcolecciones con mismo nombre.
/+ collectionGroup.where(...).snapshots() → en vivo, con filtro, de subcolecciones con mismo nombre.
*/

class DocGet {
  static Future<List<Map<String, dynamic>>> documentosGet({
    required List<String>
    rutas, // ej: ["empresas/empresa123", "clientes/cliente456"]
    Map<String, Map<String, String>> reglas =
        const {}, // convierte {empresaID} en valor real
    List<String?>? nombreMapas,
    List<List<String>>? nombreCampos,
    //List<List<String>> campos = const [], // ej: [["nombre", "direccion"], [], ["monto", "estado"]]
    //Source source = Source.serverAndCache, // Leer de server o cache. Server datos más frescos, cache más rápido
    //bool incluirMeta = false, // Te dice si los datos vienen de cache o server
  }) async {
    final resultados = <Map<String, dynamic>>[];

    for (int i = 0; i < rutas.length; i++) {
      // 1) Resolver placeholders (ej: {empresaID}, {uid}, etc.)
      final rutaResuelta = await Placeholders.resolverRuta(
        rutas[i],
        reglas: reglas,
      );
      final ref = FirebaseFirestore.instance.doc(rutaResuelta); // Arma la ruta

      // Lectura puntual del documento
      final snap = await ref.get();
      //  FirebaseFirestore.instance
      //      .collection('NOMBRE_COLECCION')
      //      .doc('ID_DEL_DOC')
      //      .get();

      debugPrint("📄 Doc '$rutaResuelta' existe: ${snap.exists}");

      if (snap.exists) {
        final raw = snap.data() as Map<String, dynamic>?;

        // 1) Base por mapa (guiones) o doc completo
        final selectorMapa = (nombreMapas != null && i < nombreMapas.length)
            ? nombreMapas[i]
            : null;
        final base = CampoUtils.extraerMapaPorGuion(raw, selectorMapa);

        // 2) Filtrado por campos top-level (si se piden)
        final campos = (nombreCampos != null && i < nombreCampos.length)
            ? nombreCampos[i]
            : null;
        final contenido = CampoCampos.filtrar(base, campos);

        resultados.add({
          "path": rutaResuelta,
          "id": snap.id,
          "data": contenido,
        });
      } else {
        resultados.add({
          "path": rutaResuelta,
          "id": ref.id,
          "data": null, // no existe
        });

        // Debug opcional, igual que en tu ejemplo:
        // print("📄 ID: ${snap.id}");
        // print("➡️ Data: ${snap.data()}");
      }
    }

    return resultados;
  }
}

/* Ejemplo de uso:
import 'package:buses2/shared/services/save_traer_firebase/lecturas/docGet.dart';
...
  String? _servicioSeleccionado;
  // (opcional) si prefieres precargar y cachear:
  List<String> _cacheServicios = [];

  @override
  void initState() {
    // Precarga (silenciosa)
    (() async {
      _cacheServicios = await _traerServicios();
      _cacheDepartamentos = await _traerDepartamentos();
      if (mounted) setState(() {});
    })();
  }
...
Future<void> _cargarDatos() async {
  print("⏳ Cargando datos...");
  final docs = await DocGet.documentosGet(
    rutas: [
      "empresas/{empresaID}",
      "clientes/cliente456",
      "prestamos/prestamo789",
    ],
    reglas: {
      'empresaID': {
        'doc': 'pasajeros/{uid}', // 👈 de este doc saco el
        'field': 'uidEmpresa',    // 👈 este campo tiene el ID de la empresa
      },
    },
    nombreMapas: [
      'info-detalles',     // devuelve raw['info'] del 1er doc
      '',         // doc completo del 2º (clave vacía => doc completo)
      'informacion',       //
    ],
    nombreCampos: [
      ['nombre', 'direccion'], // campos específicos para el 1er doc
      [],                     // todos los campos para el 2º doc
      ['monto', 'estado'],    // campos específicos para el 3er doc
    ],
    //source: Source.serverAndCache, // Leer de server o cache. Server datos más frescos, cache más rápido
    //incluirMeta: true, // Te dice si los datos vienen de cache o server
  );
  print("🏢 Empresa encontrada: $docs[0]");
  print("👤 Cliente encontrado: $docs[1]");
  print("💰 Préstamo encontrado: $docs[2]");
}

/* Usar Cache de Pantalla
// Usa cache si ya cargaste antes
final servicios = _cacheServicios.isNotEmpty
    ? _cacheServicios              // ✅ usa caché
    : await _traerServicios();     // ❌ si está vacío, recién lee
if (_cacheServicios.isEmpty) _cacheServicios = servicios; // guarda en caché

if (!mounted) return;

if (servicios.isEmpty) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('No hay servicios disponibles')),
  );
  return;
}
*/
*/

class CampoUtils {
  /// Si path es null/'' => devuelve el doc completo.
  /// Si path = 'a-b-c' => devuelve raw['a']['b']['c'].
  /// No trata el último segmento como "campo": TODO es parte del mapa.
  static dynamic extraerMapaPorGuion(Map<String, dynamic>? raw, String? path) {
    if (raw == null) return null;
    if (path == null || path.trim().isEmpty) return raw;

    dynamic current = raw;
    for (final seg in path.split('-')) {
      if (current is Map<String, dynamic> && current.containsKey(seg)) {
        current = current[seg];
      } else {
        return null;
      }
    }
    return current; // Map, List o valor escalar
  }
}

class CampoCampos {
  /// Si [campos] es null o vacío => devuelve [base] tal cual.
  /// Si [base] es Map => devuelve solo las claves indicadas (si no existen, se omiten).
  /// Si [base] NO es Map (p.ej. List/num/String) y pides campos => devuelve null.
  static dynamic filtrar(dynamic base, List<String>? campos) {
    if (campos == null || campos.isEmpty) return base;
    if (base is! Map<String, dynamic>) return null;

    final out = <String, dynamic>{};
    for (final c in campos) {
      if (c.isEmpty) continue;
      if (base.containsKey(c)) out[c] = base[c];
      // si no existe, simplemente no lo agregamos
    }
    return out;
  }
}
