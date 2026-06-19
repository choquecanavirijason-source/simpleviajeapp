import 'dart:async';
import 'package:flutter/material.dart';
import 'package:buses2/shared/theme/app_colors.dart';

class CursorInput extends StatefulWidget {
  final double height;
  final Color color;
  final EdgeInsets margin;

  const CursorInput({
    super.key,
    this.height = 20,
    this.color = AppColors.cursor,
    this.margin = const EdgeInsets.symmetric(horizontal: 2),
  });

  @override
  State<CursorInput> createState() => _CursorInputState();
}

class _CursorInputState extends State<CursorInput> {
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _startBlinking();
  }

  void _startBlinking() {
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted) return timer.cancel();
      setState(() {
        _visible = !_visible;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: _visible,
      child: Container(
        margin: widget.margin,
        width: 2,
        height: widget.height,
        color: widget.color,
      ),
    );
  }
}
