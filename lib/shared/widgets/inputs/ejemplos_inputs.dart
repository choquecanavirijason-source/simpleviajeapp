import 'package:flutter/material.dart';

class InputScreen extends StatefulWidget {
  @override
  _InputScreenState createState() => _InputScreenState();
}

class _InputScreenState extends State<InputScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _multilineController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _postalCodeController = TextEditingController();

  bool _passwordVisible = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Formulario de Inputs')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Correo
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: 'Correo electrónico'),
                validator: (value) {
                  if (value!.isEmpty) return 'Por favor ingresa tu correo';
                  if (!RegExp(r'\S+@\S+\.\S+').hasMatch(value)) {
                    return 'Correo no válido';
                  }
                  return null;
                },
              ),

              // Teléfono
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: 'Teléfono'),
                validator: (value) {
                  if (value!.isEmpty) return 'Por favor ingresa tu teléfono';
                  return null;
                },
              ),

              // Contraseña
              TextFormField(
                controller: _passwordController,
                keyboardType: TextInputType.visiblePassword,
                obscureText: !_passwordVisible,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _passwordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _passwordVisible = !_passwordVisible;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value!.isEmpty) return 'Por favor ingresa tu contraseña';
                  return null;
                },
              ),

              // Multilínea
              TextFormField(
                controller: _multilineController,
                keyboardType: TextInputType.multiline,
                maxLines: null,
                decoration: InputDecoration(labelText: 'Descripción'),
                validator: (value) {
                  if (value!.isEmpty)
                    return 'Por favor ingresa una descripción';
                  return null;
                },
              ),

              // URL
              TextFormField(
                controller: _urlController,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(labelText: 'URL'),
                validator: (value) {
                  if (value!.isEmpty) return 'Por favor ingresa una URL';
                  return null;
                },
              ),

              // Código postal
              TextFormField(
                controller: _postalCodeController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Código Postal'),
                validator: (value) {
                  if (value!.isEmpty)
                    return 'Por favor ingresa un código postal';
                  return null;
                },
              ),

              // Confirmación (campo repetido)
              TextFormField(
                keyboardType: TextInputType.visiblePassword,
                obscureText: true,
                decoration: InputDecoration(labelText: 'Confirmar Contraseña'),
                validator: (value) {
                  if (value != _passwordController.text) {
                    return 'Las contraseñas no coinciden';
                  }
                  return null;
                },
              ),

              // Autocompletar (nombre)
              TextFormField(
                keyboardType: TextInputType.text,
                decoration: InputDecoration(labelText: 'Autocompletar Nombre'),
                autofillHints: [AutofillHints.name],
                validator: (value) {
                  if (value!.isEmpty) return 'Por favor ingresa tu nombre';
                  return null;
                },
              ),

              // Deshabilitado
              TextFormField(
                enabled: false,
                decoration: InputDecoration(labelText: 'Campo Deshabilitado'),
              ),

              // Solo lectura
              TextFormField(
                readOnly: true,
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Solo lectura'),
              ),

              // Buscar
              TextFormField(
                keyboardType: TextInputType.text,
                decoration: InputDecoration(
                  labelText: 'Buscar',
                  prefixIcon: Icon(Icons.search),
                ),
                validator: (value) {
                  if (value!.isEmpty)
                    return 'Por favor ingresa algo para buscar';
                  return null;
                },
              ),

              // Botón para enviar formulario
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Formulario enviado')),
                      );
                    }
                  },
                  child: Text('Enviar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
