import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class RideBadge extends StatelessWidget {
  const RideBadge({
    super.key,
    required this.text,
    required this.bg,
    required this.fg,
    this.icon,
  });

  final String text;
  final Color bg;
  final Color fg;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: TextStyle(color: fg, fontWeight: FontWeight.w700, height: 1),
          ),
        ],
      ),
    );
  }
}

class RideRequestCard2080 extends StatelessWidget {
  const RideRequestCard2080({
    super.key,
    // Izquierda
    required this.passengerName,
    required this.rating,
    required this.ratingCount,
    this.avatarInitial,
    this.avatarImage,
    this.avatarBg,
    required this.timeText,
    // Derecha
    required this.distanceKm,
    required this.priceText,
    required this.title,
    required this.subtitle,
    this.headerBadges = const [],
    this.belowPriceBadges = const [],
    // Programado
    this.isProgramado = false,
    this.scheduleDatesText,
    this.scheduleTimeText,
    // Acciones (compatibilidad; no se usa menú)
    this.menuItems = const [],
    this.onMenuSelect,
    this.onTap,
    // Estilo
    this.elevation = 0,
    this.leftFactor = 0.20,
    this.minLeft = 78,
    // Live profile (opcional)
    this.uidPasajero,
    this.fallbackNombre,
    this.fallbackFotoUrl,
    // Botones de acción de la tarjeta
    this.showMarkEnCamino = false,
    this.onMarkEnCamino,
    this.showVerRuta = false,
    this.onVerRuta,
    // Estado visible
    this.estadoText,
    this.estadoBg,
    this.estadoFg,
  });

  // Izquierda
  final String passengerName;
  final double rating;
  final int ratingCount;
  final String? avatarInitial;
  final ImageProvider? avatarImage;
  final Color? avatarBg;
  final String timeText;

  // Derecha
  final double distanceKm;
  final String priceText;
  final String title;
  final String subtitle;
  final List<RideBadge> headerBadges;
  final List<RideBadge> belowPriceBadges;

  // Programado
  /// OJO: para que se pinte el ✔, manda una lista de maps:
  /// [{'text':'20/11/2025','completed':true}, {'text':'21/11/2025','completed':false}, ...]
  final bool isProgramado;
  final List<dynamic>? scheduleDatesText;
  final String? scheduleTimeText;

  // Menú (no usado)
  final List<PopupMenuEntry<String>> menuItems;
  final ValueChanged<String>? onMenuSelect;
  final VoidCallback? onTap;

  // Estilo
  final double elevation;
  final double leftFactor;
  final double minLeft;

  // Live
  final String? uidPasajero;
  final String? fallbackNombre;
  final String? fallbackFotoUrl;

  // Acciones específicas
  final bool showMarkEnCamino;
  final VoidCallback? onMarkEnCamino;

  final bool showVerRuta;
  final VoidCallback? onVerRuta;

  // Estado visible en la tarjeta
  final String? estadoText;
  final Color? estadoBg;
  final Color? estadoFg;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final distanceStr = distanceKm <= 0
        ? ''
        : '~${distanceKm.toStringAsFixed(1)}km';

    final hasDates = scheduleDatesText != null && scheduleDatesText!.isNotEmpty;
    final hasTime =
        scheduleTimeText != null && scheduleTimeText!.trim().isNotEmpty;
    final hasProgramacion = isProgramado && (hasDates || hasTime);

    return Material(
      color: Colors.white,
      elevation: elevation,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: LayoutBuilder(
            builder: (context, c) {
              final leftW = c.maxWidth * leftFactor;
              final sideWidth = leftW < minLeft ? minLeft : leftW;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // IZQUIERDA (20%)
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: minLeft,
                          maxWidth: sideWidth,
                        ),
                        child: (uidPasajero == null || uidPasajero!.isEmpty)
                            ? _UserBlock(
                                passengerName: passengerName,
                                rating: rating,
                                ratingCount: ratingCount,
                                avatarInitial: avatarInitial,
                                avatarImage: avatarImage,
                                avatarBg: avatarBg,
                                timeText: timeText,
                              )
                            : _UserBlockLive(
                                uidPasajero: uidPasajero!,
                                rating: rating,
                                ratingCount: ratingCount,
                                timeText: timeText,
                                avatarBg: avatarBg,
                                fallbackNombre: fallbackNombre ?? passengerName,
                                fallbackFotoUrl: fallbackFotoUrl,
                              ),
                      ),
                      const SizedBox(width: 8),
                      // DERECHA (80%)
                      Expanded(
                        child: _TripBlock(
                          distanceStr: distanceStr,
                          priceText: priceText,
                          title: title,
                          subtitle: subtitle,
                          headerBadges: headerBadges,
                          belowPriceBadges: belowPriceBadges,
                          menuItems: menuItems,
                          onMenuSelect: onMenuSelect,
                          theme: theme,
                          estadoText: estadoText,
                          estadoBg: estadoBg,
                          estadoFg: estadoFg,
                        ),
                      ),
                    ],
                  ),

                  // === Bloque de VIAJE PROGRAMADO a lo ancho de la card ===
                  if (hasProgramacion) ...[
                    const SizedBox(height: 10),
                    ProgramadoMinimalBlock(
                      scheduleDatesText: scheduleDatesText,
                      scheduleTimeText: scheduleTimeText,
                    ),
                  ],

                  // === Zona de botones bajo la tarjeta ===
                  if (showMarkEnCamino || showVerRuta) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (showMarkEnCamino)
                          ElevatedButton.icon(
                            onPressed: onMarkEnCamino,
                            icon: const Icon(Icons.route),
                            label: const Text('Marcar en camino'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              elevation: 0,
                            ),
                          ),
                        if (showMarkEnCamino && showVerRuta)
                          const SizedBox(width: 10),
                        if (showVerRuta)
                          ElevatedButton.icon(
                            onPressed: onVerRuta,
                            icon: const Icon(Icons.map_rounded),
                            label: const Text('Ver ruta'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0EA5E9),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              elevation: 0,
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _UserBlockLive extends StatelessWidget {
  const _UserBlockLive({
    required this.uidPasajero,
    required this.rating,
    required this.ratingCount,
    required this.timeText,
    this.avatarBg,
    required this.fallbackNombre,
    this.fallbackFotoUrl,
  });

  final String uidPasajero;
  final double rating;
  final int ratingCount;
  final String timeText;
  final Color? avatarBg;
  final String fallbackNombre;
  final String? fallbackFotoUrl;

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: db.collection('pasajeros').doc(uidPasajero).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return _UserBlock(
            passengerName: fallbackNombre,
            rating: rating,
            ratingCount: ratingCount,
            timeText: timeText,
            avatarBg: avatarBg,
            avatarInitial: fallbackNombre.characters.first.toUpperCase(),
            avatarImage:
                (fallbackFotoUrl != null && fallbackFotoUrl!.isNotEmpty)
                ? NetworkImage(fallbackFotoUrl!)
                : null,
          );
        }

        final raw = snap.data?.data() ?? const <String, dynamic>{};
        final perfil = (raw['perfil'] is Map)
            ? Map<String, dynamic>.from(raw['perfil'])
            : const <String, dynamic>{};

        final nombre = (raw['name'] ?? perfil['name'] ?? fallbackNombre)
            .toString();
        final foto = (raw['photoUrl'] ?? perfil['photoUrl'] ?? fallbackFotoUrl)
            ?.toString();
        final fotoSan = (foto != null && foto.trim().isNotEmpty) ? foto : null;

        return _UserBlock(
          passengerName: nombre,
          rating: rating,
          ratingCount: ratingCount,
          timeText: timeText,
          avatarBg: avatarBg,
          avatarInitial: (fotoSan == null)
              ? nombre.characters.first.toUpperCase()
              : null,
          avatarImage: (fotoSan != null) ? NetworkImage(fotoSan) : null,
        );
      },
    );
  }
}

class _UserBlock extends StatelessWidget {
  const _UserBlock({
    required this.passengerName,
    required this.rating,
    required this.ratingCount,
    required this.timeText,
    this.avatarInitial,
    this.avatarImage,
    this.avatarBg,
  });

  final String passengerName;
  final double rating;
  final int ratingCount;
  final String timeText;

  final String? avatarInitial;
  final ImageProvider? avatarImage;
  final Color? avatarBg;

  @override
  Widget build(BuildContext context) {
    final primary = Colors.black87;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: avatarBg ?? const Color(0xFFE9F5FF),
          backgroundImage: avatarImage,
          child: avatarImage == null
              ? Text(
                  (avatarInitial ?? 'P').toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                )
              : null,
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: Text(
            passengerName,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF2B01E)),
            const SizedBox(width: 3),
            Text(
              rating.toStringAsFixed(1),
              style: TextStyle(
                color: primary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                '($ratingCount)',
                style: TextStyle(color: primary.withOpacity(.55), fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.left,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: Text(
            timeText,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 12,
              height: 1.15,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _TripBlock extends StatelessWidget {
  const _TripBlock({
    required this.distanceStr,
    required this.priceText,
    required this.title,
    required this.subtitle,
    required this.headerBadges,
    required this.belowPriceBadges,
    required this.menuItems,
    required this.onMenuSelect,
    required this.theme,
    required this.estadoText,
    required this.estadoBg,
    required this.estadoFg,
  });

  final String distanceStr;
  final String priceText;
  final String title;
  final String subtitle;
  final List<RideBadge> headerBadges;
  final List<RideBadge> belowPriceBadges;
  final List<PopupMenuEntry<String>> menuItems;
  final ValueChanged<String>? onMenuSelect;
  final ThemeData theme;

  final String? estadoText;
  final Color? estadoBg;
  final Color? estadoFg;

  @override
  Widget build(BuildContext context) {
    IconData estadoIcon = Icons.flag_rounded;
    Color chipBg = estadoBg ?? const Color(0xFFF5F5F5);
    Color chipFg = estadoFg ?? const Color(0xFF616161);

    if (estadoText != null && estadoText!.isNotEmpty) {
      final est = estadoText!.toLowerCase();

      if (est.contains('complet')) {
        chipBg = const Color(0xFFE8F5E9);
        chipFg = const Color(0xFF1B5E20);
        estadoIcon = Icons.check_circle_rounded;
      } else if (est.contains('en_curso') || est.contains('en curso')) {
        chipBg = const Color(0xFFE3F2FD);
        chipFg = const Color(0xFF1565C0);
        estadoIcon = Icons.play_circle_rounded;
      } else if (est.contains('en_camino') || est.contains('en camino')) {
        chipBg = const Color(0xFFEDE9FE);
        chipFg = const Color(0xFF5B21B6);
        estadoIcon = Icons.directions_car_rounded;
      } else if (est.contains('en_lugar')) {
        chipBg = const Color(0xFFE0F2F1);
        chipFg = const Color(0xFF00695C);
        estadoIcon = Icons.my_location_rounded;
      } else if (est.contains('acept')) {
        chipBg = const Color(0xFFE0F2FE);
        chipFg = const Color(0xFF0369A1);
        estadoIcon = Icons.schedule_rounded;
      } else if (est.contains('cancel') || est.contains('rechaz')) {
        chipBg = const Color(0xFFFEE2E2);
        chipFg = const Color(0xFFB91C1C);
        estadoIcon = Icons.cancel_rounded;
      } else if (est.contains('pend')) {
        chipBg = const Color(0xFFFFF7ED);
        chipFg = const Color(0xFFC05621);
        estadoIcon = Icons.hourglass_bottom_rounded;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (distanceStr.isNotEmpty) ...[
          Text(
            distanceStr,
            style: const TextStyle(color: Colors.black54, fontSize: 13),
          ),
          const SizedBox(height: 4),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Wrap(
                spacing: 10,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (priceText.isNotEmpty)
                    Text(
                      priceText,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ...headerBadges,
                ],
              ),
            ),
            if (estadoText != null && estadoText!.isNotEmpty)
              RideBadge(
                text: estadoText!,
                bg: chipBg,
                fg: chipFg,
                icon: estadoIcon,
              ),
          ],
        ),

        const SizedBox(height: 8),

        if (belowPriceBadges.isNotEmpty) ...[
          Wrap(spacing: 8, runSpacing: 6, children: belowPriceBadges),
          const SizedBox(height: 8),
        ],

        // ===== Origen (una sola fila) =====
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2.0),
              child: Icon(
                Icons.location_on_rounded,
                size: 18,
                color: Colors.red,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 4),

        // ===== Destino (una sola fila) =====
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2.0),
              child: Icon(
                Icons.location_on_rounded,
                size: 18,
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                subtitle,
                style: const TextStyle(fontSize: 15, height: 1.2),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Item interno para ProgramadoMinimalBlock:
/// fecha cruda + si está completada.
class _ProgramadoFechaItem {
  final String raw;
  final bool completed;

  _ProgramadoFechaItem(this.raw, this.completed);
}

/// Widget reutilizable para la sección "Viaje programado" (minimalista),
/// ocupando TODO el ancho de la card.
class ProgramadoMinimalBlock extends StatelessWidget {
  const ProgramadoMinimalBlock({
    super.key,
    required this.scheduleDatesText,
    required this.scheduleTimeText,
  });

  final List<dynamic>? scheduleDatesText;
  final String? scheduleTimeText;

  @override
  Widget build(BuildContext context) {
    final hasDates = scheduleDatesText != null && scheduleDatesText!.isNotEmpty;
    final hasTime =
        scheduleTimeText != null && scheduleTimeText!.trim().isNotEmpty;

    // Convertimos a lista de {_ProgramadoFechaItem}
    final List<_ProgramadoFechaItem> fechasList = hasDates
        ? scheduleDatesText!
              .map<_ProgramadoFechaItem>((e) {
                String raw;
                bool completed = false;

                if (e is Map && e['text'] != null) {
                  raw = e['text'].toString();
                  completed = e['completed'] == true;
                } else {
                  raw = e.toString();
                }

                return _ProgramadoFechaItem(raw.trim(), completed);
              })
              .where((f) => f.raw.isNotEmpty)
              .toList()
        : const <_ProgramadoFechaItem>[];

    // Ordenar por fecha (usando la fecha cruda dd/MM/yyyy)
    final List<_ProgramadoFechaItem> fechasOrdenadas = [...fechasList];
    fechasOrdenadas.sort((a, b) {
      final pa = _parseDdMmYyyy(a.raw);
      final pb = _parseDdMmYyyy(b.raw);
      if (pa == null || pb == null) return 0;
      return pa.compareTo(pb);
    });

    if (!hasDates && !hasTime) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB), // gris muy suave
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(
                Icons.event_available_rounded,
                size: 18,
                color: Color(0xFF1D4ED8),
              ),
              const SizedBox(width: 6),
              const Text(
                'Viaje programado',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
              const Spacer(),
              if (hasTime)
                Text(
                  scheduleTimeText!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF4B5563),
                  ),
                ),
            ],
          ),

          if (fechasOrdenadas.isNotEmpty) ...[
            const SizedBox(height: 6),
            const Text(
              'Fechas programadas',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 4),

            // 3 fechas por fila, texto simple pero con ✔ cuando está completada
            LayoutBuilder(
              builder: (context, constraints) {
                const double spacing = 6;
                final double colWidth =
                    (constraints.maxWidth - (spacing * 2)) / 3;

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: fechasOrdenadas.map((item) {
                    final dt = _parseDdMmYyyy(item.raw);

                    const dias = [
                      'Lun',
                      'Mar',
                      'Mié',
                      'Jue',
                      'Vie',
                      'Sáb',
                      'Dom',
                    ];
                    const meses = [
                      'Ene',
                      'Feb',
                      'Mar',
                      'Abr',
                      'May',
                      'Jun',
                      'Jul',
                      'Ago',
                      'Sep',
                      'Oct',
                      'Nov',
                      'Dic',
                    ];

                    String label;
                    if (dt != null) {
                      final diaSemana = dias[dt.weekday - 1];
                      final dia = dt.day.toString().padLeft(2, '0');
                      final mes = meses[dt.month - 1];
                      label = '$diaSemana $dia $mes ${dt.year}';
                    } else {
                      label = item.raw;
                    }

                    final textColor = item.completed
                        ? const Color(0xFF16A34A)
                        : const Color(0xFF111827);

                    return SizedBox(
                      width: colWidth,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (item.completed) ...[
                            Container(
                              margin: const EdgeInsets.only(right: 4),
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Color(0xFF16A34A),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ],
                          Expanded(
                            child: Text(
                              label,
                              textAlign: TextAlign.left,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: textColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  /// Helper para parsear "dd/MM/yyyy"
  static DateTime? _parseDdMmYyyy(String s) {
    final parts = s.split('/');
    if (parts.length < 3) return null;
    final d = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final y = int.tryParse(parts[2]);
    if (d == null || m == null || y == null) return null;
    return DateTime(y, m, d);
  }
}
