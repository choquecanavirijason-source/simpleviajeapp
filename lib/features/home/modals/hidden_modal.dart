// lib/shared/widgets/modals/hidden_modal.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:buses2/shared/state/apis_visibility.dart'; // ⬅️ Firebase Auth

Future<Map<String, String>?> showHiddenLoginBottomSheet(
  BuildContext context, {
  String title = 'Acceso avanzado',
}) {
  return showModalBottomSheet<Map<String, String>?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    // ⬇️ evita cierre por swipe y por tocar fuera
    enableDrag: false,
    isDismissible: false,
    builder: (_) => _HiddenLoginSheet(title: title),
  );
}

class _HiddenLoginSheet extends StatefulWidget {
  const _HiddenLoginSheet({required this.title});
  final String title;

  @override
  State<_HiddenLoginSheet> createState() => _HiddenLoginSheetState();
}

class _HiddenLoginSheetState extends State<_HiddenLoginSheet>
    with WidgetsBindingObserver {
  // ✅ Controladores activos
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final _emailFocus = FocusNode();
  final _passFocus = FocusNode();
  late final DraggableScrollableController _dragCtrl;

  bool _obscure = true;
  bool _submitting = false;

  static const double _initialSize = 0.5;
  static const double _minSize = 0.4;
  static const double _maxSize = 0.9;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _dragCtrl = DraggableScrollableController();
    _emailFocus.addListener(_onFocusChange);
    _passFocus.addListener(_onFocusChange);
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    _maybeExpandForKeyboard();
  }

  void _onFocusChange() {
    if (!mounted) return;
    if (_emailFocus.hasFocus || _passFocus.hasFocus) _expandToMax();
  }

  void _maybeExpandForKeyboard() {
    final kb = MediaQuery.of(context).viewInsets.bottom;
    if (kb > 0) _expandToMax();
  }

  void _expandToMax() {
    if (!_dragCtrl.isAttached) return;
    _dragCtrl.animateTo(
      _maxSize,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _emailFocus
      ..removeListener(_onFocusChange)
      ..dispose();
    _passFocus
      ..removeListener(_onFocusChange)
      ..dispose();
    _dragCtrl.dispose();
    super.dispose();
  }

  InputBorder _roundedBorder(Color c) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: c, width: 1.1),
  );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = Theme.of(context).scaffoldBackgroundColor;

    return DraggableScrollableSheet(
      controller: _dragCtrl,
      initialChildSize: _initialSize,
      minChildSize: _minSize,
      maxChildSize: _maxSize,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 18,
                offset: const Offset(0, -6),
              ),
            ],
            border: Border.all(color: Colors.black.withOpacity(0.04)),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [bg, bg.withOpacity(0.96)],
            ),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Material(
              color: Colors.transparent,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 10,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode
                        .onUserInteraction, // ✅ valida al escribir
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 44,
                            height: 5,
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: Colors.black12,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.lock_outline,
                              size: 22,
                              color: cs.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Ingresa tus credenciales para continuar.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.black.withOpacity(0.6),
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Email
                        TextFormField(
                          focusNode: _emailFocus,
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          onTap: _expandToMax,
                          decoration: InputDecoration(
                            labelText: 'Correo electrónico',
                            hintText: 'tucorreo@empresa.com',
                            prefixIcon: const Icon(Icons.alternate_email),
                            enabledBorder: _roundedBorder(Colors.black12),
                            focusedBorder: _roundedBorder(cs.primary),
                            errorBorder: _roundedBorder(Colors.redAccent),
                            focusedErrorBorder: _roundedBorder(
                              Colors.redAccent,
                            ),
                            fillColor: Colors.black.withOpacity(0.02),
                            filled: true,
                          ),
                          validator: (v) {
                            final value = (v ?? '').trim();
                            if (value.isEmpty) return 'Ingresa tu correo';
                            final emailRegex = RegExp(
                              r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                            );
                            if (!emailRegex.hasMatch(value))
                              return 'Correo no válido';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Password
                        TextFormField(
                          focusNode: _passFocus,
                          controller: _passCtrl,
                          obscureText: _obscure,
                          textInputAction: TextInputAction.done,
                          onTap: _expandToMax,
                          onFieldSubmitted: (_) =>
                              _onAccept(), // enter para enviar
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            hintText: '●●●●●●',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              tooltip: _obscure ? 'Mostrar' : 'Ocultar',
                            ),
                            enabledBorder: _roundedBorder(Colors.black12),
                            focusedBorder: _roundedBorder(cs.primary),
                            errorBorder: _roundedBorder(Colors.redAccent),
                            focusedErrorBorder: _roundedBorder(
                              Colors.redAccent,
                            ),
                            fillColor: Colors.black.withOpacity(0.02),
                            filled: true,
                          ),
                          validator: (v) {
                            final value = v ?? '';
                            if (value.isEmpty) return 'Ingresa tu contraseña';
                            if (value.length < 6) return 'Mínimo 6 caracteres';
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancelar'),
                            ),
                            FilledButton.icon(
                              icon: _submitting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.login),
                              onPressed: _submitting ? null : _onAccept,
                              label: const Text('Ingresar'),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            'Solo para personal autorizado',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.black.withOpacity(0.45),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Sign-in con Firebase Auth; si es exitoso, muestra "Apis" y cierra el modal
  Future<void> _onAccept() async {
    if (_formKey.currentState?.validate() != true) return;

    setState(() => _submitting = true);
    try {
      final email = _emailCtrl.text.trim();
      final pass = _passCtrl.text;

      // 🔐 Login contra Firebase Authentication
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: pass,
      );

      // ✅ Acceso concedido: muestra "Apis"
      ApisVisibility.notifier.value = true;

      if (!mounted) return;
      setState(() => _submitting = false);

      // Cierra devolviendo info útil (opcional)
      Navigator.of(
        context,
      ).pop(<String, String>{'email': email, 'status': 'ok'});
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);

      // Códigos que consideramos "no autorizado"
      const unauthorizedCodes = {
        'user-not-found',
        'wrong-password',
        'user-disabled',
      };

      if (unauthorizedCodes.contains(e.code)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No es un usuario autorizado.')),
        );
        return;
      }

      // Otros errores con mensaje genérico/útil
      String msg = 'Error de autenticación';
      switch (e.code) {
        case 'invalid-email':
          msg = 'Correo inválido.';
          break;
        case 'too-many-requests':
          msg = 'Demasiados intentos. Intenta más tarde.';
          break;
        case 'network-request-failed':
          msg = 'Sin conexión. Verifica tu red.';
          break;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ocurrió un error. Intenta nuevamente.')),
      );
    }
  }
}
