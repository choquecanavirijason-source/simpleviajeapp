import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_modular/flutter_modular.dart';
import '../data/lugares_guardados.dart';
import 'package:buses2/core/services/ubicacion_usuario/ubicacion_user.dart';
import 'package:buses2/core/utils/particionarDireccion.dart';

class LugaresGuardadosPage extends StatefulWidget {
  const LugaresGuardadosPage({Key? key}) : super(key: key);

  @override
  State<LugaresGuardadosPage> createState() => _LugaresGuardadosPageState();
}

class _LugaresGuardadosPageState extends State<LugaresGuardadosPage> {
  final UbicacionUsuario _ubicacion = UbicacionUsuario();
  String? uid;

  @override
  void initState() {
    super.initState();
    uid = FirebaseAuth.instance.currentUser?.uid;
  }

  Future<void> _abrirMapaParaGuardar(String tipo, String nombreDefault) async {
    // Obtener ubicación actual del usuario
    final coords = await _ubicacion.coordenadasUser();
    if (coords == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo obtener tu ubicación')),
        );
      }
      return;
    }

    final direccionCompleta = await _ubicacion.obtenerDireccionDesdeCoordenadas(
      coords['lat']!,
      coords['lng']!,
    );

    final partes = direccionCompleta != null
        ? direccionPorPartes(direccionCompleta)
        : <String, String>{};

    // Navegar al mapa de destino para seleccionar ubicación
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

    if (result != null && mounted) {
      // Guardar el lugar
      await _guardarLugar(
        tipo: tipo,
        nombre: nombreDefault,
        lat: result['lat'] ?? 0.0,
        lng: result['lng'] ?? 0.0,
        texto: result['texto'],
        calle: result['calle'],
        ciudad: result['ciudad'],
        departamento: result['departamento'],
        pais: result['pais'],
      );
    }
  }

  Future<void> _guardarLugar({
    required String tipo,
    required String nombre,
    required double lat,
    required double lng,
    String? texto,
    String? calle,
    String? ciudad,
    String? departamento,
    String? pais,
  }) async {
    if (uid == null) return;

    final lugar = LugarGuardado(
      tipo: tipo,
      nombre: nombre,
      lat: lat,
      lng: lng,
      texto: texto,
      calle: calle,
      ciudad: ciudad,
      departamento: departamento,
      pais: pais,
    );

    final success = await LugaresGuardadosRepo.guardarLugar(
      uid: uid!,
      lugar: lugar,
    );

    if (success) {
      _showSnackBar('$nombre guardado correctamente');
      setState(() {});
    } else {
      _showSnackBar('Error al guardar $nombre');
    }
  }

  Future<void> _eliminarLugar(String tipo, String nombre) async {
    if (uid == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Eliminar $nombre'),
        content: Text('¿Estás seguro de eliminar este lugar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await LugaresGuardadosRepo.eliminarLugar(
        uid: uid!,
        tipo: tipo,
      );

      if (success) {
        _showSnackBar('$nombre eliminado');
        setState(() {});
      } else {
        _showSnackBar('Error al eliminar');
      }
    }
  }

  Future<void> _agregarFavorito() async {
    if (uid == null) return;

    final nombreController = TextEditingController();

    final nombre = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nombre del favorito'),
        content: TextField(
          controller: nombreController,
          decoration: const InputDecoration(
            hintText: 'Ej: Gimnasio, Supermercado...',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final text = nombreController.text.trim();
              if (text.isNotEmpty) {
                Navigator.pop(context, text);
              }
            },
            child: const Text('Continuar'),
          ),
        ],
      ),
    );

    if (nombre == null || nombre.isEmpty) return;

    // Obtener ubicación actual del usuario
    final coords = await _ubicacion.coordenadasUser();
    if (coords == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo obtener tu ubicación')),
        );
      }
      return;
    }

    final direccionCompleta = await _ubicacion.obtenerDireccionDesdeCoordenadas(
      coords['lat']!,
      coords['lng']!,
    );

    final partes = direccionCompleta != null
        ? direccionPorPartes(direccionCompleta)
        : <String, String>{};

    // Navegar al mapa de destino para seleccionar ubicación
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

    if (result != null && mounted) {
      final lugar = LugarGuardado(
        tipo: 'favorito',
        nombre: nombre,
        lat: result['lat'] ?? 0.0,
        lng: result['lng'] ?? 0.0,
        texto: result['texto'],
        calle: result['calle'],
        ciudad: result['ciudad'],
        departamento: result['departamento'],
        pais: result['pais'],
      );

      final id = await LugaresGuardadosRepo.agregarFavorito(
        uid: uid!,
        lugar: lugar,
      );

      if (id != null && mounted) {
        _showSnackBar('Favorito agregado');
        setState(() {});
      } else if (mounted) {
        _showSnackBar('Error al agregar favorito');
      }
    }
  }

  Future<void> _eliminarFavorito(String id, String nombre) async {
    if (uid == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar favorito'),
        content: Text('¿Eliminar "$nombre"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await LugaresGuardadosRepo.eliminarFavorito(
        uid: uid!,
        favoritoId: id,
      );

      if (success) {
        _showSnackBar('Favorito eliminado');
        setState(() {});
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lugares Guardados')),
        body: const Center(
          child: Text('Debes iniciar sesión para ver tus lugares'),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        // Navegar a /home/viajes en lugar de salir de la app
        Modular.to.navigate('/home/viajes');
        return false; // Prevenir el pop por defecto
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Mis Lugares'),
          backgroundColor: const Color(0xFF43A047),
          foregroundColor: Colors.white,
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Modular.to.navigate('/home/viajes');
            },
          ),
        ),
        body: StreamBuilder<Map<String, LugarGuardado?>>(
          stream: LugaresGuardadosRepo.streamLugares(uid: uid!),
          builder: (context, snapshot) {
            final casa = snapshot.data?['casa'];
            final trabajo = snapshot.data?['trabajo'];

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Casa
                  _buildLugarCard(
                    icon: Icons.home_rounded,
                    title: 'Casa',
                    color: const Color(0xFF43A047),
                    lugar: casa,
                    onAdd: () => _abrirMapaParaGuardar('casa', 'Casa'),
                    onDelete: casa != null
                        ? () => _eliminarLugar('casa', 'Casa')
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Trabajo
                  _buildLugarCard(
                    icon: Icons.work_rounded,
                    title: 'Trabajo',
                    color: const Color(0xFF1E88E5),
                    lugar: trabajo,
                    onAdd: () => _abrirMapaParaGuardar('trabajo', 'Trabajo'),
                    onDelete: trabajo != null
                        ? () => _eliminarLugar('trabajo', 'Trabajo')
                        : null,
                  ),
                  const SizedBox(height: 24),

                  // Favoritos
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Favoritos',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        onPressed: _agregarFavorito,
                        icon: const Icon(Icons.add_circle_rounded),
                        color: const Color(0xFFFFA726),
                        iconSize: 32,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  StreamBuilder<List<LugarGuardado>>(
                    stream: LugaresGuardadosRepo.streamFavoritos(uid: uid!),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      final favoritos = snapshot.data ?? [];

                      if (favoritos.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Column(
                              children: const [
                                Icon(
                                  Icons.star_outline_rounded,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Sin favoritos',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Agrega tus lugares favoritos',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return Column(
                        children: favoritos.map((fav) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFFFA726).withOpacity(0.3),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFFFA726,
                                    ).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.star_rounded,
                                    color: Color(0xFFFFA726),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        fav.nombre,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        fav.calle ??
                                            fav.texto ??
                                            'Ubicación guardada',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.black54,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      _eliminarFavorito(fav.id!, fav.nombre),
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                  ),
                                  color: Colors.red,
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLugarCard({
    required IconData icon,
    required String title,
    required Color color,
    required LugarGuardado? lugar,
    required VoidCallback onAdd,
    VoidCallback? onDelete,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  lugar != null
                      ? (lugar.calle ?? lugar.texto ?? 'Dirección guardada')
                      : 'No configurado',
                  style: TextStyle(
                    fontSize: 13,
                    color: lugar != null ? Colors.black54 : Colors.grey,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (lugar == null)
            IconButton(
              onPressed: onAdd,
              icon: const Icon(Icons.add_circle_rounded),
              color: color,
              iconSize: 32,
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: onAdd,
                  icon: const Icon(Icons.edit_rounded),
                  color: color,
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: Colors.red,
                ),
              ],
            ),
        ],
      ),
    );
  }
}
