import 'package:flutter/material.dart';
import 'package:buses2/shared/theme/app_colors.dart';

class NumericKeyboard extends StatelessWidget {
  final void Function(String) onKeyTap;

  const NumericKeyboard({super.key, required this.onKeyTap});

  @override
  Widget build(BuildContext context) {
    final buttons = [
      '1', '2', '3',
      '4', '5', '6',
      '7', '8', '9',
      'AUTO', '0', 'Borrar', // Última fila: AUTO, 0, Borrar
    ];

    return Container(
      color: AppColors.fondoTeclado,
      padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 5),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: buttons.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 5,
          mainAxisSpacing: 5,
          childAspectRatio: 1.65,
        ),
        itemBuilder: (context, index) {
          final label = buttons[index];
          final isAction = label == 'AUTO' || label == 'Borrar';

          return InkWell(
            onTap: () {
              if (label != 'AUTO') {
                onKeyTap(label);
              }
              // Aquí puedes agregar futura animación para AUTO
            },
            borderRadius: BorderRadius.circular(25),
            splashColor: AppColors.teclaPresioanda,
            child: Container(
              decoration: BoxDecoration(
                color: isAction
                    ? AppColors.fondoTeclaEspecial
                    : AppColors.fondoTecla,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: Center(
                child: label == 'Borrar'
                    ? Icon(
                        Icons.backspace_outlined,
                        size: 24,
                        color: AppColors.error,
                      ) // Ícono borrar
                    : label == 'AUTO'
                    ? Icon(
                        Icons.directions_car,
                        size: 24,
                        color: Colors.blue,
                      ) // Icono auto
                    : Text(
                        label,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}
