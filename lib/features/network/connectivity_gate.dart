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

class _ConnectivityGateState extends State<ConnectivityGate>
    with WidgetsBindingObserver {
  late final StreamSubscription<List<ConnectivityResult>> _sub;
  bool _online = true;
  bool _pushed = false;
  bool _inForeground = true;
  Timer? _periodicTimer;
  // Debounce: absorbs momentary drops (background WiFi power-save, brief blips).
  // The offline page is only shown after this window passes with no recovery.
  Timer? _debounce;
  static const _debounceDuration = Duration(seconds: 3);
  // Grace period on app-resume: gives the OS time to reconnect WiFi before
  // we run a check, preventing a false /sinconexion flash on every open.
  static const _resumeGrace = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Stream: debounce each change to swallow momentary drops.
    _sub = Connectivity().onConnectivityChanged.listen((list) {
      if (widget.log) debugPrint('connectivity change: $list');
      _scheduleCheck();
    });

    // Initial check after first frame (Navigator/Router ready).
    SchedulerBinding.instance
        .addPostFrameCallback((_) => _checkAndReact());

    // Periodic fallback (only runs while app is in foreground).
    _startPeriodicTimer();
  }

  void _startPeriodicTimer() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(widget.checkInterval, (_) {
      if (_inForeground) _checkAndReact();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _inForeground = true;
      // After resume, wait for the OS to restore WiFi before checking.
      Future.delayed(_resumeGrace, () {
        if (mounted) _checkAndReact();
      });
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _inForeground = false;
      // Cancel any pending debounce so a background drop never triggers push.
      _debounce?.cancel();
    }
  }

  // Called by the connectivity stream: waits [_debounceDuration] before
  // actually reacting, so momentary drops are ignored.
  void _scheduleCheck() {
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, () {
      if (mounted && _inForeground) _checkAndReact();
    });
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
    final ok = hasTransport ? await _hasRealInternet() : false;

    if (!mounted) return;

    if (_online != ok) {
      setState(() => _online = ok);
    }

    if (!widget.usePage) return;

    if (!_online && !_pushed) {
      _pushed = true;
      if (widget.log) debugPrint('ConnectivityGate: push /sinconexion');
      Modular.to.pushNamed('/sinconexion').then((_) {
        _pushed = false;
      });
    } else if (_online && _pushed) {
      if (Modular.to.canPop()) {
        if (widget.log) debugPrint('ConnectivityGate: pop /sinconexion');
        Modular.to.pop();
      }
      _pushed = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub.cancel();
    _periodicTimer?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.usePage) return widget.child;
    if (_online) return widget.child;
    return Container(
      color: Colors.white,
      alignment: Alignment.center,
      child: const Text('Sin conexión a internet'),
    );
  }
}
