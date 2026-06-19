import 'package:flutter/material.dart';
import 'package:buses2/shared/widgets/controles/switch.dart'; // tu Switch3
import 'package:buses2/shared/widgets/etiquetas/etiqueta_estado.dart'; // 👈 importa tu etiqueta

class InfoBoxAction {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const InfoBoxAction({
    required this.icon,
    required this.onTap,
    this.color = Colors.blue,
  });
}

class InfoBox extends StatelessWidget {
  final int? numero; // opcional
  final IconData? icono; // 👈 nuevo: icono en vez del número
  final Color? iconoColor;
  final String titulo;
  final bool? initialValue; // opcional para switch
  final ValueChanged<bool>? onToggle;
  final String? estado; // 👈 nuevo: etiqueta de estado
  final List<InfoBoxAction>? actions;

  const InfoBox({
    super.key,
    this.numero,
    this.icono,
    this.iconoColor,
    required this.titulo,
    this.initialValue,
    this.onToggle,
    this.estado,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    Widget? leading;

    if (icono != null) {
      leading = CircleIcon(
        icon: icono!,
        backgroundColor: iconoColor ?? Colors.blue,
        iconColor: Colors.white,
        size: 40,
      );
    } else if (numero != null) {
      leading = Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Colors.blue.shade300, Colors.blue.shade700],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Text(
            numero.toString(),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(0),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.grey, width: 0.4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icono o número
            if (leading != null) ...[leading, const SizedBox(width: 12)],

            // Texto principal
            Expanded(
              child: Text(
                titulo,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),

            // 👇 Estado tiene prioridad sobre el switch
            if (estado != null) ...[
              EtiquetaEstado(estado!),
              const SizedBox(width: 12),
            ] else if (initialValue != null) ...[
              Switch3(
                initialValue: initialValue!,
                onChanged: onToggle,
                activeGradient: const [Colors.blue, Colors.lightBlueAccent],
                inactiveGradient: const [Colors.grey, Colors.black26],
              ),
              const SizedBox(width: 12),
            ],

            // Botones dinámicos
            if (actions != null)
              ...actions!.map(
                (a) => Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: a.onTap,
                      child: Icon(a.icon, size: 22, color: a.color),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/* Ejemplo de uso:
import 'package:buses2/shared/widgets/cajas/caja_edit/caja_edit.dart';
...
InfoBox(
  numero: 1,
  titulo: "Licencia de conducir",
  estado: "aprobado", // etiqueta estado
  initialValue: true, // switch
  onToggle: (v) => debugPrint("Toggle licencia: $v"),
  actions: [
    InfoBoxAction(
      icon: Icons.edit,
      color: Colors.blue,
      onTap: () => debugPrint("Editar licencia"),
    ),
    InfoBoxAction(
      icon: Icons.delete,
      color: Colors.redAccent,
      onTap: () => debugPrint("Eliminar licencia"),
    ),
  ],
),
*/

class CircleIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color backgroundColor;
  final Color iconColor;
  final VoidCallback? onTap;

  const CircleIcon({
    super.key,
    required this.icon,
    this.size = 48.0,
    this.backgroundColor = Colors.blue,
    this.iconColor = Colors.white,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(icon, color: iconColor, size: size * 0.6),
        ),
      ),
    );
  }
}

/* Ejemplo de uso:
import 'package:buses2/shared/widgets/cajas/caja_edit/caja_edit.dart';
...
CircleIcon(
  icon: Icons.local_taxi,
  backgroundColor: Colors.blueGrey,
  iconColor: Colors.white,
  size: 40,
  onTap: () => debugPrint("Icono taxi"),
),
*/
