import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// 🚕 Importaciones para billetera de taxista
import '../../home_taxi_features/billetera_taxista/services/taxista_wallet_service.dart';
import '../../home_taxi_features/billetera_taxista/models/taxista_wallet_models.dart';

class BilleteraPage extends StatefulWidget {
  const BilleteraPage({super.key});

  @override
  State<BilleteraPage> createState() => _BilleteraPageState();
}

class _BilleteraPageState extends State<BilleteraPage>
    with SingleTickerProviderStateMixin {
  final _svc = TaxistaWalletService();
  late TabController _tabController;

  // 🎨 Paleta base en torno a Colors.green
  static const _greenDark = Color(0xFF1B5E20); // primario fuerte
  static const _green = Colors.green;
  static final _greenMid = Colors.green.shade600;
  static final _greenSoft = Colors.green.shade50; // fondos suaves

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    // 🔄 Refrescar forzando rebuild del Stream
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _greenSoft, // fondo general verdoso muy suave
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: Row(
          children: const [
            Icon(Icons.account_balance_wallet_rounded, color: Colors.green),
            SizedBox(width: 8),
            Text('Billetera'),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: _greenDark,
          unselectedLabelColor: Colors.grey,
          indicatorColor: _greenDark,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.add_circle_outline), text: 'Recargas'),
            Tab(icon: Icon(Icons.receipt_long), text: 'Comisiones'),
          ],
        ),
      ),
      body: StreamBuilder<TaxistaSaldo>(
        stream: _svc.streamSaldo(),
        builder: (context, saldoSnap) {
          if (saldoSnap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.green),
            );
          }
          if (saldoSnap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text('Error: ${saldoSnap.error}'),
              ),
            );
          }

          final saldo = saldoSnap.data!;

          return Column(
            children: [
              // Header con el saldo (siempre visible)
              _HeaderBalance(saldo: saldo),
              // Botón de recargar
              _ActionsRecargar(onTap: () => _mostrarDialogoRecarga(context)),
              const SizedBox(height: 8),
              // TabBarView con las dos pestañas
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Pestaña 1: Recargas
                    _TabRecargas(svc: _svc, onRefresh: _refresh),
                    // Pestaña 2: Comisiones
                    _TabComisiones(svc: _svc, onRefresh: _refresh),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ✂️ Método _applyFilter eliminado (sin filtros)

  static void _snack(BuildContext c, String msg) {
    ScaffoldMessenger.of(c).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _mostrarDialogoRecarga(BuildContext context) async {
    final montoCtrl = TextEditingController();
    final referenciaCtrl = TextEditingController();
    String metodoPago = 'efectivo';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Registrar Recarga'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: montoCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Monto (ARS)',
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: metodoPago,
                  decoration: const InputDecoration(
                    labelText: 'Método de Pago',
                    prefixIcon: Icon(Icons.payment),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'efectivo',
                      child: Text('Efectivo'),
                    ),
                    DropdownMenuItem(
                      value: 'transferencia',
                      child: Text('Transferencia'),
                    ),
                    DropdownMenuItem(value: 'tarjeta', child: Text('Tarjeta')),
                  ],
                  onChanged: (val) =>
                      setState(() => metodoPago = val ?? 'efectivo'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: referenciaCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Referencia (opcional)',
                    prefixIcon: Icon(Icons.receipt),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Registrar'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;

    final montoStr = montoCtrl.text.trim();
    if (montoStr.isEmpty) {
      if (context.mounted) _snack(context, 'Ingrese un monto');
      return;
    }

    final monto = double.tryParse(montoStr);
    if (monto == null || monto <= 0) {
      if (context.mounted) _snack(context, 'Monto inválido');
      return;
    }

    try {
      await _svc.registrarRecarga(
        monto: monto,
        metodoPago: metodoPago,
        referencia: referenciaCtrl.text.trim().isEmpty
            ? null
            : referenciaCtrl.text.trim(),
        notas: 'Recarga registrada desde la app',
      );
      if (context.mounted) {
        _snack(context, 'Recarga registrada correctamente');
      }
    } catch (e) {
      if (context.mounted) {
        _snack(context, 'Error al registrar recarga: $e');
      }
    }
  }
}

/// ───────────────────────── HEADER BALANCE (más verde) ─────────────────────────
class _HeaderBalance extends StatelessWidget {
  const _HeaderBalance({required this.saldo});
  final TaxistaSaldo saldo;

  @override
  Widget build(BuildContext context) {
    final f = NumberFormat.currency(locale: 'es_AR', symbol: 'ARS ');
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [Colors.green.shade800, Colors.green.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Saldo disponible',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            f.format(saldo.saldo),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          // ✂️ Estado de cuenta eliminado (no necesario para conductor)
        ],
      ),
    );
  }

  // ✂️ Métodos _miniStat y _statusDot eliminados
}

/// ───────────────────────── ACCIÓN ÚNICA: RECARGAR ─────────────────────────
class _ActionsRecargar extends StatelessWidget {
  const _ActionsRecargar({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.add_circle_rounded),
          label: const Text('Recargar'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
        ),
      ),
    );
  }
}

// ✂️ Widget _Filters eliminado (sin filtros de Ingresos/Egresos/Pendientes)

/// ───────────────────────── LISTA AGRUPADA ─────────────────────────
class _TransactionsList extends StatelessWidget {
  const _TransactionsList({required this.recargas});
  final List<RecargaHistorial> recargas;

  @override
  Widget build(BuildContext context) {
    // agrupar por día
    final groups = <String, List<RecargaHistorial>>{};
    final fDay = DateFormat('EEEE d', 'es'); // lunes 27
    for (final r in recargas) {
      final key = fDay.format(r.fecha.toLocal());
      groups.putIfAbsent(key, () => []).add(r);
    }

    return SliverList.separated(
      itemCount: groups.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final day = groups.keys.elementAt(index);
        final items = groups[day]!..sort((a, b) => b.fecha.compareTo(a.fecha));

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              Text(
                day,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.green.shade800,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              ...items.map(_TxnTile.new),
            ],
          ),
        );
      },
    );
  }
}

class _TxnTile extends StatelessWidget {
  const _TxnTile(this.recarga);
  final RecargaHistorial recarga;

  @override
  Widget build(BuildContext context) {
    final color = recarga.monto >= 0
        ? Colors.green.shade700
        : const Color(0xFFC62828);
    final f = NumberFormat.currency(locale: 'es_AR', symbol: 'ARS ');
    final hour = DateFormat('HH:mm').format(recarga.fecha.toLocal());

    // Título según método de pago
    final titulo = _getTitulo(recarga.metodoPago);
    final subtitulo = recarga.notas ?? recarga.referencia ?? 'Sin detalles';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(.10)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _methodIcon(recarga.metodoPago, color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Colors.green.shade900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitulo,
                  style: TextStyle(color: Colors.green.shade700, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _statusChip(recarga.estado),
                    const SizedBox(width: 8),
                    Text(
                      hour,
                      style: const TextStyle(
                        color: Colors.black45,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            (recarga.monto >= 0 ? '+' : '') +
                f.format(recarga.monto).replaceFirst('ARS ', ''),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  String _getTitulo(String metodoPago) {
    switch (metodoPago.toLowerCase()) {
      case 'transferencia':
        return 'Recarga por Transferencia';
      case 'efectivo':
        return 'Recarga en Efectivo';
      case 'tarjeta':
        return 'Recarga con Tarjeta';
      case 'descuento':
        return 'Descuento';
      default:
        return 'Recarga';
    }
  }

  Widget _methodIcon(String metodoPago, Color color) {
    final icon = switch (metodoPago.toLowerCase()) {
      'tarjeta' => Icons.credit_card_rounded,
      'transferencia' => Icons.swap_horiz_rounded,
      'efectivo' => Icons.payments_rounded,
      'descuento' => Icons.remove_circle_outline_rounded,
      _ => Icons.account_balance_wallet_rounded,
    };
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(.20)),
      ),
      child: Icon(icon, color: color),
    );
  }

  Widget _statusChip(String estado) {
    late Color bg, fg;
    late String text;
    switch (estado.toLowerCase()) {
      case 'completado':
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        text = 'Completado';
        break;
      case 'pendiente':
        bg = const Color(0xFFFFF8E1);
        fg = const Color(0xFFF9A825);
        text = 'Pendiente';
        break;
      case 'fallido':
        bg = const Color(0xFFFFEBEE);
        fg = const Color(0xFFC62828);
        text = 'Fallido';
        break;
      default:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade800;
        text = estado;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }
}

/// ───────────────────────── EMPTY ─────────────────────────
class _EmptyState extends StatelessWidget {
  final String mensaje;
  const _EmptyState({this.mensaje = 'Sin movimientos'});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: Colors.green.shade100,
            child: Icon(
              Icons.account_balance_wallet_outlined,
              size: 40,
              color: Colors.green.shade700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            mensaje,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 6),
          Text(
            'Cuando tengas movimientos, verás el historial aquí.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.green.shade800),
          ),
        ],
      ),
    );
  }
}

// ==================== PESTAÑAS ====================

/// Pestaña de Recargas
class _TabRecargas extends StatelessWidget {
  final TaxistaWalletService svc;
  final Future<void> Function() onRefresh;

  const _TabRecargas({required this.svc, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RecargaHistorial>>(
      stream: svc.streamHistorialRecargas(limite: 50),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.green),
          );
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final recargas = snapshot.data ?? [];

        if (recargas.isEmpty) {
          return const _EmptyState(mensaje: 'Sin recargas');
        }

        return RefreshIndicator(
          color: Colors.white,
          backgroundColor: Colors.green.shade600,
          onRefresh: onRefresh,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: recargas.length,
            itemBuilder: (context, i) => _TxnTileRecarga(recarga: recargas[i]),
          ),
        );
      },
    );
  }
}

/// Pestaña de Comisiones
class _TabComisiones extends StatelessWidget {
  final TaxistaWalletService svc;
  final Future<void> Function() onRefresh;

  const _TabComisiones({required this.svc, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ComisionHistorial>>(
      stream: svc.streamHistorialComisiones(limite: 50),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.green),
          );
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final comisiones = snapshot.data ?? [];

        if (comisiones.isEmpty) {
          return const _EmptyState(mensaje: 'Sin comisiones');
        }

        return RefreshIndicator(
          color: Colors.white,
          backgroundColor: Colors.green.shade600,
          onRefresh: onRefresh,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: comisiones.length,
            itemBuilder: (context, i) =>
                _TxnTileComision(comision: comisiones[i]),
          ),
        );
      },
    );
  }
}

// ==================== WIDGETS DE ITEMS ====================

/// Widget para mostrar una recarga en el historial
class _TxnTileRecarga extends StatelessWidget {
  final RecargaHistorial recarga;
  const _TxnTileRecarga({required this.recarga});

  @override
  Widget build(BuildContext context) {
    final color = recarga.monto >= 0
        ? Colors.green.shade700
        : const Color(0xFFC62828);
    final f = NumberFormat.currency(locale: 'es_AR', symbol: 'ARS ');
    final hour = DateFormat('HH:mm').format(recarga.fecha.toLocal());
    final day = DateFormat('dd MMM yyyy', 'es').format(recarga.fecha.toLocal());

    final titulo = _getTituloMetodoPago(recarga.metodoPago);
    final subtitulo = recarga.notas ?? recarga.referencia ?? 'Sin detalles';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(.10)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _methodIcon(recarga.metodoPago, color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Colors.green.shade900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitulo,
                  style: TextStyle(color: Colors.green.shade700, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _statusChip(recarga.estado),
                    const SizedBox(width: 8),
                    Text(
                      '$hour • $day',
                      style: TextStyle(
                        color: Colors.green.shade600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            (recarga.monto >= 0 ? '+' : '') +
                f.format(recarga.monto).replaceFirst('ARS ', ''),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  String _getTituloMetodoPago(String metodoPago) {
    switch (metodoPago.toLowerCase()) {
      case 'transferencia':
        return 'Recarga por Transferencia';
      case 'efectivo':
        return 'Recarga en Efectivo';
      case 'tarjeta':
        return 'Recarga con Tarjeta';
      case 'descuento':
        return 'Descuento';
      default:
        return 'Recarga';
    }
  }

  Widget _methodIcon(String metodoPago, Color color) {
    final icon = switch (metodoPago.toLowerCase()) {
      'tarjeta' => Icons.credit_card_rounded,
      'transferencia' => Icons.swap_horiz_rounded,
      'efectivo' => Icons.payments_rounded,
      'descuento' => Icons.remove_circle_outline_rounded,
      _ => Icons.account_balance_wallet_rounded,
    };
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(.20)),
      ),
      child: Icon(icon, color: color),
    );
  }

  Widget _statusChip(String estado) {
    late Color bg, fg;
    late String text;
    switch (estado.toLowerCase()) {
      case 'completado':
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        text = 'Completado';
        break;
      case 'pendiente':
        bg = const Color(0xFFFFF8E1);
        fg = const Color(0xFFF9A825);
        text = 'Pendiente';
        break;
      case 'fallido':
        bg = const Color(0xFFFFEBEE);
        fg = const Color(0xFFC62828);
        text = 'Fallido';
        break;
      default:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade800;
        text = estado;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }
}

/// Widget para mostrar una comisión en el historial
class _TxnTileComision extends StatelessWidget {
  final ComisionHistorial comision;
  const _TxnTileComision({required this.comision});

  @override
  Widget build(BuildContext context) {
    final f = NumberFormat.currency(locale: 'es_AR', symbol: 'ARS ');
    final hour = DateFormat('HH:mm').format(comision.fecha.toLocal());
    final day = DateFormat(
      'dd MMM yyyy',
      'es',
    ).format(comision.fecha.toLocal());

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(.10)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(.20)),
                ),
                child: Icon(Icons.local_taxi, color: Colors.blue.shade700),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comision.servicio,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Colors.green.shade900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      comision.pasajeroNombre ?? 'Pasajero',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '+${f.format(comision.montoNeto).replaceFirst('ARS ', '')}',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Neto',
                    style: TextStyle(
                      color: Colors.green.shade600,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Monto del viaje:',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      f.format(comision.montoViaje),
                      style: TextStyle(
                        color: Colors.grey.shade900,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Comisión (${comision.porcentajeComision.toStringAsFixed(1)}%):',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '-${f.format(comision.montoComision)}',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recibido:',
                      style: TextStyle(
                        color: Colors.green.shade800,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      f.format(comision.montoNeto),
                      style: TextStyle(
                        color: Colors.green.shade800,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$hour • $day',
            style: TextStyle(color: Colors.green.shade600, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
