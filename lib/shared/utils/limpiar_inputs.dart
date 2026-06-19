import 'package:flutter/material.dart';

typedef ControllerList = List<TextEditingController>;

/// Utilidad para limpiar formularios y controllers de forma genérica.
class LimpiarInputs {
  LimpiarInputs._(); // no instanciable

  /// Resetea la `Form`, limpia/disposea controllers y ejecuta un callback extra.
  static void clear({
    GlobalKey<FormState>? formKey,
    Iterable<TextEditingController> fixed = const [],
    Iterable<ControllerList> dynamicLists = const [],
    bool disposeDynamic = false,
    VoidCallback? extraReset,
  }) {
    // 1) Reset de la Form (borra errores/touched)
    formKey?.currentState?.reset();

    // 2) Limpia controllers "fijos"
    for (final c in fixed) {
      try {
        c.clear();
      } catch (_) {}
    }

    // 3) Limpia o elimina controllers dinámicos
    for (final list in dynamicLists) {
      if (disposeDynamic) {
        for (final c in list) {
          try {
            c.dispose();
          } catch (_) {}
        }
        list.clear();
      } else {
        for (final c in list) {
          try {
            c.clear();
          } catch (_) {}
        }
      }
    }

    // 4) Extra (ids, contadores, selecciones, etc.)
    extraReset?.call();
  }
}

/// Azúcar sintáctico para usarlo en cualquier State con un one-liner.
extension LimpiarInputsStateX on State {
  /// Igual que `LimpiarInputs.clear` pero además hace `setState` (opcional).
  void clearFormInputs({
    GlobalKey<FormState>? formKey,
    Iterable<TextEditingController> fixed = const [],
    Iterable<ControllerList> dynamicLists = const [],
    bool disposeDynamic = false,
    VoidCallback? extraReset,
    bool rebuild = true,
  }) {
    LimpiarInputs.clear(
      formKey: formKey,
      fixed: fixed,
      dynamicLists: dynamicLists,
      disposeDynamic: disposeDynamic,
      extraReset: extraReset,
    );
    if (rebuild && mounted) setState(() {});
  }
}

/* Ejemplo de uso:
      // ⬇️ Limpia inputs y estados
      clearFormInputs(
        formKey: _formKey,
        fixed: [_nombreBtnCtrl, _subtituloBtnCtrl, _tituloDocCtrl],
        dynamicLists: [_camposControllers, _subirFotosControllers],
        // Si quieres BORRAR los campos creados dinámicamente, activa esto:
        // disposeDynamic: true,
        // y resetea ids/contadores aquí:
        extraReset: () {
          // Solo si usas disposeDynamic:true y quieres empezar “from scratch”
          // _campoIds.clear();
          // _fileIds.clear();
          // _campoSeq = 0;
          // _fileSeq = 0;
        },
        // rebuild:true por defecto -> refresca previsualizaciones
      );
*/
