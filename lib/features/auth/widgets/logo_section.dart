import 'package:flutter/material.dart';

class LogoSection extends StatelessWidget {
  const LogoSection({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final double logoWidth = (screenW * 0.85).clamp(240.0, 420.0);
    final double logoHeight = (logoWidth / 1.5).clamp(140.0, 260.0);
    return Center(
      child: Container(
        width: logoWidth,
        height: logoHeight,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.asset(
            'assets/images/icono_oficial_simple.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
