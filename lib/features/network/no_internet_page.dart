import 'dart:io';
import 'package:flutter/material.dart';

const kBrandGreen = Color(0xFF4CB050);

class NoInternetPage extends StatefulWidget {
  const NoInternetPage({super.key, this.onRetry});

  final Future<bool> Function()? onRetry;

  @override
  State<NoInternetPage> createState() => _NoInternetPageState();
}

class _NoInternetPageState extends State<NoInternetPage> {
  bool _checking = false;
  String _msg = 'Sin conexión a internet';

  Future<void> _retry() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _msg = 'Verificando conexión...';
    });

    bool ok = false;
    try {
      final result = await InternetAddress.lookup(
        'example.com',
      ).timeout(const Duration(seconds: 3));
      ok = result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      ok = false;
    }

    if (!mounted) return;

    if (ok) {
      Navigator.of(context).maybePop(); // cerramos si fue presentada via push
    } else {
      setState(() {
        _msg = 'Aún sin conexión';
      });
    }

    setState(() => _checking = false);
    // si alguien pasó un callback, también lo invocamos
    if (widget.onRetry != null) {
      await widget.onRetry!.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo / marca
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kBrandGreen.withOpacity(.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.wifi_off, size: 80, color: kBrandGreen),
                ),
                const SizedBox(height: 20),
                Text(
                  'Tropical',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _msg,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                Text(
                  'Revisa tus datos móviles o Wi-Fi.\n'
                  'Cuando recuperes la conexión podrás seguir usando la app.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.black54,
                    height: 1.25,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _checking ? null : _retry,
                    icon: _checking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: Text(_checking ? 'Verificando...' : 'Reintentar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kBrandGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextButton.icon(
                  onPressed: _checking ? null : _retry,
                  icon: const Icon(Icons.signal_cellular_alt_2_bar),
                  label: const Text('Probar de nuevo'),
                  style: TextButton.styleFrom(foregroundColor: cs.primary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
