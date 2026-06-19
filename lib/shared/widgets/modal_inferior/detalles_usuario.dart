import 'package:flutter/material.dart';
import 'package:buses2/shared/widgets/etiquetas/etiqueta_estado.dart';
import 'package:buses2/shared/widgets/etiquetas/etiqueta_servicio.dart';
import 'package:buses2/shared/widgets/phone_display_widget.dart';

class DetallesUsuarioBottomSheet {
  static void show(
    BuildContext context, {
    required String nombre,
    required String telefono,
    String? codigoPais, // Nuevo parámetro opcional
    required String correo,
    String? fotoUrl, // ✅ opcional aquí
    required String estado,
    required Widget child,
    double? puntuacion,
    List<Color> headerColors = const [Color(0xFF1565C0), Color(0xFF42A5F5)],
    List<EtiquetaServicio> servicios = const [],
    List<String>? opcionesEstado,
    Future<void> Function(String nuevoEstado)? onConfirmar,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _DetallesUsuarioContent(
          nombre: nombre,
          telefono: telefono,
          codigoPais: codigoPais, // Pasar código de país
          correo: correo,
          fotoUrl: fotoUrl, // ✅ pasa nullable
          estado: estado,
          child: child,
          puntuacion: puntuacion,
          headerColors: headerColors,
          servicios: servicios,
          opcionesEstado: opcionesEstado,
          onConfirmar: onConfirmar,
        );
      },
    );
  }
}

class _DetallesUsuarioContent extends StatelessWidget {
  final String nombre;
  final String telefono;
  final String? codigoPais; // Código de país opcional
  final String correo;
  final String? fotoUrl; // ✅ ahora nullable
  final String estado;
  final Widget child;
  final List<Color> headerColors;
  final double? puntuacion;
  final List<EtiquetaServicio> servicios;
  final List<String>? opcionesEstado; // 🆕
  final Future<void> Function(String nuevoEstado)? onConfirmar;

  const _DetallesUsuarioContent({
    required this.nombre,
    required this.telefono,
    this.codigoPais, // Opcional, defaulta a Bolivia
    required this.correo,
    this.fotoUrl, // ✅ ya no required
    required this.estado,
    required this.child,
    required this.headerColors,
    this.puntuacion,
    this.servicios = const [],
    this.opcionesEstado,
    this.onConfirmar,
  });

  bool get _tieneFoto => (fotoUrl != null && fotoUrl!.trim().isNotEmpty);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [BoxShadow(blurRadius: 20, color: Colors.black26)],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: Material(
              color: Colors.white,
              child: CustomScrollView(
                controller: scrollController,
                slivers: [
                  SliverToBoxAdapter(
                    child: Stack(
                      children: [
                        // Header con gradiente
                        Container(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: headerColors,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: _HeaderUsuario(
                            nombre: nombre,
                            telefono: telefono,
                            codigoPais: codigoPais,
                            correo: correo,
                            fotoUrl: fotoUrl,
                            estado: estado,
                            puntuacion: puntuacion,
                            servicios: servicios,
                            opcionesEstado: opcionesEstado,
                            onConfirmar: onConfirmar,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Body ocupa todo el espacio restante (tight constraints)
                  SliverFillRemaining(
                    hasScrollBody: false, // el hijo gestiona su propio scroll
                    child: child, // 👈 aquí va tu ScaffoldConBottom
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HeaderUsuario extends StatelessWidget {
  final String nombre;
  final String telefono;
  final String? codigoPais;
  final String correo;
  final String? fotoUrl;
  final String estado;
  final double? puntuacion;
  final List<EtiquetaServicio> servicios;
  final List<String>? opcionesEstado; // 🆕
  final Future<void> Function(String nuevoEstado)? onConfirmar;

  const _HeaderUsuario({
    required this.nombre,
    required this.telefono,
    this.codigoPais,
    required this.correo,
    this.fotoUrl,
    required this.estado,
    this.puntuacion,
    this.servicios = const [],
    this.opcionesEstado,
    this.onConfirmar,
  });

  bool get _tieneFoto => fotoUrl != null && fotoUrl!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final textColor = Colors.white.withOpacity(0.85);
    final iconColor = Colors.white70;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // -------- Fila 1: Nombre | Estado --------
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (_tieneFoto) ...[
              CircleAvatar(radius: 40, backgroundImage: NetworkImage(fotoUrl!)),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: Text(
                nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            EtiquetaEstado(
              estado,
              opciones: opcionesEstado,
              onEstadoCambiado: (seleccionado) async {
                if (seleccionado != null && onConfirmar != null) {
                  await onConfirmar!(
                    seleccionado,
                  ); // ✅ pasa el nuevo estado y espera el Future
                }
              },
            ),
          ],
        ),

        const SizedBox(height: 8),

        // --- Fila 2: Teléfono (izq) | Servicios (der, debajo del estado) ---
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Izquierda: teléfono con bandera
            Expanded(
              child: PhoneDisplayWidget(
                phone: telefono,
                countryCode:
                    codigoPais, // Usar código de país o default Bolivia
                showIcon: true,
                icon: Icons.phone,
                iconColor: iconColor,
                textStyle: TextStyle(color: textColor),
              ),
            ),
            const SizedBox(width: 8),

            // Derecha: servicios  👉 pegado al rincón derecho
            if (servicios.isNotEmpty)
              Expanded(
                // <- antes era Flexible; usa Expanded
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: servicios,
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 8),

        // -------- Fila 3: Correo | (opcional) puntuación --------
        _InfoTexto(correo: correo, puntuacion: puntuacion),
      ],
    );
  }
}

class _InfoTexto extends StatelessWidget {
  final String correo;
  final double? puntuacion;

  const _InfoTexto({required this.correo, this.puntuacion});

  @override
  Widget build(BuildContext context) {
    final textColor = Colors.white.withOpacity(0.85);
    final iconColor = Colors.white70;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.email, size: 16, color: iconColor),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            correo,
            style: TextStyle(color: textColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (puntuacion != null) ...[
          const SizedBox(width: 8),
          _StarRating(rating: puntuacion!.clamp(0, 5).toDouble()),
          const SizedBox(width: 6),
          Text(
            puntuacion!.toStringAsFixed(1),
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _StarRating extends StatelessWidget {
  final double rating; // 0.0 - 5.0
  final int maxStars;

  const _StarRating({required this.rating, this.maxStars = 5});

  @override
  Widget build(BuildContext context) {
    final fullStars = rating.floor();
    final hasHalf = (rating - fullStars) >= 0.25 && (rating - fullStars) < 0.75;
    final extraFull = (rating - fullStars) >= 0.75 ? 1 : 0;
    final totalFull = (fullStars + extraFull).clamp(0, maxStars);

    final icons = <Widget>[];
    for (int i = 0; i < maxStars; i++) {
      IconData icon;
      if (i < totalFull) {
        icon = Icons.star;
      } else if (hasHalf && i == fullStars) {
        icon = Icons.star_half;
      } else {
        icon = Icons.star_border;
      }
      icons.add(Icon(icon, size: 18, color: Colors.amberAccent));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: icons);
  }
}

/* Ejemplo de uso:
DetallesUsuarioBottomSheet.show(
  context,
  nombre: "Juan Pérez",
  telefono: "+34 600 123 456",
  correo: "hola@gmail.com",
  fotoUrl: "https://i.pravatar.cc/200?img=5",
  estado: "aprobado",
  puntuacion: 4.3,
  headerColors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
  child: Column(
    children: [
      InfoBox(
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
        ],
      ),
      const SizedBox(height: 12),
      InfoBox(
        titulo: "Seguro del vehículo",
        estado: "pendiente", // etiqueta estado
        actions: [
          InfoBoxAction(
            icon: Icons.edit,
            color: Colors.blue,
            onTap: () => debugPrint("Editar seguro"),
          ),
        ],
      ),
    ],
  ),
);
*/
