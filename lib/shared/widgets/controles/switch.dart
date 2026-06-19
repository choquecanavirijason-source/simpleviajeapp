import 'package:flutter/material.dart';

class Switch1 extends StatefulWidget {
  final bool initialValue;
  final ValueChanged<bool>? onChanged;
  final Color activeColor;

  const Switch1({
    super.key,
    this.initialValue = true,
    this.onChanged,
    this.activeColor = Colors.blueAccent,
  });

  @override
  State<Switch1> createState() => _Switch1State();
}

class _Switch1State extends State<Switch1> {
  late bool _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  void _toggle(bool newValue) {
    setState(() {
      _value = newValue;
    });
    if (widget.onChanged != null) {
      widget.onChanged!(newValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 25,
      width: 30, // 👈 ajusta según quieras (lo mínimo para el switch)
      child: Switch.adaptive(
        value: _value,
        activeColor: widget.activeColor,
        onChanged: _toggle,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

/* Ejemplos de uso:
Switch1(
  initialValue: false,
  activeColor: Colors.green,
  //onChanged: (v) => debugPrint("Material: $v"),
),
*/

class Switch2 extends StatefulWidget {
  final bool initialValue;
  final ValueChanged<bool>? onChanged;
  final Color activeColor;
  final Color inactiveColor;

  const Switch2({
    super.key,
    this.initialValue = true,
    this.onChanged,
    this.activeColor = Colors.blueAccent,
    this.inactiveColor = Colors.grey,
  });

  @override
  State<Switch2> createState() => _Switch2State();
}

class _Switch2State extends State<Switch2> {
  late bool _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  void _toggle() {
    setState(() => _value = !_value);
    widget.onChanged?.call(_value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 50,
        height: 28,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: _value ? widget.activeColor : widget.inactiveColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: _value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* Ejemplos de uso:
Switch2(
  initialValue: true,
  activeColor: Colors.green,
  inactiveColor: Colors.redAccent,
  //onChanged: (v) => debugPrint("Pill: $v"),
),
*/

class Switch3 extends StatefulWidget {
  final bool initialValue;
  final ValueChanged<bool>? onChanged;
  final List<Color> activeGradient;
  final List<Color> inactiveGradient;

  const Switch3({
    super.key,
    this.initialValue = true,
    this.onChanged,
    this.activeGradient = const [Colors.green, Colors.lightGreen],
    this.inactiveGradient = const [Colors.grey, Colors.black26],
  });

  @override
  State<Switch3> createState() => _Switch3State();
}

class _Switch3State extends State<Switch3> {
  late bool _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  void _toggle() {
    setState(() => _value = !_value);
    widget.onChanged?.call(_value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        width: 60,
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _value ? widget.activeGradient : widget.inactiveGradient,
          ),
          borderRadius: BorderRadius.circular(30),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          alignment: _value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Icon(
              _value ? Icons.check : Icons.close,
              size: 16,
              color: _value ? Colors.green : Colors.redAccent,
              shadows: [
                Shadow(
                  color: _value ? Colors.green : Colors.redAccent,
                  blurRadius: 1.5,
                ),
                Shadow(
                  color: _value ? Colors.green : Colors.redAccent,
                  blurRadius: 1.5,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* Ejemplos de uso:
Switch3(
  initialValue: false,
  activeGradient: [Colors.blue, Colors.lightBlueAccent],
  inactiveGradient: [Colors.grey, Colors.black26],
  onChanged: (v) => debugPrint("Switch3: $v"),
),
--- OTRA FORMA DE USARLO ---
Switch3(),
*/
