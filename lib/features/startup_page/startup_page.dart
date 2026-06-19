// lib/features/home_empresa_features/startup_page/startup_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:buses2/shared/services/login_google/login_google_service.dart';
import 'package:buses2/shared/services/save_traer_firebase/get_datos_genericos.dart';

class StartupPage extends StatefulWidget {
  const StartupPage({super.key});

  @override
  State<StartupPage> createState() => _StartupPageState();
}

class _StartupPageState extends State<StartupPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      // 0) Onboarding (solo una vez por dispositivo)
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getBool('seen_onboarding') ?? false;
      if (!seen) {
        if (!mounted) return;
        Modular.to.navigate('/onboarding');
        return;
      }

      // 1) Autenticación
      final auth = Modular.get<LoginService>();
      final user = auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        Modular.to.navigate('/login'); // ajusta si tu ruta de auth es distinta
        return;
      }

      // 2) Verificar si es un logout manual
      final manualLogout = prefs.getBool('manual_logout') ?? false;
      if (manualLogout) {
        // Limpiar la bandera y forzar selección
        await prefs.remove('manual_logout');
        if (!mounted) return;
        Modular.to.navigate('/user-type-selection');
        return;
      }

      // 3) Verificar si el documento de pasajeros realmente existe
      final pasajeroData = await GetDatosGenericos.traerDoc(
        absoluteDocPath: 'pasajeros/{uid}',
      );

      // Si el documento no existe, ir a selección de tipo de usuario
      if (pasajeroData == null || pasajeroData.isEmpty) {
        if (!mounted) return;
        Modular.to.navigate('/user-type-selection');
        return;
      }

      // 4) Si existe, decidir por modo en pasajeros/{uid}
      final modo = await GetDatosGenericos.traerCampo<String>(
        absoluteDocPath: 'pasajeros/{uid}',
        nombreMap: '@root',
        nombreCampo: 'modo',
      );

      if (!mounted) return;

      switch ((modo ?? '').trim().toLowerCase()) {
        case 'taxista':
          // cambiar modo en SharedPreferences
          try {
            await prefs.setString('modo', 'taxista');
          } catch (_) {}
          Modular.to.navigate('/startup-taxista');
          break;
        case 'empresa':
          Modular.to.navigate('/startup-empresa');
          break;
        case 'pasajero':
        case '':
        default:
          // cambiar modo en SharedPreferences
          try {
            await prefs.setString('modo', 'pasajero');
          } catch (_) {}

          // Verificar si tiene datos completos antes de ir a home
          final perfil = pasajeroData['perfil'] as Map<String, dynamic>?;
          final datosCompletos = perfil?['datosCompletos'] == true;

          final telefono = perfil?['telefono'];
          final tieneTelefono =
              telefono != null && telefono.toString().isNotEmpty;

          final genero = perfil?['genero'];
          final tieneGenero = genero != null && genero.toString().isNotEmpty;

          final departamento = perfil?['departamento'];
          final tieneDepartamento =
              departamento != null && departamento.toString().isNotEmpty;

          print(
            'DEBUG: datosCompletos=$datosCompletos, telefono=$telefono, genero=$genero, departamento=$departamento',
          );

          if (!datosCompletos ||
              !tieneTelefono ||
              !tieneGenero ||
              !tieneDepartamento) {
            print('DEBUG: Redirigiendo a passenger-data porque faltan datos');
            Modular.to.navigate('/passenger-data');
          } else {
            print('DEBUG: Datos completos, yendo a home');
            Modular.to.navigate('/home');
          }
          break;
      }
    } catch (e) {
      // fallback razonable si algo falla (sin conexión, reglas, etc.)
      if (!mounted) return;
      Modular.to.navigate('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
