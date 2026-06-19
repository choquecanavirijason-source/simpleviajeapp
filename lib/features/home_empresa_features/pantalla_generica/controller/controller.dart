// controller.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class GenericPageController extends ChangeNotifier {
  final ImagePicker _picker;

  GenericPageController({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  // Meta
  late String id;
  late String pageTitle;
  String? pageSubtitle;

  // Config cruda
  late List<dynamic> inputsCfg;
  late List<dynamic> filesCfg;

  // Estado
  final Map<String, TextEditingController> ctrls = {};
  final Map<String, File?> files = {};

  bool canSave = false;

  // ===== Inicialización =====
  void init({
    required Map<String, dynamic>? args,
    String? fallbackTitle,
    String? fallbackSubtitle,
    List<dynamic>? fallbackInputs,
    List<dynamic>? fallbackFiles,
  }) {
    id = (args?['id'] as String?) ?? 'sin_id';
    pageTitle = (args?['title'] as String?) ?? fallbackTitle ?? 'Formulario';
    pageSubtitle = (args?['subtitle'] as String?) ?? fallbackSubtitle;

    inputsCfg =
        (args?['inputsConfig'] as List<dynamic>?) ??
        (fallbackInputs ?? const []);
    filesCfg =
        (args?['fileSectionsConfig'] as List<dynamic>?) ??
        (fallbackFiles ?? const []);

    // Controllers y slots de archivos
    for (final input in inputsCfg) {
      final key = keyForInput(input);
      final c = TextEditingController(
        text: (input['initialValue'] as String?) ?? '',
      );
      c.addListener(recomputeCanSave);
      ctrls[key] = c;
    }
    for (final sec in filesCfg) {
      files[keyForFile(sec)] = null;
    }

    canSave = _computeCanSave();
  }

  @override
  void dispose() {
    for (final c in ctrls.values) {
      c.removeListener(recomputeCanSave);
      c.dispose();
    }
    super.dispose();
  }

  // ===== Helpers de llaves =====
  String keyForInput(Map input) =>
      (input['key'] as String?) ??
      (input['label'] as String?) ??
      'input_${inputsCfg.indexOf(input)}';

  String keyForFile(Map sec) =>
      (sec['key'] as String?) ??
      (sec['label'] as String?) ??
      'file_${filesCfg.indexOf(sec)}';

  // ===== Validación =====
  bool _computeCanSave() {
    // Inputs requeridos (por defecto)
    for (final input in inputsCfg) {
      final isRequired = (input['required'] != false);
      if (!isRequired) continue;
      final key = keyForInput(input);
      final txt = (ctrls[key]?.text ?? '').trim();
      if (txt.isEmpty) return false;
    }

    // Archivos requeridos (por defecto)
    for (final sec in filesCfg) {
      final isRequired = (sec['required'] != false);
      if (!isRequired) continue;
      final key = keyForFile(sec);
      final hasLocal = files[key] != null;
      final hasRemote = (sec['initialUrl'] as String?)?.isNotEmpty == true;
      if (!hasLocal && !hasRemote) return false;
    }

    return true;
  }

  void recomputeCanSave() {
    final v = _computeCanSave();
    if (v != canSave) {
      canSave = v;
      notifyListeners();
    }
  }

  // ===== Acciones =====
  Future<void> pickImage(Map sec) async {
    final key = keyForFile(sec);
    final maxWidth = (sec['maxWidth'] as num?)?.toDouble() ?? 1024;
    final maxHeight = (sec['maxHeight'] as num?)?.toDouble() ?? 1024;
    final imageQuality = (sec['imageQuality'] as int?) ?? 80;
    final sourceStr = (sec['source'] as String?)?.toLowerCase();
    final ImageSource source = (sourceStr == 'gallery')
        ? ImageSource.gallery
        : ImageSource.camera;

    final picked = await _picker.pickImage(
      source: source,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
    );

    if (picked != null) {
      files[key] = File(picked.path);
      canSave = _computeCanSave();
      notifyListeners();
    }
  }

  Map<String, dynamic> buildResult() {
    final data = <String, String>{};
    ctrls.forEach((k, c) => data[k] = c.text);

    final outFiles = <String, String?>{};
    for (final sec in filesCfg) {
      final key = keyForFile(sec);
      final local = files[key];
      final remoteUrl = sec['initialUrl'] as String?;
      outFiles[key] = local != null
          ? local.path
          : (remoteUrl?.isNotEmpty == true ? remoteUrl : null);
    }

    if (kDebugMode) {
      debugPrint(
        '[GenericPageController] buildResult($id): data=$data files=$outFiles',
      );
    }

    return {'id': id, 'data': data, 'files': outFiles};
  }
}
