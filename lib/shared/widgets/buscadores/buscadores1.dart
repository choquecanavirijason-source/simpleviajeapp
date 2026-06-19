import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------------
/// Buscador1 — Campo con título integrado dentro del input (estilo Uber)
/// ---------------------------------------------------------------------------
class Buscador1 extends StatefulWidget {
  final String? titulo;
  final String? textoInicial;
  final IconData iconoBuscador;
  final Color colorCajaIconoBuscador;
  final String hintText;
  final String textoBoton;
  final Color colorCajaBoton;
  final Color colorTextoBoton;
  final VoidCallback? onBotonPressed;
  final Color colorIconoBuscador;
  final ValueChanged<String>? onChanged;

  const Buscador1({
    super.key,
    this.titulo,
    this.textoInicial,
    this.iconoBuscador = Icons.search,
    this.colorCajaIconoBuscador = const Color(0xFFD6D6D6),
    this.hintText = 'Buscar...',
    this.textoBoton = 'Mapa',
    this.colorCajaBoton = Colors.greenAccent,
    this.colorTextoBoton = Colors.black,
    this.onBotonPressed,
    this.colorIconoBuscador = Colors.white,
    this.onChanged,
  });

  @override
  State<Buscador1> createState() => _Buscador1State();
}

class _Buscador1State extends State<Buscador1> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  bool _mostrarX = false;
  bool _mostrarMapa = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.textoInicial ?? '');
    _mostrarX = (widget.textoInicial?.isNotEmpty ?? false);
    _focusNode.addListener(() {
      setState(() => _mostrarMapa = _focusNode.hasFocus);
    });
  }

  @override
  void didUpdateWidget(covariant Buscador1 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.textoInicial != oldWidget.textoInicial) {
      final newText = widget.textoInicial ?? '';
      if (_controller.text != newText) {
        _controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newText.length),
        );
        setState(() {
          _mostrarX = newText.isNotEmpty;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        // 🔹 Campo principal
        TextField(
          focusNode: _focusNode,
          controller: _controller,
          style: const TextStyle(
            fontSize: 16,
            height: 1.3,
            color: Colors.black,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            hintText: widget.hintText,
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 16),
            prefixIcon: Container(
              width: 46,
              height: 46,
              margin: const EdgeInsets.only(left: 0, right: 8),
              decoration: BoxDecoration(
                color: widget.colorCajaIconoBuscador,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                widget.iconoBuscador,
                color: widget.colorIconoBuscador,
                size: 26,
              ),
            ),

            // 🔹 X + botón derecho (Mapa)
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_mostrarX)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black45),
                    onPressed: () {
                      _controller.clear();
                      setState(() => _mostrarX = false);
                    },
                  ),
                if (_mostrarMapa)
                  Container(
                    decoration: BoxDecoration(
                      color: widget.colorCajaBoton,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.only(right: 0),
                    child: TextButton(
                      onPressed:
                          widget.onBotonPressed ??
                          () => debugPrint(
                            'Botón "${widget.textoBoton}" presionado',
                          ),
                      child: Text(
                        widget.textoBoton,
                        style: TextStyle(
                          color: widget.colorTextoBoton,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide.none,
            ),
            enabledBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide.none,
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.fromLTRB(0, 18, 10, 10),
          ),
          onChanged: (value) {
            setState(() => _mostrarX = value.isNotEmpty);
            if (widget.onChanged != null) {
              widget.onChanged!(value);
            }
          },
        ),

        // 🔹 Título flotante dentro del campo (estilo Uber)
        if (widget.titulo != null)
          Positioned(
            left: 53,
            top: -2,
            child: Text(
              widget.titulo!,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black54,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
      ],
    );
  }
}

/// ---------------------------------------------------------------------------
/// BuscadoresBox — Contenedor externo con sombra y borde
/// ---------------------------------------------------------------------------
class BuscadoresBox extends StatelessWidget {
  final List<Widget> buscadores;

  const BuscadoresBox({super.key, required this.buscadores});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade400, width: 0.6),
        boxShadow: const [
          BoxShadow(
            color: Color.fromARGB(80, 0, 0, 0),
            offset: Offset(0, 3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: buscadores),
    );
  }
}

/* Ejemplo de uso:
BuscadoresBox(
  buscadores: [
    Buscador1(
      titulo: 'Punto de partida',
      hintText: 'Origen...',
      iconoBuscador: Icons.location_on,
      colorCajaIconoBuscador: Colors.green,
      colorIconoBuscador: Colors.white,
      textoBoton: 'Mapa',
      colorCajaBoton: Colors.red,
      colorTextoBoton: Colors.white,
      onBotonPressed: () => print('Origen'),
    ),
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Divider(height: 1, color: Colors.black54),
    ),
    Buscador1(
      titulo: 'Destino',
      hintText: 'Destino...',
      iconoBuscador: Icons.flag,
      colorCajaIconoBuscador: Colors.red,
      colorIconoBuscador: Colors.white,
      textoBoton: 'Mapa',
      colorCajaBoton: Colors.red,
      colorTextoBoton: Colors.white,
      onBotonPressed: () => print('Destino'),
    ),
  ],
),
*/
