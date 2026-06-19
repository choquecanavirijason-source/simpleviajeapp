import 'package:flutter/material.dart';
import 'package:buses2/features/home_taxi_features/home_taxi/widgets/ride_request_card.dart';

class HeaderBadgeButton extends RideBadge {
  HeaderBadgeButton({
    required this.buttonIcon,
    required this.onPressed,
    super.key,
  }) : super(
         text: '',
         bg: Colors.transparent,
         fg: Colors.transparent,
         icon: null,
       );

  final IconData buttonIcon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      width: 32,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: const CircleBorder(),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        child: Icon(buttonIcon, size: 18),
      ),
    );
  }
}
