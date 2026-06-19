import 'package:flutter/material.dart';
import 'package:buses2/shared/widgets/app_bar/app_bar.dart';
import './widgets/card.dart';
import 'widgets/detalles.dart';

// Modelo + Repo
import './data/taxistas_registrados_data.dart';

class TaxistasRegistradosPage extends StatefulWidget {
  const TaxistasRegistradosPage({super.key});

  @override
  State<TaxistasRegistradosPage> createState() =>
      _TaxistasRegistradosPageState();
}

class _TaxistasRegistradosPageState extends State<TaxistasRegistradosPage> {
  List<TaxistaRegistrado> _taxistas = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final lista = await TaxistasRegistradosRepo.traerDeEmpresaEstatica();
    if (!mounted) return;
    setState(() {
      _taxistas = lista;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar1(
        titleSize: TitleSize.big,
        titulo: 'Taxistas Registrados',
        backgroundColor: Colors.green,
        textColor: Colors.white,
        hasShadow: false,
        leftAction: LeftAction.back,
        iconoIzquierda: Icons.arrow_back,
        iconoDerecha: Icons.settings,
        onTapDerecha: () => debugPrint('Ajustes'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _taxistas.length,
              separatorBuilder: (_, __) => const SizedBox(height: 0),
              itemBuilder: (context, i) {
                // Obtener taxista
                final taxista = _taxistas[i];
                return TaxistaCard(
                  nombre: taxista.nombre?.trim().isNotEmpty == true
                      ? taxista.nombre
                      : null,
                  //telefono: (taxista.telefono ?? '').trim().isNotEmpty ? taxista.telefono : null,
                  estado: (taxista.estado ?? '').trim().isNotEmpty
                      ? taxista.estado
                      : 'sin datos',
                  fotoUrl: taxista.fotoPerfil?.trim().isNotEmpty == true
                      ? taxista.fotoPerfil
                      : null,
                  onVerDetalles: () {
                    final taxista = _taxistas[i]; // 👈 el objeto actual

                    // 🔹 Enviar el taxista como argumento
                    DetallesTaxistaPage.show(context, taxista: taxista);
                  },
                );
              },
            ),
    );
  }
}
