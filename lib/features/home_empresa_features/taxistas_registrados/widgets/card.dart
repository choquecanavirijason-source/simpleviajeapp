import 'package:flutter/material.dart';

class TaxistaCard extends StatelessWidget {
  final String? nombre;
  final String? telefono;
  final String? estado;
  final String? fotoUrl;
  final VoidCallback? onVerDetalles;

  const TaxistaCard({
    super.key,
    this.nombre,
    this.telefono,
    this.estado,
    this.fotoUrl,
    this.onVerDetalles,
  });

  bool _has(String? s) => s != null && s.trim().isNotEmpty;

  Color get _estadoColor {
    switch ((estado ?? '').trim().toLowerCase()) {
      case 'aprobado':
        return Colors.green;
      case 'pendiente':
        return Colors.orange;
      case 'rechazado':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData get _estadoIcon {
    switch ((estado ?? '').trim().toLowerCase()) {
      case 'aprobado':
        return Icons.check_circle;
      case 'pendiente':
        return Icons.hourglass_empty;
      case 'rechazado':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasNombre = _has(nombre);
    final hasTelefono = _has(telefono);
    final hasEstado = _has(estado);
    final hasFoto = _has(fotoUrl);
    final hasBoton = onVerDetalles != null;

    // Si no hay nada que mostrar, no renderizar nada
    if (!(hasNombre || hasTelefono || hasEstado || hasFoto || hasBoton)) {
      return const SizedBox.shrink();
    }

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.grey, width: 0.4),
      ),
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(10, 2, 10, 2),
        leading: hasFoto
            ? CircleAvatar(radius: 28, backgroundImage: NetworkImage(fotoUrl!))
            : null, // 👈 si no hay foto, no se muestra nada
        title: hasNombre
            ? Text(
                nombre!,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              )
            : null, // 👈 si no hay nombre, no aparece
        subtitle: (hasTelefono || hasEstado)
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasTelefono) ...[
                    const SizedBox(height: 4),
                    Text("Telefono: $telefono"),
                  ],
                  if (hasEstado) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(_estadoIcon, color: _estadoColor, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          estado!,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _estadoColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              )
            : null, // 👈 si no hay nada, no hay subtitle
        trailing: hasBoton
            ? ElevatedButton(
                onPressed: onVerDetalles,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text("Ver"),
              )
            : null, // 👈 si no hay callback, no hay botón
      ),
    );
  }
}

/* Ejemplo de uso:
TaxistaCard(
  nombre: taxista.perfil.nombre?.trim().isNotEmpty == true
      ? taxista.perfil.nombre
      : null,
  telefono: (taxista.perfil.telefono ?? '').trim().isNotEmpty
      ? taxista.perfil.telefono
      : null,
  estado: (taxista.estado ?? '').trim().isNotEmpty
      ? taxista.estado
      : null,
  fotoUrl: (taxista.perfil.fotoPerfil ?? '').trim().isNotEmpty
      ? taxista.perfil.fotoPerfil
      : null,
  onVerDetalles: () {
    // Acción al presionar "Ver"
  },
);
*/
