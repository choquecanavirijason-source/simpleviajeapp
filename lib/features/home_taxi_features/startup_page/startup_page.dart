// lib/features/home_taxi_features/startup_page/startup_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:buses2/shared/services/save_traer_firebase/get_queries_filtro.dart';
import 'package:buses2/shared/services/save_traer_firebase/save_datos_genericos.dart';
import 'package:buses2/shared/services/save_traer_firebase/get_datos_genericos.dart';
import 'package:buses2/shared/services/save_traer_firebase/lecturas/doc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StartupTaxiPage extends StatefulWidget {
  const StartupTaxiPage({super.key});

  @override
  State<StartupTaxiPage> createState() => _StartupTaxiPageState();
}

class _StartupTaxiPageState extends State<StartupTaxiPage> {
  late final GetQueriesFiltro _queries = Modular.get<GetQueriesFiltro>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _decidirRuta());
  }

  Future<void> _decidirRuta() async {
    try {
      // Verificar que el usuario realmente tiene modo 'taxista' antes de continuar
      // guardo asi   await prefs.setString('modo', 'taxista');
      final prefs = await SharedPreferences.getInstance();
      final modoActual = prefs.getString('modo');

      // Si el usuario NO es taxista, redirigir a user-type-selection
      if (modoActual != 'taxista') {
        debugPrint(
          '⚠️ [StartupTaxiPage] Usuario con modo "$modoActual" intentó acceder a ruta de taxista',
        );
        if (!mounted) return;
        Modular.to.navigate('/user-type-selection');
        return;
      }

      final existeUidEmpresa = (await DocGets.existe(
        absoluteDocPath: ['taxistas/{uid}'],
        nombreMap: ['@root'],
        nombreCampo: [
          {'uidTaxista'}, // Set<String>
        ],
      )).first;

      if (existeUidEmpresa) {
        debugPrint('✅ [StartupTaxiPage] Usuario confirmado como taxista');

        // Verificar si tiene el perfil de taxista completo
        Map<String, dynamic>? perfilTaxista;
        try {
          final res = await DocGets.get(
            absoluteDocPath: ['taxistas/{uid}'],
            nombreMap: ['perfilTaxista'],
            nombreCampo: [
              {'datosCompletos'},
            ],
          );
          perfilTaxista = res.isNotEmpty ? res.first : null;
        } catch (e) {
          debugPrint(
            '🔴 [StartupTaxiPage][_decidirRuta] Error leyendo perfilTaxista: $e',
          );
        }

        final bool perfilCompleto =
            (perfilTaxista != null && perfilTaxista['datosCompletos'] == true);

        debugPrint('🔍 [StartupTaxiPage] perfilTaxista: $perfilTaxista');
        debugPrint('🔍 [StartupTaxiPage] perfilCompleto: $perfilCompleto');

        // Si no tiene perfil completo, ir a registro
        if (!perfilCompleto) {
          if (!mounted) return;
          await Modular.to.pushNamed('/registro-taxista');
          if (!mounted) return;
          Modular.to.navigate('/');
          return;
        }

        // Verificar si los documentos del vehículo están habilitados
        // Obtener el documento completo para verificar documentosVehiculo
        Map<String, dynamic>? documentosVehiculo;
        bool habilitado = false;
        try {
          final taxistaDoc = await FirebaseFirestore.instance
              .collection('taxistas')
              .doc(FirebaseAuth.instance.currentUser?.uid)
              .get();

          if (taxistaDoc.exists) {
            final data = taxistaDoc.data();
            documentosVehiculo =
                data?['documentosVehiculo'] as Map<String, dynamic>?;
            habilitado = documentosVehiculo?['habilitado'] == true;
          }
        } catch (e) {
          debugPrint(
            '🔴 [StartupTaxiPage][_decidirRuta] Error leyendo documentosVehiculo: $e',
          );
        }

        // Verificar si ya subió los documentos (aunque no estén validados)
        // Considerar como "documentos subidos" si el mapa existe y no está vacío
        final bool documentosSubidos =
            documentosVehiculo != null && documentosVehiculo.isNotEmpty;

        debugPrint(
          '🔍 [StartupTaxiPage] documentosVehiculo existe: ${documentosVehiculo != null}, isEmpty: ${documentosVehiculo?.isEmpty ?? true}',
        );
        if (documentosVehiculo != null) {
          debugPrint(
            '🔑 [StartupTaxiPage] Campos encontrados: ${documentosVehiculo.keys.toList()}',
          );
          debugPrint(
            '📊 [StartupTaxiPage] Total campos: ${documentosVehiculo.length}',
          );
        }
        debugPrint('🔍 [StartupTaxiPage] habilitado: $habilitado');
        debugPrint(
          '🔍 [StartupTaxiPage] documentosSubidos: $documentosSubidos',
        );

        if (!mounted) return;

        if (habilitado) {
          debugPrint('✅ [StartupTaxiPage] Navegando a /home-taxista');
          // Documentos validados: ir directo al home del taxista
          Modular.to.navigate('/home-taxista');
        } else if (documentosSubidos) {
          debugPrint(
            '⏳ [StartupTaxiPage] Documentos subidos pero pendientes - Navegando a /home-taxista',
          );
          // Ya subió los documentos, esperando validación del admin
          Modular.to.navigate('/home-taxista');
        } else {
          debugPrint('🟠🟠🟠 STARTUP_PAGE: Navegando a /documentos-vehiculo');
          debugPrint('🟠 Razón: No hay documentos subidos');
          debugPrint(
            '🟠 documentosVehiculo: ${documentosVehiculo?.keys.toList()}',
          );
          debugPrint('🟠 habilitado: $habilitado');
          // Tiene perfil completo pero no documentos: ir al flujo de documentos
          Modular.to.navigate('/documentos-vehiculo');
        }
      } else {
        if (!mounted) return;
        // Usar await para detectar cuando el usuario regresa
        await Modular.to.pushNamed('/registro-taxista');

        // Si el usuario regresó (sin importar el resultado), volver al inicio
        // porque si completó exitosamente, ya navegó a /home-taxista
        if (!mounted) return;
        Modular.to.navigate('/'); // Volver a la página inicial
      }
    } catch (e, st) {
      debugPrint('🔴 [StartupTaxiPage][_decidirRuta][ERROR] $e\n$st');
      if (!mounted) return;
      // Si hay error, intentar ir a registro
      await Modular.to.pushNamed('/registro-taxista');
      // Si el usuario regresó, volver al inicio
      if (!mounted) return;
      Modular.to.navigate('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
