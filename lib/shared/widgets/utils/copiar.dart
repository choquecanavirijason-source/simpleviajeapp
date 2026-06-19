// core/widgets/utilsReusables/copiar.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CopiarIcono extends StatelessWidget {
  final String texto;

  const CopiarIcono({Key? key, required this.texto}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: texto));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Copiado al portapapeles')),
        );
      },
      child: const Icon(Icons.copy, size: 20, color: Colors.black54),
    );
  }
}
