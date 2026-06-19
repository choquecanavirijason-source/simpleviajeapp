import 'package:flutter/material.dart';
import '../data/models/servicio_empresa_model.dart';
import '../service/servicios.dart';

class ServiciosDeEmpresa extends StatefulWidget {
  final String departamento;
  final String? pais;
  final Widget Function(BuildContext, AsyncSnapshot<List<ServicioEmpresa>>)
  builder;

  const ServiciosDeEmpresa({
    super.key,
    required this.departamento,
    this.pais,
    required this.builder,
  });

  @override
  State<ServiciosDeEmpresa> createState() => _ServiciosDeEmpresaState();
}

class _ServiciosDeEmpresaState extends State<ServiciosDeEmpresa>
    with AutomaticKeepAliveClientMixin {
  late Future<List<ServicioEmpresa>> _future;

  @override
  void initState() {
    super.initState();
    _future = serviciosDeEmpresaEnDepartamento(
      departamento: widget.departamento,
      pais: widget.pais,
    );
  }

  @override
  void didUpdateWidget(covariant ServiciosDeEmpresa oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.departamento != widget.departamento ||
        oldWidget.pais != widget.pais) {
      _future = serviciosDeEmpresaEnDepartamento(
        departamento: widget.departamento,
        pais: widget.pais,
      );
      setState(() {}); // refresca el FutureBuilder
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // keepAlive
    return FutureBuilder<List<ServicioEmpresa>>(
      future: _future,
      builder: widget.builder,
    );
  }

  @override
  bool get wantKeepAlive => true;
}
