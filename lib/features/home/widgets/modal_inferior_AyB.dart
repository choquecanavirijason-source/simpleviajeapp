// modal_inferior_AyB.dart
// VERSIÓN FINAL - COMPATIBLE CON TU APP
// ✅ Al tocar una sugerencia (estática o dinámica) → va a /mapa-destino con destino precargado
// ✅ PERO ya NO fuerza abrir el Sheet2 (resumen). Deja que el usuario elija el servicio.
// 🔧 Nuevo flag: 'autoDestino': true  (para que MapaDestino trace ruta automáticamente sin abrir Sheet2)

import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:buses2/core/services/google/buscador_google.dart';
import 'package:buses2/core/services/ubicacion_usuario/ubicacion_usuario.dart';
import 'package:buses2/core/utils/particionarDireccion.dart';
import 'package:buses2/shared/widgets/buscadores/buscadores1.dart';
import 'package:buses2/shared/widgets/modal_inferior/modal_inferior3.dart';
import 'package:buses2/shared/widgets/cajas/sugerencias_busqueda/sugerencias_busqueda.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ModalInferiorAyB {
  static Future<void> mostrar({
    required BuildContext context,
    required TextEditingController destinoController,
    double? lat,
    double? lng,
    String? calle,
    String? ciudad,
    String? pais,
    String? departamento,
  }) async {
    final GooglePlacesService googleService = GooglePlacesService();

    String _inferCountryCode(String? pais) {
      final p = (pais ?? '').trim().toLowerCase();
      if (p.contains('argentina')) return 'ar';
      if (p.contains('bolivia')) return 'bo';
      return 'ar'; // default: Argentina (mercado principal)
    }

    // ✅ Copias mutables (para poder cambiar origen dentro del modal)
    double? _lat = lat;
    double? _lng = lng;
    String? _calle = calle;
    String? _ciudad = ciudad;
    String? _pais = pais;
    String? _departamento = departamento;

    final origenController = TextEditingController(
      text: _calle ?? 'Mi ubicación',
    );

    // Resultados dinámicos
    List<Map<String, String>> resultadosOrigen = [];
    List<Map<String, String>> resultadosDestino = [];
    bool cargandoOrigen = false;
    bool cargandoDestino = false;

    // 🔥 LUGARES POPULARES dinámicos según ubicación actual del usuario.
    //   `popularesYaPedidos` evita que se vuelva a pedir en cada rebuild.
    List<Map<String, dynamic>> lugaresPopulares = [];
    bool cargandoPopulares = (_lat != null && _lng != null);
    bool popularesYaPedidos = false;

    // DESTINOS ESTÁTICOS
    final List<SugerenciaEntry> destinosEstaticos = [
      const SugerenciaEntry(
        titulo: 'Plaza 14 de Septiembre',
        subtitulo: 'Cochabamba, Bolivia',
        leadingIcon: Icons.location_city,
        trailingIcon: Icons.directions,
      ),
      const SugerenciaEntry(
        titulo: 'Aeropuerto Internacional Jorge Wilstermann',
        subtitulo: 'Av. Guillermo Killman S/N, Zona Aeropuerto, Bolivia',
        leadingIcon: Icons.flight_takeoff,
        trailingIcon: Icons.directions,
      ),
      const SugerenciaEntry(
        titulo: 'Terminal de Buses Cochabamba',
        subtitulo: 'Cochabamaba, Bolivia',
        leadingIcon: Icons.directions_bus,
        trailingIcon: Icons.directions,
      ),
      const SugerenciaEntry(
        titulo: 'Cristo de la Concordia',
        subtitulo: 'Cochabamba, Bolivia',
        leadingIcon: Icons.photo_camera,
        trailingIcon: Icons.directions,
      ),
      const SugerenciaEntry(
        titulo: 'La Cancha',
        subtitulo: 'Mercado Central, Cochabamba',
        leadingIcon: Icons.shopping_cart,
        trailingIcon: Icons.directions,
      ),
    ];

    // COORDENADAS REALES (coinciden con los títulos)
    final Map<String, Map<String, dynamic>> coordenadasEstaticas = {
      'Plaza 14 de Septiembre': {
        'lat': -17.393785,
        'lng': -66.156964,
        'texto': 'Plaza 14 de Septiembre',
        'calle': 'Plaza 14 de Septiembre',
        'ciudad': 'Cochabamba',
        'pais': 'Bolivia',
      },
      'Aeropuerto Internacional Jorge Wilstermann': {
        'lat': -17.4208,
        'lng': -66.1769,
        'texto': 'Aeropuerto Internacional Jorge Wilstermann',
        'calle': 'Av. Guillermo Killman S/N, Zona Aeropuerto',
        'ciudad': 'Cochabamba',
        'pais': 'Bolivia',
      },
      'Terminal de Buses Cochabamba': {
        'lat': -17.402436427445583,
        'lng': -66.15756358299929,
        'texto': 'Terminal De Buses',
        'calle': 'Av Ayacucho',
        'ciudad': 'Cochabamba',
        'pais': 'Bolivia',
      },
      'Cristo de la Concordia': {
        'lat': -17.384500,
        'lng': -66.135000,
        'texto': 'Cristo de la Concordia',
        'calle': 'Cristo de la Concordia',
        'ciudad': 'Cochabamba',
        'pais': 'Bolivia',
      },
      'La Cancha': {
        'lat': -17.40397245649872,
        'lng': -66.15158206315473,
        'texto': 'La Cancha',
        'calle': 'Mercado La Cancha',
        'ciudad': 'Cochabamba',
        'pais': 'Bolivia',
      },
    };

    await ModalInferior3.show<Map<String, dynamic>>(
      context: context,
      minChildSize: 0.00,
      initialChildSize: 1.0,
      maxChildSize: 1.0,
      contentPadding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      builder: (ctx, sc) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // FUNCIÓN PRINCIPAL: Ir al mapa con destino precargado (estáticos)
            Future<void> irADestinoEstatico(SugerenciaEntry entry) async {
              final datos = coordenadasEstaticas[entry.titulo];
              if (datos == null) return;

              // Validar origen primero
              if (_lat == null || _lng == null) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Obteniendo tu ubicación...'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
                return;
              }

              // Actualizar campo destino
              setModalState(() {
                destinoController.text = entry.titulo;
              });

              // Cerrar modal primero
              if (context.mounted) {
                Navigator.of(context).pop();
              }

              await Future.delayed(const Duration(milliseconds: 100));

              Modular.to.pushNamed(
                '/mapa-destino',
                arguments: {
                  // Origen
                  'lat': _lat,
                  'lng': _lng,
                  'calle': _calle ?? 'Mi ubicación actual',
                  'ciudad': _ciudad ?? '',
                  'pais': _pais ?? 'Bolivia',
                  'departamento': _departamento,

                  // Destino
                  'destinoLat': datos['lat'],
                  'destinoLng': datos['lng'],
                  'destinoTexto': datos['texto'],
                  'destinoCalle': datos['calle'],
                  'destinoCiudad': datos['ciudad'],
                  'destinoPais': datos['pais'],

                  // ✅ NUEVO: traza automáticamente (cuando ajustes MapaDestino)
                  'autoDestino': true,

                  // ❌ YA NO ABRIMOS el resumen automático
                  'openSheet2': false,
                },
              );
            }

            // FUNCIÓN: Ir al mapa con destino precargado (dinámicos Google)
            Future<void> irADestinoDinamico(SugerenciaEntry entry) async {
              final placeId = entry.placeId ?? '';
              if (placeId.isEmpty) return;

              // Validar origen primero
              if (_lat == null || _lng == null) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Obteniendo tu ubicación...'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
                return;
              }

              // Mostrar loading en el modal
              setModalState(() {
                cargandoDestino = true;
              });

              try {
                // Obtener coordenadas
                final coords = await googleService.obtenerCoordenadas(placeId);

                if (coords == null) {
                  if (context.mounted) {
                    setModalState(() {
                      cargandoDestino = false;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No se pudo obtener la ubicación'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                  return;
                }

                // Coordenadas como double
                final destinoLat = (coords['lat'] as num).toDouble();
                final destinoLng = (coords['lng'] as num).toDouble();

                // Obtener departamento más confiable desde Mapbox usando lat/lng
                final ubicacionUsuario = UbicacionUsuario();
                final infoDepto = await ubicacionUsuario
                    .obtenerDireccionLegible(destinoLat, destinoLng);
                final deptoMapbox = infoDepto?['departamento'];

                // Parsear dirección completa
                final fullAddress = '${entry.titulo}, ${entry.subtitulo}';
                final partes = direccionPorPartes(fullAddress);

                // Departamento final: prioriza Mapbox y normaliza
                final destinoDepartamento = deptoMapbox?.isNotEmpty == true
                    ? normalizarDepartamento(deptoMapbox!)
                    : normalizarDepartamento(partes['departamento'] ?? '');

                // Actualizar campo destino
                setModalState(() {
                  destinoController.text = entry.titulo;
                  cargandoDestino = false;
                });

                // Cerrar modal primero
                if (context.mounted) {
                  Navigator.of(context).pop();
                }

                await Future.delayed(const Duration(milliseconds: 100));

                Modular.to.pushNamed(
                  '/mapa-destino',
                  arguments: {
                    // Origen
                    'lat': _lat,
                    'lng': _lng,
                    'calle': _calle ?? 'Mi ubicación actual',
                    'ciudad': _ciudad ?? '',
                    'pais': _pais ?? 'Bolivia',
                    'departamento': _departamento,

                    // Destino
                    'destinoLat': destinoLat,
                    'destinoLng': destinoLng,
                    'destinoTexto': entry.titulo,
                    'destinoCalle': partes['calle'],
                    'destinoCiudad': partes['ciudad'],
                    'destinoDepartamento': destinoDepartamento,
                    'destinoPais': partes['pais'],

                    // ✅ NUEVO: traza automáticamente (cuando ajustes MapaDestino)
                    'autoDestino': true,

                    // ❌ YA NO ABRIMOS el resumen automático
                    'openSheet2': false,
                  },
                );
              } catch (e) {
                if (context.mounted) {
                  setModalState(() {
                    cargandoDestino = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              }
            }

            // FUNCIÓN: actualizar origen (dinámicos)
            Future<void> irAOrigenDinamico(SugerenciaEntry entry) async {
              final placeId = entry.placeId ?? '';
              if (placeId.isEmpty) return;

              setModalState(() {
                cargandoOrigen = true;
              });

              try {
                final coords = await googleService.obtenerCoordenadas(placeId);

                if (coords == null) {
                  if (context.mounted) {
                    setModalState(() {
                      cargandoOrigen = false;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No se pudo obtener la ubicación'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                  return;
                }

                final origenLat = (coords['lat'] as num).toDouble();
                final origenLng = (coords['lng'] as num).toDouble();

                // Departamento más confiable desde Mapbox
                final ubicacionUsuario = UbicacionUsuario();
                final infoDepto = await ubicacionUsuario
                    .obtenerDireccionLegible(origenLat, origenLng);
                final deptoMapbox = infoDepto?['departamento'];

                // Parsear dirección completa
                final fullAddress = '${entry.titulo}, ${entry.subtitulo}';
                final partes = direccionPorPartes(fullAddress);

                final origenDepartamento = normalizarDepartamento(
                  (deptoMapbox?.isNotEmpty == true
                      ? deptoMapbox ?? ''
                      : partes['departamento'] ?? ''),
                );

                setModalState(() {
                  origenController.text = entry.titulo;

                  // ✅ actualizar copias mutables
                  _lat = origenLat;
                  _lng = origenLng;
                  _calle = entry.titulo;
                  _ciudad = partes['ciudad'];
                  _pais = partes['pais'];
                  _departamento = origenDepartamento;

                  cargandoOrigen = false;
                  resultadosOrigen = [];
                });

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Origen actualizado: ${entry.titulo}'),
                      duration: const Duration(seconds: 2),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  setModalState(() {
                    cargandoOrigen = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al seleccionar origen: $e'),
                      duration: const Duration(seconds: 2),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            }

            return SingleChildScrollView(
              controller: sc,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // BUSCADORES
                  BuscadoresBox(
                    buscadores: [
                      // ORIGEN
                      Buscador1(
                        titulo: 'Punto de partidas',
                        textoInicial: origenController.text,
                        iconoBuscador: Icons.location_on,
                        colorCajaIconoBuscador: Colors.green,
                        colorIconoBuscador: Colors.white,
                        textoBoton: 'Mapa',
                        colorCajaBoton: const Color.fromARGB(255, 41, 17, 158),
                        colorTextoBoton: Colors.white,
                        onBotonPressed: () async {
                          final result = await Modular.to.pushNamed(
                            '/mapa-origen',
                            arguments: {
                              'lat': _lat,
                              'lng': _lng,
                              'calle': _calle,
                              'ciudad': _ciudad,
                              'pais': _pais,
                              'departamento':
                                  _departamento, // ✅ no perder depto
                            },
                          );

                          if (result is Map) {
                            setModalState(() {
                              _lat = (result['lat'] as num?)?.toDouble();
                              _lng = (result['lng'] as num?)?.toDouble();
                              _calle = result['calle'] as String?;
                              _ciudad = result['ciudad'] as String?;
                              _pais = result['pais'] as String?;
                              _departamento = result['departamento'] as String?;

                              origenController.text =
                                  (result['calle'] as String?) ??
                                  'Mi ubicación';
                            });
                          }
                        },
                        onChanged: (v) async {
                          debugPrint('🔍 Modal Origen: onChanged "$v"');

                          if (v.trim().isEmpty) {
                            setModalState(() {
                              resultadosOrigen = [];
                              cargandoOrigen = false;
                            });
                            return;
                          }

                          setModalState(() => cargandoOrigen = true);
                          final res = await googleService.buscarLugares(
                            v,
                            countryCode: _inferCountryCode(_pais),
                            lat: _lat,
                            lng: _lng,
                          );

                          // Filtrado inteligente: priorizar departamento pero no excluir otros
                          List<Map<String, String>> filtrados = [];
                          List<Map<String, String>> otros = [];

                          if (_departamento != null &&
                              _departamento!.isNotEmpty) {
                            for (var item in res) {
                              final subtitulo =
                                  item['subtitulo']?.toLowerCase() ?? '';
                              if (subtitulo.contains(
                                _departamento!.toLowerCase(),
                              )) {
                                filtrados.add(item);
                              } else {
                                otros.add(item);
                              }
                            }

                            if (filtrados.length < 3 && otros.isNotEmpty) {
                              final cantidadAgregar = otros.length < 5
                                  ? otros.length
                                  : 5;
                              filtrados.addAll(otros.take(cantidadAgregar));
                            }
                          } else {
                            filtrados = res;
                          }

                          setModalState(() {
                            resultadosOrigen = filtrados;
                            cargandoOrigen = false;
                          });
                        },
                      ),

                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(height: 1),
                      ),

                      // DESTINO
                      Buscador1(
                        titulo: 'Destino',
                        hintText: '¿A dónde vas?',
                        iconoBuscador: Icons.flag,
                        colorCajaIconoBuscador: Colors.red,
                        colorIconoBuscador: Colors.white,
                        textoBoton: 'Mapa',
                        colorCajaBoton: Colors.red,
                        colorTextoBoton: Colors.white,
                        onBotonPressed: () {
                          Modular.to.pushNamed(
                            '/mapa-destino',
                            arguments: {
                              'lat': _lat,
                              'lng': _lng,
                              'calle': _calle,
                              'ciudad': _ciudad,
                              'pais': _pais,
                              'departamento': _departamento,
                            },
                          );
                        },
                        onChanged: (v) async {
                          debugPrint('🔍 Modal Destino: onChanged "$v"');

                          if (v.trim().isEmpty) {
                            setModalState(() {
                              resultadosDestino = [];
                              cargandoDestino = false;
                            });
                            return;
                          }

                          setModalState(() => cargandoDestino = true);

                          final res = await googleService.buscarLugares(
                            v,
                            countryCode: _inferCountryCode(_pais),
                            lat: _lat,
                            lng: _lng,
                          );

                          List<Map<String, String>> filtrados = [];
                          List<Map<String, String>> otros = [];

                          if (_departamento != null &&
                              _departamento!.isNotEmpty) {
                            final deptoNormalizado = normalizarDepartamento(
                              _departamento!,
                            ).toLowerCase();

                            for (var item in res) {
                              final subtitulo =
                                  item['subtitulo']?.toLowerCase() ?? '';
                              if (subtitulo.contains(deptoNormalizado)) {
                                filtrados.add(item);
                              } else {
                                otros.add(item);
                              }
                            }

                            if (filtrados.length < 3 && otros.isNotEmpty) {
                              final cantidadAgregar = otros.length < 5
                                  ? otros.length
                                  : 5;
                              filtrados.addAll(otros.take(cantidadAgregar));
                            }
                          } else {
                            filtrados = res;
                          }

                          setModalState(() {
                            resultadosDestino = filtrados;
                            cargandoDestino = false;
                          });
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // RESULTADOS DINÁMICOS ORIGEN
                  if (cargandoOrigen) ...[
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            CircularProgressIndicator(color: Colors.green),
                            SizedBox(height: 12),
                            Text(
                              'Buscando orígenes...',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else if (resultadosOrigen.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(Icons.search, size: 20, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(
                          'Orígenes encontrados (${resultadosOrigen.length})',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SugerenciasBusqueda(
                      controller: origenController,
                      onUpdate: (entry) async => irAOrigenDinamico(entry),
                      items: resultadosOrigen
                          .map(
                            (r) => SugerenciaEntry(
                              titulo: r['titulo'] ?? '',
                              subtitulo: r['subtitulo'] ?? '',
                              placeId: r['place_id'],
                              leadingIcon: Icons.location_on,
                              trailingIcon: Icons.north_east,
                            ),
                          )
                          .toList(),
                      mostrarSubtitulo: true,
                      dense: false,
                      showDivider: true,
                      iconSize: 24,
                      itemVerticalPadding: 10,
                      leadingGap: 10,
                      trailingGap: 6,
                      defaultLeadingColor: Colors.green,
                    ),
                    const SizedBox(height: 24),
                  ],

                  // RESULTADOS DINÁMICOS DESTINO
                  if (cargandoDestino) ...[
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text(
                              'Buscando lugares...',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else if (resultadosDestino.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(Icons.search, size: 20, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          'Resultados (${resultadosDestino.length})',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SugerenciasBusqueda(
                      controller: destinoController,
                      onUpdate: (entry) async => irADestinoDinamico(entry),
                      items: resultadosDestino
                          .map(
                            (r) => SugerenciaEntry(
                              titulo: r['titulo'] ?? '',
                              subtitulo: r['subtitulo'] ?? '',
                              placeId: r['place_id'],
                              leadingIcon: Icons.location_on,
                              trailingIcon: Icons.north_east,
                            ),
                          )
                          .toList(),
                      mostrarSubtitulo: true,
                      dense: false,
                      showDivider: true,
                      iconSize: 24,
                      itemVerticalPadding: 10,
                      leadingGap: 10,
                      trailingGap: 6,
                      defaultLeadingColor: Colors.red,
                    ),
                  ] else ...[
                    // 🔥 SUGERENCIAS DINÁMICAS según ubicación del usuario.
                    //   Lanza el fetch UNA sola vez (popularesYaPedidos).
                    Builder(
                      builder: (_) {
                        if (!popularesYaPedidos &&
                            _lat != null &&
                            _lng != null) {
                          popularesYaPedidos = true;
                          googleService
                              .obtenerLugaresPopulares(
                                lat: _lat!,
                                lng: _lng!,
                              )
                              .then((list) {
                                if (!context.mounted) return;
                                setModalState(() {
                                  lugaresPopulares = list;
                                  cargandoPopulares = false;
                                });
                              })
                              .catchError((_) {
                                if (!context.mounted) return;
                                setModalState(() {
                                  cargandoPopulares = false;
                                });
                              });
                        }

                        return Row(
                          children: [
                            const Icon(
                              Icons.near_me_rounded,
                              size: 20,
                              color: Color(0xFF4CB050),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Lugares cerca de ti',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            if (cargandoPopulares) ...[
                              const SizedBox(width: 10),
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF4CB050),
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),

                    if (cargandoPopulares && lugaresPopulares.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text(
                            'Buscando lugares populares cerca…',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      )
                    else if (lugaresPopulares.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_off_rounded,
                              size: 20,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _lat == null || _lng == null
                                    ? 'Activa tu ubicación para ver lugares cercanos.'
                                    : 'No encontramos lugares populares cerca de ti.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      SugerenciasBusqueda(
                        controller: destinoController,
                        onUpdate: (entry) async {
                          // Buscar el item dinámico que matchea con la entry
                          final pop = lugaresPopulares.firstWhere(
                            (p) =>
                                (p['titulo'] as String? ?? '') == entry.titulo,
                            orElse: () => const {},
                          );
                          if (pop.isEmpty) return;

                          final destinoLat = (pop['lat'] as num?)?.toDouble();
                          final destinoLng = (pop['lng'] as num?)?.toDouble();
                          if (destinoLat == null || destinoLng == null) return;

                          if (_lat == null || _lng == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Obteniendo tu ubicación...'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                            return;
                          }

                          setModalState(() {
                            destinoController.text = entry.titulo;
                          });

                          if (context.mounted) Navigator.of(context).pop();
                          await Future.delayed(
                            const Duration(milliseconds: 100),
                          );

                          Modular.to.pushNamed(
                            '/mapa-destino',
                            arguments: {
                              'lat': _lat,
                              'lng': _lng,
                              'calle': _calle ?? 'Mi ubicación actual',
                              'ciudad': _ciudad ?? '',
                              'pais': _pais ?? '',
                              'departamento': _departamento,
                              'destinoLat': destinoLat,
                              'destinoLng': destinoLng,
                              'destinoTexto': entry.titulo,
                              'destinoCalle': entry.titulo,
                              'destinoCiudad': entry.subtitulo,
                              'destinoPais': _pais,
                              'autoDestino': true,
                              'openSheet2': false,
                            },
                          );
                        },
                        items: lugaresPopulares.map((p) {
                          // Elegir icono según el tipo reportado por Google
                          IconData icon = Icons.place_rounded;
                          final t = (p['tipo'] as String? ?? '').toLowerCase();
                          if (t.contains('airport')) {
                            icon = Icons.flight_takeoff_rounded;
                          } else if (t.contains('bus_station') ||
                              t.contains('transit_station')) {
                            icon = Icons.directions_bus_rounded;
                          } else if (t.contains('train_station')) {
                            icon = Icons.train_rounded;
                          } else if (t.contains('shopping')) {
                            icon = Icons.shopping_bag_rounded;
                          } else if (t.contains('park')) {
                            icon = Icons.park_rounded;
                          } else if (t.contains('museum')) {
                            icon = Icons.museum_rounded;
                          } else if (t.contains('stadium')) {
                            icon = Icons.stadium_rounded;
                          } else if (t.contains('tourist')) {
                            icon = Icons.photo_camera_rounded;
                          }
                          return SugerenciaEntry(
                            titulo: (p['titulo'] as String?) ?? '',
                            subtitulo: (p['subtitulo'] as String?) ?? '',
                            leadingIcon: icon,
                            trailingIcon: Icons.directions,
                          );
                        }).toList(),
                        mostrarSubtitulo: true,
                        dense: false,
                        showDivider: true,
                        iconSize: 26,
                        itemVerticalPadding: 12,
                        leadingGap: 12,
                        trailingGap: 8,
                        defaultLeadingColor: const Color(0xFF4CB050),
                      ),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
