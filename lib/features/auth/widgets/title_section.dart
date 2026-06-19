import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TitleSection extends StatelessWidget {
  const TitleSection({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final double scale = (screenW / 360).clamp(0.9, 1.2);

    return Column(
      children: [
        Center(
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: GoogleFonts.poppins(
                fontSize: 22 * scale,
                fontWeight: FontWeight.bold,
              ),
              children: const [
                TextSpan(
                  text: 'Simple ',
                  style: TextStyle(color: Color(0xFF00359D)),
                ),
                TextSpan(
                  text: 'Viaje',
                  style: TextStyle(color: Color(0xFF2CAC3F)),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 8 * scale),
        Center(
          child: Text(
            'Un servicio creado para acompañarte en cada trayecto con verificación y control.',
            style: GoogleFonts.poppins(
              fontSize: 14 * scale,
              color: const Color(0xFF757575),
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(height: 12 * scale),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Prioridad a conductoras y personal autorizado por la empresa.',
              style: GoogleFonts.poppins(
                fontSize: 14 * scale,
                color: const Color(0xFF757575),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}
