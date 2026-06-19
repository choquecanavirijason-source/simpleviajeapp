// import 'package:buses2/shared/theme/app_buttons_styles.dart';
import 'package:flutter/material.dart';
import 'package:buses2/shared/theme/app_colors.dart';
import 'app_button_sizes.dart'; // importa la clase de tamaños
import 'package:buses2/shared/layout/padding_margin.dart';

//** ¿Cómo usar los botones en tus widgets?
/*ElevatedButton(
    onPressed: () {},
    style: ButtonStyles.boton1,
    child: const Text('Siguiente'),
  ),

  ElevatedButton(
    onPressed: () {},
    style: ButtonStyles.googleButtonStyle,
    child: const Text('Iniciar con Google'),
  ),*/
class ButtonStyles {
  // Botón 1
  static final boton1 = ElevatedButton.styleFrom(
    padding: const EdgeInsets.symmetric(vertical: 16),
    minimumSize: Size(AppButtonSizes.widthFull, AppButtonSizes.heightMedium),
    backgroundColor: AppColors.botonGlobal,
    foregroundColor: AppColors.botonGlobalTexto,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
  );

  // Botón Google con tamaño mediano
  static final botonGoogle = ElevatedButton.styleFrom(
    backgroundColor: AppColors.botonGoogle,
    foregroundColor: AppColors.botonGoogleTexto,
    padding: const EdgeInsets.symmetric(vertical: 14),
    minimumSize: Size(AppButtonSizes.widthMedium, AppButtonSizes.heightMedium),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(50),
      side: const BorderSide(color: AppColors.borderColor),
    ),
    elevation: 2,
    textStyle: const TextStyle(fontSize: 16),
  );

  // Botón Facebook con tamaño mediano
  static final botonFacebook = ElevatedButton.styleFrom(
    backgroundColor: AppColors.botonFacebook,
    foregroundColor: AppColors.botonFacebookTexto,
    padding: const EdgeInsets.symmetric(vertical: 14),
    minimumSize: Size(AppButtonSizes.widthMedium, AppButtonSizes.heightMedium),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
    elevation: 2,
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
  );

  // Botón 2
  static final boton2 = ElevatedButton.styleFrom(
    padding: const EdgeInsets.symmetric(vertical: 16),
    minimumSize: Size(AppButtonSizes.widthMedium, AppButtonSizes.heightMedium),
    backgroundColor: AppColors.botonBlueGrey,
    foregroundColor: AppColors.botonBlueGreyText,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
  );

  // Botón deshabilitado con tamaño mediano y ancho medio
  static final ButtonStyle boton3 = ElevatedButton.styleFrom(
    backgroundColor: Colors.grey.shade400,
    foregroundColor: Colors.grey.shade700,
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
    minimumSize: Size(AppButtonSizes.widthMedium, AppButtonSizes.heightMedium),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    elevation: 0,
  );

  // Botón pequeño (por ejemplo: "Mapa", "Editar", etc.)
  static Widget botonSmall({
    required String text,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 70,
      height: 25,
      margin: const EdgeInsets.all(0),
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: AppColors.sombra,
            blurRadius: 2,
            offset: const Offset(2, 2),
          ),
        ],
        borderRadius: BorderRadius.circular(20),
      ),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: AppColors.botonGlobal,
          foregroundColor: AppColors.botonGlobalTexto,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  // Boton 4
  static final boton = ElevatedButton.styleFrom(
    backgroundColor: Colors.white,
    foregroundColor: Colors.black87,
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
    minimumSize: Size(AppButtonSizes.widthFull, AppButtonSizes.heightMedium),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: Colors.grey),
    ),
    elevation: 4,
    shadowColor: Colors.black26,
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
  );

  // Widget para botón con iconos a izquierda y derecha
  static Widget boton4({
    required String text,
    required VoidCallback onPressed,
    required IconData leftIcon,
    required IconData rightIcon,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: boton,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(leftIcon, color: Colors.black87),
          const SizedBox(width: 8),
          Text(text),
          const SizedBox(width: 8),
          Icon(rightIcon, color: Colors.black87),
        ],
      ),
    );
  }
}

class Boton5 extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData? iconoIzquierdo;
  final IconData? iconoDerecho;
  final String texto;
  final Color colorFondo;
  final Color colorBorde;
  final double radioBorde;
  final Color? colorIcono;
  final Color? colorTexto;
  final bool mostrarSeparador;

  const Boton5({
    super.key,
    required this.onPressed,
    required this.texto,
    this.iconoIzquierdo,
    this.iconoDerecho,
    this.colorFondo = Colors.red,
    this.colorBorde = Colors.red,
    this.radioBorde = 16,
    this.colorIcono,
    this.colorTexto,
    this.mostrarSeparador = true,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = colorIcono ?? Colors.white;
    final textoColor = colorTexto ?? Colors.white;

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        //height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: colorFondo,
          borderRadius: BorderRadius.circular(radioBorde),
          border: Border.all(color: colorBorde, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color.fromARGB(179, 0, 0, 0),
              blurRadius: 2,
              offset: Offset(2, 2),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (iconoIzquierdo != null)
                  Icon(iconoIzquierdo, color: iconColor),
                if (iconoDerecho != null) Icon(iconoDerecho, color: iconColor),
              ],
            ),
            Center(
              child: Text(
                texto,
                style: TextStyle(
                  fontSize: 20,
                  color: textoColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /*
Ejemplo de uso:
Boton5(
  texto: '¿A dónde y por cuánto?',
  iconoIzquierdo: Icons.flag,
  iconoDerecho: Icons.arrow_forward,
  onPressed: () {
    // tu lógica
  },
)
*/
}

// Boton simulador de input
class InputFalso extends StatelessWidget {
  final String label;
  final Widget? prefixIcon; // antes era IconData icon
  final VoidCallback onTap;

  const InputFalso({required this.label, required this.onTap, this.prefixIcon});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            if (prefixIcon != null) prefixIcon!,
            if (prefixIcon != null) const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 14, color: Colors.grey[800]),
              ),
            ),
            const Icon(Icons.expand_more, color: Colors.black),
          ],
        ),
      ),
    );
  }
}
