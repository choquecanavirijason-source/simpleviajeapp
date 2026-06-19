// import 'package:buses2/shared/widgets/botones/boton.dart';
import 'package:flutter/material.dart';

enum BotonColor { color1, color2, color3 }

enum BotonBorde { borde1, borde2, borde3 }

class Boton1 extends StatelessWidget {
  final String label;
  final IconData? iconoIzquierdo;
  final IconData? iconoDerecho;
  final VoidCallback? onPressed;
  final BotonColor color;
  final BotonBorde borde;

  const Boton1({
    super.key,
    required this.label,
    this.iconoIzquierdo,
    this.iconoDerecho,
    this.onPressed,
    this.color = BotonColor.color1,
    this.borde = BotonBorde.borde1,
  });

  Color _getColor() {
    switch (color) {
      case BotonColor.color1:
        return Colors.green;
      case BotonColor.color2:
        return Colors.blue;
      case BotonColor.color3:
        return Color(0xFF4CB050);
    }
  }

  OutlinedBorder _getBorde() {
    switch (borde) {
      case BotonBorde.borde1:
        return RoundedRectangleBorder(borderRadius: BorderRadius.circular(50));
      case BotonBorde.borde2:
        return RoundedRectangleBorder(borderRadius: BorderRadius.circular(13));
      case BotonBorde.borde3:
        return RoundedRectangleBorder(borderRadius: BorderRadius.circular(0));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Colors.white;
    final displayText = label;

    return Container(
      decoration: BoxDecoration(
        borderRadius: (_getBorde() as RoundedRectangleBorder).borderRadius,
        boxShadow: const [
          BoxShadow(
            color: Color.fromARGB(151, 0, 0, 0), // Sombra fuerte
            blurRadius: 1, // Sombra bien definida
            offset: Offset(-1.5, 2.5), // Un poco hacia abajo
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _getColor(),
          shape: _getBorde(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          minimumSize: const Size.fromHeight(50),
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            iconoIzquierdo != null
                ? Icon(iconoIzquierdo, color: textColor)
                : const SizedBox(width: 24),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            iconoDerecho != null
                ? Icon(iconoDerecho, color: textColor)
                : const SizedBox(width: 24),
          ],
        ),
      ),
    );
  }
}

/*Ejemplo de uso:
Boton1(
  label: 'Subir documentos',
  color: BotonColor.color2,
  borde: BotonBorde.borde1,
  iconoIzquierdo: Icons.upload_file,
  iconoDerecho: Icons.upload_file,
  onPressed: () {
    print('Botón presionado');
  },
),
*/
