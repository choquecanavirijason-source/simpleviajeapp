import 'package:flutter/material.dart';
import '../data/taxistas_registrados_data.dart';

class ModalEditarSaldo {
  static Future<double?> show(BuildContext context, TaxistaRegistrado taxista) {
    final formKey = GlobalKey<FormState>();
    final TextEditingController montoCtrl = TextEditingController();

    return showDialog<double>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 30,
            vertical: 24,
          ),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ====== CABECERA ======
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Colors.green,
                        size: 30,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Editar saldo',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),
                  Text(
                    taxista.nombre ?? 'Taxista sin nombre',
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ====== INPUT MONTO ======
                  TextFormField(
                    controller: montoCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Monto (Bs)',
                      labelStyle: const TextStyle(color: Colors.black54),
                      prefixIcon: const Icon(Icons.attach_money_rounded),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Colors.grey,
                          width: 0.6,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Colors.blueAccent,
                          width: 1.2,
                        ),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty)
                        return 'Ingresa un monto';
                      final val = double.tryParse(v);
                      if (val == null) return 'Monto inválido';
                      if (val <= 0) return 'Debe ser mayor a 0';
                      return null;
                    },
                  ),

                  const SizedBox(height: 24),

                  // ====== BOTONES ======
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(
                            Icons.remove_circle_rounded,
                            size: 22,
                          ),
                          label: const Text('Restar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.greenAccent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            if (formKey.currentState?.validate() != true)
                              return;
                            final monto = double.parse(montoCtrl.text);
                            Navigator.pop(
                              context,
                              -monto,
                            ); // 👈 devuelve monto negativo
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.add_circle_rounded, size: 22),
                          label: const Text('Sumar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            if (formKey.currentState?.validate() != true)
                              return;
                            final monto = double.parse(montoCtrl.text);
                            Navigator.pop(
                              context,
                              monto,
                            ); // 👈 devuelve monto positivo
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
