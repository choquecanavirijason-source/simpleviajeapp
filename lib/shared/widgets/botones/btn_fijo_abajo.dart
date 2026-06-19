// import 'package:prestamos1/shared/widgets/botones/btn_fijo_abajo.dart';
import 'package:flutter/material.dart';

/// Un Scaffold que coloca cualquier [btnFijoAbajo] fijo en la parte inferior,
/// respetando el teclado y el SafeArea.
class ScaffoldConBottom extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget btnFijoAbajo;
  final bool scrollBody;
  final Color? colorFondo; // 👈 color de la barra inferior
  final Color? backgroundColor; // 👈 fondo plano
  final Gradient? backgroundGradient; // 👈 nuevo: fondo degradado

  const ScaffoldConBottom({
    super.key,
    this.appBar,
    required this.body,
    required this.btnFijoAbajo,
    this.scrollBody = false,
    this.colorFondo,
    this.backgroundColor,
    this.backgroundGradient,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final content = SafeArea(
      child: scrollBody
          ? SingleChildScrollView(padding: EdgeInsets.zero, child: body)
          : body,
    );

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: appBar,
      // Evita fondo blanco del Scaffold cuando usamos gradiente
      backgroundColor: backgroundGradient == null
          ? backgroundColor
          : Colors.transparent,
      // <- 👇 pinta el gradiente a pantalla completa, no sólo al alto del contenido
      body: backgroundGradient == null
          ? content
          : Container(
              constraints:
                  const BoxConstraints.expand(), // 👈 ocupa todo el alto/ancho
              decoration: BoxDecoration(gradient: backgroundGradient),
              child: content,
            ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          color: colorFondo,
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: btnFijoAbajo,
        ),
      ),
    );
  }
}

/*
import 'package:flutter/material.dart';
import 'package:prestamos1/shared/widgets/botones/btn_fijo_abajo.dart';
import 'package:prestamos1/shared/widgets/botones/boton.dart';

/// Un Scaffold que coloca cualquier [btnFijoAbajo] fijo en la parte inferior,
/// respetando el teclado y el SafeArea.
class ScaffoldConBottom extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget btnFijoAbajo;

  const ScaffoldConBottom({
    super.key,
    this.appBar,
    required this.body,
    required this.btnFijoAbajo,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: appBar,
      body: body,
      bottomSheet: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: btnFijoAbajo,
        ),
      ),
    );
  }
}
*/

/* Se usa así:
ScaffoldConBottom(
  appBar: AppBar1(...),
  scrollBody: true, // 👈 activa scroll
  body: ListView(...),
  btnFijoAbajo: Boton1(
    label: 'Guardar Datos',
    color: BotonColor.color1,
    borde: BotonBorde.borde1,
    iconoIzquierdo: Icons.save,
    iconoDerecho: Icons.save,
    onPressed: () {},
  ),
  backgroundGradient: const LinearGradient(
  begin: Alignment.topCenter,   // 👈 empieza arriba
  end: Alignment.bottomCenter,  // 👈 termina abajo
    colors: [
      Color(0xFF1e3c72), // azul oscuro
      Color(0xFF2a5298), // azul más claro
    ],
  ),
  colorFondo: Color(0xFF2a5298), // color de la barra inferior
);
*/

/* Poner 2 o más botones:
btnFijoAbajo: Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    Boton1(
      label: 'Vista Previa',
      color: BotonColor.color2,
      borde: BotonBorde.borde1,
      iconoIzquierdo: Icons.article,
      onPressed: () {
        debugPrint('Vista previa');
      },
    ),
    const SizedBox(height: 12),
    Boton1(
      label: 'Crear Contrato',
      color: BotonColor.color2,
      borde: BotonBorde.borde1,
      iconoIzquierdo: Icons.article,
      onPressed: () {
        debugPrint('Contrato guardado');
      },
    ),
  ],
),
*/

/* Solo cambiar el fondo de pantalla:
return ScaffoldConBottom(
  appBar: const AppBar1(...),
  body: Padding(...),
  btnFijoAbajo: const SizedBox.shrink(), // 👈 vacío, se puede rellenar luego
  colorFondo: const Color(0xFF2a5298), // fondo barra inferior
  backgroundGradient: const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF1e3c72), // azul oscuro
      Color(0xFF2a5298), // azul más claro
    ],
  ),
);
*/
