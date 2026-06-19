// lib/shared/services/facial/face_detector_service.dart
//
// Envuelve google_mlkit_face_detection para validar selfies (1 rostro,
// con tamaño mínimo). Es on-device, gratis y sin backend.
//
// Uso típico:
//   final result = await FaceDetectorService.tomarSelfieYValidar();
//   if (result.ok) { /* result.file es la foto válida */ }
//   else { mostrarSnack(result.errorMensaje!); }

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';

class SelfieResult {
  final bool ok;
  final File? file;
  final String? errorMensaje;

  const SelfieResult._({required this.ok, this.file, this.errorMensaje});

  factory SelfieResult.exito(File f) => SelfieResult._(ok: true, file: f);
  factory SelfieResult.error(String mensaje) =>
      SelfieResult._(ok: false, errorMensaje: mensaje);
}

class FaceDetectorService {
  FaceDetectorService._();

  /// Abre la cámara frontal, captura una foto y valida con ML Kit que
  /// contenga EXACTAMENTE UN rostro de tamaño suficiente.
  ///
  /// Devuelve [SelfieResult.exito(file)] si pasa, o [SelfieResult.error(msg)]
  /// con un mensaje listo para mostrar al usuario.
  ///
  /// Si el usuario cancela el picker, devuelve `null`.
  static Future<SelfieResult?> tomarSelfieYValidar({
    int imageQuality = 85,
  }) async {
    FaceDetector? detector;
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: imageQuality,
      );

      if (picked == null) return null;

      final inputImage = InputImage.fromFilePath(picked.path);
      detector = FaceDetector(
        options: FaceDetectorOptions(
          performanceMode: FaceDetectorMode.accurate,
          enableLandmarks: false,
          enableContours: false,
          enableClassification: false,
          minFaceSize: 0.15,
        ),
      );

      final faces = await detector.processImage(inputImage);

      if (faces.isEmpty) {
        return SelfieResult.error(
          'No se detectó ningún rostro. Toma la foto con buena luz.',
        );
      }
      if (faces.length > 1) {
        return SelfieResult.error(
          'Se detectaron varios rostros. Debe aparecer solo una persona.',
        );
      }

      return SelfieResult.exito(File(picked.path));
    } catch (e) {
      if (kDebugMode) debugPrint('🟥 face detector: $e');
      return SelfieResult.error('Error al verificar el rostro.');
    } finally {
      try {
        await detector?.close();
      } catch (_) {}
    }
  }
}
