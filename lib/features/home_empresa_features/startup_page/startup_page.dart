// lib/features/home_empresa_features/startup_page/startup_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:buses2/shared/services/save_traer_firebase/get_queries_filtro.dart';
import 'package:buses2/shared/services/save_traer_firebase/save_datos_genericos.dart';

class StartupEmpresaPage extends StatefulWidget {
  const StartupEmpresaPage({super.key});

  @override
  State<StartupEmpresaPage> createState() => _StartupEmpresaPageState();
}

class _StartupEmpresaPageState extends State<StartupEmpresaPage> {
  late final GetQueriesFiltro _queries = Modular.get<GetQueriesFiltro>();

  @override
  void initState() {
    super.initState();
    // Ejecuta la decisión después del primer frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _decidirRuta());
  }

  Future<void> _decidirRuta() async {
    try {
      final empresaId = await _queries.idPrimero(
        coleccion: 'empresas',
        filtros: [Filtro.arrayContiene('uidPropietarios', '{uid}')],
      );

      if (empresaId != null) {
        await SaveDatosGenericos.guardarCampoEnMap(
          absoluteDocPath: 'pasajeros/{uid}', // doc exacto
          nombreMap: '@root', // modo.nombre.etc
          nombreCampo: 'modo', // modo.nombre.etc
          valor: 'empresa', // valor fijo dentro de nombreCampo
        );
        Modular.to.navigate('/empresa');
      } else {
        Modular.to.pushNamed('/unauthorized');
      }
    } catch (e, st) {
      debugPrint('🔴 [_decidirRuta][ERROR] $e\n$st');
      if (!mounted) return;
      Modular.to.pushNamed('/unauthorized');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
