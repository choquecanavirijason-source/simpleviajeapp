import 'package:flutter/material.dart';
import 'package:buses2/features/home_taxi_features/home_taxi/widgets/ride_request_card.dart';

class HeaderPriceBadge extends RideBadge {
  HeaderPriceBadge({super.key, required this.texto, this.onTap})
    : super(
        text: '',
        bg: Colors.transparent,
        fg: Colors.transparent,
        icon: null,
      );

  final String texto;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Text(
      texto,
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w900,
        height: 1,
      ),
    );
    if (onTap == null) return child;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: child,
      ),
    );
  }
}
