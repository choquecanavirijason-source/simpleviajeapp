import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:buses2/shared/widgets/app_bar/app_bar.dart';
import '../documentos_vehiculo/widgets/documento_upload_widget.dart';
import '../documentos_vehiculo/services/documentos_config_service.dart';
import '../documentos_vehiculo/models/documento_config_model.dart';

/// Página para ver los documentos de respaldo del taxista
/// Muestra en modo solo lectura los documentos subidos
class DocumentosRespaldoTaxi extends StatefulWidget {
  const DocumentosRespaldoTaxi({super.key});

  @override
  State<DocumentosRespaldoTaxi> createState() => _DocumentosRespaldoTaxiState();
}

class _DocumentosRespaldoTaxiState extends State<DocumentosRespaldoTaxi> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Map<String, dynamic>? _documentos;
  ConfiguracionDocumentos? _configuracion;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Cargar documentos del taxista
      final doc = await _firestore.collection('taxistas').doc(user.uid).get();
      final data = doc.data();

      // Cargar configuración dinámica de documentos (con fallback a por defecto)
      final config =
          await DocumentosConfigService.cargarConfiguracionConFallback();

      if (!mounted) return;

      setState(() {
        _documentos = data?['documentosVehiculo'] as Map<String, dynamic>?;
        _configuracion = config;
        _cargando = false;
      });
    } catch (e) {
      debugPrint('Error cargando documentos: $e');
      if (!mounted) return;
      setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar1(
        titleSize: TitleSize.big,
        titulo: 'Documentos de Respaldo',
        leftAction: LeftAction.back,
        iconoIzquierda: Icons.arrow_back,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _documentos == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No has subido documentos aún',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Completa el registro de documentos para verlos aquí',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _cargarDatos,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Información del registro
                  if (_documentos!['fechaRegistro'] != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Documentos registrados',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Fecha: ${_formatearFecha(_documentos!['fechaRegistro'])}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Información General (siempre se muestra)
                  _seccionTitulo('Información General'),
                  const SizedBox(height: 12),
                  _itemInfo('Licencia N.°', _documentos!['numeroLicencia']),
                  _itemInfo('Marca', _documentos!['marca']),
                  _itemInfo('Color', _documentos!['color']),
                  _itemInfo('Asientos', _documentos!['numeroAsientos']),

                  const SizedBox(height: 24),

                  // Si por algún motivo no se cargó la configuración,
                  // mostramos el layout estático anterior como fallback.
                  if (_configuracion == null) ...[
                    _seccionTitulo('Documentos Personales'),
                    const SizedBox(height: 12),

                    DocumentoUploadWidget(
                      titulo: 'Antecedentes Penales',
                      urlInicial: _documentos!['fotoAntecedentesPenales'],
                      verificado:
                          _documentos!['verificadoFotoAntecedentesPenales'] ??
                          false,
                      soloLectura: true,
                      requerido: true,
                    ),

                    DocumentoUploadWidget(
                      titulo: 'Foto del Conductor',
                      urlInicial: _documentos!['fotoConductor'],
                      verificado:
                          _documentos!['verificadoFotoConductor'] ?? false,
                      soloLectura: true,
                      requerido: true,
                    ),

                    DocumentoUploadWidget(
                      titulo: 'Carné de Identidad - Anverso',
                      urlInicial: _documentos!['fotoCarneIdentidadAnverso'],
                      verificado:
                          _documentos!['verificadoFotoCarneIdentidadAnverso'] ??
                          false,
                      soloLectura: true,
                      requerido: true,
                    ),

                    DocumentoUploadWidget(
                      titulo: 'Carné de Identidad - Reverso',
                      urlInicial: _documentos!['fotoCarneIdentidadReverso'],
                      verificado:
                          _documentos!['verificadoFotoCarneIdentidadReverso'] ??
                          false,
                      soloLectura: true,
                      requerido: true,
                    ),

                    DocumentoUploadWidget(
                      titulo: 'Licencia de Conducir - Anverso',
                      urlInicial: _documentos!['fotoLicenciaConducirAnverso'],
                      verificado:
                          _documentos!['verificadoFotoLicenciaConducirAnverso'] ??
                          false,
                      soloLectura: true,
                      requerido: true,
                    ),

                    DocumentoUploadWidget(
                      titulo: 'Licencia de Conducir - Reverso',
                      urlInicial: _documentos!['fotoLicenciaConducirReverso'],
                      verificado:
                          _documentos!['verificadoFotoLicenciaConducirReverso'] ??
                          false,
                      soloLectura: true,
                      requerido: true,
                    ),

                    const SizedBox(height: 24),

                    _seccionTitulo('Documentos del Vehículo'),
                    const SizedBox(height: 12),

                    DocumentoUploadWidget(
                      titulo: 'SOAT',
                      urlInicial: _documentos!['fotoSoat'],
                      verificado: _documentos!['verificadoFotoSoat'] ?? false,
                      soloLectura: true,
                      requerido: true,
                    ),

                    DocumentoUploadWidget(
                      titulo: 'Permiso de Circulación',
                      urlInicial: _documentos!['fotoPermisoCirculacion'],
                      verificado:
                          _documentos!['verificadoFotoPermisoCirculacion'] ??
                          false,
                      soloLectura: true,
                      requerido: true,
                    ),

                    DocumentoUploadWidget(
                      titulo: 'Revisión Técnica',
                      urlInicial: _documentos!['fotoRevisionTecnica'],
                      verificado:
                          _documentos!['verificadoFotoRevisionTecnica'] ??
                          false,
                      soloLectura: true,
                      requerido: true,
                    ),

                    const SizedBox(height: 24),

                    _seccionTitulo('Fotografías del Vehículo'),
                    const SizedBox(height: 12),

                    DocumentoUploadWidget(
                      titulo: 'Foto del Vehículo 1',
                      urlInicial: _documentos!['fotoVehiculo1'],
                      verificado:
                          _documentos!['verificadoFotoVehiculo1'] ?? false,
                      soloLectura: true,
                      requerido: true,
                    ),

                    if (_documentos!['fotoVehiculo2'] != null)
                      DocumentoUploadWidget(
                        titulo: 'Foto del Vehículo 2',
                        urlInicial: _documentos!['fotoVehiculo2'],
                        verificado:
                            _documentos!['verificadoFotoVehiculo2'] ?? false,
                        soloLectura: true,
                        requerido: false,
                      ),

                    const SizedBox(height: 24),
                  ] else ...[
                    // Layout dinámico basado en la configuración de documentos

                    // Documentos Personales (Paso 1)
                    _seccionTitulo('Documentos Personales'),
                    const SizedBox(height: 12),
                    ..._buildSeccionPorPaso(1),

                    const SizedBox(height: 24),

                    // Documentos del Vehículo (Paso 2)
                    _seccionTitulo('Documentos del Vehículo'),
                    const SizedBox(height: 12),
                    ..._buildSeccionPorPaso(2),

                    const SizedBox(height: 24),

                    // Fotografías del Vehículo (Paso 3)
                    _seccionTitulo('Fotografías del Vehículo'),
                    const SizedBox(height: 12),
                    ..._buildSeccionPorPaso(3),

                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
    );
  }

  /// Construye la lista de widgets de una sección (por paso)
  /// usando la configuración dinámica. Solo se muestran documentos activos
  /// y que tengan datos en Firestore.
  List<Widget> _buildSeccionPorPaso(int paso) {
    if (_configuracion == null || _documentos == null) {
      return [];
    }

    final docs = _configuracion!.getDocumentosPorPaso(paso)
      ..sort((a, b) => a.orden.compareTo(b.orden));

    // Filtrar documentos que tengan datos
    final documentosConDatos = docs.where((doc) {
      if (doc.tipo == 'foto') {
        final url = _documentos![doc.id];
        // Solo mostrar fotos si tienen URL
        return url != null && url.toString().isNotEmpty;
      } else {
        final valor = _documentos![doc.id];
        // Solo mostrar otros tipos si tienen valor
        return valor != null && valor.toString().isNotEmpty;
      }
    }).toList();

    return documentosConDatos.map((doc) {
      // Por ahora solo manejamos tipo 'foto' con DocumentoUploadWidget
      if (doc.tipo == 'foto') {
        final url = _documentos![doc.id];
        final verificadoKey = _buildVerificadoKey(doc.id);
        final verificado = _documentos![verificadoKey] as bool? ?? false;

        return DocumentoUploadWidget(
          titulo: doc.nombre,
          urlInicial: url,
          verificado: verificado,
          soloLectura: true,
          requerido: doc.requerido,
        );
      }

      // Para otros tipos (texto, número, selección),
      // mostramos solo una fila informativa.
      final valor = _documentos![doc.id];
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _itemInfo(doc.nombre, valor),
      );
    }).toList();
  }

  /// Construye la key de verificación a partir del id del documento
  /// Ej: 'fotoAntecedentesPenales' -> 'verificadoFotoAntecedentesPenales'
  String _buildVerificadoKey(String id) {
    if (id.isEmpty) return '';
    return 'verificado${id[0].toUpperCase()}${id.substring(1)}';
  }

  Widget _seccionTitulo(String titulo) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          titulo,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _itemInfo(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value?.toString() ?? 'No especificado',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  String _formatearFecha(dynamic fecha) {
    if (fecha == null) return 'No disponible';
    try {
      if (fecha is String) {
        final dt = DateTime.parse(fecha);
        return '${dt.day}/${dt.month}/${dt.year}';
      }
      return fecha.toString();
    } catch (e) {
      return 'No disponible';
    }
  }
}
