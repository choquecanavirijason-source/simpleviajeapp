// import 'package:buses2/app_module.dart';
// import 'package:flutter_modular/flutter_modular.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:buses2/features/chats/pages/chat_list_page.dart';
import 'package:buses2/features/chats/pages/chat_screen.dart';
import 'package:buses2/features/home/pages/historial_viajes.dart';
import 'package:buses2/features/home/pages/perfil_pasajero_page.dart';
import 'package:buses2/features/home/pages/ver_conductor_page.dart';
import 'package:buses2/features/home/pages/viajes.dart';
import 'package:buses2/features/home/pages/detalle_viaje.dart';
import 'package:buses2/features/home/pages/lugares_guardados_page.dart';
import 'package:buses2/features/home/pages/lugares_tab_page.dart';

import 'package:buses2/features/home_taxi_features/home_taxi/pages/detalle_viaje_taxista.dart';
import 'package:buses2/features/home_taxi_features/home_taxi/pages/billetera_taxista.dart';
import 'package:buses2/features/home_taxi_features/home_taxi/pages/en_camino.dart';
import 'package:buses2/features/home_taxi_features/home_taxi/pages/historial_taxista.dart';
import 'package:buses2/features/home_taxi_features/home_taxi/pages/mapa_taxi.dart';
import 'package:buses2/features/home_taxi_features/home_taxi/pages/solicitudes_taxista.dart';
import 'package:buses2/features/mapa_destino/page/viaje_solicitado.dart';
import 'package:buses2/features/network/no_internet_page.dart';
import 'package:buses2/features/restricted/restricted.dart';

import 'package:buses2/shared/services/auth_service.dart'; // login google
import 'package:buses2/shared/services/phone_auth_service.dart'; // login phone
import 'package:buses2/data/firebase/firebase_auth_service.dart'; // login google
import 'package:buses2/data/firebase/FB_phone_auth_service.dart'; // login phone

import 'package:buses2/shared/services/login_google/login_google_service.dart';
import 'package:buses2/shared/services/login_google/login_google_firebase/login_google_firebase.dart';

import 'features/auth/login_page.dart';
import 'features/auth/user_type_selection_page.dart';
import 'features/auth/passenger_data_page.dart';
import 'features/auth/auth_phone/phone_login_page.dart';
import 'package:buses2/features/onboarding/onboarding_page.dart';
import 'package:buses2/features/startup_page/startup_page.dart';
import 'package:buses2/features/auth/verify_code/verify_code_page.dart';
import 'package:buses2/features/auth/auth_google/google_login_page.dart';
import 'package:buses2/features/home/home_page.dart';
import 'package:buses2/features/mapa_destino/mapa_destino.dart';
import 'package:buses2/features/mapa_origen/mapa_origen.dart';
import 'package:buses2/features/home_empresa_features/home_empresa/home_empresa_page.dart';
import 'package:buses2/features/home_taxi_features/home_taxi/home_taxista_page.dart';
import 'package:buses2/features/home_empresa_features/pantalla_generica/pantalla_generica.dart';
import 'package:buses2/features/home_empresa_features/datos_empresa/perfil_empresa_page.dart';
import 'package:buses2/features/home_empresa_features/taxistas_registrados/taxistas_registrados.dart';
import 'package:buses2/features/home_empresa_features/startup_page/startup_page.dart';
import 'package:buses2/features/home_taxi_features/startup_page/startup_page.dart';
import 'package:buses2/features/home_taxi_features/registro_taxi/registro_taxi.dart';
import 'package:buses2/features/home_taxi_features/datos_taxi/datos_taxi_page.dart';
import 'package:buses2/features/home_taxi_features/perfil_conductor/perfil_conductor_page.dart';
import 'package:buses2/features/home_empresa_features/crear_doc/crear_doc.dart';
import 'package:buses2/features/home_empresa_features/ver_edit_doc/ver_edit_doc.dart';
import 'package:buses2/features/home_taxi_features/documentos/documentos.dart';
import 'package:buses2/features/home_taxi_features/documentos_vehiculo/documentos_vehiculo_page.dart';
import 'package:buses2/features/home_taxi_features/documentos_vehiculo/documentos_nuevos_page.dart';
import 'package:buses2/features/home_taxi_features/pantalla_generica/pantalla_generica.dart';
import 'package:buses2/features/home_empresa_features/taxistas_registrados/widgets/validar_documentos.dart';
import 'package:buses2/features/home_empresa_features/servicios/servicios.dart';
import 'package:buses2/features/home_empresa_features/servicios/page/new_service.dart';
// import 'package:buses2/features/chats/chats.dart';
import 'package:buses2/features/chats/controller/chat_controller.dart';

import 'package:buses2/shared/services/save_traer_firebase/get_queries_filtro.dart';
// TRAER DOCS
import 'package:buses2/core/services/data/traer_docs/traer_docs.dart';
import 'package:buses2/core/services/data/traer_docs/firebase_traer_docs.dart';
import 'package:buses2/core/services/data/local/local_docs_service.dart';

// RECIBIR DOCS
import 'package:buses2/core/services/data/recibir_docs/recibir_docs.dart';
import 'package:buses2/core/services/data/recibir_docs/firebase_recibir_docs.dart';

// SUBIR DOCS
import 'package:buses2/core/services/data/subir_docs/subir_docs.dart';
import 'package:buses2/core/services/data/subir_docs/firebase_subir_docs.dart';
import 'package:buses2/core/services/data/subir_docs/documentos_writer.dart';

// Obtener usuario actual
import 'package:buses2/shared/services/cuenta_user/cuenta_user.dart';
import 'package:buses2/core/services/doc_store/doc_store_cache.dart'; // para caché local

// Guardar documentos
import 'package:buses2/core/services/doc_store/doc_store.dart';

// Obtiene el campo empresa del UID de users
import 'package:buses2/core/services/user_empresa/empresa.dart';

class AppModule extends Module {
  @override
  void binds(Injector i) {
    i.addSingleton<GetQueriesFiltro>(
      GetQueriesFiltro.new,
    ); // Queries con filtros

    i.add<LoginService>(FirebaseLoginService.new); // Login Google

    // Auth
    i.addSingleton<AuthService>(FirebaseAuthService.new);
    i.addSingleton<PhoneAuthService>(FirebasePhoneAuthService.new);

    // Recibir documentos (Firebase)
    i.addSingleton<DocumentosDataSource>(FirebaseDocumentosDataSource.new);

    // TRAER (solo lectura) — usa tu ruta traer_docs
    i.addSingleton<TraerDocs>(FirebaseTraerDocs.new);
    i.addSingleton<LocalDocsService>(LocalDocsService.new);

    // Subir documentos (Firebase)
    i.addSingleton<SubirDocsDataSource>(FirebaseSubirDocsDataSource.new);

    // Guardar documentos (local cache)
    i.addSingleton<DocStoreCache>(DocStoreCache.new);

    // Servicio para obtener el usuario actual
    i.addSingleton<UserAccountPort>(FirebaseUserAccountAdapter.new);
    i.addSingleton<UserAccountService>(
      () => UserAccountService(i.get<UserAccountPort>()),
    );

    // Obtiene el campo empresa del UID de users
    i.addSingleton<EmpresaPort>(FirebaseEmpresaAdapter.new);
    i.addSingleton<EmpresaService>(() => EmpresaService(i.get<EmpresaPort>()));

    // === Guardado de documentos (backend actual: Firebase) ===
    i.addSingleton<DocumentSaverPort>(FirebaseDocumentSaverAdapter.new);
    i.addSingleton<DocStoreService>(
      () => DocStoreService(i.get<DocumentSaverPort>()),
    );

    // Orquestador: usa SubirDocsDataSource por dentro
    i.addSingleton<DocumentosWriter>(
      () => DocumentosWriterImpl(i.get<SubirDocsDataSource>()),
    );

    // Chat controller (singleton) - controlador central para chats
    // i.addSingleton<ChatController>(ChatController.new);
  }

  @override
  void routes(RouteManager r) {
    // Decide a dónde ir onboarding o login 🡆 features/startup_page/startup_page.dart';
    r.child('/', child: (context) => const StartupPage());
    // Ruta raíz va al onboarding 🡆 features/onboarding/onboarding_page.dart';
    r.child('/onboarding', child: (context) => const OnboardingPage());
    // Ruta para el login 🡆 features/auth/login_page.dart';
    r.child('/login', child: (context) => LoginPage());
    // Ruta para selección de tipo de usuario
    r.child(
      '/user-type-selection',
      child: (_) => const UserTypeSelectionPage(),
    ); // Ruta para datos adicionales del pasajero
    r.child(
      '/passenger-data',
      child: (_) => const PassengerDataPage(),
    ); // Ruta para el login phone 🡆 features/auth/auth_phone/phone_login_page.dart';
    r.child('/phone-login', child: (_) => const PhoneLoginPage());
    // Ruta para verificar code 🡆 features/auth/verify_code/verify_code_page.dart';
    r.child(
      '/verify-code',
      child: (_) => const VerifyCodePage(),
      transition: TransitionType.noTransition, // fadeIn transicion suave
    );
    // Ruta para login_google 🡆 features/auth/auth_google/google_login_page.dart'
    r.child('/google-login', child: (_) => const GoogleLoginPage());
    // Ruta para home 🡆 features/home/home_page.dart
    // Ruta para viajes 🡆 features/home/pages/viajes.dart
    // Ruta para viajes 🡆 features/home/pages/viajes_historial.dart
    r.child(
      '/home',
      child: (_) => const HomePage(),
      children: [
        // Hijo por defecto (cuando entras a /home)
        ChildRoute('/', child: (_) => const ViajesPage()),
        ChildRoute('/viajes', child: (_) => const ViajesPage()),
        ChildRoute(
          '/historial',
          child: (_) {
            final uid = FirebaseAuth.instance.currentUser?.uid;

            if (uid == null || uid.isEmpty) {
              // Pantalla mínima de error inline (sin widget adicional)
              return Scaffold(
                appBar: AppBar(title: const Text('Mis viajes')),
                body: const Center(
                  child: Text(
                    'No hay sesión activa. Inicia sesión para ver tu historial.',
                  ),
                ),
              );
            }

            // 👇 IMPORTANTE: sin `const` porque el uid es dinámico
            return HistorialViajesPage(uidPasajero: uid);
          },
        ),
        ChildRoute('/perfil', child: (_) => const PerfilPasajeroPage()),
        // ❌ Billetera eliminada para pasajeros - solo disponible para taxistas en /billetera_taxista
        ChildRoute('/detalles-viaje', child: (_) => const DetallesViaje()),
        ChildRoute(
          '/lugares-guardados',
          child: (_) => const LugaresGuardadosPage(),
        ),
        ChildRoute('/lugares', child: (_) => const LugaresTabPage()),
        ChildRoute('/chats', child: (_) => ChatListPage()),

        ChildRoute(
          '/chat/detail',
          child: (_) {
            final args = Modular.args.data as Map<String, dynamic>?;

            if (args == null) {
              return Scaffold(
                appBar: AppBar(title: const Text('Chat')),
                body: const Center(
                  child: Text('No se recibieron datos del chat'),
                ),
              );
            }

            return ChatScreen(
              chatId: args['chatId'],
              otherUid: args['otherUid'],
              otherName: args['otherName'],
              otherPhotoUrl: args['otherPhotoUrl'] ?? '', // opcional
            );
          },
        ),
      ],
    );

    // De Home a Mapa 🡆 features/mapa/mapa_page.dart
    r.child('/mapa-destino', child: (_) => const MapaDestino());
    r.child('/mapa-origen', child: (_) => const MapaOrigen());

    // De Hometaxista a MapaTaxi 🡆 features/home_taxi_features/home_taxi/pages/mapa_taxi.dart
    r.child('/mapa-taxi', child: (_) => const MapaTaxi());
    // De Hometaxista a EnCamino 🡆 features/home_taxi_features/home_taxi/pages/en_camino.dart
    r.child('/en-camino', child: (_) => const EnCaminoPage());
    // De HistorialTaxista a DetallesViajeTaxista 🡆 features/home_taxi_features/home_taxi/pages/detalle_viaje_taxista.dart
    r.child(
      '/detalles-viaje-taxista',
      child: (_) => const DetallesViajeTaxista(),
    );
    // De Home a VerConductor 🡆 features/home/pages/ver_conductor_page.dart
    r.child('/ver-conductor', child: (_) => const VerConductorPage());
    // De Home a HomeEmpresa 🡆 features/home_empresa/home_empresa.dart
    r.child('/empresa', child: (_) => const HomeEmpresa());
    // De Home a HomeTaxista 🡆 features/home_taxista/home_taxista.dart

    r.child(
      '/home-taxista',
      child: (_) => const HomeTaxista(),
      children: [
        // hijo inicial del RouterOutlet
        ChildRoute(
          Modular.initialRoute,
          child: (_) => const SolicitudesTaxistaPage(),
        ),
        ChildRoute(
          '/viajes_taxista',
          child: (_) => const SolicitudesTaxistaPage(),
        ),
        ChildRoute(
          '/historial_taxista',
          child: (_) {
            final uid = FirebaseAuth.instance.currentUser?.uid;
            if (uid == null || uid.isEmpty) {
              return Scaffold(
                appBar: AppBar(title: const Text('Historial (Taxista)')),
                body: const Center(
                  child: Text('No hay sesión activa. Inicia sesión.'),
                ),
              );
            }
            return HistorialTaxistaPage(uidTaxista: uid);
          },
        ),
        ChildRoute(
          '/billetera_taxista',
          child: (_) => const BilleteraTaxistaPage(),
        ),
        ChildRoute(
          '/chats_taxista',
          child: (_) => ChatListPage(mode: 'taxista'),
        ), // Ruta para el BottomNavigationBar
        ChildRoute(
          '/chat/detail',
          child: (_) {
            final args = Modular.args.data as Map<String, dynamic>?;

            if (args == null) {
              return Scaffold(
                appBar: AppBar(title: const Text('Chat')),
                body: const Center(
                  child: Text('No se recibieron datos del chat'),
                ),
              );
            }

            return ChatScreen(
              chatId: args['chatId'],
              otherUid: args['otherUid'],
              otherName: args['otherName'],
              otherPhotoUrl: args['otherPhotoUrl'] ?? '', // opcional
            );
          },
        ),
      ],
    );
    //r.child('/home-taxista', child: (_) => const HomeTaxista());
    // De Home a InfoEmpresa 🡆 features/home_empresa_features/info_empresa/info_empresa_page.dart
    r.child('/pantalla-generica', child: (_) => const GenericPage());
    r.child('/datos-empresa', child: (_) => const DatosEmpresaPage());
    r.child('/taxistas-registrados', child: (_) => TaxistasRegistradosPage());
    r.child('/startup-empresa', child: (_) => const StartupEmpresaPage());
    r.child('/startup-taxista', child: (_) => const StartupTaxiPage());
    r.child('/registro-taxista', child: (_) => const RegistroTaxista());
    r.child(
      '/documentos-vehiculo',
      child: (_) => const DocumentosVehiculoPage(),
    );
    r.child('/documentos-nuevos', child: (_) => const DocumentosNuevosPage());
    r.child('/datos-taxi', child: (_) => const DatosTaxiPage());
    r.child('/perfil-conductor', child: (_) => const PerfilConductorPage());
    r.child('/crear-documentos', child: (_) => const CrearDocPage());
    r.child('/ver-documento', child: (_) => const VerEditDocPage());
    r.child(
      '/documentos-respaldo-taxi',
      child: (_) => const DocumentosRespaldoTaxi(),
    );
    r.child('/page-generica-taxi', child: (_) => const GenericPageTaxi());
    r.child('/validar-documento', child: (_) => const ValidarDocumentosPage());
    r.child('/servicios', child: (_) => const ServiciosPage());
    r.child('/nuevo-servicio', child: (_) => const NewServicePage());

    r.child('/unauthorized', child: (_) => const UnauthorizedPage());

    r.child('/sinconexion', child: (_) => const NoInternetPage());
    r.child('/viaje-solicitado', child: (_) => const ViajeSolicitadoPage());
  }
}

/* Se usa así:
  onPressed: () {
    Modular.to.pushNamed('/chat');
  },
*/
