import 'package:flutter/material.dart';
import 'package:buses2/shared/widgets/botones/boton.dart';

/// Botón igual a [Boton1] pero siempre desactivado.
/// Reutiliza el mismo estilo de tu `Boton1`.
class BotonDesactivado extends StatelessWidget {
  final String label;
  final IconData? iconoIzquierdo;
  final IconData? iconoDerecho;

  const BotonDesactivado({
    super.key,
    required this.label,
    this.iconoIzquierdo,
    this.iconoDerecho,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.5, // 👈 lo ves “apagado”
      child: Boton1(
        label: label,
        color: BotonColor.color1,
        borde: BotonBorde.borde1,
        iconoIzquierdo: iconoIzquierdo,
        iconoDerecho: iconoDerecho,
        onPressed: null, // 👈 sin acción
      ),
    );
  }
}

/* Ejemplo de uso:
import 'package:buses2/shared/widgets/botones/boton_desactivado.dart';
...
bool _puedeGuardar = false; // botón desactivado por defecto
...
  btnFijoAbajo: _puedeGuardar
    ? Btn_Cargando(
        loading: _loading,
        borde: BtnBorde.borde1,               // borde1 (pill) | borde2 (12) | borde3 (cuadrado)
        workingLabel: 'Enviando Datos...',        // 👈 texto que quieres ver mientras carga
        overlayColor: Colors.grey,            // sólido
        spinnerColor: Colors.white,           // visible sobre gris
        child: Boton1(
          label: 'Guardar y Cerrar',
          color: BotonColor.color1,
          borde: BotonBorde.borde1,
          iconoIzquierdo: Icons.save,
          iconoDerecho: Icons.save,
          onPressed: disableOnLoading(_loading, _guardar), // 👈 evita doble click
        ),
      ) : const BotonDesactivado(
        label: 'Guardar y Cerrar',
        iconoIzquierdo: Icons.save,
        iconoDerecho: Icons.save,
      ),
*/
