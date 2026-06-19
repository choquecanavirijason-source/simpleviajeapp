import 'package:flutter/material.dart';

class ImgAvatar extends StatelessWidget {
  final String initial;
  final double radius;

  const ImgAvatar({super.key, this.initial = 'M', this.radius = 50});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 30),
        Center(
          child: CircleAvatar(
            radius: radius,
            backgroundColor: Colors.grey.shade300,
            child: Text(
              initial,
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}
