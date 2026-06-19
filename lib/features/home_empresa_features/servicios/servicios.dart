import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ServiciosPage extends StatefulWidget {
  const ServiciosPage({super.key});
  @override
  State<ServiciosPage> createState() => _ServiciosPageState();
}

class _ServiciosPageState extends State<ServiciosPage> {
  IconData iconFromString(String? raw) {
    if (raw == null || raw.isEmpty) return Icons.miscellaneous_services;
    final name = raw.startsWith('Icons.') ? raw.substring(6) : raw;
    const map = <String, IconData>{
      'directions_car': Icons.directions_car,
      'local_taxi': Icons.local_taxi,
      'two_wheeler': Icons.two_wheeler,
      'motorcycle': Icons.motorcycle,
      'local_shipping': Icons.local_shipping,
      'airport_shuttle': Icons.airport_shuttle,
      'directions_bus': Icons.directions_bus,
      'pedal_bike': Icons.pedal_bike,
      'sailing': Icons.sailing,
    };
    return map[name] ?? Icons.miscellaneous_services;
  }

  Future<bool> _confirmarEliminar({
    required String departamento,
    required String servicioNombre,
  }) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Eliminar servicio'),
            content: Text(
              '¿Seguro que deseas eliminar “$servicioNombre” del departamento “$departamento”?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton.tonal(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.redAccent,
                ),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .collection('empresas')
        .doc('mujeresalvolante')
        .collection('tarifas');

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Servicios',
          style: TextStyle(color: Colors.white),
        ), //use esto forzado por que no aplica el foregroundColor
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: ref.snapshots(),
        builder: (context, s) {
          if (s.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (s.hasError) return Center(child: Text('Error: ${s.error}'));
          if (!s.hasData || s.data!.docs.isEmpty)
            return const Center(child: Text('Sin datos'));

          final items = <Map<String, dynamic>>[];
          for (final doc in s.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final depId = doc.id;
            data.forEach((key, value) {
              if (value is Map) {
                items.add({
                  '__docId': depId,
                  '__path': key,
                  'departamento': depId,
                  'servicio': value['servicio'] ?? key,
                  'activo': value['activo'] ?? false,
                  'logo': value['logo'],
                  'icono': value['icono'] ?? '',
                });
              }
            });
          }
          if (items.isEmpty)
            return const Center(child: Text('No hay servicios disponibles'));

          final grupos = <String, List<Map<String, dynamic>>>{};
          for (final it in items) {
            (grupos[it['departamento']] ??= []).add(it);
          }
          final deps = grupos.keys.toList()..sort();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final dep in deps) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 6),
                    child: Text(
                      dep,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  ...grupos[dep]!.map((it) {
                    final docId = it['__docId'] as String;
                    final path = it['__path'] as String;
                    final nombre = (it['servicio'] ?? '').toString();
                    final activo = it['activo'] == true;
                    final logoUrl = (it['logo'] ?? '').toString();
                    final iconData = iconFromString(
                      (it['icono'] ?? '').toString(),
                    );

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: Colors.white,
                        elevation: 4,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          height: 72,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: logoUrl.isNotEmpty
                                      ? Image.network(
                                          logoUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              _fallback(iconData),
                                          loadingBuilder: (c, child, p) =>
                                              p == null ? child : _loading(),
                                        )
                                      : _fallback(iconData),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  nombre,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Switch(
                                value: activo,
                                onChanged: (v) async {
                                  try {
                                    await ref.doc(docId).update({
                                      '$path.activo': v,
                                    });
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error guardando: $e'),
                                      ),
                                    );
                                  }
                                },
                                activeColor: Colors.white,
                                activeTrackColor: Colors.blue,
                              ),
                              _roundBtn(Icons.edit, Colors.blue, () async {
                                final snap = await ref.doc(docId).get();
                                if (!snap.exists) return;
                                final data =
                                    snap.data() as Map<String, dynamic>;
                                final servicioMap =
                                    (data[path] ?? {}) as Map<String, dynamic>;
                                Modular.to.pushNamed(
                                  '/nuevo-servicio',
                                  arguments: {
                                    'departamento': docId,
                                    'servicioKey': path,
                                    'servicioMap': servicioMap,
                                  },
                                );
                              }),
                              const SizedBox(width: 6),
                              _roundBtn(
                                Icons.delete,
                                Colors.redAccent,
                                () async {
                                  final ok = await _confirmarEliminar(
                                    departamento: docId,
                                    servicioNombre: nombre,
                                  );
                                  if (!ok) return;
                                  try {
                                    await ref.doc(docId).update({
                                      path: FieldValue.delete(),
                                    });
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error al eliminar: $e'),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Crear Nuevo Servicio'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: const StadiumBorder(),
              elevation: 4,
            ),
            onPressed: () => Modular.to.pushNamed('/nuevo-servicio'),
          ),
        ),
      ),
      backgroundColor: Colors.white,
    );
  }

  Widget _fallback(IconData icon) => Container(
    color: const Color(0xFFEFF3F6),
    alignment: Alignment.center,
    child: Icon(icon, color: Colors.blueGrey, size: 28),
  );

  Widget _loading() => const Center(
    child: SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    ),
  );

  Widget _roundBtn(IconData icon, Color color, VoidCallback onTap) => Material(
    color: color.withOpacity(.12),
    shape: const CircleBorder(),
    child: InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, color: color, size: 20),
      ),
    ),
  );
}
