import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:buses2/features/home/data/recientes.dart';
import 'package:buses2/features/home/data/lugares_guardados.dart';
import 'package:buses2/core/services/ubicacion_usuario/ubicacion_user.dart';
import 'package:buses2/core/utils/particionarDireccion.dart';
import 'package:buses2/shared/widgets/cajas/sugerencias_busqueda/sugerencias_busqueda.dart';

class LugaresTabPage extends StatefulWidget {
  const LugaresTabPage({super.key});

  @override
  State<LugaresTabPage> createState() => _LugaresTabPageState();
}

class _LugaresTabPageState extends State<LugaresTabPage> {
  static const Color _blue = Color(0xFF00359D);
  static const Color _green = Color(0xFF2CAC3F);

  final UbicacionUsuario _ubicacion = UbicacionUsuario();
  final TextEditingController _ctrl = TextEditingController();

  // Ubicación actual del usuario (se resuelve lazy cuando se necesita)
  double? _lat;
  double? _lng;
  String _calle = '';
  String _ciudad = '';
  String _pais = '';
  String _depto = '';

  // Lugares guardados
  LugarGuardado? _casa;
  LugarGuardado? _trabajo;
  List<LugarGuardado> _favoritos = [];

  // Recientes
  List<SugerenciaEntry> _recientesUI = [];
  List<DestinoReciente> _recientesData = [];
  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _cargando = false);
      return;
    }

    try {
      final results = await Future.wait([
        LugaresGuardadosRepo.obtenerLugar(uid: uid, tipo: 'casa'),
        LugaresGuardadosRepo.obtenerLugar(uid: uid, tipo: 'trabajo'),
        LugaresGuardadosRepo.obtenerFavoritos(uid: uid),
        RecientesRepo.obtenerRecientes(uid: uid),
      ]);

      if (!mounted) return;

      final casa = results[0] as LugarGuardado?;
      final trabajo = results[1] as LugarGuardado?;
      final favs = results[2] as List<LugarGuardado>;
      final recientes = results[3] as List<DestinoReciente>;

      final ui = recientes.map((r) {
        final titulo = (r.texto?.trim().isNotEmpty ?? false)
            ? r.texto!.trim()
            : (r.calle?.trim().isNotEmpty ?? false)
                ? r.calle!.trim()
                : 'Destino reciente';
        final sub = [r.ciudad?.trim(), r.pais?.trim()]
            .where((e) => (e ?? '').isNotEmpty)
            .join(' - ');
        return SugerenciaEntry(
          titulo: titulo,
          subtitulo: sub.isNotEmpty ? sub : 'Ubicación reciente',
          leadingIcon: Icons.location_on,
          trailingIcon: r.programado ? Icons.schedule : Icons.north_east,
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _casa = casa;
        _trabajo = trabajo;
        _favoritos = favs;
        _recientesUI = ui;
        _recientesData = recientes;
        _cargando = false;
      });
    } catch (e) {
      debugPrint('⚠️ LugaresTabPage._cargar error: $e');
      if (mounted) setState(() => _cargando = false);
    }
  }

  // ── Helpers de ubicación ──────────────────────────────────────────────

  /// Resuelve el origen del usuario (cache tras la primera vez).
  Future<bool> _resolverOrigen() async {
    if (_lat != null && _lng != null) return true;
    final coords = await _ubicacion.coordenadasUser();
    if (coords == null) return false;
    final dir = await _ubicacion.obtenerDireccionDesdeCoordenadas(
      coords['lat']!,
      coords['lng']!,
    );
    final partes = dir != null ? direccionPorPartes(dir) : <String, String>{};
    if (!mounted) return false;
    setState(() {
      _lat = coords['lat'];
      _lng = coords['lng'];
      _calle = partes['calle'] ?? '';
      _ciudad = partes['ciudad'] ?? '';
      _depto = partes['departamento'] ?? '';
      _pais = partes['pais'] ?? '';
    });
    return true;
  }

  Map<String, dynamic> get _origenArgs => {
        'lat': _lat,
        'lng': _lng,
        'calle': _calle,
        'ciudad': _ciudad,
        'pais': _pais,
        'departamento': _depto,
        'openSheet2': true,
      };

  // ── Selección de ubicación en mapa ────────────────────────────────────

  /// Abre el mapa en modo solo-seleccionar y devuelve el lugar elegido.
  Future<Map<String, dynamic>?> _abrirMapaPicker() async {
    final coords = await _ubicacion.coordenadasUser();
    if (coords == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo obtener tu ubicación')),
        );
      }
      return null;
    }

    final dir = await _ubicacion.obtenerDireccionDesdeCoordenadas(
      coords['lat']!,
      coords['lng']!,
    );
    final partes = dir != null ? direccionPorPartes(dir) : <String, String>{};

    if (!mounted) return null;

    final result = await Modular.to.pushNamed<Map<String, dynamic>>(
      '/mapa-destino',
      arguments: {
        'soloSeleccionar': true,
        'lat': coords['lat'],
        'lng': coords['lng'],
        'calle': partes['calle'] ?? '',
        'ciudad': partes['ciudad'] ?? '',
        'pais': partes['pais'] ?? '',
        'departamento': partes['departamento'] ?? '',
      },
    );

    return result;
  }

  // ── Configurar / editar lugar ─────────────────────────────────────────

  Future<void> _configurarCasa() async {
    setState(() => _guardando = true);
    try {
      final result = await _abrirMapaPicker();
      if (result == null || !mounted) return;

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final lugar = LugarGuardado(
        tipo: 'casa',
        nombre: 'Casa',
        lat: (result['lat'] as num).toDouble(),
        lng: (result['lng'] as num).toDouble(),
        texto: result['texto'] as String?,
        calle: result['calle'] as String?,
        ciudad: result['ciudad'] as String?,
        departamento: result['departamento'] as String?,
        pais: result['pais'] as String?,
      );

      final ok = await LugaresGuardadosRepo.guardarLugar(uid: uid, lugar: lugar);
      if (!mounted) return;

      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Casa guardada correctamente'),
            backgroundColor: Color(0xFF43A047),
          ),
        );
        setState(() => _cargando = true);
        await _cargar();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al guardar Casa')),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _configurarTrabajo() async {
    setState(() => _guardando = true);
    try {
      final result = await _abrirMapaPicker();
      if (result == null || !mounted) return;

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final lugar = LugarGuardado(
        tipo: 'trabajo',
        nombre: 'Trabajo',
        lat: (result['lat'] as num).toDouble(),
        lng: (result['lng'] as num).toDouble(),
        texto: result['texto'] as String?,
        calle: result['calle'] as String?,
        ciudad: result['ciudad'] as String?,
        departamento: result['departamento'] as String?,
        pais: result['pais'] as String?,
      );

      final ok = await LugaresGuardadosRepo.guardarLugar(uid: uid, lugar: lugar);
      if (!mounted) return;

      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trabajo guardado correctamente'),
            backgroundColor: Color(0xFF1E88E5),
          ),
        );
        setState(() => _cargando = true);
        await _cargar();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al guardar Trabajo')),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _configurarFavorito() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // 1. Pedir nombre del favorito
    final ctrl = TextEditingController();
    final nombre = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Nombre del favorito',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Ej: Gimnasio, Supermercado…',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final t = ctrl.text.trim();
              if (t.isNotEmpty) Navigator.pop(context, t);
            },
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    ctrl.dispose();

    if (nombre == null || nombre.isEmpty || !mounted) return;

    // 2. Abrir mapa para marcar la ubicación
    setState(() => _guardando = true);
    try {
      final result = await _abrirMapaPicker();
      if (result == null || !mounted) return;

      final lugar = LugarGuardado(
        tipo: 'favorito',
        nombre: nombre,
        lat: (result['lat'] as num).toDouble(),
        lng: (result['lng'] as num).toDouble(),
        texto: result['texto'] as String?,
        calle: result['calle'] as String?,
        ciudad: result['ciudad'] as String?,
        departamento: result['departamento'] as String?,
        pais: result['pais'] as String?,
      );

      final id = await LugaresGuardadosRepo.agregarFavorito(uid: uid, lugar: lugar);
      if (!mounted) return;

      if (id != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Favorito guardado'),
            backgroundColor: Color(0xFFFFA726),
          ),
        );
        setState(() => _cargando = true);
        await _cargar();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al guardar favorito')),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  // ── Navegación usando lugar guardado ─────────────────────────────────

  Future<void> _irA(LugarGuardado lugar) async {
    final ok = await _resolverOrigen();
    if (!ok || !mounted) return;
    await Modular.to.pushNamed('/mapa-destino', arguments: {
      ..._origenArgs,
      'destinoLat': lugar.lat,
      'destinoLng': lugar.lng,
      'destinoCalle': lugar.calle,
      'destinoCiudad': lugar.ciudad,
      'destinoPais': lugar.pais,
      'destinoDepartamento': lugar.departamento,
      'destinoTexto': lugar.texto ?? lugar.nombre,
    });
  }

  Future<void> _irACasa() async {
    if (_casa == null) {
      await _configurarCasa();
    } else {
      await _irA(_casa!);
    }
  }

  Future<void> _irATrabajo() async {
    if (_trabajo == null) {
      await _configurarTrabajo();
    } else {
      await _irA(_trabajo!);
    }
  }

  Future<void> _mostrarFavoritos() async {
    if (_favoritos.isEmpty) {
      await _configurarFavorito();
      return;
    }

    final sel = await showModalBottomSheet<_FavoritoAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FavoritosSheet(favoritos: _favoritos),
    );

    if (sel == null || !mounted) return;

    if (sel.action == _FavAction.ir) {
      await _irA(sel.lugar);
    } else if (sel.action == _FavAction.eliminar) {
      await _eliminarFavorito(sel.lugar);
    }
  }

  Future<void> _eliminarFavorito(LugarGuardado fav) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || fav.id == null) return;

    final ok = await LugaresGuardadosRepo.eliminarFavorito(
      uid: uid,
      favoritoId: fav.id!,
    );
    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${fav.nombre}" eliminado')),
      );
      setState(() => _cargando = true);
      await _cargar();
    }
  }

  Future<void> _irARecientemente(SugerenciaEntry entry) async {
    final idx = _recientesUI.indexWhere(
      (e) => e.titulo == entry.titulo && e.subtitulo == entry.subtitulo,
    );
    if (idx < 0 || idx >= _recientesData.length) return;
    final d = _recientesData[idx];
    if (d.lat == null || d.lng == null) return;
    final ok = await _resolverOrigen();
    if (!ok || !mounted) return;
    await Modular.to.pushNamed('/mapa-destino', arguments: {
      ..._origenArgs,
      'destinoLat': d.lat,
      'destinoLng': d.lng,
      'destinoTexto': d.texto,
      'destinoCalle': d.calle,
      'destinoCiudad': d.ciudad,
      'destinoPais': d.pais,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        automaticallyImplyLeading: false,
        title: const Text(
          'Mis Lugares',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              setState(() => _cargando = true);
              await _cargar();
            },
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                    children: [
                      // ── Accesos rápidos ──────────────────────────────
                      _Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Header(
                              icon: Icons.flash_on_rounded,
                              title: 'Accesos rápidos',
                              color: _blue,
                              action: TextButton.icon(
                                onPressed: () => Modular.to
                                    .navigate('/home/lugares-guardados'),
                                icon: const Icon(Icons.tune_rounded, size: 16),
                                label: const Text(
                                  'Más opciones',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: _blue,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _PlaceCard(
                                    icon: Icons.home_rounded,
                                    label: 'Casa',
                                    address: _casa?.calle ??
                                        _casa?.texto ??
                                        (_casa != null ? 'Guardada' : null),
                                    color: const Color(0xFF43A047),
                                    isSet: _casa != null,
                                    onTap: _irACasa,
                                    onEdit: _casa != null
                                        ? _configurarCasa
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _PlaceCard(
                                    icon: Icons.work_rounded,
                                    label: 'Trabajo',
                                    address: _trabajo?.calle ??
                                        _trabajo?.texto ??
                                        (_trabajo != null ? 'Guardado' : null),
                                    color: const Color(0xFF1E88E5),
                                    isSet: _trabajo != null,
                                    onTap: _irATrabajo,
                                    onEdit: _trabajo != null
                                        ? _configurarTrabajo
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _PlaceCard(
                                    icon: Icons.star_rounded,
                                    label: 'Favoritos',
                                    address: _favoritos.isEmpty
                                        ? null
                                        : '${_favoritos.length} lugar${_favoritos.length == 1 ? '' : 'es'}',
                                    color: const Color(0xFFFFA726),
                                    isSet: _favoritos.isNotEmpty,
                                    onTap: _mostrarFavoritos,
                                    onEdit: _favoritos.isNotEmpty
                                        ? _configurarFavorito
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── Destinos recientes ────────────────────────────
                      if (_recientesUI.isNotEmpty)
                        _Card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _Header(
                                icon: Icons.history_rounded,
                                title: 'Destinos recientes',
                                color: _green,
                              ),
                              const SizedBox(height: 12),
                              SugerenciasBusqueda(
                                controller: _ctrl,
                                onUpdate: _irARecientemente,
                                items: _recientesUI,
                                mostrarSubtitulo: true,
                                dense: false,
                                showDivider: true,
                                iconSize: 24,
                                itemVerticalPadding: 10,
                                leadingGap: 10,
                                trailingGap: 6,
                                defaultLeadingColor: _green,
                              ),
                            ],
                          ),
                        )
                      else
                        _Card(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.history_rounded,
                                  size: 40,
                                  color: Colors.grey.shade300,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Sin destinos recientes',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tus viajes anteriores aparecerán aquí.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade400,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
          ),

          // Indicador de guardado
          if (_guardando)
            Container(
              color: Colors.black26,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 14),
                        Text('Guardando ubicación…'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Enums para sheet de favoritos ──────────────────────────────────────────

enum _FavAction { ir, eliminar }

class _FavoritoAction {
  final LugarGuardado lugar;
  final _FavAction action;
  const _FavoritoAction(this.lugar, this.action);
}

// ── Widgets internos ───────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: child,
      );
}

class _Header extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final Widget? action;
  const _Header({
    required this.icon,
    required this.title,
    required this.color,
    this.action,
  });

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const Spacer(),
          if (action != null) action!,
        ],
      );
}

/// Tarjeta de lugar con dos estados: configurado y no configurado.
class _PlaceCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? address; // null = no configurado
  final Color color;
  final bool isSet;
  final VoidCallback onTap;
  final VoidCallback? onEdit;

  const _PlaceCard({
    required this.icon,
    required this.label,
    required this.address,
    required this.color,
    required this.isSet,
    required this.onTap,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 14),
        decoration: BoxDecoration(
          color: isSet
              ? color.withValues(alpha: 0.06)
              : const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSet
                ? color.withValues(alpha: 0.25)
                : Colors.grey.shade200,
          ),
        ),
        child: Column(
          children: [
            // Icono + botón editar (si está configurado)
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.13),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 22, color: color),
                ),
                if (isSet && onEdit != null)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: GestureDetector(
                      onTap: onEdit,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: color.withValues(alpha: 0.4)),
                        ),
                        child: Icon(
                          Icons.edit_rounded,
                          size: 11,
                          color: color,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 3),
            if (isSet)
              Text(
                address ?? '',
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline_rounded,
                      size: 11, color: Colors.grey.shade400),
                  const SizedBox(width: 3),
                  Text(
                    'Marcar',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade400,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _FavoritosSheet extends StatelessWidget {
  final List<LugarGuardado> favoritos;
  const _FavoritosSheet({required this.favoritos});

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.star_rounded, color: Color(0xFFFFA726)),
                const SizedBox(width: 12),
                const Text(
                  'Mis Favoritos',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: favoritos.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final fav = favoritos[i];
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFA726).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFFFA726),
                      ),
                    ),
                    title: Text(
                      fav.nombre,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      fav.calle ?? fav.texto ?? 'Ubicación guardada',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Botón ir
                        IconButton(
                          icon: const Icon(Icons.navigation_rounded,
                              color: Color(0xFF2CAC3F)),
                          onPressed: () => Navigator.pop(
                            context,
                            _FavoritoAction(fav, _FavAction.ir),
                          ),
                        ),
                        // Botón eliminar
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: Colors.red),
                          onPressed: () => Navigator.pop(
                            context,
                            _FavoritoAction(fav, _FavAction.eliminar),
                          ),
                        ),
                      ],
                    ),
                    onTap: () => Navigator.pop(
                      context,
                      _FavoritoAction(fav, _FavAction.ir),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
}
