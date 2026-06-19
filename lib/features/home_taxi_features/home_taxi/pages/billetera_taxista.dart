import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:gal/gal.dart';

//  Importaciones para billetera de taxista
import '../../billetera_taxista/services/taxista_wallet_service.dart';
import '../../billetera_taxista/models/taxista_wallet_models.dart';

class BilleteraTaxistaPage extends StatefulWidget {
  const BilleteraTaxistaPage({super.key});

  @override
  State<BilleteraTaxistaPage> createState() => _BilleteraTaxistaPageState();
}

// Enum para tipos de filtro
enum FiltroTiempo { dia, semana, mes, anio }

class _BilleteraTaxistaPageState extends State<BilleteraTaxistaPage>
    with SingleTickerProviderStateMixin {
  final _svc = TaxistaWalletService();
  late TabController _tabController;

  // 🎨 Paleta base en torno a Colors.green
  static const _greenDark = Color(0xFF1B5E20); // primario fuerte
  static final _greenSoft = Colors.green.shade50; // fondos suaves

  // 📊 Filtro actual
  FiltroTiempo _filtroActual = FiltroTiempo.mes;

  // 📅 Fechas seleccionadas para reportes
  DateTime _fechaSeleccionada = DateTime.now();
  int _semanaSeleccionada = 1; // Semana del mes (1-5)
  int _mesSeleccionadoSemana =
      DateTime.now().month; // Mes para el filtro de semana
  int _mesSeleccionado = DateTime.now().month;
  int _anioSeleccionado = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: _greenDark,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Billetera',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(54),
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.black54,
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              indicator: BoxDecoration(
                color: _greenDark,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: _greenDark.withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              splashBorderRadius: BorderRadius.circular(10),
              tabs: const [
                Tab(text: 'Recargas', icon: Icon(Icons.add_circle_outline, size: 18)),
                Tab(text: 'Comisiones', icon: Icon(Icons.receipt_long, size: 18)),
                Tab(text: 'Reportes', icon: Icon(Icons.analytics_outlined, size: 18)),
              ],
            ),
          ),
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

          return TabBarView(
            controller: _tabController,
            children: [
              // Pestaña 1: Recargas
              _TabRecargas(svc: _svc, saldo: saldo, onRefresh: _refresh),
              // Pestaña 2: Comisiones
              _TabComisiones(svc: _svc, saldo: saldo, onRefresh: _refresh),
              // Pestaña 3: Reportes
              _TabReportes(
                svc: _svc,
                filtroActual: _filtroActual,
                fechaSeleccionada: _fechaSeleccionada,
                semanaSeleccionada: _semanaSeleccionada,
                mesSeleccionadoSemana: _mesSeleccionadoSemana,
                mesSeleccionado: _mesSeleccionado,
                anioSeleccionado: _anioSeleccionado,
                onFiltroChanged: (filtro) {
                  setState(() => _filtroActual = filtro);
                },
                onFechaChanged: (fecha) {
                  setState(() => _fechaSeleccionada = fecha);
                },
                onSemanaChanged: (semana) {
                  setState(() => _semanaSeleccionada = semana);
                },
                onMesSemanaChanged: (mes) {
                  setState(() => _mesSeleccionadoSemana = mes);
                },
                onMesChanged: (mes) {
                  setState(() => _mesSeleccionado = mes);
                },
                onAnioChanged: (anio) {
                  setState(() => _anioSeleccionado = anio);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  // Métodos eliminados - Las recargas ahora se gestionan desde el panel de administración
}

/// ───────────────────────── HEADER BALANCE ─────────────────────────
/// Tarjeta del saldo: gradiente verde, decoración tipo tarjeta bancaria
/// (círculos translúcidos en la esquina) y dot pulsante de "en vivo".
class _HeaderBalance extends StatelessWidget {
  const _HeaderBalance({required this.saldo});
  final TaxistaSaldo saldo;

  @override
  Widget build(BuildContext context) {
    final f = NumberFormat.currency(locale: 'es_AR', symbol: 'ARS ');
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF43A047)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B5E20).withOpacity(0.30),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // Círculos decorativos translúcidos
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              right: 30,
              bottom: -50,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: Colors.greenAccent.shade100,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.greenAccent.shade100
                                        .withOpacity(0.6),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'En vivo',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Colors.white.withOpacity(0.55),
                        size: 22,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'SALDO DISPONIBLE',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    f.format(saldo.saldo),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ───────────────────────── WIDGET QR RECARGA ─────────────────────────
class _QRRecargaWidget extends StatelessWidget {
  const _QRRecargaWidget({required this.svc});
  final TaxistaWalletService svc;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ConfiguracionQR>(
      stream: svc.streamConfiguracionQR(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(color: Colors.green),
            ),
          );
        }

        final config = snapshot.data;

        if (config == null || config.qrImageUrl.isEmpty) {
          return Container(
            margin: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Column(
              children: [
                Icon(Icons.qr_code_2, size: 48, color: Colors.orange.shade700),
                const SizedBox(height: 12),
                Text(
                  'QR de recarga no disponible',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.orange.shade900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Contacta al administrador para obtener el QR de recarga',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.orange.shade800),
                ),
              ],
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 6, 16, 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.qr_code_scanner, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  const Text(
                    'QR para Recargas',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (config.descripcion != null &&
                  config.descripcion!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  config.descripcion!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
              ],
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  config.qrImageUrl,
                  height: 250,
                  width: 250,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return SizedBox(
                      height: 250,
                      width: 250,
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                              : null,
                          color: Colors.green,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 250,
                      width: 250,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Error al cargar QR',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Escanea este QR para realizar recargas a tu saldo',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _downloadQR(context, config.qrImageUrl),
                  icon: const Icon(Icons.download),
                  label: const Text('Descargar QR'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ✅ SIN permission_handler (solo Gal)
  Future<void> _downloadQR(BuildContext context, String imageUrl) async {
    // Mostrar indicador de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) =>
          const Center(child: CircularProgressIndicator(color: Colors.green)),
    );

    try {
      // Descargar imagen
      final dio = Dio();
      final response = await dio.get(
        imageUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      final bytes = Uint8List.fromList(response.data);

      // ✅ Pedir acceso con Gal (sin READ_MEDIA / sin READ_EXTERNAL)
      final hasAccess = await Gal.hasAccess(toAlbum: true);
      if (!hasAccess) {
        await Gal.requestAccess(toAlbum: true);
      }

      final granted = await Gal.hasAccess(toAlbum: true);
      if (!granted) {
        if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permiso para guardar en galería denegado.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Guardar imagen usando Gal (más moderno y compatible)
      await Gal.putImageBytes(bytes, album: 'Tropical');

      // Cerrar indicador de carga
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

      // Mostrar mensaje de éxito
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('QR guardado en galería (álbum Tropical)')),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // Cerrar indicador de carga
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

      // Mostrar error
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al descargar: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}

/// ───────────────────────── BOTÓN MOSTRAR QR ─────────────────────────
class _BotonMostrarQR extends StatelessWidget {
  const _BotonMostrarQR({required this.svc});
  final TaxistaWalletService svc;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.06),
        child: InkWell(
          onTap: () => _abrirBottomSheet(context),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Icon(
                    Icons.qr_code_2,
                    color: Colors.green.shade700,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'QR de Recarga',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.green.shade900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Toca para mostrar y descargar el QR',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Colors.green.shade700,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _abrirBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF5FBF5),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: 'Cerrar',
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollCtrl,
                  child: _QRRecargaWidget(svc: svc),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
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
  final TaxistaSaldo saldo;
  final Future<void> Function() onRefresh;

  const _TabRecargas({
    required this.svc,
    required this.saldo,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RecargaHistorial>>(
      stream: svc.streamHistorialRecargas(limite: 100),
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

        return RefreshIndicator(
          color: Colors.white,
          backgroundColor: Colors.green.shade600,
          onRefresh: onRefresh,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    _HeaderBalance(saldo: saldo),
                    _BotonMostrarQR(svc: svc),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.history,
                            size: 20,
                            color: Colors.green.shade700,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Historial de Recargas',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade900,
                            ),
                          ),
                          const Spacer(),
                          if (recargas.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${recargas.length}',
                                style: TextStyle(
                                  color: Colors.green.shade900,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              recargas.isEmpty
                  ? const SliverFillRemaining(
                      child: _EmptyState(mensaje: 'Sin recargas registradas'),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => _TxnTileRecarga(recarga: recargas[i]),
                          childCount: recargas.length,
                        ),
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }
}

/// Pestaña de Comisiones
class _TabComisiones extends StatelessWidget {
  final TaxistaWalletService svc;
  final TaxistaSaldo saldo;
  final Future<void> Function() onRefresh;

  const _TabComisiones({
    required this.svc,
    required this.saldo,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ComisionHistorial>>(
      stream: svc.streamHistorialComisiones(limite: 100),
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

        return Column(
          children: [
            _HeaderBalance(saldo: saldo),
            const SizedBox(height: 8),
            Expanded(
              child: comisiones.isEmpty
                  ? const _EmptyState(mensaje: 'Sin comisiones registradas')
                  : RefreshIndicator(
                      color: Colors.white,
                      backgroundColor: Colors.green.shade600,
                      onRefresh: onRefresh,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount: comisiones.length,
                        itemBuilder: (context, i) =>
                            _TxnTileComision(comision: comisiones[i]),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// Pestaña de Reportes con filtros avanzados y estadísticas
class _TabReportes extends StatelessWidget {
  final TaxistaWalletService svc;
  final FiltroTiempo filtroActual;
  final DateTime fechaSeleccionada;
  final int semanaSeleccionada;
  final int mesSeleccionadoSemana;
  final int mesSeleccionado;
  final int anioSeleccionado;
  final Function(FiltroTiempo) onFiltroChanged;
  final Function(DateTime) onFechaChanged;
  final Function(int) onSemanaChanged;
  final Function(int) onMesSemanaChanged;
  final Function(int) onMesChanged;
  final Function(int) onAnioChanged;

  const _TabReportes({
    required this.svc,
    required this.filtroActual,
    required this.fechaSeleccionada,
    required this.semanaSeleccionada,
    required this.mesSeleccionadoSemana,
    required this.mesSeleccionado,
    required this.anioSeleccionado,
    required this.onFiltroChanged,
    required this.onFechaChanged,
    required this.onSemanaChanged,
    required this.onMesSemanaChanged,
    required this.onMesChanged,
    required this.onAnioChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Reportes de Actividad',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1B5E20),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Selecciona un periodo para visualizar tus estadísticas',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 20),
        _FiltrosAvanzados(
          filtroActual: filtroActual,
          onFiltroChanged: onFiltroChanged,
        ),
        const SizedBox(height: 20),
        _SelectoresFecha(
          filtroActual: filtroActual,
          fechaSeleccionada: fechaSeleccionada,
          semanaSeleccionada: semanaSeleccionada,
          mesSeleccionadoSemana: mesSeleccionadoSemana,
          mesSeleccionado: mesSeleccionado,
          anioSeleccionado: anioSeleccionado,
          onFechaChanged: onFechaChanged,
          onSemanaChanged: onSemanaChanged,
          onMesSemanaChanged: onMesSemanaChanged,
          onMesChanged: onMesChanged,
          onAnioChanged: onAnioChanged,
        ),
        const SizedBox(height: 20),
        _EstadisticasReportes(
          svc: svc,
          filtro: filtroActual,
          fechaSeleccionada: fechaSeleccionada,
          semanaSeleccionada: semanaSeleccionada,
          mesSeleccionadoSemana: mesSeleccionadoSemana,
          mesSeleccionado: mesSeleccionado,
          anioSeleccionado: anioSeleccionado,
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Los reportes muestran información actualizada en tiempo real.',
                  style: TextStyle(fontSize: 13, color: Colors.blue.shade900),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ==================== FILTROS AVANZADOS PARA REPORTES ====================

class _FiltrosAvanzados extends StatelessWidget {
  final FiltroTiempo filtroActual;
  final Function(FiltroTiempo) onFiltroChanged;

  const _FiltrosAvanzados({
    required this.filtroActual,
    required this.onFiltroChanged,
  });

  @override
  Widget build(BuildContext context) {
    Widget cell({
      required String label,
      required IconData icon,
      required FiltroTiempo value,
    }) {
      final active = filtroActual == value;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (active) return;
            onFiltroChanged(value);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: active ? const Color(0xFF1B5E20) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: const Color(0xFF1B5E20).withOpacity(0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: active ? Colors.white : Colors.black54,
                  size: 19,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: active ? Colors.white : Colors.black54,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          cell(label: 'Día', icon: Icons.today_rounded, value: FiltroTiempo.dia),
          cell(
            label: 'Semana',
            icon: Icons.date_range_rounded,
            value: FiltroTiempo.semana,
          ),
          cell(
            label: 'Mes',
            icon: Icons.calendar_month_rounded,
            value: FiltroTiempo.mes,
          ),
          cell(
            label: 'Año',
            icon: Icons.event_note_rounded,
            value: FiltroTiempo.anio,
          ),
        ],
      ),
    );
  }
}

/// Selectores específicos de fecha según el tipo de filtro
class _SelectoresFecha extends StatelessWidget {
  final FiltroTiempo filtroActual;
  final DateTime fechaSeleccionada;
  final int semanaSeleccionada;
  final int mesSeleccionadoSemana;
  final int mesSeleccionado;
  final int anioSeleccionado;
  final Function(DateTime) onFechaChanged;
  final Function(int) onSemanaChanged;
  final Function(int) onMesSemanaChanged;
  final Function(int) onMesChanged;
  final Function(int) onAnioChanged;

  const _SelectoresFecha({
    required this.filtroActual,
    required this.fechaSeleccionada,
    required this.semanaSeleccionada,
    required this.mesSeleccionadoSemana,
    required this.mesSeleccionado,
    required this.anioSeleccionado,
    required this.onFechaChanged,
    required this.onSemanaChanged,
    required this.onMesSemanaChanged,
    required this.onMesChanged,
    required this.onAnioChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _getTituloSelector(),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B5E20),
            ),
          ),
          const SizedBox(height: 12),
          _buildSelector(context),
        ],
      ),
    );
  }

  String _getTituloSelector() {
    switch (filtroActual) {
      case FiltroTiempo.dia:
        return 'Selecciona el día';
      case FiltroTiempo.semana:
        return 'Selecciona semana, mes y año';
      case FiltroTiempo.mes:
        return 'Selecciona mes y año';
      case FiltroTiempo.anio:
        return 'Selecciona el año';
    }
  }

  Widget _buildSelector(BuildContext context) {
    switch (filtroActual) {
      case FiltroTiempo.dia:
        return _buildSelectorDia(context);
      case FiltroTiempo.semana:
        return _buildSelectorSemana(context);
      case FiltroTiempo.mes:
        return _buildSelectorMes(context);
      case FiltroTiempo.anio:
        return _buildSelectorAnio(context);
    }
  }

  Widget _buildSelectorDia(BuildContext context) {
    final formatter = DateFormat('dd/MM/yyyy', 'es');
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: fechaSeleccionada,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          locale: const Locale('es', 'ES'),
        );
        if (picked != null) {
          onFechaChanged(picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.green.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: Colors.green, size: 20),
            const SizedBox(width: 12),
            Text(
              formatter.format(fechaSeleccionada),
              style: const TextStyle(fontSize: 16),
            ),
            const Spacer(),
            const Icon(Icons.arrow_drop_down, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectorSemana(BuildContext context) {
    final meses = [
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

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.green.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: mesSeleccionadoSemana,
                    isExpanded: true,
                    items: List.generate(12, (i) {
                      return DropdownMenuItem(
                        value: i + 1,
                        child: Text(meses[i]),
                      );
                    }),
                    onChanged: (val) => onMesSemanaChanged(val!),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDropdown(
                label: 'Año',
                value: anioSeleccionado,
                items: List.generate(10, (i) => DateTime.now().year - i),
                onChanged: (val) => onAnioChanged(val!),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildDropdown(
          label: 'Semana',
          value: semanaSeleccionada,
          items: [1, 2, 3, 4, 5],
          onChanged: (val) => onSemanaChanged(val!),
          prefix: 'Semana ',
        ),
      ],
    );
  }

  Widget _buildSelectorMes(BuildContext context) {
    final meses = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.green.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: mesSeleccionado,
                isExpanded: true,
                items: List.generate(12, (i) {
                  return DropdownMenuItem(value: i + 1, child: Text(meses[i]));
                }),
                onChanged: (val) => onMesChanged(val!),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildDropdown(
            label: 'Año',
            value: anioSeleccionado,
            items: List.generate(10, (i) => DateTime.now().year - i),
            onChanged: (val) => onAnioChanged(val!),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectorAnio(BuildContext context) {
    return _buildDropdown(
      label: 'Año',
      value: anioSeleccionado,
      items: List.generate(10, (i) => DateTime.now().year - i),
      onChanged: (val) => onAnioChanged(val!),
    );
  }

  Widget _buildDropdown({
    required String label,
    required int value,
    required List<int> items,
    required Function(int?) onChanged,
    String prefix = '',
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.green.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          isExpanded: true,
          items: items.map((item) {
            return DropdownMenuItem(value: item, child: Text('$prefix$item'));
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// Estadísticas mejoradas con parámetros de fecha
class _EstadisticasReportes extends StatelessWidget {
  final TaxistaWalletService svc;
  final FiltroTiempo filtro;
  final DateTime fechaSeleccionada;
  final int semanaSeleccionada;
  final int mesSeleccionadoSemana;
  final int mesSeleccionado;
  final int anioSeleccionado;

  const _EstadisticasReportes({
    required this.svc,
    required this.filtro,
    required this.fechaSeleccionada,
    required this.semanaSeleccionada,
    required this.mesSeleccionadoSemana,
    required this.mesSeleccionado,
    required this.anioSeleccionado,
  });

  DateTime _getFechaInicio() {
    switch (filtro) {
      case FiltroTiempo.dia:
        return DateTime(
          fechaSeleccionada.year,
          fechaSeleccionada.month,
          fechaSeleccionada.day,
        );
      case FiltroTiempo.semana:
        final primerDiaMes = DateTime(
          anioSeleccionado,
          mesSeleccionadoSemana,
          1,
        );
        final diasDesdeInicio = (semanaSeleccionada - 1) * 7;
        return primerDiaMes.add(Duration(days: diasDesdeInicio));
      case FiltroTiempo.mes:
        return DateTime(anioSeleccionado, mesSeleccionado, 1);
      case FiltroTiempo.anio:
        return DateTime(anioSeleccionado, 1, 1);
    }
  }

  DateTime _getFechaFin() {
    switch (filtro) {
      case FiltroTiempo.dia:
        return DateTime(
          fechaSeleccionada.year,
          fechaSeleccionada.month,
          fechaSeleccionada.day,
          23,
          59,
          59,
        );
      case FiltroTiempo.semana:
        return _getFechaInicio().add(const Duration(days: 7));
      case FiltroTiempo.mes:
        return DateTime(anioSeleccionado, mesSeleccionado + 1, 0, 23, 59, 59);
      case FiltroTiempo.anio:
        return DateTime(anioSeleccionado, 12, 31, 23, 59, 59);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ComisionHistorial>>(
      stream: svc.streamHistorialComisiones(limite: 500),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(color: Colors.green),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final comisiones = snapshot.data ?? [];
        final fechaInicio = _getFechaInicio();
        final fechaFin = _getFechaFin();

        final comisionesFiltradas = comisiones.where((c) {
          return (c.fecha.isAfter(fechaInicio) && c.fecha.isBefore(fechaFin)) ||
              c.fecha.isAtSameMomentAs(fechaInicio) ||
              c.fecha.isAtSameMomentAs(fechaFin);
        }).toList();

        comisionesFiltradas.sort((a, b) => b.fecha.compareTo(a.fecha));

        double totalViajes = 0;
        double totalComisiones = 0;
        for (final comision in comisionesFiltradas) {
          totalViajes += comision.montoViaje;
          totalComisiones += comision.montoComision;
        }

        final f = NumberFormat.currency(locale: 'es_AR', symbol: 'ARS ');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Total Viajes',
                    value: f.format(totalViajes),
                    color: Colors.blue.shade700,
                    icon: Icons.local_taxi,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Comisiones',
                    value: f.format(totalComisiones),
                    color: const Color(0xFFC62828),
                    icon: Icons.receipt_long,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (comisionesFiltradas.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.local_taxi,
                      color: Color(0xFF1B5E20),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No tienes viajes en el período seleccionado.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.green.shade900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.local_taxi,
                        color: Color(0xFF1B5E20),
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${comisionesFiltradas.length} viajes en el período seleccionado',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B5E20),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...comisionesFiltradas.map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _TxnTileComision(comision: c),
                    ),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }
}

// ==================== WIDGETS DE ITEMS ====================

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

    // ✅ TOTAL = monto del viaje - comisión
    final total = comision.montoViaje - comision.montoComision;

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
                    '-${f.format(comision.montoComision).replaceFirst('ARS ', '')}',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Comisión',
                    style: TextStyle(color: Colors.red.shade600, fontSize: 10),
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

                // ✅ AQUÍ CAMBIAMOS "Recibiste en efectivo" por "Total: monto del viaje - comision"
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total:',
                      style: TextStyle(
                        color: Colors.green.shade800,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      f.format(total),
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
