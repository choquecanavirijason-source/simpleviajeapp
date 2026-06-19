import 'package:flutter/material.dart';
import 'package:buses2/shared/theme/app_colors.dart';

class TitleSection extends StatelessWidget {
  final String phone; // Guarda el numero y lo muestra
  // Recibe el numero this.phone y se lo pasas a phone
  const TitleSection({Key? key, required this.phone}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final double scale = (screenW / 360).clamp(0.9, 1.2);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center, // Centra horizontalmente
        children: [
          SizedBox(height: 12 * scale),
          Text(
            'Ingrese el código',
            style: TextStyle(fontSize: 20 * scale, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 6 * scale),
          Text(
            'Te enviamos un código a $phone',
            style: TextStyle(
              fontSize: 14 * scale,
              color: AppColors.placeholder,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20 * scale),
        ],
      ),
    );
  }
}
