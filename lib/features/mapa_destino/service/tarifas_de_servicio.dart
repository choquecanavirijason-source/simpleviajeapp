import 'package:flutter/material.dart';
import '../service/tarifas.dart';

class TarifasDeServicio extends StatefulWidget {
  final String empresaId;
  final String departamento;
  final String servicio;
  final Widget Function(BuildContext, AsyncSnapshot<Tarifa?>) builder;
  const TarifasDeServicio({
    super.key,
    required this.empresaId,
    required this.departamento,
    required this.servicio,
    required this.builder,
  });

  @override
  State<TarifasDeServicio> createState() => _TarifasDeServicioState();
}

class _TarifasDeServicioState extends State<TarifasDeServicio>
    with AutomaticKeepAliveClientMixin {
  late Future<Tarifa?> _future;

  @override
  void initState() {
    super.initState();
    _future = tarifaDeServicioEnDepartamento(
      empresaId: widget.empresaId,
      departamento: widget.departamento,
      servicio: widget.servicio,
    );
  }

  @override
  void didUpdateWidget(covariant TarifasDeServicio old) {
    super.didUpdateWidget(old);
    if (old.empresaId != widget.empresaId ||
        old.departamento != widget.departamento ||
        old.servicio != widget.servicio) {
      _future = tarifaDeServicioEnDepartamento(
        empresaId: widget.empresaId,
        departamento: widget.departamento,
        servicio: widget.servicio,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // keepAlive
    return FutureBuilder<Tarifa?>(future: _future, builder: widget.builder);
  }

  @override
  bool get wantKeepAlive => true;
}
