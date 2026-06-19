import 'dart:io';
import 'package:flutter/material.dart';
import '../models/documento_config_model.dart';
import '../widgets/campo_dinamico_widget.dart';

/// Helper class para construir pasos del Stepper dinámicamente
class StepsBuilder {
  /// Construye los pasos del Stepper según la configuración de documentos
  static List<Step> construirPasos({
    required ConfiguracionDocumentos? configuracion,
    required bool cargando,
    required int currentStep,
    required bool infoExpanded,
    required Function() onToggleInfo,
    required TextEditingController marcaController,
    required TextEditingController colorController,
    required TextEditingController asientosController,
    required TextEditingController numeroPlacaController,
    required TextEditingController tipoVehiculoController,
    required TextEditingController modeloController,
    required Map<String, File?> documentosArchivos,
    required Function(String docId, File? file) onArchivoCambiado,
    required Function(String docId, String? texto) onTextoCambiado,
  }) {
    final List<Step> pasos = [];

    // SIEMPRE mantener el mismo número de steps para evitar error del Stepper
    // Si está cargando, mostrar placeholders pero mantener estructura

    // PASO 0: Información Inicial y Datos del Vehículo
    pasos.add(
      Step(
        title: const Text('Información Inicial'),
        subtitle: const Text('Datos del vehículo'),
        isActive: currentStep >= 0,
        state: currentStep > 0 ? StepState.complete : StepState.indexed,
        content: _construirContenidoPaso0(
          infoExpanded: infoExpanded,
          onToggleInfo: onToggleInfo,
          marcaController: marcaController,
          colorController: colorController,
          asientosController: asientosController,
          numeroPlacaController: numeroPlacaController,
          tipoVehiculoController: tipoVehiculoController,
          modeloController: modeloController,
        ),
      ),
    );

    // PASOS 1-3: SIEMPRE agregar 3 pasos más (total 4)
    // Si está cargando o no hay configuración, mostrar placeholders
    if (cargando || configuracion == null) {
      // Agregar 3 steps de placeholder para mantener estructura
      for (int i = 1; i <= 3; i++) {
        pasos.add(
          Step(
            title: const Text('Cargando...'),
            subtitle: const Text('Espere un momento'),
            isActive: false,
            state: StepState.indexed,
            content: const Center(
              child: Padding(
                padding: EdgeInsets.all(40.0),
                child: CircularProgressIndicator(),
              ),
            ),
          ),
        );
      }
    } else {
      // Configuración cargada: construir pasos dinámicamente
      for (int paso = 1; paso <= 3; paso++) {
        final documentosPaso = configuracion
            .getDocumentosPorPaso(paso)
            .where((doc) => doc.activo)
            .toList();

        String titulo, subtitulo;
        IconData icono;
        switch (paso) {
          case 1:
            titulo = 'Documentos Personales';
            subtitulo = 'Identidad y licencia';
            icono = Icons.badge_outlined;
            break;
          case 2:
            titulo = 'Documentos del Vehículo';
            subtitulo = 'SOAT, permisos y revisiones';
            icono = Icons.description_outlined;
            break;
          case 3:
            titulo = 'Fotografías del Vehículo';
            subtitulo = 'Imágenes de tu vehículo';
            icono = Icons.photo_camera_outlined;
            break;
          default:
            titulo = 'Documentos Paso $paso';
            subtitulo = '';
            icono = Icons.file_present;
        }

        // Si no hay documentos para este paso, mostrar mensaje
        Widget contenido;
        if (documentosPaso.isEmpty) {
          contenido = const Center(
            child: Padding(
              padding: EdgeInsets.all(40.0),
              child: Text(
                'No hay documentos configurados para este paso',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        } else {
          contenido = _construirContenidoPasoDinamico(
            documentos: documentosPaso,
            icono: icono,
            documentosArchivos: documentosArchivos,
            onArchivoCambiado: onArchivoCambiado,
            onTextoCambiado: onTextoCambiado,
          );
        }

        pasos.add(
          Step(
            title: Text(titulo),
            subtitle: Text(subtitulo),
            isActive: currentStep >= paso,
            state: currentStep > paso ? StepState.complete : StepState.indexed,
            // Mostrar siempre el contenido del paso para evitar huecos visuales
            // entre steps cuando se avanza o retrocede.
            content: contenido,
          ),
        );
      }
    }

    return pasos;
  }

  /// Construye el contenido del Paso 0 (Información Inicial)
  static Widget _construirContenidoPaso0({
    required bool infoExpanded,
    required Function() onToggleInfo,
    required TextEditingController marcaController,
    required TextEditingController colorController,
    required TextEditingController asientosController,
    required TextEditingController numeroPlacaController,
    required TextEditingController tipoVehiculoController,
    required TextEditingController modeloController,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cuadro informativo con gradiente
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF43A047), Color(0xFF66BB6A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF43A047).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onToggleInfo,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.description_outlined,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Documentos del Vehículo',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Icon(
                          infoExpanded ? Icons.expand_less : Icons.expand_more,
                          color: Colors.white,
                          size: 28,
                        ),
                      ],
                    ),
                    if (infoExpanded) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'A continuación deberás subir todos los documentos requeridos para completar tu registro como driver.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.start,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Datos del Vehículo',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: marcaController,
          decoration: InputDecoration(
            labelText: 'Marca del vehículo',
            hintText: 'Ej: Toyota, Nissan, Hyundai',
            prefixIcon: const Icon(Icons.directions_car),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.white,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'La marca es obligatoria';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: colorController,
          decoration: InputDecoration(
            labelText: 'Color del vehículo',
            hintText: 'Ej: Blanco, Negro, Rojo',
            prefixIcon: const Icon(Icons.palette),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.white,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'El color es obligatorio';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: asientosController,
          decoration: InputDecoration(
            labelText: 'Número de asientos',
            hintText: 'Ej: 4, 5, 6',
            prefixIcon: const Icon(Icons.event_seat),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.white,
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'El número de asientos es obligatorio';
            }
            final numero = int.tryParse(value.trim());
            if (numero == null || numero < 2 || numero > 20) {
              return 'Ingresa un número válido entre 2 y 20';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        const SizedBox(height: 12),
        TextFormField(
          controller: modeloController,
          decoration: InputDecoration(
            labelText: 'Modelo (Año)',
            hintText: 'Ej: 2018',
            prefixIcon: const Icon(Icons.calendar_today),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.white,
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'El año del modelo es obligatorio';
            }
            final numero = int.tryParse(value.trim());
            final currentYear = DateTime.now().year;
            if (numero == null || numero < 1900 || numero > currentYear) {
              return 'Ingrese un año válido (1900-$currentYear)';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: tipoVehiculoController,
          decoration: InputDecoration(
            labelText: 'Tipo de vehículo',
            hintText: 'Ej: Sedán, SUV, Van',
            prefixIcon: const Icon(Icons.drive_eta),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.white,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'El tipo de vehículo es obligatorio';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: numeroPlacaController,
          decoration: InputDecoration(
            labelText: 'Número de placa',
            hintText: 'Ej: 1234ABC',
            prefixIcon: const Icon(Icons.confirmation_number),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.white,
          ),
          textCapitalization: TextCapitalization.characters,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'El número de placa es obligatorio';
            }
            final placa = value.trim().toUpperCase();
            // Eliminar guiones para validar solo caracteres alfanuméricos
            final placaSimple = placa.replaceAll('-', '');
            final placaRegex = RegExp(r'^[0-9A-Z]{4,10}$');
            if (!placaRegex.hasMatch(placaSimple)) {
              return 'Formato de placa inválido';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  /// Construye el contenido de un paso dinámico con documentos
  static Widget _construirContenidoPasoDinamico({
    required List<DocumentoConfig> documentos,
    required IconData icono,
    required Map<String, File?> documentosArchivos,
    required Function(String docId, File? file) onArchivoCambiado,
    required Function(String docId, String? texto) onTextoCambiado,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header decorativo
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF43A047).withOpacity(0.15),
                const Color(0xFF66BB6A).withOpacity(0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF43A047).withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF43A047),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icono, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Sube fotos de tus documentos desde tu galería o saca una foto con tu cámara. Asegúrate de que sean legibles.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade800,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Renderizar documentos dinámicamente según el tipo de campo
        ...documentos.map((doc) {
          return CampoDinamicoWidget(
            documento: doc,
            archivoInicial: documentosArchivos[doc.id],
            valorTextoInicial:
                null, // Se puede inyectar valor inicial si se requiere en el futuro
            soloLectura: false,
            onArchivoCambiado: (file) => onArchivoCambiado(doc.id, file),
            onTextoCambiado: (texto) {
              onTextoCambiado(doc.id, texto);
            },
          );
        }).toList(),
        const SizedBox(height: 16),
      ],
    );
  }
}
