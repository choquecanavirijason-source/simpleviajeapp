import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:buses2/shared/widgets/cajas/caja_edit/caja_edit.dart';
import 'package:buses2/shared/widgets/app_bar/app_bar.dart';

class VerEditDocPage extends StatefulWidget {
  const VerEditDocPage({super.key});

  @override
  State<VerEditDocPage> createState() => _VerEditDocPageState();
}

class _VerEditDocPageState extends State<VerEditDocPage> {
  // Documento raíz donde vive el mapa "documentos"
  final _docRef = FirebaseFirestore.instance
      .collection('empresas')
      .doc('mujeresalvolante');

  // Elimina UNA entrada del mapa "documentos"
  Future<void> _eliminarEntrada(String entryKey, String titulo) async {
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Eliminar documento'),
            content: Text('¿Seguro que deseas eliminar “$titulo”?'),
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

    if (!ok) return;

    try {
      await _docRef.update({'documentos.$entryKey': FieldValue.delete()});
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('“$titulo” eliminado')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
    }
  }

  void _editarEntrada(String entryKey, Map<String, dynamic> value) {
    // Navega a tu editor si lo necesitas:
    // Navigator.pushNamed(context, '/editar-doc', arguments: {'entryKey': entryKey, 'data': value});
    debugPrint('Editar $entryKey → $value');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar1(
        titleSize: TitleSize.big,
        titulo: 'Documentos Creados',
        backgroundColor: Colors.blueAccent,
        textColor: Colors.white,
        hasShadow: false,
        leftAction: LeftAction.back,
        iconoIzquierda: Icons.arrow_back,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _docRef.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          final data = snap.data?.data() ?? {};
          final documentos = data['documentos'];

          if (documentos is! Map<String, dynamic> || documentos.isEmpty) {
            return const Center(child: Text('No hay documentos.'));
          }

          // ✅ Solo entradas que sean Map (ignora contadorDocumentos y similares)
          final items =
              documentos.entries
                  .where((e) => e.value is Map<String, dynamic>)
                  .map((e) {
                    final key = e.key;
                    final val = e.value as Map<String, dynamic>;
                    final titulo = (val['tituloDoc'] ?? key).toString().trim();
                    return _DocItem(
                      entryKey: key,
                      titulo: titulo.isEmpty ? '(sin título)' : titulo,
                      data: val,
                    );
                  })
                  .toList()
                ..sort(
                  (a, b) =>
                      a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase()),
                );

          if (items.isEmpty) {
            return const Center(child: Text('No hay documentos.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final item = items[i];
              return InfoBox(
                numero: i + 1,
                titulo: item.titulo,
                initialValue: true,
                onToggle: (v) => debugPrint('Toggle $i: $v'),
                actions: [
                  InfoBoxAction(
                    icon: Icons.edit,
                    color: Colors.blue,
                    onTap: () => _editarEntrada(item.entryKey, item.data),
                  ),
                  InfoBoxAction(
                    icon: Icons.delete,
                    color: Colors.redAccent,
                    onTap: () => _eliminarEntrada(item.entryKey, item.titulo),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _DocItem {
  final String entryKey; // p.ej. "doc_1"
  final String titulo;
  final Map<String, dynamic> data;
  _DocItem({required this.entryKey, required this.titulo, required this.data});
}
