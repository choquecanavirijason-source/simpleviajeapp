import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import '../../core/services/mapa/mapbox/MarcadorAnimado.dart';
import 'package:buses2/core/services/mapa/mapbox/mapa_widget.dart';
import 'package:buses2/shared/widgets/modal_inferior/modal_inferior2.dart';

import 'package:buses2/shared/widgets/botones/boton.dart';
import 'package:buses2/shared/widgets/botones/btn_fijo_abajo.dart';
import 'package:buses2/features/mapa_destino/widgets/direccion.dart';
import 'package:buses2/core/utils/particionarDireccion.dart';
import 'package:buses2/shared/widgets/overlays/btn_cargando.dart';

class MapaOrigen extends StatefulWidget {
  const MapaOrigen({super.key});

  @override
  State<MapaOrigen> createState() => _MapaOrigenState();
}

class _MapaOrigenState extends State<MapaOrigen> {
  // ✅ controlador modal inferior 1
  final DraggableScrollableController _sheet1Ctrl =
      DraggableScrollableController();

  // ===== Variables recibidas. DIRECCION =====
  double? lat;
  double? lng;
  String? calle;
  String? ciudad;
  String? pais;

  // ✅ NUEVO: departamento
  String? departamento;

  bool _mostrandoTexto = true;
  MarcadorLineType _tipoLinea = MarcadorLineType.linea1;
  double _lineHeight = 50; // tamaño normal de la linea

  double? newLat;
  double? newLng;
  String? newCalle;
  String? newCiudad;
  String? newPais;

  // ✅ NUEVO: departamento confirmado
  String? newDepartamento;

  bool _cargarBtn = true;

  @override
  void initState() {
    super.initState();

    // 🔹 Recuperar los argumentos recibidos desde Modular
    final args = Modular.args.data as Map<String, dynamic>?;

    if (args != null) {
      lat = (args['lat'] as num?)?.toDouble();
      lng = (args['lng'] as num?)?.toDouble();
      calle = args['calle'] as String?;
      ciudad = args['ciudad'] as String?;
      pais = args['pais'] as String?;

      // ✅ NUEVO
      departamento = args['departamento'] as String?;

      debugPrint('📍 Datos recibidos desde ModalInferiorAyB (MapaOrigen):');
      debugPrint('🧭 Calle: $calle');
      debugPrint('🏙️ Ciudad: $ciudad');
      debugPrint('🏛️ Depto: $departamento');
      debugPrint('🌎 País: $pais');
      debugPrint('📍 Coordenadas: $lat, $lng');
    }
  }

  // ===== Modal inferior 1 =====
  double _sheet1Min = 0.20;
  static const double _sheet1Initial = 0.20;
  static const double _sheet1Max = 0.20;

  Future<void> _confirmarPuntoA() async {
    // Guardar los valores actuales del mapa
    newLat = lat;
    newLng = lng;
    newCalle = calle;
    newCiudad = ciudad;
    newPais = pais;

    // ✅ NUEVO
    newDepartamento = departamento;

    debugPrint('✅ Punto de partida confirmado (MapaOrigen):');
    debugPrint('📍 Coordenadas: $newLat, $newLng');
    debugPrint('🏠 Calle: $newCalle');
    debugPrint('🏙️ Ciudad: $newCiudad');
    debugPrint('🏛️ Depto: $newDepartamento');
    debugPrint('🌎 País: $newPais');

    // 🔹 Volver a la pantalla anterior y enviar los datos
    Modular.to.pop({
      'lat': newLat,
      'lng': newLng,
      'calle': newCalle,
      'ciudad': newCiudad,
      'pais': newPais,

      // ✅ NUEVO
      'departamento': newDepartamento,
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldConBottom(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            Modular.to.pop();
          },
        ),
        title: const Text('Elegir destino'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // 1) El mapa queda al fondo. Se puede tocar donde no hay panel encima.
          MapaWidget(
            centerLat: lat ?? -17.3895,
            centerLng: lng ?? -66.1568,

            // Detección de movimiento del mapa
            onMoveStart: () {
              setState(() {
                _cargarBtn = true;
                calle = null;
                ciudad = null;
                pais = null;

                // ✅ opcional: mientras mueve, resetea departamento
                departamento = null;

                _mostrandoTexto = false;
                _tipoLinea = MarcadorLineType.linea2;
                _lineHeight = 35;
              });
            },

            onUbicacionCambiada: (latitud, longitud, direccion) {
              if (direccion == null) return;

              // 🔹 Usa tu función utilitaria para dividir correctamente
              final partes = direccionPorPartes(direccion);

              setState(() {
                lat = latitud;
                lng = longitud;
                calle = partes['calle'];
                ciudad = partes['ciudad'];
                pais = partes['pais'];

                // ✅ NUEVO
                departamento = partes['departamento'];

                _mostrandoTexto = true;
                _tipoLinea = MarcadorLineType.linea1;
                _lineHeight = 50;
                _cargarBtn = false;
              });

              debugPrint('📍 Nueva ubicación del mapa (MapaOrigen):');
              debugPrint('Lat: $lat, Lng: $lng');
              debugPrint('🏠 Calle: $calle');
              debugPrint('🏙️ Ciudad: $ciudad');
              debugPrint('🏛️ Depto: $departamento');
              debugPrint('🌎 País: $pais');
            },
          ),

          // 2️⃣ Marcador animado en el centro del mapa
          MarcadorAnimado(
            line: _tipoLinea,
            lineHeight: _lineHeight,
            tiempoTexto: calle ?? 'Cargando ubicación...',
            textoSecundario: () {
              final parts = <String>[];
              if ((ciudad ?? '').trim().isNotEmpty) parts.add(ciudad!.trim());
              if ((departamento ?? '').trim().isNotEmpty) {
                parts.add(departamento!.trim());
              }
              if ((pais ?? '').trim().isNotEmpty) parts.add(pais!.trim());
              return parts.isEmpty ? '' : parts.join(' - ');
            }(),
            icono: (calle == null)
                ? const WidgetCargandoPro2(size: 28, color: Colors.blue)
                : Icons.place,
            iconColor: Colors.blue,
            lineColor: Colors.blue,
            offsetY: -155,
            mostrarTiempo: _mostrandoTexto,
            mostrarSecundario: _mostrandoTexto,
            mostrarCajaTexto: true,
          ),

          // 2) "Modal" inferior que aparece al abrir, deslizable y NO descartable
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: ModalInferior2(
                controller: _sheet1Ctrl,
                initialChildSize: _sheet1Initial,
                minChildSize: _sheet1Min,
                maxChildSize: _sheet1Max,
                builder: (context, scrollController) {
                  return ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    children: [
                      const SizedBox(height: 8),

                      Text(
                        'Punto de partida',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                              height: 1.1,
                            ),
                      ),
                      Divider(color: Colors.grey[400], thickness: 1),

                      AddressTile(
                        icono: Icons.my_location_rounded,
                        iconColor: Colors.blue,
                        lineaPrincipal: calle ?? 'Ubicación desconocida',
                        lineaSecundaria: () {
                          final parts = <String>[];
                          if ((ciudad ?? '').trim().isNotEmpty) {
                            parts.add(ciudad!.trim());
                          }
                          if ((departamento ?? '').trim().isNotEmpty) {
                            parts.add(departamento!.trim());
                          }
                          if ((pais ?? '').trim().isNotEmpty) {
                            parts.add(pais!.trim());
                          }
                          return parts.isEmpty
                              ? 'Sin información'
                              : parts.join(' - ');
                        }(),
                        onTap: () {},
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),

      // ===== Botón fijo abajo =====
      btnFijoAbajo: Btn_Cargando(
        loading: _cargarBtn,
        borde: BtnBorde.borde1,
        workingLabel: 'Encontrando...',
        overlayColor: Colors.grey,
        spinnerColor: Colors.white,
        child: Boton1(
          label: 'Confirmar Punto de Partida',
          color: BotonColor.color3,
          borde: BotonBorde.borde1,
          iconoIzquierdo: Icons.local_taxi,
          iconoDerecho: Icons.local_taxi,
          onPressed: disableOnLoading(_cargarBtn, _confirmarPuntoA),
        ),
      ),
      colorFondo: const Color(0xFFFFFFFF),
    );
  }
}
