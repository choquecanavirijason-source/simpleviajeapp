// lib/features/network/connectivity_gate.dart
import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_modular/flutter_modular.dart';

/// Gate de conectividad:
/// - Si [usePage] = true => navega a /sinconexion con Modular.
/// - Si [usePage] = false => muestra overlay (devuelve un widget "offline").
///   Para overlay debes tener una pantalla offline disponible como widget
///   (puedes crear un NoInternetPage y devolverlo en el build).
class ConnectivityGate extends StatefulWidget {
  const ConnectivityGate({
    super.key,
    required this.child,
    this.checkInterval = const Duration(seconds: 8),
    this.usePage = true,
    this.log = false,
  });

  final Widget child;
  final Duration checkInterval;
  final bool usePage;
  final bool log;

  @override
  State<ConnectivityGate> createState() => _ConnectivityGateState();
}

class _ConnectivityGateState extends State<ConnectivityGate> {
  late final StreamSubscription<List<ConnectivityResult>> _sub;
  bool _online = true;
  bool _pushed = false; // evita doble push
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    // 1) escucha cambios de conectividad (wifi/datos/none)
    _sub = Connectivity().onConnectivityChanged.listen((list) {
      if (widget.log) debugPrint('connectivity: $list');
      _checkAndReact();
    });

    // 2) chequeo inicial tras el primer frame (Navigator/Router listos)
    SchedulerBinding.instance.addPostFrameCallback((_) => _checkAndReact());

    // 3) chequeo periódico por si el stream no emite
    _timer = Timer.periodic(widget.checkInterval, (_) => _checkAndReact());
  }

  Future<bool> _hasRealInternet() async {
    try {
      final res = await InternetAddress.lookup(
        'example.com',
      ).timeout(const Duration(seconds: 3));
      return res.isNotEmpty && res.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _checkAndReact() async {
    final list = await Connectivity().checkConnectivity();
    final hasTransport = list.any((r) => r != ConnectivityResult.none);

    // si no hay transporte, es offline seguro; si hay, verificamos internet real
    final ok = hasTransport ? await _hasRealInternet() : false;

    if (!mounted) return;

    if (_online != ok) {
      setState(() => _online = ok);
    }

    if (!widget.usePage) {
      // Modo overlay: no navegamos, solo reconstruimos
      return;
    }

    // --- Manejo por navegación con Modular ---
    if (!_online && !_pushed) {
      _pushed = true;
      if (widget.log) debugPrint('ConnectivityGate: Modular push /sinconexion');
      // Empuja la ruta de tu pantalla "Sin conexión"
      Modular.to.pushNamed('/sinconexion').then((_) {
        // si el usuario vuelve manualmente, permitimos volver a empujar si falta internet
        _pushed = false;
      });
    } else if (_online && _pushed) {
      // Si volvió internet, cerramos la pantalla si sigue arriba
      if (Modular.to.canPop()) {
        if (widget.log)
          debugPrint('ConnectivityGate: Modular pop /sinconexion');
        Modular.to.pop();
      }
      _pushed = false;
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.usePage) {
      // en modo navegación, solo devolvemos el child
      return widget.child;
    }

    // --- Modo overlay (si lo quieres sin navegación) ---
    // TODO: reemplaza este Container por tu widget de "Sin conexión"
    if (_online) return widget.child;
    return Container(
      color: Colors.white,
      alignment: Alignment.center,
      child: const Text('Sin conexión a internet'),
    );
  }
}
