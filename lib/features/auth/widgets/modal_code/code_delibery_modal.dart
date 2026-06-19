// Boton Enviar Codigo, cuando se apreta.
// sale un modal debajo de la pantalla con 2 botones
// recibir codigo por sms o whatsapp

import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:buses2/shared/theme/app_buttons_styles.dart';

void showCodeDeliveryModal(BuildContext context, String phone) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '¿Cómo quieres recibir el código?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            // ✅ Recibir por WhatsApp
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Modular.to.pushNamed('/verify-code', arguments: phone);
                },
                icon: Image.asset(
                  'assets/icon/whatsapp.png',
                  height: 24,
                  width: 24,
                ),
                label: const Text('Recibir por WhatsApp'),
              ),
            ),
            const SizedBox(height: 12),

            // ✅ Recibir por SMS
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Modular.to.pushNamed('/verify-code', arguments: phone);
                },
                icon: const Icon(Icons.sms),
                label: const Text('Recibir por SMS'),
                style: ButtonStyles.boton3,
              ),
            ),
          ],
        ),
      );
    },
  );
}
